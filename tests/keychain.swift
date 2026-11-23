import Foundation

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fatalError("FAIL: \(message)") }
}

@main
struct KeychainContract {
    static func main() throws {
        try keychainSceneGateContract()
        let policy = try CredentialPolicy.defaultPassword(name: "fixture")
        let decoded = try CredentialPolicy.parse(policy.json())
        check(decoded.authentication.mode == .biometryCurrentSet, "default current enrollment")
        check(decoded.authentication.reuseSeconds == 0, "default zero reuse")
        check(decoded.consumers["cli"]?.operations == ["read"], "explicit generic export")
        let git = try CredentialPolicy.defaultPassword(name: "git:https://example.invalid/team/project.git")
        check(git.consumers["cli"]?.operations == [], "Git token denies CLI export")
        check(git.consumers["git"]?.scope == "https://example.invalid/team/project.git", "Git destination bound")
        print("PASS policy defaults and JSON round-trip")
        let os = FixtureOS()
        let bytes = Data([0, 255, 10, 13, 0, 128, 65])
        let stored = KeychainCommand.run(["set", "fixture"], input: { bytes }, platform: os)
        check(stored.status == 0 && stored.output.isEmpty, "set emits no secret")
        let exported = KeychainCommand.run(["get", "fixture"], input: { Data() }, platform: os)
        check(exported.status == 0 && exported.output == bytes, "exact binary export without newline")
        check(
            KeychainCommand.run(["ls"], input: { Data() }, platform: os).output == Data("fixture\tpassword\n".utf8),
            "names/types only")
        check(
            KeychainCommand.run(["get", "missing"], input: { Data() }, platform: os).status != 0, "missing get fails")
        check(
            KeychainCommand.run(["rm", "missing"], input: { Data() }, platform: os).status == 0,
            "missing deletion is a no-op")
        print("PASS CLI binary round-trip, listing and missing handling")
        func run(_ args: [String], _ data: Data = Data()) -> KeychainCommand.Result {
            KeychainCommand.run(args, input: { data }, platform: os)
        }
        for name in [
            "", "-option", "bad name", "bad\nname", "../item", String(repeating: "a", count: 256),
            "git:https://example.invalid/team/project",
            // Synthetic credential-bearing URL must be rejected.
            "git:https://user:password@example.invalid/team/project.git",  // betterleaks:allow
        ] {
            check(run(["set", name], bytes).status != 0, "invalid name rejected")
        }
        check(run(["set", "fixture", "secret-in-argv"]).status != 0, "secret argv rejected")
        check(run(["set", "fixture"], Data(repeating: 65, count: 65537)).status != 0, "oversized input rejected")
        check(run(["get", "fixture"]).output == bytes, "validation preserves old bytes")
        os.failure = .update
        check(run(["set", "fixture"], Data([66])).status != 0, "update failure propagated")
        os.failure = nil
        check(run(["get", "fixture"]).output == bytes, "update failure preserves old item")
        os.failure = .duplicate
        check(run(["set", "raced"], bytes).status != 0, "concurrent duplicate is an error, never implicit overwrite")
        os.failure = .authorization
        check(run(["set", "fixture"], Data([66])).status != 0, "denied mutation fails")
        check(run(["rm", "fixture"]).status != 0, "denied delete fails")
        os.failure = nil
        check(run(["get", "fixture"]).output == bytes, "denied mutations preserve item")
        let gitName = "git:https://example.invalid/team/project.git"
        check(run(["set", gitName], bytes).status == 0, "create Git token")
        let gitExport = run(["get", gitName])
        check(gitExport.status != 0 && gitExport.output.isEmpty, "Git token cannot export")
        let shown = String(decoding: run(["policy", "fixture"]).output, as: UTF8.self)
        check(
            shown.contains("OS-enforced") && shown.contains("bypassable by native code"),
            "policy states enforcement boundary")
        print("PASS CLI names/size/argv, duplicates, denial and update atomicity")
        let validJSON = try policy.json()
        func invalidPolicy(_ mutate: (inout [String: Any]) -> Void) throws {
            var object = try JSONSerialization.jsonObject(with: validJSON) as! [String: Any]
            mutate(&object)
            let changed = try JSONSerialization.data(withJSONObject: object)
            do {
                _ = try CredentialPolicy.parse(changed)
                fatalError("FAIL invalid policy accepted")
            } catch is CredentialError {}
            os.edited = changed
            check(run(["policy", "fixture", "--edit"]).status != 0, "CLI rejects invalid edited policy")
            check(run(["get", "fixture"]).output == bytes, "invalid policy preserves old access")
        }
        try invalidPolicy { $0["unexpected"] = true }
        try invalidPolicy { $0["version"] = 2 }
        try invalidPolicy { $0["synchronizable"] = true }
        try invalidPolicy { $0["group"] = "shared" }
        try invalidPolicy { $0["hardwareToken"] = "serial" }
        try invalidPolicy { $0["authentication"] = ["mode": "biometry-any", "reuseSeconds": 0] }
        try invalidPolicy { $0["authentication"] = ["mode": "biometry-current-set", "reuseSeconds": 301] }
        try invalidPolicy {
            $0["consumers"] = [
                "cli": ["operations": ["read"], "authentication": ["mode": "unlocked", "reuseSeconds": 0]],
                "git": ["operations": []], "shortcuts": ["operations": []],
            ]
        }
        do {
            _ = try CredentialPolicy.parse(Data(repeating: 32, count: 16385) + validJSON)
            fatalError("FAIL oversized policy accepted")
        } catch is CredentialError {}
        os.edited = validJSON
        check(run(["policy", "fixture", "--edit"]).status == 0, "valid native policy edit succeeds")
        check(os.policyReview?.changes.isEmpty == true, "unchanged edit has no change rows")
        check(
            os.policyReview?.unchanged.contains(where: { $0.label == "Context reuse limit" && $0.newValue == "0s" })
                == true, "unchanged reuse disclosed")
        check(run(["get", "fixture"]).output == bytes, "policy edit preserves binary value")
        var reuseEdit = policy
        reuseEdit.authentication.reuseSeconds = 30
        os.edited = try reuseEdit.json()
        check(run(["policy", "fixture", "--edit"]).status == 0, "single reuse edit succeeds")
        check(
            os.policyReview?.changes == [.init(label: "Context reuse limit", oldValue: "0s", newValue: "30s")],
            "review isolates 0s to 30s")
        var strengthened = policy
        strengthened.authentication.reuseSeconds = 300
        strengthened.consumers["cli"]?.authentication = .init(mode: .biometryCurrentSet, reuseSeconds: 0)
        os.edited = try strengthened.json()
        check(run(["policy", "fixture", "--edit"]).status == 0, "stronger CLI reuse policy accepted")
        check(
            os.policyReview?.changes == [
                .init(label: "Context reuse limit", oldValue: "30s", newValue: "300s"),
                .init(label: "CLI authentication", oldValue: "Inherit item", newValue: "biometry-current-set"),
                .init(label: "CLI reuse limit", oldValue: "Inherit item", newValue: "0s"),
            ], "review lists all changed fields in stable order")
        let effective = String(decoding: run(["policy", "fixture"]).output, as: UTF8.self)
        check(
            effective.contains("CLI: read; authentication=biometry-current-set; maximum context reuse=0s"),
            "display effective CLI authentication and reuse")
        os.failure = .disclosure
        let denied = run(["get", "fixture"])
        check(denied.status != 0 && denied.output.isEmpty, "cancelled disclosure emits no bytes")
        os.failure = nil
        check(run(["rm", "fixture"]).status == 0 && run(["get", "fixture"]).status != 0, "authorized deletion")
        print("PASS strict policy parser, CLI edits, export cancellation and removal")
        check(run(["set", "unreadable"], bytes).status == 0, "unreadable fixture stored")
        os.failure = .read
        let unreadable = run(["get", "unreadable"])
        check(unreadable.status == 1 && unreadable.output.isEmpty, "unreadable item cannot export")
        check(run(["rm", "unreadable"]).status == 0, "freshly authorized deletion does not decrypt old item")
        os.failure = nil
        check(!String(decoding: run(["ls"]).output, as: UTF8.self).contains("unreadable\t"), "unreadable item removed")
        check(run(["get", "unreadable"]).status == 1, "removed unreadable item is missing")
        print("PASS unreadable item removal without secret decryption")
        let reviewOS = FixtureOS()
        check(
            KeychainCommand.run(["set", "review"], input: { bytes }, platform: reviewOS).status == 0,
            "review fixture stored")
        reviewOS.edited = try reuseEdit.json()
        for reason in ["cancelled", "dismissed", "cancelled on lock/background", "generation changed"] {
            reviewOS.reviewDenial = reason
            reviewOS.mutationAuthorized = false
            let rejected = KeychainCommand.run(["policy", "review", "--edit"], input: { Data() }, platform: reviewOS)
            check(rejected.status == 1 && rejected.output.isEmpty, "\(reason) denies review")
            check(!reviewOS.mutationAuthorized, "\(reason) requests no mutation authentication")
            let after = KeychainCommand.run(["policy", "review"], input: { Data() }, platform: reviewOS)
            check(
                String(decoding: after.output, as: UTF8.self).contains("reuse limit 0s"), "\(reason) preserves policy")
            check(
                KeychainCommand.run(["get", "review"], input: { Data() }, platform: reviewOS).output == bytes,
                "\(reason) preserves secret")
        }
        print("PASS policy review no-change, single/multiple changes and deny-without-mutation")
    }
}

// Only the external database and native authentication/UI are substituted.
final class FixtureOS: CredentialPlatform {
    let biometryState: Data? = Data([1])
    enum Failure { case update, duplicate, authorization, disclosure, read }
    var failure: Failure?
    var edited: Data?
    var policyReview: CredentialPolicyReview?
    var reviewDenial: String?
    var mutationAuthorized = false
    var interactionGate: (() throws -> Void)?
    var items: [String: Data] = [:]
    func read(_ name: String) throws -> Data? {
        if failure == .read { throw CredentialError.system(-25293) }
        return items[name]
    }
    func names() throws -> [String] { Array(items.keys) }
    func add(_ name: String, data: Data, policy: CredentialPolicy) throws {
        guard items[name] == nil, failure != .duplicate else { throw CredentialError.system(-25299) }
        items[name] = data
    }
    func update(_ name: String, data: Data, policy: CredentialPolicy) throws {
        if failure == .update { throw CredentialError.system(-50) }
        items[name] = data
    }
    func remove(_ name: String) throws { items.removeValue(forKey: name) }
    func authorizeMutation(_ reason: String) throws {
        mutationAuthorized = true
        if failure == .authorization { throw CredentialError.denied("cancelled") }
    }
    func confirm(_ title: String, message: String) throws {
        if failure == .disclosure { throw CredentialError.denied("cancelled") }
    }
    func confirmPolicy(_ name: String, review: CredentialPolicyReview) throws {
        policyReview = review
        if let reviewDenial { throw CredentialError.denied(reviewDenial) }
        if failure == .disclosure { throw CredentialError.denied("cancelled") }
    }
    func secureInput(_ name: String) throws -> Data { Data() }
    func editPolicy(_ data: Data) throws -> Data { edited ?? data }
    func enforce(_ policy: CredentialPolicy, revision: String, biometryState: Data?) throws {
        try interactionGate?()
    }
    func finish(success: Bool) {}
}
