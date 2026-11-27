import Foundation

@main
struct RestorationContract {
    static func main() {
        let scene = InteractiveCommandRestoration()
        scene.bind(to: UnsafeRawPointer(bitPattern: 1))
        let otherScene = InteractiveCommandRestoration()
        otherScene.bind(to: UnsafeRawPointer(bitPattern: 2))
        let thread = "c122cba2-0e43-4f31-9954-13075b990cd1"
        let activity = NSUserActivity(activityType: "AsheKube.app.a-Shell.TermSession")
        activity.addUserInfoEntries(from: ["terminal": "existing scrollback"])

        publish(thread)
        otherScene.save(in: activity, runningCommand: "codex")
        precondition(InteractiveCommandRestoration.consume(from: activity) == nil)
        scene.save(in: activity, runningCommand: "codex login")
        precondition(InteractiveCommandRestoration.consume(from: activity) == nil)
        scene.save(in: activity, runningCommand: "codex -c model=other")
        precondition(InteractiveCommandRestoration.consume(from: activity) == nil)
        scene.save(in: activity, runningCommand: "codex")
        let resumed = NSUserActivity(activityType: activity.activityType)
        resumed.userInfo = activity.userInfo
        precondition(InteractiveCommandRestoration.consume(from: resumed) == "codex resume \(thread)")
        precondition(InteractiveCommandRestoration.consume(from: resumed) == nil)
        precondition(resumed.userInfo?["terminal"] as? String == "existing scrollback")

        scene.save(in: activity, runningCommand: "codex resume \(thread)")
        precondition(InteractiveCommandRestoration.consume(from: activity) == "codex resume \(thread)")
        scene.save(in: activity, runningCommand: "codex")
        InteractiveCommandRestoration.discard(from: activity)
        precondition(InteractiveCommandRestoration.consume(from: activity) == nil)

        publish(nil)
        scene.save(in: activity, runningCommand: "codex")
        precondition(InteractiveCommandRestoration.consume(from: activity) == nil)
        publish("\(thread); echo unsafe")
        scene.save(in: activity, runningCommand: "codex")
        precondition(InteractiveCommandRestoration.consume(from: activity) == nil)
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
