import Foundation

@main
struct RestorationContract {
    static func main() {
        let scene = InteractiveCommandRestoration()
        scene.bind(to: UnsafeRawPointer(bitPattern: 1))
        let otherScene = InteractiveCommandRestoration()
        otherScene.bind(to: UnsafeRawPointer(bitPattern: 2))
        let thread = "c122cba2-0e43-4f31-9954-13075b990cd1"
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("scene.plist")
        let otherFile = directory.appendingPathComponent("other-scene.plist")

        let defaults = UserDefaults.standard
        func setPreferences(restart: Bool, scrollback: Bool) {
            defaults.setVolatileDomain(["restart_vim": restart, "keep_content": scrollback],
                                       forName: UserDefaults.argumentDomain)
        }

        publish(thread)
        setPreferences(restart: true, scrollback: false)
        scene.save(to: file, runningCommand: "codex")
        precondition(InteractiveCommandRestoration.consume(from: file) == "codex resume \(thread)",
                     "Restart on must resume Codex even when scrollback is off")

        scene.save(to: file, runningCommand: "codex")
        precondition(FileManager.default.fileExists(atPath: file.path))
        setPreferences(restart: false, scrollback: true)
        precondition(InteractiveCommandRestoration.consume(from: file) == nil,
                     "Restart off must not resume an existing Codex checkpoint, even when scrollback is on")
        precondition(!FileManager.default.fileExists(atPath: file.path))
        scene.save(to: file, runningCommand: "codex")
        precondition(!FileManager.default.fileExists(atPath: file.path),
                     "Restart off must not save a new checkpoint")
        setPreferences(restart: true, scrollback: true)

        otherScene.save(to: otherFile, runningCommand: "codex")
        precondition(InteractiveCommandRestoration.consume(from: otherFile) == nil)
        scene.save(to: file, runningCommand: "codex login")
        precondition(InteractiveCommandRestoration.consume(from: file) == nil)
        scene.save(to: file, runningCommand: "codex -c model=other")
        precondition(InteractiveCommandRestoration.consume(from: file) == nil)
        scene.save(to: file, runningCommand: "codex")
        precondition(InteractiveCommandRestoration.consume(from: otherFile) == nil)
        precondition(InteractiveCommandRestoration.consume(from: file) == "codex resume \(thread)")
        precondition(InteractiveCommandRestoration.consume(from: file) == nil)

        scene.save(to: file, runningCommand: "codex resume \(thread)")
        InteractiveCommandRestoration.discard(at: otherFile)
        precondition(InteractiveCommandRestoration.consume(from: file) == "codex resume \(thread)")
        // Record a background save, exit normally without another save, then relaunch.
        scene.save(to: file, runningCommand: "codex")
        InteractiveCommandRestoration.discard(at: file)
        precondition(InteractiveCommandRestoration.consume(from: file) == nil,
                     "A stale background snapshot must not restart a normally exited command")

        publish(nil)
        scene.save(to: file, runningCommand: "codex")
        precondition(InteractiveCommandRestoration.consume(from: file) == nil)
        publish("\(thread); echo unsafe")
        scene.save(to: file, runningCommand: "codex")
        precondition(InteractiveCommandRestoration.consume(from: file) == nil)
#if NVIM_EMBEDDED
        for command in ["nvim", "nvim sample.lua other.lua", "nvim ~/Documents/sample.lua"] {
            scene.save(to: file, runningCommand: command)
            precondition(InteractiveCommandRestoration.consume(from: file) == command,
                         "Restart on must reopen Neovim with its original file arguments")
            precondition(InteractiveCommandRestoration.consume(from: file) == nil)
        }
        scene.save(to: file, runningCommand: "nvim sample.lua")
        setPreferences(restart: false, scrollback: true)
        precondition(InteractiveCommandRestoration.consume(from: file) == nil)
        scene.save(to: file, runningCommand: "nvim sample.lua")
        precondition(!FileManager.default.fileExists(atPath: file.path))
        setPreferences(restart: true, scrollback: false)
        for command in ["nvim --headless", "nvim file | other", "nvim file\nother", "nvim -S $(other)", "nvim -S ~/Documents/session.vim", "nvim -S", "nvim file +quit", "nvim file>log"] {
            scene.save(to: file, runningCommand: command)
            precondition(InteractiveCommandRestoration.consume(from: file) == nil,
                         "Non-interactive invocations and shell syntax must not be replayed")
        }
#else
        scene.save(to: file, runningCommand: "nvim sample.lua")
        precondition(!FileManager.default.fileExists(atPath: file.path), "Full app must not save Neovim checkpoints")
#endif
        let session = try! PropertyListEncoder().encode(["command": "nvim", "token": "nvim -S changed.vim"])
        try! session.write(to: file)
        precondition(InteractiveCommandRestoration.consume(from: file) == nil,
                     "A checkpoint from an older build must not source a session on relaunch")
#if !NVIM_EMBEDDED
        let files = try! PropertyListEncoder().encode(["command": "nvim", "token": "nvim sample.lua"])
        try! files.write(to: file)
        precondition(InteractiveCommandRestoration.consume(from: file) == nil,
                     "Full app must not consume Neovim checkpoints")
#endif
        print("Interactive restoration contract passed")
    }

    private static func publish(_ token: String?) {
        var info: [String: Any] = ["context": NSNumber(value: 1), "command": "codex"]
        info["token"] = token
        NotificationCenter.default.post(
            name: Notification.Name("AsheKube.app.a-Shell.InteractiveCommandCheckpoint"),
            object: nil,
            userInfo: info)
    }
}
