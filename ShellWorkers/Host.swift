import ExtensionFoundation
import Foundation

@available(iOS 26.0, *)
extension AppExtensionPoint {
    @Definition
    static var shellWorker: AppExtensionPoint { Name("ShellWorker") }
}

// Process lifetime and discovery belong to MainActor. Blocking C ABI calls wait
// only on the calling runner thread, never on the UI actor.
@available(iOS 26.0, *)
@MainActor
final class ShellWorkerPool {
    static let shared = ShellWorkerPool()
    private enum Slot {
        case launching(UUID)
        case connected(UUID, AppExtensionProcess, NSXPCConnection)

        var generation: UUID {
            switch self {
            case .launching(let generation), .connected(let generation, _, _): generation
            }
        }
    }
    private var slots: [String: Slot] = [:]

    func connect() async throws -> NSXPCConnection {
        guard Bundle.main.object(forInfoDictionaryKey: "ShellWorkerCount") != nil else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(ENOTSUP))
        }
        let monitor = try await AppExtensionPoint.Monitor(appExtensionPoint: .shellWorker)
        for _ in 0..<100 {
            let configured = Bundle.main.object(forInfoDictionaryKey: "ShellWorkerCount")
            let capacity = (configured as? NSNumber)?.intValue ?? Int(configured as? String ?? "") ?? 0
            if capacity > 0 && slots.count >= capacity {
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(ENOSPC), userInfo: [NSLocalizedDescriptionKey: "All shell workers are in use. Close a pane before opening another."])
            }
            if let identity = monitor.identities.sorted(by: { $0.bundleIdentifier < $1.bundleIdentifier }).first(where: { slots[$0.bundleIdentifier] == nil }) {
                let key = identity.bundleIdentifier
                let generation = UUID()
                slots[key] = .launching(generation)
                do {
                    let process = try await AppExtensionProcess(configuration: .init(appExtensionIdentity: identity, onInterruption: {
                        Task { @MainActor in
                            guard self.slots[key]?.generation == generation else { return }
                            self.slots.removeValue(forKey: key)
                        }
                    }))
                    guard slots[key]?.generation == generation else {
                        process.invalidate()
                        throw CancellationError()
                    }
                    let connection = try process.makeXPCConnection()
                    slots[key] = .connected(generation, process, connection)
                    return connection
                } catch {
                    if slots[key]?.generation == generation { slots.removeValue(forKey: key) }
                    throw error
                }
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(ETIMEDOUT), userInfo: [NSLocalizedDescriptionKey: "shell worker discovery timed out"])
    }

    func disconnect(_ connection: NSXPCConnection) {
        for (key, slot) in slots {
            guard case .connected(_, let process, let stored) = slot, stored === connection else { continue }
            // Explicit invalidation does not guarantee an interruption callback.
            // Release the reservation in this MainActor transaction; generation
            // checks keep a late callback from removing a replacement process.
            connection.invalidate()
            process.invalidate()
            slots.removeValue(forKey: key)
            return
        }
    }
}

@_cdecl("ashell_extension_disconnect")
func shellExtensionDisconnect(_ connection: NSXPCConnection) {
    if #available(iOS 26.0, *) {
        Task { @MainActor in ShellWorkerPool.shared.disconnect(connection) }
    }
}

@_cdecl("ashell_extension_connect")
func shellExtensionConnect(_ callback: @escaping @convention(block) (NSXPCConnection?, NSError?) -> Void) {
    guard #available(iOS 26.0, *) else {
        callback(nil, NSError(domain: NSPOSIXErrorDomain, code: Int(ENOTSUP)))
        return
    }
    Task { @MainActor in
        do { callback(try await ShellWorkerPool.shared.connect(), nil) }
        catch { callback(nil, error as NSError) }
    }
}
