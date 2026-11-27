import Foundation

/// Binds native checkpoints to the terminal scene they came from. Only registered
/// commands may construct a resume invocation; saved shell text is never replayed.
final class InteractiveCommandRestoration: @unchecked Sendable {
    private struct Rule: Sendable {
        let accepts: @Sendable ([Substring]) -> Bool
        let resume: @Sendable (String) -> String?
    }

    private static let rules = [
        "codex": Rule(accepts: { arguments in
            arguments.isEmpty || (arguments.count == 2 && arguments[0] == "resume"
                                  && UUID(uuidString: String(arguments[1])) != nil)
        }, resume: { token in
            guard UUID(uuidString: token) != nil else { return nil }
            return "codex resume \(token.lowercased())"
        })
    ]
    private static let notification = Notification.Name("AsheKube.app.a-Shell.InteractiveCommandCheckpoint")

    private let lock = NSLock()
    private var terminalContext: UInt?
    private var checkpoint: [String: String]?
    private var observer: NSObjectProtocol?

    init() {
        observer = NotificationCenter.default.addObserver(forName: Self.notification, object: nil, queue: nil) { [weak self] notification in
            guard let self, let context = notification.userInfo?["context"] as? UInt,
                  let command = notification.userInfo?["command"] as? String,
                  let rule = Self.rules[command] else { return }
            self.lock.withLock {
                guard self.terminalContext == context else { return }
                if let token = notification.userInfo?["token"] as? String, rule.resume(token) != nil {
                    self.checkpoint = ["command": command, "token": token]
                } else if self.checkpoint?["command"] == command {
                    self.checkpoint = nil
                }
            }
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    func bind(to context: UnsafeRawPointer?) {
        lock.withLock {
            terminalContext = context.map { UInt(bitPattern: $0) }
            checkpoint = nil
        }
    }

    static func checkpointURL(for sceneIdentifier: String) -> URL? {
        guard let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
              let name = sceneIdentifier.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else { return nil }
        return directory.appendingPathComponent("InteractiveCommandRestoration", isDirectory: true)
            .appendingPathComponent(name + ".plist")
    }

    func save(to file: URL, runningCommand: String) {
        let arguments = runningCommand.split(whereSeparator: \.isWhitespace)
        guard let command = arguments.first.map(String.init),
              let rule = Self.rules[command], rule.accepts(Array(arguments.dropFirst())),
              let checkpoint = lock.withLock({ checkpoint }), checkpoint["command"] == command else {
            Self.discard(at: file)
            return
        }
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try PropertyListEncoder().encode(checkpoint).write(to: file, options: .atomic)
        } catch {
            Self.discard(at: file)
            NSLog("Could not save interactive command checkpoint")
        }
    }

    static func consume(from file: URL) -> String? {
        guard let data = try? Data(contentsOf: file), discard(at: file),
              let checkpoint = try? PropertyListDecoder().decode([String: String].self, from: data),
              let command = checkpoint["command"], let token = checkpoint["token"] else { return nil }
        return rules[command]?.resume(token)
    }

    // The previous UIKit restoration snapshot can survive SIGKILL even after command exit.
    // Keep this one-shot checkpoint separate so completion can remove it before showing the prompt.
    @discardableResult
    static func discard(at file: URL) -> Bool {
        do {
            try FileManager.default.removeItem(at: file)
            return true
        } catch CocoaError.fileNoSuchFile {
            return false
        } catch {
            NSLog("Could not remove interactive command checkpoint")
            return false
        }
    }
}
