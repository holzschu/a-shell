import ExtensionFoundation
import Foundation

@available(iOS 26.0, *)
extension AppExtensionPoint {
    @Definition
    static var shellWorker: AppExtensionPoint { Name("ShellWorker") }
}

// Concurrent workers: the user's "worker_limit" setting (0 or unset = automatic, the physical
// core count), never more than the bundled ShellWorkerCount extensions. 0 means no workers.
enum ShellWorkerCapacity {
    static var bundled: Int {
        let configured = Bundle.main.object(forInfoDictionaryKey: "ShellWorkerCount")
        return (configured as? NSNumber)?.intValue ?? Int(configured as? String ?? "") ?? 0
    }

    static var physicalCores: Int {
        var count: Int32 = 0
        var size = MemoryLayout<Int32>.size
        return sysctlbyname("hw.physicalcpu", &count, &size, nil, 0) == 0 ? Int(count) : 1
    }

    static var current: Int {
        let requested = UserDefaults.standard.integer(forKey: "worker_limit")
        return min(requested > 0 ? requested : physicalCores, bundled)
    }
}

@_cdecl("ashell_extension_capacity")
func shellExtensionCapacity() -> Int32 { Int32(ShellWorkerCapacity.current) }

// Process lifetime and discovery belong to MainActor. Blocking C ABI calls wait
// only on the calling runner thread, never on the UI actor.
@available(iOS 26.0, *)
@MainActor
final class ShellWorkerPool {
    static let shared = ShellWorkerPool()
    private enum Slot {
        case launching(UUID)
        case connected(UUID, AppExtensionProcess, NSXPCConnection, DispatchSourceProcess?)
        case retiring(UUID, DispatchSourceProcess?)

        var generation: UUID {
            switch self {
            case .launching(let generation), .connected(let generation, _, _, _), .retiring(let generation, _): generation
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
            let capacity = ShellWorkerCapacity.current
            if capacity > 0 && slots.count >= capacity {
                if slots.values.contains(where: { if case .retiring = $0 { return true }; return false }) {
                    try await Task.sleep(for: .milliseconds(100))
                    continue
                }
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
                            // A connected worker is retired using its spawn-reply PID.
                            if case .launching = self.slots[key] {
                                self.slots.removeValue(forKey: key)
                            }
                        }
                    }))
                    guard slots[key]?.generation == generation else {
                        process.invalidate()
                        throw CancellationError()
                    }
                    let connection = try process.makeXPCConnection()
                    connection.exportedInterface = NSXPCInterface(with: AShellSpawnBrokerWire.self)
                    connection.exportedObject = ashell_spawn_broker()
                    slots[key] = .connected(generation, process, connection, nil)
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

    func observe(_ connection: NSXPCConnection, pid: pid_t, registered: @escaping () -> Void) {
        for (key, slot) in slots {
            guard case .connected(let generation, let process, let stored, nil) = slot, stored === connection else { continue }
            let exit = DispatchSource.makeProcessSource(identifier: pid, eventMask: .exit, queue: .main)
            slots[key] = .connected(generation, process, connection, exit)
            exit.setEventHandler { [weak self] in
                Task { @MainActor in
                    guard let self, let current = self.slots[key], current.generation == generation else { return }
                    let source: DispatchSourceProcess?
                    switch current {
                    case .connected(_, _, _, let value), .retiring(_, let value): source = value
                    case .launching: return
                    }
                    source?.cancel()
                    connection.invalidate()
                    process.invalidate()
                    self.slots.removeValue(forKey: key)
                }
            }
            // Arm observation while the admitted process is still alive.
            exit.setRegistrationHandler(handler: registered)
            exit.resume()
            return
        }
        registered()
    }

    func disconnect(_ connection: NSXPCConnection) {
        for (key, slot) in slots {
            guard case .connected(let generation, let process, let stored, let exit) = slot, stored === connection else { continue }
            if exit == nil {
                connection.invalidate()
                process.invalidate()
                slots.removeValue(forKey: key)
                return
            }
            slots[key] = .retiring(generation, exit)
            // Keep the process assertion until exit, with a deadline if observation fails.
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                guard case .retiring(let current, let source) = self.slots[key], current == generation else { return }
                source?.cancel()
                connection.invalidate()
                process.invalidate()
                self.slots.removeValue(forKey: key)
            }
            return
        }
    }
}

@_cdecl("ashell_extension_observe")
func shellExtensionObserve(_ connection: NSXPCConnection, _ pid: pid_t) {
    if #available(iOS 26.0, *), pid > 0 {
        let registered = DispatchSemaphore(value: 0)
        Task { @MainActor in
            ShellWorkerPool.shared.observe(connection, pid: pid) { registered.signal() }
        }
        _ = registered.wait(timeout: .now() + 1)
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
