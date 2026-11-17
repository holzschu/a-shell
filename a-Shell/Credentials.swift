import Foundation

enum CredentialError: Error, CustomStringConvertible {
    case invalid(String)
    case missing
    case denied(String)
    case system(Int32)

    var description: String {
        switch self {
        case .invalid(let reason): return reason
        case .missing:
            return "item not found (or invalidated by a passcode/enrollment change); reprovision from recovery"
        case .denied(let reason): return reason
        case .system(let status): return "Keychain operation failed (OSStatus \(status)); no fallback was attempted"
        }
    }
}

struct CredentialPolicy: Codable, Equatable {
    enum Mode: String, Codable {
        case biometryCurrentSet = "biometry-current-set"
        case userPresence = "user-presence"
        case devicePasscode = "device-passcode"
        case unlocked
    }

    struct Authentication: Codable, Equatable {
        var mode: Mode
        var reuseSeconds: Int
    }

    struct Consumer: Codable, Equatable {
        var operations: [String]
        var scope: String?
        var authentication: Authentication?
    }

    var version = 1
    var kind = "password"
    var group = "private"
    var accessibility = "when-passcode-set-this-device-only"
    var synchronizable = false
    var authentication = Authentication(mode: .biometryCurrentSet, reuseSeconds: 0)
    var hardwareToken: String? = nil
    var consumers: [String: Consumer]

    static func canonicalDestination(_ text: String) throws -> String {
        guard let parts = URLComponents(string: text), parts.scheme == "https",
            let host = parts.host, !host.isEmpty, host == host.lowercased(),
            parts.user == nil, parts.password == nil, parts.query == nil, parts.fragment == nil,
            parts.port == nil || (1...65535).contains(parts.port!),
            !parts.percentEncodedPath.contains("%"), !parts.path.contains("\\"),
            !parts.path.contains("//"), !parts.path.hasSuffix("/"),
            parts.path.split(separator: "/").count >= 2,
            !parts.path.split(separator: "/").contains(where: { $0 == "." || $0 == ".." })
        else {
            throw CredentialError.invalid(
                "destination must be a canonical HTTPS repository URL without credentials/query/fragment")
        }
        let canonical = parts.string!
        guard canonical == text else { throw CredentialError.invalid("noncanonical destination") }
        return text.hasSuffix(".git") ? text : text + ".git"
    }

    static func validateName(_ name: String) throws {
        guard !name.isEmpty, name.utf8.count <= 255,
            name.unicodeScalars.allSatisfy({
                CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-:/")
                    .contains($0)
            }),
            !name.hasPrefix("-"), !name.contains("..")
        else {
            throw CredentialError.invalid(
                "name must be 1-255 ASCII letters, digits or . _ - : /, without leading - or ..")
        }
        if name.hasPrefix("git:") {
            guard name.hasPrefix("git:https://"),
                try canonicalDestination(String(name.dropFirst(4))) == String(name.dropFirst(4))
            else {
                throw CredentialError.invalid(
                    "Git names must contain the exact canonical HTTPS repository scope ending in .git")
            }
        }
    }

    static func defaultPassword(name: String) throws -> Self {
        try validateName(name)
        let gitScope = name.hasPrefix("git:https://") ? String(name.dropFirst(4)) : nil
        return Self(consumers: [
            "cli": Consumer(operations: gitScope == nil ? ["read"] : []),
            "git": Consumer(operations: gitScope == nil ? [] : ["use"], scope: gitScope),
            "shortcuts": Consumer(operations: []),
        ])
    }

    // Parse the public schema strictly before Codable can discard unknown fields.
    static func parse(_ data: Data) throws -> Self {
        guard data.count <= 16384 else { throw CredentialError.invalid("policy exceeds 16384 bytes") }
        func keys(_ value: Any?, required: Set<String>, optional: Set<String> = []) throws -> [String: Any] {
            guard let object = value as? [String: Any], required.isSubset(of: Set(object.keys)),
                Set(object.keys).isSubset(of: required.union(optional))
            else { throw CredentialError.invalid("invalid or unknown policy fields") }
            return object
        }
        do {
            let root = try keys(
                JSONSerialization.jsonObject(with: data),
                required: [
                    "version", "kind", "group", "accessibility", "synchronizable", "authentication", "hardwareToken",
                    "consumers",
                ])
            guard root["hardwareToken"] is NSNull else {
                throw CredentialError.invalid("hardwareToken is not supported; use null")
            }
            _ = try keys(root["authentication"], required: ["mode", "reuseSeconds"])
            let consumers = try keys(root["consumers"], required: ["cli", "git", "shortcuts"])
            for value in consumers.values {
                let consumer = try keys(value, required: ["operations"], optional: ["scope", "authentication"])
                if let auth = consumer["authentication"] { _ = try keys(auth, required: ["mode", "reuseSeconds"]) }
            }
            let policy = try JSONDecoder().decode(Self.self, from: data)
            try policy.validate()
            return policy
        } catch let error as CredentialError { throw error } catch {
            throw CredentialError.invalid("invalid policy JSON or unsupported field type")
        }
    }

    func validate() throws {
        guard version == 1, kind == "password", group == "private",
            accessibility == "when-passcode-set-this-device-only", !synchronizable, hardwareToken == nil,
            Set(consumers.keys) == ["cli", "git", "shortcuts"]
        else {
            throw CredentialError.invalid("unsupported policy version, kind, group, accessibility or synchronization")
        }
        func valid(_ auth: Authentication) -> Bool {
            (0...300).contains(auth.reuseSeconds) && (auth.mode == .biometryCurrentSet || auth.reuseSeconds == 0)
        }
        guard valid(authentication) else {
            throw CredentialError.invalid(
                "reuse must be 0-300 seconds, and nonzero reuse requires current-set biometry")
        }
        for (name, consumer) in consumers {
            let allowed: Set<String> = name == "cli" ? ["read"] : ["use"]
            guard Set(consumer.operations).isSubset(of: allowed),
                Set(consumer.operations).count == consumer.operations.count
            else { throw CredentialError.invalid("unsupported or duplicate consumer operations") }
            if name == "git", !consumer.operations.isEmpty {
                guard let scope = consumer.scope, try Self.canonicalDestination(scope) == scope else {
                    throw CredentialError.invalid("Git use requires an exact canonical destination")
                }
            } else if consumer.scope != nil {
                throw CredentialError.invalid("scope is supported only for Git use")
            }
            if let override = consumer.authentication {
                let strong =
                    override.mode == authentication.mode || authentication.mode == .unlocked
                    || (authentication.mode == .userPresence && override.mode != .unlocked)
                guard valid(override), strong, override.reuseSeconds <= authentication.reuseSeconds else {
                    throw CredentialError.invalid(
                        "consumer authentication must strengthen the item floor and reuse limit")
                }
            }
        }
    }

    func validate(name: String) throws {
        try Self.validateName(name)
        try validate()
        if name.hasPrefix("git:"), consumers["git"]?.scope != String(name.dropFirst(4)) {
            throw CredentialError.invalid("Git namespace policy must retain its exact destination")
        }
    }

    func json() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        // Optional nil encodes as absent by default; the reserved field is mandatory.
        var object = try JSONSerialization.jsonObject(with: encoder.encode(self)) as! [String: Any]
        object["hardwareToken"] = NSNull()
        return try JSONSerialization.data(
            withJSONObject: object, options: [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes])
    }

    var explanation: String {
        let cli = consumers["cli"]
        let effectiveCLI = cli?.authentication ?? authentication
        let operations = cli?.operations.joined(separator: ",") ?? ""
        return
            "OS-enforced: private signed-app group; passcode-set ThisDeviceOnly; nonsynchronizable. Configured ACL mode: \(authentication.mode.rawValue) (not independently re-inspected).\n"
            + "App-enforced: consumer operations, exact destination, overrides and item context reuse limit \(authentication.reuseSeconds)s; bypassable by native code with this app's identity.\n"
            + "CLI: \(operations.isEmpty ? "denied" : operations); authentication=\(effectiveCLI.mode.rawValue); maximum context reuse=\(effectiveCLI.reuseSeconds)s.\n"
            + "user-presence permits biometrics OR device passcode; device-passcode permits passcode; unlocked permits entitled native callers while unlocked. No automatic fallback.\n"
    }
}

// Pure review data shared by the command and native confirmation.
struct CredentialPolicyReview {
    struct Row: Equatable {
        let label: String
        let oldValue: String
        let newValue: String
    }
    let old: CredentialPolicy
    let new: CredentialPolicy
    let changes: [Row]
    let unchanged: [Row]

    init(old: CredentialPolicy, new: CredentialPolicy) {
        self.old = old
        self.new = new
        func fields(_ policy: CredentialPolicy) -> [(String, String)] {
            var result = [
                ("Version", String(policy.version)), ("Kind", policy.kind), ("Group", policy.group),
                ("Accessibility", policy.accessibility),
                ("Synchronization", policy.synchronizable ? "On" : "Off"),
                ("Authentication", policy.authentication.mode.rawValue),
                ("Context reuse limit", "\(policy.authentication.reuseSeconds)s"),
                ("Hardware token", policy.hardwareToken ?? "None"),
            ]
            for (key, label) in [("cli", "CLI"), ("git", "Git"), ("shortcuts", "Shortcuts")] {
                let consumer = policy.consumers[key]
                let operations = consumer?.operations.sorted().joined(separator: ", ") ?? ""
                result += [
                    ("\(label) operations", operations.isEmpty ? "Denied" : operations),
                    ("\(label) destination", consumer?.scope ?? "None"),
                    ("\(label) authentication", consumer?.authentication?.mode.rawValue ?? "Inherit item"),
                    ("\(label) reuse limit", consumer?.authentication.map { "\($0.reuseSeconds)s" } ?? "Inherit item"),
                ]
            }
            return result
        }
        let rows = zip(fields(old), fields(new)).map {
            Row(label: $0.0.0, oldValue: $0.0.1, newValue: $0.1.1)
        }
        changes = rows.filter { $0.oldValue != $0.newValue }
        unchanged = rows.filter { $0.oldValue == $0.newValue }
    }
}

// The external Security database, LocalAuthentication and native UI boundary.
protocol CredentialPlatform: AnyObject {
    var biometryState: Data? { get }
    func read(_ name: String) throws -> Data?
    func names() throws -> [String]
    func add(_ name: String, data: Data, policy: CredentialPolicy) throws
    func update(_ name: String, data: Data, policy: CredentialPolicy) throws
    func remove(_ name: String) throws
    func authorizeMutation(_ reason: String) throws
    func confirm(_ title: String, message: String) throws
    func confirmPolicy(_ name: String, review: CredentialPolicyReview) throws
    func secureInput(_ name: String) throws -> Data
    func editPolicy(_ data: Data) throws -> Data
    func enforce(_ policy: CredentialPolicy, revision: String, biometryState: Data?) throws
    func finish(success: Bool)
}

struct CredentialRecord: Codable {
    let version: Int
    let name: String
    var revision: String
    var policy: Data
    var secret: Data
    var biometryState: Data?

    static func decode(_ data: Data, name: String) throws -> Self {
        do {
            let record = try PropertyListDecoder().decode(Self.self, from: data)
            guard record.version == 1, record.name == name, !record.revision.isEmpty,
                record.secret.count <= KeychainCommand.maximumSecretBytes
            else {
                throw CredentialError.invalid("corrupt credential record; preserve it and reprovision through recovery")
            }
            try CredentialPolicy.parse(record.policy).validate(name: name)
            return record
        } catch let error as CredentialError { throw error } catch {
            throw CredentialError.invalid("corrupt credential record; preserve it and reprovision through recovery")
        }
    }

    func encoded() throws -> Data {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return try encoder.encode(self)
    }
}

enum KeychainCommand {
    static let maximumSecretBytes = 65536
    struct Result {
        var status: Int32 = 0
        var output = Data()
        var diagnostic = ""
    }
    static let usage =
        "usage: keychain set|get|rm|policy <name> | keychain policy <name> --edit | keychain ls\nset reads up to 65536 bytes from stdin to EOF, or native secure entry for a terminal. get is explicit export to command output after native disclosure. No secret argv, environment, clipboard or policy files.\nGit credential names use git:https://host/team/project.git and deny CLI export by default. See man keychain for naming rules, protections and examples.\n"

    // Both the native C command and host contracts enter here.
    static func run(_ arguments: [String], input: () throws -> Data, platform: CredentialPlatform) -> Result {
        var success = false
        defer { platform.finish(success: success) }
        do {
            if arguments == ["--help"] || arguments == ["help"] {
                success = true
                return Result(output: Data(usage.utf8))
            }
            if arguments == ["ls"] {
                let names = try platform.names().sorted()
                for name in names { try CredentialPolicy.validateName(name) }
                success = true
                return Result(output: Data(names.map { "\($0)\tpassword\n" }.joined().utf8))
            }
            guard
                arguments.count == 2 || (arguments.count == 3 && arguments[0] == "policy" && arguments[2] == "--edit"),
                let operation = arguments.first, ["set", "get", "rm", "policy"].contains(operation)
            else { throw CredentialError.invalid(usage) }
            let name = arguments[1]
            try CredentialPolicy.validateName(name)
            var incoming = Data()
            defer { incoming.resetBytes(in: 0..<incoming.count) }
            if operation == "set" {
                incoming = try input()
                guard incoming.count <= maximumSecretBytes else {
                    throw CredentialError.invalid("secret exceeds 65536 bytes; item unchanged")
                }
                try platform.authorizeMutation("Store or replace password: \(name)")
            }
            if operation == "get" {
                try platform.confirm(
                    "Export protected password?",
                    message:
                        "\(name)\nExport to command output. The terminal, pipeline and transcripts can capture the exact secret bytes."
                )
            }
            if operation == "rm" {
                // Deletion must remain possible when an old enrollment makes the value unreadable.
                // Do not probe by decrypting; even missing names require deliberate fresh authorization.
                try platform.confirm(
                    "Delete protected password?", message: name + "\nKeep an independent recovery copy.")
                try platform.authorizeMutation("Delete password: \(name)")
                try platform.remove(name)
                success = true
                return Result()
            }
            var encoded = try platform.read(name)
            defer { if encoded != nil { encoded!.resetBytes(in: 0..<encoded!.count) } }
            var record = try encoded.map { try CredentialRecord.decode($0, name: name) }
            defer { if record != nil { record!.secret.resetBytes(in: 0..<record!.secret.count) } }
            switch operation {
            case "set":
                let policy =
                    try record.map { try CredentialPolicy.parse($0.policy) }
                    ?? CredentialPolicy.defaultPassword(name: name)
                let replacement = CredentialRecord(
                    version: 1, name: name, revision: UUID().uuidString, policy: try policy.json(), secret: incoming,
                    biometryState: platform.biometryState)
                var value = try replacement.encoded()
                defer { value.resetBytes(in: 0..<value.count) }
                if record == nil {
                    try platform.add(name, data: value, policy: policy)
                } else {
                    try platform.update(name, data: value, policy: policy)
                }
            case "get":
                guard let stored = record else { throw CredentialError.missing }
                let policy = try CredentialPolicy.parse(stored.policy)
                guard policy.consumers["cli"]?.operations.contains("read") == true else {
                    throw CredentialError.denied(
                        "CLI export denied by item policy; use an authorized native policy edit")
                }
                try platform.enforce(policy, revision: stored.revision, biometryState: stored.biometryState)
                success = true
                return Result(output: stored.secret)
            case "policy":
                guard var stored = record else { throw CredentialError.missing }
                let old = try CredentialPolicy.parse(stored.policy)
                if arguments.count == 3 {
                    let policy = try CredentialPolicy.parse(platform.editPolicy(stored.policy))
                    try policy.validate(name: name)
                    try platform.confirmPolicy(name, review: CredentialPolicyReview(old: old, new: policy))
                    try platform.authorizeMutation("Change protection for password: \(name)")
                    stored.policy = try policy.json()
                    stored.revision = UUID().uuidString
                    stored.biometryState = platform.biometryState
                    var value = try stored.encoded()
                    defer { value.resetBytes(in: 0..<value.count) }
                    try platform.update(name, data: value, policy: policy)
                } else {
                    success = true
                    return Result(output: try old.json() + Data(("\n" + old.explanation).utf8))
                }
            default: throw CredentialError.invalid(usage)
            }
            success = true
            return Result()
        } catch let error as CredentialError { return Result(status: 1, diagnostic: "keychain: \(error)\n") } catch {
            return Result(status: 1, diagnostic: "keychain: operation failed; item unchanged; no fallback\n")
        }
    }
}

// Pure interaction contract; UIKit supplies state and the native bridge owns output/UI checks.
enum CredentialSceneGate {
    enum Boundary { case entry, presentation, export }
    enum Activation { case active, inactive, unavailable }

    static func require(
        _ boundary: Boundary, activation: Activation, protectedDataAvailable: Bool,
        appInBackground: Bool, generationMatches: Bool, exportAuthorized: Bool
    ) throws {
        guard activation == .active || activation == .inactive,
            protectedDataAvailable, !appInBackground, generationMatches
        else {
            throw CredentialError.denied("interaction required: originating scene is unavailable or invalidated")
        }
        if boundary == .export, !exportAuthorized {
            throw CredentialError.denied("export authorization is incomplete")
        }
    }
}

#if os(iOS)
    import UIKit
    import Security
    import LocalAuthentication
    import ios_system

    private extension CredentialSceneGate.Activation {
        init(_ state: UIScene.ActivationState) {
            switch state {
            case .foregroundActive: self = .active
            case .foregroundInactive: self = .inactive
            default: self = .unavailable
            }
        }
    }

    // Retain authentication contexts only. Never retain decrypted records or tokens.
    private final class CredentialSessions {
        static let shared = CredentialSessions()
        struct Session {
            let context: LAContext
            let revision: String
            let expires: UInt64
            let id = UUID()
        }
        private let lock = NSLock()
        private var cached: [String: Session] = [:]
        private var active: [ObjectIdentifier: LAContext] = [:]
        private var epoch = 0
        private var observers: [NSObjectProtocol] = []

        private init() {
            for notification in [
                UIApplication.didEnterBackgroundNotification,
                UIApplication.protectedDataWillBecomeUnavailableNotification, UIScene.didEnterBackgroundNotification,
                UIScene.didDisconnectNotification,
            ] {
                observers.append(
                    NotificationCenter.default.addObserver(forName: notification, object: nil, queue: nil) {
                        [weak self] _ in self?.invalidateAll()
                    })
            }
        }
        var generation: Int {
            lock.lock()
            defer { lock.unlock() }
            return epoch
        }
        func register(_ context: LAContext) {
            lock.lock()
            defer { lock.unlock() }
            active[ObjectIdentifier(context)] = context
        }
        func unregister(_ context: LAContext) {
            lock.lock()
            defer { lock.unlock() }
            active.removeValue(forKey: ObjectIdentifier(context))
        }
        func take(_ name: String) -> Session? {
            lock.lock()
            defer { lock.unlock() }
            guard let session = cached.removeValue(forKey: name) else { return nil }
            guard DispatchTime.now().uptimeNanoseconds < session.expires else {
                session.context.invalidate()
                return nil
            }
            return session
        }
        func retain(_ name: String, context: LAContext, revision: String, seconds: Int, expires: UInt64?) {
            let deadline = expires ?? (DispatchTime.now().uptimeNanoseconds + UInt64(seconds) * 1_000_000_000)
            let session = Session(context: context, revision: revision, expires: deadline)
            lock.lock()
            cached.removeValue(forKey: name)?.context.invalidate()
            cached[name] = session
            lock.unlock()
            DispatchQueue.global().asyncAfter(deadline: DispatchTime(uptimeNanoseconds: deadline)) { [weak self] in
                guard let self else { return }
                self.lock.lock()
                defer { self.lock.unlock() }
                if self.cached[name]?.id == session.id { self.cached.removeValue(forKey: name)?.context.invalidate() }
            }
        }
        func invalidate(_ name: String) {
            lock.lock()
            defer { lock.unlock() }
            cached.removeValue(forKey: name)?.context.invalidate()
        }
        private func invalidateAll() {
            lock.lock()
            defer { lock.unlock() }
            epoch += 1
            for session in cached.values { session.context.invalidate() }
            for context in active.values { context.invalidate() }
            cached.removeAll()
        }
    }

    private final class NativeCredentialPlatform: CredentialPlatform {
        // A fixed service survives compatible app updates; the group follows signing.
        private let service = "org.a-shell.protected-passwords.v1"
        private let group: String
        private let scene: UIWindowScene
        private let name: String
        private let operation: String
        private let generation: Int
        private var context: LAContext
        private let reused: CredentialSessions.Session?
        private var reusable: (String, Int)?
        private var exportAuthorized = false
        private var observers: [NSObjectProtocol] = []
        // Access only on the main queue. Lock/background completes and dismisses UI.
        private var cancelUI: (() -> Void)?

        init(scene: UIWindowScene, name: String, operation: String) throws {
            guard let group = Bundle.main.object(forInfoDictionaryKey: "CredentialPrivateAccessGroup") as? String,
                !group.isEmpty, !group.contains("$"), group.hasSuffix("." + (Bundle.main.bundleIdentifier ?? "invalid"))
            else {
                throw CredentialError.denied(
                    "private signing group is unavailable; rebuild with the existing app identity")
            }
            self.group = group
            self.scene = scene
            self.name = name
            self.operation = operation
            let pool = CredentialSessions.shared
            generation = pool.generation
            reused = operation == "get" ? pool.take(name) : nil
            context = reused?.context ?? LAContext()
            context.touchIDAuthenticationAllowableReuseDuration = 0
            context.localizedReason = "\(operation) protected password: \(name)"
            pool.register(context)
            for notification in [
                UIApplication.didEnterBackgroundNotification,
                UIApplication.protectedDataWillBecomeUnavailableNotification, UIScene.didEnterBackgroundNotification,
                UIScene.didDisconnectNotification,
            ] {
                observers.append(
                    NotificationCenter.default.addObserver(forName: notification, object: nil, queue: .main) {
                        [weak self] _ in self?.cancelUI?()
                    })
            }
            try available()
        }
        deinit {
            for observer in observers { NotificationCenter.default.removeObserver(observer) }
            CredentialSessions.shared.unregister(context)
        }

        private func available() throws {
            let state = DispatchQueue.main.sync {
                (
                    CredentialSceneGate.Activation(scene.activationState),
                    UIApplication.shared.isProtectedDataAvailable,
                    UIApplication.shared.applicationState == .background
                )
            }
            do {
                try CredentialSceneGate.require(
                    .entry, activation: state.0, protectedDataAvailable: state.1, appInBackground: state.2,
                    generationMatches: generation == CredentialSessions.shared.generation, exportAuthorized: false)
            } catch {
                throw CredentialError.denied(
                    "interaction required: originating scene is backgrounded or protected data is locked; retry in the foreground"
                )
            }
            if let reused, DispatchTime.now().uptimeNanoseconds >= reused.expires {
                context.invalidate()
                throw CredentialError.denied("biometric reuse window expired; retry with fresh authorization")
            }
        }
        var biometryState: Data? { context.evaluatedPolicyDomainState }
        func checkOutputAvailability() throws {
            try available()
            if operation == "get" {
                // Security read and effective policy must complete before output, even if Face ID leaves UIKit inactive.
                try DispatchQueue.main.sync {
                    try CredentialSceneGate.require(
                        .export, activation: .init(scene.activationState),
                        protectedDataAvailable: UIApplication.shared.isProtectedDataAvailable,
                        appInBackground: UIApplication.shared.applicationState == .background,
                        generationMatches: generation == CredentialSessions.shared.generation,
                        exportAuthorized: exportAuthorized)
                }
                let visible = DispatchQueue.main.sync {
                    guard let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
                        return false
                    }
                    return root.viewIfLoaded?.window?.isHidden == false && root.presentedViewController == nil
                }
                guard visible else {
                    throw CredentialError.denied(
                        "interaction required: originating export scene has pending or unavailable UI")
                }
                // A real lock/background invalidates the generation permanently, including during the UI check.
                try available()
            }
        }
        private func query(_ name: String? = nil) -> [String: Any] {
            var query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                kSecAttrAccessGroup as String: group, kSecAttrSynchronizable as String: false,
                kSecUseAuthenticationContext as String: context,
            ]
            if let name { query[kSecAttrAccount as String] = name }
            return query
        }
        private func status(_ status: OSStatus) throws {
            // Security may commit a mutation just before background/lock arrives. Do not turn that success
            // into a failure suggesting a retry; read callers separately recheck before consuming data.
            switch status {
            case errSecSuccess: return
            case errSecUserCanceled: throw CredentialError.denied("authentication cancelled")
            case errSecAuthFailed:
                throw CredentialError.denied("authentication failed or item invalidated; no fallback")
            case errSecInteractionNotAllowed:
                throw CredentialError.denied("interaction not allowed; unlock and foreground the originating scene")
            case errSecMissingEntitlement:
                throw CredentialError.denied("private Keychain group is not provisioned for this signed app")
            case errSecDuplicateItem:
                throw CredentialError.denied("duplicate item; concurrent creation was not overwritten")
            default: throw CredentialError.system(status)
            }
        }
        private func accessControl(_ policy: CredentialPolicy) throws -> SecAccessControl {
            let flags: SecAccessControlCreateFlags
            switch policy.authentication.mode {
            case .biometryCurrentSet: flags = .biometryCurrentSet
            case .userPresence: flags = .userPresence
            case .devicePasscode: flags = .devicePasscode
            case .unlocked: flags = []
            }
            var error: Unmanaged<CFError>?
            guard
                let acl = SecAccessControlCreateWithFlags(
                    nil, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, flags, &error)
            else {
                throw CredentialError.denied("requested OS access control is unavailable; no weaker fallback")
            }
            return acl
        }
        func read(_ name: String) throws -> Data? {
            try available()
            var request = query(name)
            request[kSecReturnData as String] = true
            request[kSecReturnAttributes as String] = true
            request[kSecMatchLimit as String] = kSecMatchLimitOne
            var value: CFTypeRef?
            let result = SecItemCopyMatching(request as CFDictionary, &value)
            try available()
            if result == errSecItemNotFound {
                return nil
            }
            try status(result)
            guard let item = value as? [String: Any], let data = item[kSecValueData as String] as? Data else {
                throw CredentialError.invalid("invalid protected item result")
            }
            _ = try CredentialRecord.decode(data, name: name)
            // Security binds enrollment data into stored ACLs; CFEqual with a fresh template rejects valid items.
            // The OS authorizes this read with the stored ACL. Validate public identity/protection attributes;
            // the supported add/update paths construct the opaque ACL from the envelope's validated policy.
            guard let actual = item[kSecAttrAccessControl as String],
                CFGetTypeID(actual as CFTypeRef) == SecAccessControlGetTypeID(),
                item[kSecAttrAccessGroup as String] as? String == group,
                item[kSecAttrService as String] as? String == service,
                item[kSecAttrAccount as String] as? String == name,
                item[kSecAttrSynchronizable as String] as? Bool == false,
                item[kSecAttrAccessible as String] as? String == kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
                    as String
            else {
                throw CredentialError.denied(
                    "stored policy does not match OS item protection; preserve item and reprovision")
            }
            return data
        }
        func names() throws -> [String] {
            try available()
            var request = query()
            // Security can require authentication even for attributes of ACL-protected items.
            // Do not use UISkip: silently omitted items would make this inventory incomplete.
            context.localizedReason = "List protected password names"
            request[kSecReturnAttributes as String] = true
            request[kSecMatchLimit as String] = kSecMatchLimitAll
            var value: CFTypeRef?
            let result = SecItemCopyMatching(request as CFDictionary, &value)
            try available()
            if result == errSecItemNotFound {
                return []
            }
            try status(result)
            guard let items = value as? [[String: Any]] else { throw CredentialError.invalid("invalid item metadata") }
            return try items.map {
                guard let name = $0[kSecAttrAccount as String] as? String else {
                    throw CredentialError.invalid("invalid account metadata")
                }
                return name
            }
        }
        func add(_ name: String, data: Data, policy: CredentialPolicy) throws {
            var request = query(name)
            request[kSecAttrAccessControl as String] = try accessControl(policy)
            request[kSecValueData as String] = data
            try available()
            try status(SecItemAdd(request as CFDictionary, nil))
        }
        func update(_ name: String, data: Data, policy: CredentialPolicy) throws {
            CredentialSessions.shared.invalidate(name)
            // One update changes both the protected envelope and ACL, never delete/add.
            let attributes: [String: Any] = [
                kSecValueData as String: data, kSecAttrAccessControl as String: try accessControl(policy),
            ]
            try available()
            try status(SecItemUpdate(query(name) as CFDictionary, attributes as CFDictionary))
        }
        func remove(_ name: String) throws {
            try available()
            CredentialSessions.shared.invalidate(name)
            let result = SecItemDelete(query(name) as CFDictionary)
            if result != errSecItemNotFound { try status(result) }
        }
        func authorizeMutation(_ reason: String) throws {
            try available()
            if operation == "set" { try confirm("Store protected password?", message: reason) }
            CredentialSessions.shared.invalidate(name)
            CredentialSessions.shared.unregister(context)
            context.invalidate()
            context = LAContext()
            context.touchIDAuthenticationAllowableReuseDuration = 0
            context.localizedReason = reason
            CredentialSessions.shared.register(context)
            try evaluateBiometrics(reason)
        }
        private func evaluateBiometrics(_ reason: String) throws {
            let fallback = context.localizedFallbackTitle
            context.localizedFallbackTitle = ""
            defer { context.localizedFallbackTitle = fallback }
            var error: NSError?
            guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
                throw authenticationError(error)
            }
            let done = DispatchSemaphore(value: 0)
            var failure: Error?
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { ok, error in
                if !ok { failure = self.authenticationError(error as NSError?) }
                done.signal()
            }
            done.wait()
            try available()
            if let failure { throw failure }
        }
        private func authenticationError(_ error: NSError?) -> CredentialError {
            let reason: String
            switch error?.code {
            case LAError.userCancel.rawValue, LAError.systemCancel.rawValue, LAError.appCancel.rawValue:
                reason = "authentication cancelled"
            case LAError.biometryNotEnrolled.rawValue:
                reason = "no biometrics enrolled; enroll independently before provisioning"
            case LAError.biometryNotAvailable.rawValue: reason = "biometrics unavailable"
            case LAError.biometryLockout.rawValue: reason = "biometrics locked out; no passcode fallback was added"
            case LAError.passcodeNotSet.rawValue: reason = "device passcode is required"
            default: reason = "authentication failed"
            }
            return .denied(reason)
        }
        func enforce(_ policy: CredentialPolicy, revision: String, biometryState: Data?) throws {
            exportAuthorized = false
            try available()
            if let reused, reused.revision != revision {
                throw CredentialError.denied("policy revision changed; retry with fresh authorization")
            }
            let effective = policy.consumers["cli"]?.authentication ?? policy.authentication
            if effective.mode != policy.authentication.mode {
                // The extra check strengthens the OS floor; never substitutes for it.
                if effective.mode == .biometryCurrentSet {
                    try evaluateBiometrics("Authorize export of password: \(name)")
                    guard let biometryState, biometryState == context.evaluatedPolicyDomainState else {
                        throw CredentialError.denied(
                            "biometric enrollment state changed or unavailable; use a freshly authorized policy edit to re-enroll"
                        )
                    }
                } else {
                    var stronger = policy
                    stronger.authentication = effective
                    let acl = try accessControl(stronger)
                    let done = DispatchSemaphore(value: 0)
                    var failure: Error?
                    context.evaluateAccessControl(
                        acl, operation: .useItem, localizedReason: "Authorize export of password: \(name)"
                    ) { ok, error in
                        if !ok { failure = self.authenticationError(error as NSError?) }
                        done.signal()
                    }
                    done.wait()
                    try available()
                    if let failure { throw failure }
                }
            }
            if effective.mode == .biometryCurrentSet, effective.reuseSeconds > 0 {
                reusable = (revision, effective.reuseSeconds)
            }
            // The command calls enforce only after its disclosed, OS-authorized and validated record read.
            exportAuthorized = true
        }
        func finish(success: Bool) {
            if success, generation == CredentialSessions.shared.generation, let (revision, seconds) = reusable {
                CredentialSessions.shared.retain(
                    name, context: context, revision: revision, seconds: seconds, expires: reused?.expires)
            } else {
                context.invalidate()
                if !success { CredentialSessions.shared.invalidate(name) }
            }
        }

        private func present<T>(_ make: @escaping (@escaping (Swift.Result<T, Error>) -> Void) -> UIViewController)
            throws -> T
        {
            // Face ID can leave a visible foreground scene inactive; use its real presenter.
            // Inactivity alone is not background/lock authorization. Export also requires completed policy authorization.
            try available()
            let done = DispatchSemaphore(value: 0)
            var result: Swift.Result<T, Error>?
            DispatchQueue.main.async {
                do {
                    try CredentialSceneGate.require(
                        .presentation, activation: .init(self.scene.activationState),
                        protectedDataAvailable: UIApplication.shared.isProtectedDataAvailable,
                        appInBackground: UIApplication.shared.applicationState == .background,
                        generationMatches: self.generation == CredentialSessions.shared.generation,
                        exportAuthorized: false)
                } catch {
                    result = .failure(error)
                    done.signal()
                    return
                }
                // A hidden window can strand invisible UI while the command holds its serialization lock.
                guard
                    let root = self.scene.windows.first(where: { $0.isKeyWindow })?.rootViewController,
                    root.presentedViewController == nil, root.viewIfLoaded?.window?.isHidden == false
                else {
                    result = .failure(
                        CredentialError.denied("interaction required: originating scene has no available presenter"))
                    done.signal()
                    return
                }
                weak var presented: UIViewController?
                let complete: (Swift.Result<T, Error>) -> Void = { value in
                    guard result == nil else { return }
                    result = value
                    self.cancelUI = nil
                    guard let controller = presented else {
                        done.signal()
                        return
                    }
                    // Lock/background bypasses alert actions, so clear secure entry here too.
                    if let alert = controller as? UIAlertController {
                        for field in alert.textFields ?? [] { field.text = nil }
                    }
                    controller.dismiss(animated: false) { done.signal() }
                }
                let controller = make(complete)
                presented = controller
                self.cancelUI = { complete(.failure(CredentialError.denied("cancelled on lock/background"))) }
                root.present(controller, animated: false)
                if controller.presentingViewController == nil {
                    self.cancelUI = nil
                    result = .failure(CredentialError.denied("interaction required: native presentation was refused"))
                    done.signal()
                }
            }
            done.wait()
            try available()
            return try result!.get()
        }
        func confirm(_ title: String, message: String) throws {
            let _: Bool = try present { complete in
                let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                alert.addAction(
                    UIAlertAction(title: "Cancel", style: .cancel) { _ in
                        complete(.failure(CredentialError.denied("cancelled")))
                    })
                alert.addAction(UIAlertAction(title: "Continue", style: .default) { _ in complete(.success(true)) })
                return alert
            }
        }
        func confirmPolicy(_ name: String, review: CredentialPolicyReview) throws {
            let _: Bool = try present { complete in
                UINavigationController(
                    rootViewController: CredentialPolicyConfirmation(
                        name: name, review: review, completion: complete))
            }
        }
        func secureInput(_ name: String) throws -> Data {
            try present { complete in
                let alert = UIAlertController(
                    title: "Store protected password",
                    message: name + "\nText entry uses UTF-8. Pipe stdin for exact binary input.",
                    preferredStyle: .alert)
                alert.addTextField { field in
                    field.isSecureTextEntry = true
                    field.textContentType = .password
                    field.autocorrectionType = .no
                    field.autocapitalizationType = .none
                }
                alert.addAction(
                    UIAlertAction(title: "Cancel", style: .cancel) { [weak alert] _ in
                        alert?.textFields?.first?.text = nil
                        complete(.failure(CredentialError.denied("cancelled")))
                    })
                alert.addAction(
                    UIAlertAction(title: "Store", style: .default) { [weak alert] _ in
                        let bytes = Data((alert?.textFields?.first?.text ?? "").utf8)
                        alert?.textFields?.first?.text = nil
                        complete(.success(bytes))
                    })
                return alert
            }
        }
        func editPolicy(_ data: Data) throws -> Data {
            try present { complete in
                let editor = CredentialPolicyEditor(data: data, completion: complete)
                let navigation = UINavigationController(rootViewController: editor)
                navigation.isModalInPresentation = true
                return navigation
            }
        }
    }

    private final class CredentialPolicyConfirmation: UITableViewController, UIAdaptivePresentationControllerDelegate {
        private let name: String
        private let review: CredentialPolicyReview
        private let completion: (Swift.Result<Bool, Error>) -> Void
        private var showUnchanged = false
        private var showJSON = false

        init(name: String, review: CredentialPolicyReview, completion: @escaping (Swift.Result<Bool, Error>) -> Void) {
            self.name = name
            self.review = review
            self.completion = completion
            super.init(style: .insetGrouped)
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

        override func viewDidLoad() {
            super.viewDidLoad()
            title = "Review protection"
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                title: "Cancel", style: .plain, target: self, action: #selector(cancel))
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "Continue", style: .plain, target: self, action: #selector(proceed))
            tableView.rowHeight = UITableView.automaticDimension
            tableView.estimatedRowHeight = 80
        }
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            navigationController?.presentationController?.delegate = self
        }
        @objc private func cancel() { completion(.failure(CredentialError.denied("cancelled"))) }
        @objc private func proceed() { completion(.success(true)) }
        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            // Interactive dismissal must release the waiting command as denial, never authorize mutation.
            completion(.failure(CredentialError.denied("dismissed")))
        }

        override func numberOfSections(in tableView: UITableView) -> Int { 4 }
        override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            switch section {
            case 0: return 1
            case 1: return max(1, review.changes.count)
            case 2: return 1 + (showUnchanged ? review.unchanged.count + 1 : 0)
            default: return showJSON ? 3 : 1
            }
        }
        override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
            section == 1 ? "Changes" : nil
        }
        override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            var content = cell.defaultContentConfiguration()
            content.textProperties.numberOfLines = 0
            content.secondaryTextProperties.numberOfLines = 0
            cell.selectionStyle = .none
            switch indexPath.section {
            case 0:
                content.text = name
                content.textProperties.font = .preferredFont(forTextStyle: .headline)
                content.secondaryText = "Change password protection?"
            case 1:
                if review.changes.isEmpty {
                    content.text = "No settings changed"
                } else {
                    let row = review.changes[indexPath.row]
                    content.text = row.label
                    let text = NSMutableAttributedString(
                        string: row.oldValue,
                        attributes: [
                            .foregroundColor: UIColor.secondaryLabel,
                            .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                        ])
                    text.append(
                        NSAttributedString(string: " → ", attributes: [.foregroundColor: UIColor.secondaryLabel]))
                    text.append(
                        NSAttributedString(
                            string: row.newValue,
                            attributes: [
                                .font: UIFont.preferredFont(forTextStyle: .headline), .foregroundColor: UIColor.label,
                            ]))
                    content.secondaryAttributedText = text
                    cell.accessibilityLabel = "\(row.label), old: \(row.oldValue), new: \(row.newValue)"
                }
            case 2:
                if indexPath.row == 0 {
                    content.text = "Unchanged: \(review.unchanged.count) settings"
                    configureDisclosure(cell, expanded: showUnchanged)
                } else if indexPath.row <= review.unchanged.count {
                    let row = review.unchanged[indexPath.row - 1]
                    content.text = row.label
                    content.secondaryText = row.newValue
                } else {
                    content.text = "Enforcement"
                    content.secondaryText = review.new.explanation
                }
            default:
                if indexPath.row == 0 {
                    content.text = "Raw JSON"
                    configureDisclosure(cell, expanded: showJSON)
                } else {
                    let policy = indexPath.row == 1 ? review.old : review.new
                    content.text = indexPath.row == 1 ? "Old policy" : "New policy"
                    content.secondaryText = String(decoding: (try? policy.json()) ?? Data(), as: UTF8.self)
                    content.secondaryTextProperties.font = UIFontMetrics(forTextStyle: .footnote).scaledFont(
                        for: .monospacedSystemFont(ofSize: 13, weight: .regular))
                }
            }
            cell.contentConfiguration = content
            return cell
        }
        private func configureDisclosure(_ cell: UITableViewCell, expanded: Bool) {
            cell.accessoryView = UIImageView(image: UIImage(systemName: expanded ? "chevron.down" : "chevron.right"))
            cell.accessibilityTraits.insert(.button)
            cell.accessibilityValue = expanded ? "Expanded" : "Collapsed"
            cell.selectionStyle = .default
        }
        override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
            guard indexPath.row == 0, indexPath.section >= 2 else { return }
            if indexPath.section == 2 { showUnchanged.toggle() } else { showJSON.toggle() }
            tableView.reloadSections(IndexSet(integer: indexPath.section), with: .none)
        }
    }

    private final class CredentialPolicyEditor: UIViewController {
        private let text = UITextView()
        private let data: Data
        private let completion: (Swift.Result<Data, Error>) -> Void
        init(data: Data, completion: @escaping (Swift.Result<Data, Error>) -> Void) {
            self.data = data
            self.completion = completion
            super.init(nibName: nil, bundle: nil)
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
        override func viewDidLoad() {
            super.viewDidLoad()
            title = "Password policy (JSON)"
            view.backgroundColor = .systemBackground
            text.text = String(decoding: data, as: UTF8.self)
            text.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
            text.autocorrectionType = .no
            text.autocapitalizationType = .none
            text.smartQuotesType = .no
            text.smartDashesType = .no
            text.translatesAutoresizingMaskIntoConstraints = false
            text.accessibilityLabel = "Password policy JSON"
            view.addSubview(text)
            NSLayoutConstraint.activate([
                text.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
                text.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
                text.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                text.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            ])
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                title: "Cancel", style: .plain, target: self, action: #selector(cancel))
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "Review", style: .done, target: self, action: #selector(save))
        }
        @objc private func cancel() { completion(.failure(CredentialError.denied("policy edit cancelled"))) }
        @objc private func save() { completion(.success(Data(text.text.utf8))) }
    }

    private let credentialCommandLock = NSLock()

    @_cdecl("keychain_main")
    public func keychainMain(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
        // Capture ios_system TLS streams and scene identity on the original command thread.
        let inputStream = thread_stdin
        let outputStream = thread_stdout
        let errorStream = thread_stderr
        guard !Thread.isMainThread else {
            fputs("keychain: command must run off the main queue\n", errorStream)
            return 1
        }
        let arguments = (1..<Int(argc)).map { String(cString: argv![$0]!) }
        if arguments == ["--help"] || arguments == ["help"] {
            guard fputs(KeychainCommand.usage, outputStream) >= 0, fflush(outputStream) == 0 else {
                fputs("keychain: command output failed\n", errorStream)
                return 1
            }
            return 0
        }
        guard !runningInExtension, let pointer = ios_getContext() else {
            fputs("keychain: interaction required in the foreground app scene\n", errorStream)
            return 1
        }
        let sceneID = String(cString: pointer.assumingMemoryBound(to: CChar.self))
        do {
            let scene = try DispatchQueue.main.sync {
                guard
                    let origin = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first(
                        where: {
                            $0.session.persistentIdentifier == sceneID
                        })
                else {
                    throw CredentialError.denied("interaction required in the originating foreground scene")
                }
                try CredentialSceneGate.require(
                    .entry, activation: .init(origin.activationState),
                    protectedDataAvailable: UIApplication.shared.isProtectedDataAvailable,
                    appInBackground: UIApplication.shared.applicationState == .background,
                    generationMatches: true, exportAuthorized: false)
                return origin
            }
            credentialCommandLock.lock()
            defer { credentialCommandLock.unlock() }
            let platform = try NativeCredentialPlatform(
                scene: scene, name: arguments.count > 1 ? arguments[1] : "", operation: arguments.first ?? "")
            var completed = false
            defer { if !completed { platform.finish(success: false) } }
            var result = KeychainCommand.run(
                arguments,
                input: {
                    if ios_isatty(STDIN_FILENO) == 1 { return try platform.secureInput(arguments[1]) }
                    var bytes = Data()
                    var buffer = [UInt8](repeating: 0, count: 4096)
                    defer { buffer.withUnsafeMutableBytes { $0.initializeMemory(as: UInt8.self, repeating: 0) } }
                    while true {
                        let count = fread(&buffer, 1, buffer.count, inputStream)
                        if count == 0 {
                            if ferror(inputStream) != 0 {
                                bytes.resetBytes(in: 0..<bytes.count)
                                throw CredentialError.invalid("stdin read failed; item unchanged")
                            }
                            return bytes
                        }
                        bytes.append(contentsOf: buffer.prefix(count))
                        if bytes.count > KeychainCommand.maximumSecretBytes {
                            bytes.resetBytes(in: 0..<bytes.count)
                            throw CredentialError.invalid("secret exceeds 65536 bytes; item unchanged")
                        }
                    }
                }, platform: platform)
            defer { result.output.resetBytes(in: 0..<result.output.count) }
            if !result.diagnostic.isEmpty { fputs(result.diagnostic, errorStream) }
            if !result.output.isEmpty {
                try platform.checkOutputAvailability()
                let count = result.output.withUnsafeBytes { fwrite($0.baseAddress, 1, $0.count, outputStream) }
                guard count == result.output.count, fflush(outputStream) == 0 else {
                    fputs("keychain: command output failed\n", errorStream)
                    return 1
                }
            }
            completed = result.status == 0
            return result.status
        } catch let error as CredentialError {
            fputs("keychain: \(error)\n", errorStream)
            return 1
        } catch {
            fputs("keychain: unavailable; no fallback\n", errorStream)
            return 1
        }
    }
#endif
