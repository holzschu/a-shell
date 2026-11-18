import Foundation
import CoreML
import CryptoKit
#if os(iOS)
import UIKit
#endif

private let packageCeiling: UInt64 = 2 * 1024 * 1024 * 1024
private let fixtureDigest = "8f6a418c9a639f9e14e96feca47a97df2a35a0a68ae2875431c5c80e05536941"
private let fm = FileManager.default
private let hexBytes: Set<UInt8> = Set("0123456789abcdef".utf8)

private func digestOK(_ value: String?) -> Bool {
    value.map { $0.utf8.count == 64 && $0.utf8.allSatisfy(hexBytes.contains) } ?? false
}

private func hexDigest(_ digest: SHA256.Digest) -> String {
    digest.map { String(format: "%02x", $0) }.joined()
}

private func hashData(_ data: Data) -> String {
    hexDigest(SHA256.hash(data: data))
}

private func hashFile(_ file: URL, check: StopCheck) throws -> String {
    guard let stream = InputStream(url: file) else { throw failure(1, "Cannot open file for hashing") }
    stream.open()
    defer { stream.close() }
    var hash = SHA256()
    var bytes = [UInt8](repeating: 0, count: 65536)
    while true {
        let count = stream.read(&bytes, maxLength: bytes.count)
        if count < 0 { throw stream.streamError ?? failure(1, "Cannot read file for hashing") }
        if count == 0 { return hexDigest(hash.finalize()) }
        try check()
        bytes.withUnsafeBytes { hash.update(bufferPointer: UnsafeRawBufferPointer(rebasing: $0[..<count])) }
    }
}

private func modelsRoot() -> URL {
    var support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    // Keep the physical spelling of the existing ancestor for symlink checks.
    var tail: [String] = []
    var resolved = [CChar](repeating: 0, count: Int(PATH_MAX))
    while realpath(support.path, &resolved) == nil && support.path.count > 1 {
        tail.append(support.lastPathComponent)
        support.deleteLastPathComponent()
    }
    if realpath(support.path, &resolved) != nil {
        support = URL(fileURLWithPath: String(cString: resolved), isDirectory: true)
    }
    for part in tail.reversed() { support.appendPathComponent(part, isDirectory: true) }
    return support.appendingPathComponent("a-Shell/Models", isDirectory: true)
}

private func plainPath(_ url: URL) throws {
    var item = url
    while item.path.count > 1 {
        var info = stat()
        if lstat(item.path, &info) == 0 && info.st_mode & S_IFMT == S_IFLNK {
            throw failure(2, "Model storage must not contain symlinks: " + item.path)
        }
        item.deleteLastPathComponent()
    }
}

private func exclude(_ url: URL) throws {
    let resource = url as NSURL
    try resource.setResourceValue(true, forKey: .isExcludedFromBackupKey)
    resource.removeCachedResourceValue(forKey: .isExcludedFromBackupKey)
    var flag: AnyObject?
    try resource.getResourceValue(&flag, forKey: .isExcludedFromBackupKey)
#if os(iOS)
    guard (flag as? NSNumber)?.boolValue == true else { throw failure(1, "Backup exclusion was not retained") }
#endif
}

private func makeDirectory(_ url: URL) throws {
    try plainPath(url)
    try fm.createDirectory(at: url, withIntermediateDirectories: true)
    try exclude(url)
}

private func atomicData(_ data: Data, _ url: URL) throws {
    try plainPath(url)
    let parent = url.deletingLastPathComponent()
    let temp = parent.appendingPathComponent(".record-" + UUID().uuidString)
    let fd = open(temp.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
    guard fd >= 0 else { throw failure(1, "Cannot create transaction record") }
    defer { _ = unlink(temp.path) }
    let written = data.withUnsafeBytes { writeAll(fd, $0, retryInterrupted: false) }
    let synced = written && fsync(fd) == 0
    close(fd)
    guard synced else { throw failure(1, "Cannot publish transaction record") }
    try exclude(temp)
    guard rename(temp.path, url.path) == 0 else { throw failure(1, "Cannot publish transaction record") }
    let directory = open(parent.path, O_RDONLY)
    if directory >= 0 {
        fsync(directory)
        close(directory)
    }
}

private func writeJSON(_ value: JSON, _ url: URL) throws {
    try atomicData(jsonData(value), url)
}

private func readJSON(_ url: URL) -> JSON? {
    guard (try? plainPath(url)) != nil, let data = try? Data(contentsOf: url),
          data.count <= 16 * 1024 * 1024 else { return nil }
    return jsonObject(data)
}

private func verifiedFile(_ url: URL, entry: JSON, check: StopCheck) throws {
    try plainPath(url)
    var info = stat()
    guard lstat(url.path, &info) == 0, isRegular(info), info.st_size == entry["bytes"] as? Int64,
          try hashFile(url, check: check) == entry["sha256"] as? String else {
        throw failure(2, "Package member size, type or SHA256 mismatch")
    }
}

private func treeReceipt(_ url: URL, sync: Bool, check: StopCheck) throws -> [String: JSON] {
    try plainPath(url)
    var files: [String: JSON] = [:]
    guard fm.fileExists(atPath: url.path),
          let entries = fm.enumerator(at: url, includingPropertiesForKeys: nil) else {
        throw failure(2, "Compiled model is empty")
    }
    for case let child as URL in entries {
        try check()
        var info = stat()
        guard lstat(child.path, &info) == 0, isRegular(info) || info.st_mode & S_IFMT == S_IFDIR else {
            throw failure(2, "Compiled model contains an unsafe entry")
        }
        if sync { try exclude(child) }
        if isRegular(info) {
            let path = String(child.path.dropFirst(url.path.count + 1))
            files[path] = ["bytes": info.st_size, "sha256": try hashFile(child, check: check)]
        }
        if sync {
            let fd = open(child.path, O_RDONLY | O_NOFOLLOW)
            guard fd >= 0 else { throw failure(1, "Cannot make model durable") }
            let result = fsync(fd)
            close(fd)
            guard result == 0 else { throw failure(1, "Cannot make model durable") }
        }
    }
    guard !files.isEmpty else { throw failure(2, "Compiled model is empty") }
    return files
}

private func versionIdentity(_ directory: URL, check: StopCheck) throws -> [String: [Int64]] {
    try plainPath(directory)
    var failed = false
    guard let entries = fm.enumerator(at: directory, includingPropertiesForKeys: nil, errorHandler: { _, _ in
        failed = true
        return false
    }) else { throw failure(2, "Cannot inspect installed model version") }
    // ctime detects in-place leaf edits even when mtimes are restored.
    var identity: [String: [Int64]] = [:]
    var entry: URL? = directory
    while let current = entry {
        try check()
        var info = stat()
        guard lstat(current.path, &info) == 0, isRegular(info) || info.st_mode & S_IFMT == S_IFDIR else {
            throw failure(2, "Cannot inspect installed model version")
        }
        identity[current.path] = [Int64(info.st_dev), Int64(bitPattern: info.st_ino), Int64(info.st_mode), info.st_size,
                                  Int64(info.st_uid), Int64(info.st_gid), Int64(info.st_nlink),
                                  Int64(info.st_mtimespec.tv_sec), Int64(info.st_mtimespec.tv_nsec),
                                  Int64(info.st_ctimespec.tv_sec), Int64(info.st_ctimespec.tv_nsec)]
        entry = entries.nextObject() as? URL
    }
    guard !failed else { throw failure(2, "Cannot inspect installed model version") }
    return identity
}

private struct Lease {
    let fd: Int32
    let model: String
    let receipt: JSON
    let identity: [String: [Int64]]

    static let lock = NSLock()
    static var active: [String: Lease] = [:]
}

struct ModelStore {
    let model: String
    fileprivate let root: URL

    init(_ model: String) throws {
        guard model == "mnist" || isEmbedding(model) else { throw failure(2, "Unsupported model id") }
        self.model = model
        root = modelsRoot().appendingPathComponent(model, isDirectory: true)
    }

    private var currentRecord: URL { root.appendingPathComponent("active.json") }
    private var journal: URL { root.appendingPathComponent("install.json") }

    private func version(_ digest: String) -> URL {
        root.appendingPathComponent(digest, isDirectory: true)
    }

    private func lockFile(_ name: String, _ operation: Int32, wait: Bool = true) throws -> Int32 {
        try makeDirectory(root)
        let fd = open(root.appendingPathComponent(name).path, O_RDWR | O_CREAT | O_NOFOLLOW, 0o600)
        guard fd >= 0 else { throw failure(75, "Cannot open model store lock") }
        let deadline = ProcessInfo.processInfo.systemUptime + 0.5
        while flock(fd, operation | LOCK_NB) != 0 {
            if errno != EWOULDBLOCK || !wait || name != ".install-lock" || ProcessInfo.processInfo.systemUptime >= deadline {
                close(fd)
                throw failure(75, "Model store is busy; retry after the active operation completes")
            }
            if commandInterrupted() {
                close(fd)
                throw failure(130, "Installation cancelled while waiting for the model store")
            }
            usleep(10000)
        }
        return fd
    }

    private func checkedReceipt(_ digest: String?, check: StopCheck) throws -> JSON {
        guard let digest, digestOK(digest) else { throw failure(2, "Invalid installed manifest digest") }
        let dir = version(digest)
        guard let manifest = try? Data(contentsOf: dir.appendingPathComponent("manifest.json")),
              let plan = jsonObject(manifest), (try? validatePlan(plan)) != nil else {
            throw failure(2, "Installed manifest is invalid; download again with coreml install")
        }
        guard var receipt = readJSON(dir.appendingPathComponent("receipt.json")),
              plan.allSatisfy({ (receipt[$0.key] as? NSObject)?.isEqual($0.value) == true }) else {
            throw failure(2, "Installed receipt differs from its pinned manifest; download again with coreml install")
        }
        do {
            guard receipt["manifest_sha256"] as? String == digest, hashData(manifest) == digest else {
                throw failure(2, "Installed manifest digest mismatch")
            }
            try packageFiles(dir.appendingPathComponent("package", isDirectory: true), plan: plan, check: check)
            let compiled = try treeReceipt(dir.appendingPathComponent("model.mlmodelc"), sync: false, check: check)
            guard (receipt["compiled_files"] as? NSDictionary)?.isEqual(compiled as NSDictionary) == true else {
                throw failure(2, "Installed compiled receipt mismatch")
            }
        } catch {
            try check()
            throw failure(2, "Installed model files are missing or changed; download again with coreml install")
        }
        receipt["path"] = dir.path
        // Installed receipts remain usable when the backup flag cannot be queried.
        let flag = (try? dir.resourceValues(forKeys: [.isExcludedFromBackupKey]))?.isExcludedFromBackup
        receipt["excluded_from_backup"] = flag ?? false
        return receipt
    }

    func installed(check: StopCheck = checkCommand) throws -> JSON {
        guard let active = readJSON(currentRecord) else {
            try check()
            throw failure(2, "Model is not installed; reinstall with coreml install")
        }
        return try checkedReceipt(active["active"] as? String, check: check)
    }

    func acquire(check: StopCheck) throws -> JSON {
        try check()
        let storeLock = try lockFile(".install-lock", LOCK_EX)
        defer { close(storeLock) }
        guard let active = readJSON(currentRecord) else {
            throw failure(2, "Model is not installed; reinstall with coreml install")
        }
        guard let digest = active["active"] as? String, digestOK(digest) else {
            throw failure(2, "Invalid installed manifest digest")
        }
        let directory = version(digest)
        let identity = try? versionIdentity(directory, check: check)
        let reused = Lease.lock.withLock {
            Lease.active.values.first {
                identity != nil && $0.model == model && $0.receipt["manifest_sha256"] as? String == digest && $0.identity == identity
            }?.receipt
        }
        let receipt: JSON
        if let reused {
            receipt = reused
        } else {
            receipt = try installed(check: check)
            guard let identity, identity == (try? versionIdentity(directory, check: check)) else {
                try check()
                throw failure(2, "Installed model changed during verification")
            }
        }
        try check()
        let fd = try lockFile(".lease-" + digest, LOCK_SH)
        let token = UUID().uuidString
        Lease.lock.withLock {
            Lease.active[token] = Lease(fd: fd, model: model, receipt: receipt, identity: identity ?? [:])
        }
        var result = receipt
        result["lease_id"] = token
        result["verification_cached"] = reused != nil
        return result
    }

    static func release(_ token: String) {
        let lease = Lease.lock.withLock {
            let lease = Lease.active.removeValue(forKey: token)
            if let lease { close(lease.fd) }
            return lease
        }
        guard let lease, let store = try? ModelStore(lease.model),
              let storeLock = try? store.lockFile(".install-lock", LOCK_EX, wait: false) else { return }
        defer { close(storeLock) }
        if let record = readJSON(store.currentRecord) { store.collect(record) }
    }

    private func collect(_ record: JSON) {
        guard let entries = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { return }
        for child in entries {
            let name = child.lastPathComponent
            guard digestOK(name), name != record["active"] as? String, name != record["rollback"] as? String,
                  let fd = try? lockFile(".lease-" + name, LOCK_EX) else { continue }
            if (try? plainPath(child)) != nil { try? fm.removeItem(at: child) }
            close(fd)
        }
    }

    func rollback() throws -> JSON {
        let storeLock = try lockFile(".install-lock", LOCK_EX)
        defer { close(storeLock) }
        let record = readJSON(currentRecord)
        let receipt = try checkedReceipt(record?["rollback"] as? String, check: checkCommand)
        guard let active = record?["active"] as? String, let rollback = record?["rollback"] as? String else {
            throw failure(2, "Invalid installed manifest digest")
        }
        let next = ["active": rollback, "rollback": active]
        try writeJSON(next, currentRecord)
        collect(next)
        return receipt
    }

    func remove() throws -> JSON {
        let storeLock = try lockFile(".install-lock", LOCK_EX)
        var leases: [Int32] = []
        defer {
            for fd in leases { close(fd) }
            close(storeLock)
        }
        let children = try fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
        for child in children where digestOK(child.lastPathComponent) {
            leases.append(try lockFile(".lease-" + child.lastPathComponent, LOCK_EX))
        }
        // Remove the pointer first so a crash cannot leave it naming deleted content.
        if fm.fileExists(atPath: currentRecord.path) { try fm.removeItem(at: currentRecord) }
        for child in children {
            let name = child.lastPathComponent
            if digestOK(name) || name.hasPrefix(".staging-") || name == "install.json" {
                try plainPath(child)
                try fm.removeItem(at: child)
            }
        }
        return ["removed": model]
    }

    func status() throws -> JSON {
        // The journal survives crashes. Probe the lock without creating storage.
        let fd = open(root.appendingPathComponent(".install-lock").path, O_RDONLY | O_NOFOLLOW)
        defer { if fd >= 0 { close(fd) } }
        var running = false
        if fd >= 0 && flock(fd, LOCK_SH | LOCK_NB) != 0 {
            guard errno == EWOULDBLOCK else { throw failure(2, "Cannot inspect installation command lock") }
            running = true
        } else if fd < 0 && errno != ENOENT {
            throw failure(2, "Cannot inspect installation command lock")
        }
        var state = readJSON(journal) ?? ["model_id": model, "phase": "idle"]
        state["command_running"] = running
        return state
    }

    func cancel(_ generation: String) throws -> JSON {
        let commitLock = try lockFile(".commit-lock", LOCK_EX)
        defer { close(commitLock) }
        let state = try status()
        guard state["generation"] as? String == generation, state["phase"] as? String != "active" else {
            throw failure(2, "No cancellable installation with that generation")
        }
        guard let name = state["stage"] as? String, name.hasPrefix(".staging-"), !name.contains("/") else {
            throw failure(2, "Invalid installation stage")
        }
        let file = root.appendingPathComponent(name).appendingPathComponent("cancel-" + generation)
        try atomicData(Data(), file)
        return ["cancel_requested": generation]
    }

    private func phase(_ stage: URL, _ digest: String, _ generation: String, _ name: String) throws {
        try writeJSON(["model_id": model, "manifest_sha256": digest, "generation": generation,
                       "phase": name, "stage": stage.lastPathComponent], journal)
    }

    private func spaceForPlan(_ estimate: UInt64) throws {
        let capacity = try root.resourceValues(forKeys: [.volumeAvailableCapacityKey]).volumeAvailableCapacity
        guard UInt64(max(capacity ?? 0, 0)) >= estimate else {
            throw failure(75, "Insufficient disk space for source, compile peak and retained version")
        }
    }
}

@_cdecl("ASMLAcquireVersion")
func acquireVersionC(_ model: UnsafeRawPointer?, _ check: ErrorCheckBlock?,
                     _ error: UnsafeMutablePointer<UnsafeMutableRawPointer?>?) -> UnsafeMutableRawPointer? {
    bridgeJSON(error) {
        try ModelStore(borrowedObject(model) as? String ?? "").acquire {
            if let check { try checkBlock(check) } else { try checkCommand() }
        }
    }
}

@_cdecl("ASMLReleaseVersion")
func releaseVersionC(_ token: UnsafeRawPointer?) {
    if let token = borrowedObject(token) as? String { ModelStore.release(token) }
}

private func boundedNumber(_ value: Any?, _ ceiling: UInt64) -> UInt64? {
    guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
          number.doubleValue >= 1, number.doubleValue <= Double(ceiling),
          number.doubleValue == Double(number.uint64Value) else { return nil }
    return number.uint64Value
}

private func memberPath(_ name: String) -> Bool {
    !name.isEmpty && !name.hasPrefix("/") && !name.contains("\\")
        && name.utf8.allSatisfy { (32...126).contains($0) }
        && name.components(separatedBy: "/").allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
}

private func validatePackagePlan(_ plan: JSON) throws {
    guard let members = plan["members"] as? [String: JSON], (1...100000).contains(members.count),
          let limits = plan["limits"] as? JSON,
          let archiveLimit = boundedNumber(limits["archive_bytes"], packageCeiling),
          let memberLimit = boundedNumber(limits["member_bytes"], packageCeiling) else {
        throw failure(2, "Invalid package format, member map or byte limits")
    }
    let validation = plan["validation"] as? JSON
    guard let model = plan["model"] as? String, let license = plan["license_file"] as? String,
          let recipe = plan["recipe"] as? String, let input = validation?["input"] as? String,
          [model, license, recipe, input].allSatisfy(memberPath), members["manifest.json"] == nil else {
        throw failure(2, "Invalid package member paths")
    }
    guard let modelEntry = members[model] else { throw failure(2, "Package model is undeclared") }
    let modelExtension = (model as NSString).pathExtension
    let tree = modelExtension == "mlpackage" && modelEntry["type"] as? String == "directory"
    guard tree || (modelExtension == "mlmodel" && modelEntry["type"] as? String == "file") else {
        throw failure(2, "Package model must be a portable mlmodel or mlpackage")
    }
    var total: UInt64 = 0
    var sourceBytes: UInt64 = 0
    var identity = ""
    let emptyDigest = hashData(Data())
    for name in members.keys.sorted() {
        guard let entry = members[name], memberPath(name), let digest = entry["sha256"] as? String,
              digestOK(digest) else { throw failure(2, "Invalid package member declaration") }
        let belowModel = name.hasPrefix(model + "/")
        if entry["type"] as? String == "directory" {
            guard tree, name == model || belowModel, entry["bytes"] as? Int == 0, digest == emptyDigest else {
                throw failure(2, "Package directories are restricted to the model tree")
            }
        } else {
            guard entry["type"] as? String == "file", let bytes = boundedNumber(entry["bytes"], memberLimit) else {
                throw failure(2, "Package member exceeds its declared bound")
            }
            guard bytes <= packageCeiling - total else { throw failure(2, "Package content exceeds archive ceiling") }
            total += bytes
            if tree && belowModel {
                sourceBytes += bytes
                identity += "\(digest)  \(name.dropFirst(model.count + 1))\n"
            }
        }
        let parent = (name as NSString).deletingLastPathComponent
        guard parent.isEmpty || members[parent]?["type"] as? String == "directory" else {
            throw failure(2, "Package parent directory is undeclared")
        }
    }
    guard [license, recipe, input].allSatisfy({ members[$0]?["type"] as? String == "file" }) else {
        throw failure(2, "Package license, recipe and fixture must be regular members")
    }
    guard total <= archiveLimit,
          (members[license]?["bytes"] as? UInt64 ?? 0) <= 1024 * 1024,
          (members[recipe]?["bytes"] as? UInt64 ?? 0) <= 16 * 1024 * 1024,
          members[license]?["bytes"] as? UInt64 == plan["license_bytes"] as? UInt64,
          members[license]?["sha256"] as? String == plan["license_sha256"] as? String,
          plan["model_id"] as? String != "mnist"
            || (members[input]?["bytes"] as? Int == 784 && members[input]?["sha256"] as? String == fixtureDigest) else {
        throw failure(2, "Invalid package license, recipe or known-answer fixture receipt")
    }
    let sourceSHA = tree ? hashData(Data(identity.utf8)) : modelEntry["sha256"] as? String
    let sourceSize = tree ? sourceBytes : modelEntry["bytes"] as? UInt64
    guard sourceSHA == plan["source_sha256"] as? String, sourceSize == plan["source_bytes"] as? UInt64 else {
        throw failure(2, "Package model identity differs from member receipts")
    }
}

private func packageFiles(_ directory: URL, plan: JSON, check: StopCheck) throws {
    guard let members = plan["members"] as? [String: JSON],
          let entries = fm.enumerator(at: directory, includingPropertiesForKeys: nil) else {
        throw failure(2, "Package members are missing")
    }
    var count = 0
    for case let file as URL in entries {
        try check()
        let name = String(file.path.dropFirst(directory.path.count + 1))
        try plainPath(file)
        var info = stat()
        guard let entry = members[name], lstat(file.path, &info) == 0 else {
            throw failure(2, "Package contains an unknown or missing entry")
        }
        if entry["type"] as? String == "directory" {
            guard info.st_mode & S_IFMT == S_IFDIR else { throw failure(2, "Package member size, type or SHA256 mismatch") }
        } else {
            try verifiedFile(file, entry: entry, check: check)
        }
        count += 1
    }
    guard count == members.count else { throw failure(2, "Package members are missing") }
}

private func fixturePixels(_ validation: JSON) throws -> Data {
    guard let hex = validation["input_hex"] as? String, hex.utf16.count == 1568,
          validation["label"] as? String == "7" else {
        throw failure(2, "Manifest must include the bounded known-answer digit 7 fixture")
    }
    let bytes = Array(hex.utf8)
    guard bytes.allSatisfy(hexBytes.contains) else { throw failure(2, "Invalid validation fixture encoding") }
    func digit(_ byte: UInt8) -> UInt8 { byte < 97 ? byte - 48 : byte - 87 }
    return Data(stride(from: 0, to: bytes.count, by: 2).map { digit(bytes[$0]) * 16 + digit(bytes[$0 + 1]) })
}

extension ModelStore {
    private func validatePlan(_ plan: JSON) throws {
        guard plan["package_format"] as? String == "ashell-model-ustar-v1" else {
            throw failure(2, "Only portable model packages are supported; reinstall with coreml install")
        }
        guard let memory = plan["memory_profile"] as? JSON, let validation = plan["validation"] as? JSON else {
            throw failure(2, "Manifest memory profile and validation must be objects")
        }
        guard plan["source_url"] is String, plan["license_url"] is String else {
            throw failure(2, "Manifest URLs must be strings")
        }
        let common = plan["schema"] as? Int == 1 && plan["model_id"] as? String == model
            && plan["runtime"] as? String == "CoreML" && plan["runtime_abi"] as? Int == 1
            && digestOK(plan["source_sha256"] as? String) && boundedNumber(plan["source_bytes"], packageCeiling) != nil
            && digestOK(plan["license_sha256"] as? String) && boundedNumber(plan["license_bytes"], 1024 * 1024) != nil
            && (plan["version"] as? String)?.isEmpty == false
        if isEmbedding(model) {
            do {
                guard common, plan["license"] as? String == "Apache-2.0",
                      (plan["disk_estimate_bytes"] as? NSNumber)?.uint64Value ?? 0 >= packageCeiling else {
                    throw failure(2, "Invalid embedding package contract")
                }
                try validateEmbeddingPlan(plan)
                try validatePackagePlan(plan)
            } catch {
                throw failure(2, "Invalid embedding package contract")
            }
#if os(iOS)
            guard #available(iOS 18, *) else { throw failure(75, "Embedding packages require iOS 18 or newer") }
#endif
            return
        }
        let features: NSDictionary = ["image": ["type": "image", "dtype": "uint8", "shape": [28, 28]]]
        guard common, plan["adapter_version"] as? Int == 1,
              plan["source_revision"] is String, (plan["license"] as? String)?.isEmpty == false,
              (plan["features"] as? NSDictionary)?.isEqual(features) == true,
              memory["kind"] as? String == "bounded-skeleton-estimate",
              (plan["disk_estimate_bytes"] as? NSNumber)?.int64Value ?? 0 >= 8 * 1024 * 1024,
              let minimum = plan["minimum_ios"] as? String, plan["preprocessing"] is String, plan["decoder"] is String,
              ["archive", "files", "source_path", "archive_url"].allSatisfy({ plan[$0] == nil }) else {
            throw failure(2, "Unsupported or unsafe manifest for the drawing-classification adapter")
        }
        guard plan["task"] as? String == "drawing-classification" else {
            throw failure(2, "Unsupported task/adapter; only drawing-classification/1 is registered")
        }
        let outputs: NSDictionary = ["classLabel": ["type": "int64"],
                                     "labelProbabilities": ["type": "dictionary", "key_type": "int64", "count": 10]]
        do {
            try validatePackagePlan(plan)
            guard (plan["outputs"] as? NSDictionary)?.isEqual(outputs) == true else {
                throw failure(2, "Invalid package members or output feature declarations")
            }
        } catch {
            throw failure(2, "Invalid package members or output feature declarations")
        }
        let scanner = Scanner(string: minimum)
        guard let major = scanner.scanInt(), (14...100).contains(major) else {
            throw failure(2, "Invalid minimum OS version")
        }
        var minor = 0
        if !scanner.isAtEnd {
            guard scanner.scanString(".") != nil, let parsed = scanner.scanInt(), scanner.isAtEnd else {
                throw failure(2, "Invalid minimum OS version")
            }
            minor = parsed
        }
#if os(iOS)
        guard ProcessInfo.processInfo.isOperatingSystemAtLeast(
            OperatingSystemVersion(majorVersion: major, minorVersion: minor, patchVersion: 0)) else {
            throw failure(75, "Model requires a newer iOS version")
        }
#endif
        guard try hashData(fixturePixels(validation)) == fixtureDigest else {
            throw failure(2, "Known-answer fixture SHA256 mismatch")
        }
    }
}

private func readExact(_ fd: Int32, _ buffer: UnsafeMutableRawBufferPointer) -> Bool {
    var offset = 0
    while offset < buffer.count {
        let count = read(fd, buffer.baseAddress!.advanced(by: offset), buffer.count - offset)
        if count < 0 && errno == EINTR { continue }
        if count <= 0 { return false }
        offset += count
    }
    return true
}

private func tarOctal(_ bytes: ArraySlice<UInt8>) -> UInt64? {
    var value: UInt64 = 0
    var hasDigit = false
    var ended = false
    for byte in bytes {
        if byte == 0 || byte == 32 {
            if hasDigit { ended = true }
            continue
        }
        guard !ended, (48...55).contains(byte) else { return nil }
        let digit = UInt64(byte - 48)
        guard value <= (packageCeiling - digit) / 8 else { return nil }
        hasDigit = true
        value = value * 8 + digit
    }
    return hasDigit ? value : nil
}

private func tarString(_ bytes: ArraySlice<UInt8>) -> String? {
    let end = bytes.firstIndex(of: 0) ?? bytes.endIndex
    guard bytes[end...].allSatisfy({ $0 == 0 }) else { return nil }
    return String(bytes: bytes[..<end], encoding: .ascii)
}

private func checkInstall(_ stage: URL, _ generation: String, _ message: String = "Installation cancelled") throws {
    if installCancelled(stage, generation) { throw failure(130, message) }
}

private func installCancelled(_ stage: URL, _ generation: String) -> Bool {
    commandInterrupted() || fm.fileExists(atPath: stage.appendingPathComponent("cancel-" + generation).path)
}

extension ModelStore {
    private func extractPackage(_ archive: URL, stage: URL, generation: String, check: StopCheck) throws -> (JSON, Data) {
        try plainPath(archive)
        let fd = open(archive.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK)
        defer { if fd >= 0 { close(fd) } }
        var info = stat()
        guard fd >= 0, fstat(fd, &info) == 0, isRegular(info), info.st_size >= 1536,
              UInt64(info.st_size) <= packageCeiling, info.st_size % 512 == 0 else {
            throw failure(2, "Invalid or oversized ustar package")
        }
        let length = UInt64(info.st_size)
        let contents = stage.appendingPathComponent("package", isDirectory: true)
        if fm.fileExists(atPath: contents.path) {
            try plainPath(contents)
            try fm.removeItem(at: contents)
        }
        try makeDirectory(contents)
        var manifest: (JSON, Data)?
        var members: [String: JSON] = [:]
        var seen = Set<String>()
        var offset: UInt64 = 0
        var header = [UInt8](repeating: 0, count: 512)
        while offset < length {
            try checkInstall(stage, generation, "Installation cancelled during package extraction")
            guard header.withUnsafeMutableBytes({ readExact(fd, $0) }) else { break }
            offset += 512
            if header.allSatisfy({ $0 == 0 }) {
                guard header.withUnsafeMutableBytes({ readExact(fd, $0) }), header.allSatisfy({ $0 == 0 }) else { break }
                offset += 512
                while offset < length {
                    guard header.withUnsafeMutableBytes({ readExact(fd, $0) }), header.allSatisfy({ $0 == 0 }) else {
                        throw failure(2, "Nonzero content after ustar terminator")
                    }
                    offset += 512
                }
                guard let manifest, seen.count == members.count else { throw failure(2, "Package members are missing") }
                try packageFiles(contents, plan: manifest.0, check: check)
                return manifest
            }
            let actual = header.enumerated().reduce(UInt64(0)) { $0 + ((148..<156).contains($1.offset) ? 32 : UInt64($1.element)) }
            guard header[257..<265].elementsEqual([117, 115, 116, 97, 114, 0, 48, 48]),
                  tarOctal(header[148..<156]) == actual, let size = tarOctal(header[124..<136]),
                  header[157..<257].allSatisfy({ $0 == 0 }),
                  var name = tarString(header[..<100]), let prefix = tarString(header[345..<500]) else { break }
            if !prefix.isEmpty { name = prefix + "/" + name }
            let isDirectory = header[156] == 53
            if isDirectory && name.hasSuffix("/") { name.removeLast() }
            guard memberPath(name), isDirectory ? size == 0 : (header[156] == 48 || header[156] == 0),
                  size <= length - offset else { break }
            if manifest == nil {
                guard !isDirectory, name == "manifest.json", (1...1024 * 1024).contains(size) else { break }
                var data = Data(count: Int(size))
                guard data.withUnsafeMutableBytes({ readExact(fd, $0) }) else { break }
                guard let plan = jsonObject(data), plan["package_format"] != nil else {
                    throw failure(2, "Invalid package manifest")
                }
                try validatePlan(plan)
                let limits = plan["limits"] as? JSON
                guard length <= (limits?["archive_bytes"] as? UInt64 ?? 0) else {
                    throw failure(2, "Archive exceeds manifest limit")
                }
                try spaceForPlan((plan["disk_estimate_bytes"] as? NSNumber)?.uint64Value ?? 0)
                manifest = (plan, data)
                members = plan["members"] as? [String: JSON] ?? [:]
            } else {
                let parent = (name as NSString).deletingLastPathComponent
                guard let entry = members[name], !seen.contains(name), seen.count < 100000,
                      entry["type"] as? String == (isDirectory ? "directory" : "file"),
                      size == entry["bytes"] as? UInt64, parent.isEmpty || seen.contains(parent) else { break }
                let destination = contents.appendingPathComponent(name, isDirectory: isDirectory)
                if isDirectory {
                    try makeDirectory(destination)
                } else {
                    try plainPath(destination)
                    let output = open(destination.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
                    guard output >= 0 else { throw failure(2, "Cannot create package member") }
                    do {
                        defer { close(output) }
                        try copyBytes(fd, to: output, size: size, errorMessage: "Package member size or SHA256 mismatch") {
                            try checkInstall(stage, generation, "Installation cancelled during package extraction")
                        }
                    }
                    try exclude(destination)
                    try verifiedFile(destination, entry: entry, check: check)
                }
                seen.insert(name)
            }
            offset += size
            let padding = Int((512 - size % 512) % 512)
            let padded = header.withUnsafeMutableBytes {
                readExact(fd, UnsafeMutableRawBufferPointer(rebasing: $0[..<padding]))
            }
            guard padded, header[..<padding].allSatisfy({ $0 == 0 }) else { break }
            offset += UInt64(padding)
        }
        throw failure(2, "Invalid ustar header, path, entry, padding or terminator")
    }

    private func copyBytes(_ input: Int32, to output: Int32, size: UInt64, errorMessage: String, check: StopCheck) throws {
        var buffer = [UInt8](repeating: 0, count: 65536)
        var remaining = size
        while remaining > 0 {
            try check()
            let count = Int(min(remaining, UInt64(buffer.count)))
            let readOK = buffer.withUnsafeMutableBytes {
                readExact(input, UnsafeMutableRawBufferPointer(rebasing: $0[..<count]))
            }
            guard readOK, buffer.withUnsafeBytes({ writeAll(output, UnsafeRawBufferPointer(rebasing: $0[..<count])) }) else {
                throw failure(2, errorMessage)
            }
            remaining -= UInt64(count)
        }
    }

    private func copyPackage(_ source: URL, _ target: URL, stage: URL, generation: String) throws {
        try plainPath(source)
        try plainPath(target)
        let input = open(source.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK)
        defer { if input >= 0 { close(input) } }
        var info = stat()
        guard input >= 0, fstat(input, &info) == 0, isRegular(info), info.st_size > 0,
              UInt64(info.st_size) <= packageCeiling else { throw failure(2, "Invalid local package or archive size") }
        try spaceForPlan(UInt64(info.st_size) + 8 * 1024 * 1024)
        let output = open(target.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
        guard output >= 0 else { throw failure(2, "Cannot stage package") }
        defer { close(output) }
        let errorMessage = "Package changed or could not be copied"
        try copyBytes(input, to: output, size: UInt64(info.st_size), errorMessage: errorMessage) {
            try checkInstall(stage, generation, "Installation cancelled while copying package")
        }
        var byte: UInt8 = 0
        guard fstat(input, &info) == 0, read(input, &byte, 1) == 0 else { throw failure(2, errorMessage) }
        try exclude(target)
    }
}

private func webURL(_ url: URL?) -> Bool {
    guard let url else { return false }
    return url.scheme == "https" || (url.scheme == "http" && ["127.0.0.1", "::1"].contains(url.host ?? ""))
}

// URLSession calls each delegate serially. The waiting command reads the
// result only after the delegate signals completion.
private final class Transfer: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    let destination: URL
    let stage: URL
    let generation: String
    let limit: UInt64
    let finished = DispatchSemaphore(value: 0)
    var error: Error?

    init(destination: URL, stage: URL, generation: String, limit: UInt64) {
        self.destination = destination
        self.stage = stage
        self.generation = generation
        self.limit = limit
    }

    func redirect(_ request: URLRequest) -> URLRequest? {
        guard webURL(request.url) else {
            error = failure(2, "Download redirect must use HTTPS or literal loopback HTTP")
            return nil
        }
        return request
    }

    func received(_ task: URLSessionDownloadTask, total: Int64, expected: Int64) {
        if installCancelled(stage, generation) {
            error = failure(130, "Installation cancelled")
            task.cancel()
        } else if total > limit || (expected > 0 && expected > limit) {
            error = failure(2, "Download exceeds declared size")
            task.cancel()
        }
    }

    func downloaded(_ task: URLSessionDownloadTask, to location: URL) {
        guard error == nil else { return }
        do {
            try checkInstall(stage, generation)
            guard (task.response as? HTTPURLResponse)?.statusCode == 200 else {
                throw failure(1, "Download returned an HTTP error")
            }
            var info = stat()
            guard stat(location.path, &info) == 0, info.st_size <= limit else {
                throw failure(2, "Download exceeds declared size")
            }
            try plainPath(destination)
            try exclude(location)
            // The destination belongs to this generation, never to an installed version.
            try fm.moveItem(at: location, to: destination)
            try exclude(destination)
        } catch {
            self.error = error
        }
    }

    func complete(_ error: Error?) {
        if self.error == nil { self.error = error }
        finished.signal()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(redirect(request))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        received(downloadTask, total: totalBytesWritten, expected: totalBytesExpectedToWrite)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        downloaded(downloadTask, to: location)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        complete(error)
    }
}

#if os(iOS)
private final class BackgroundDownloads: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    static let identifier = (Bundle.main.bundleIdentifier ?? "") + ".models.v1"
    static let shared = BackgroundDownloads()

    private let lock = NSLock()
    private var owners: [Int: Transfer] = [:]
    private var completion: (() -> Void)?
    private(set) var session: URLSession!

    private override init() {
        super.init()
        let config = URLSessionConfiguration.background(withIdentifier: Self.identifier)
        config.sessionSendsLaunchEvents = true
        config.isDiscretionary = false
        config.timeoutIntervalForResource = 24 * 60 * 60
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    func register(_ transfer: Transfer, for task: URLSessionTask) {
        lock.withLock { owners[task.taskIdentifier] = transfer }
    }

    func setCompletion(_ completion: @escaping () -> Void) {
        lock.withLock { self.completion = completion }
    }

    private func owner(_ task: URLSessionTask) -> Transfer? {
        lock.withLock {
            if let owner = owners[task.taskIdentifier] { return owner }
            guard let description = task.taskDescription, let meta = jsonObject(Data(description.utf8)),
                  let digest = meta["manifest_sha256"] as? String, digestOK(digest),
                  let generation = meta["generation"] as? String, let name = meta["name"] as? String,
                  !name.contains("/"), !name.contains(".."), let limit = meta["limit"] as? UInt64,
                  let store = try? ModelStore(meta["model_id"] as? String ?? "mnist"), let state = try? store.status(),
                  state["generation"] as? String == generation, state["manifest_sha256"] as? String == digest else {
                task.cancel()
                return nil
            }
            let stage = store.root.appendingPathComponent(".staging-" + digest)
            guard (try? plainPath(stage)) != nil, fm.fileExists(atPath: stage.path) else {
                task.cancel()
                return nil
            }
            let owner = Transfer(destination: stage.appendingPathComponent(name), stage: stage,
                                 generation: generation, limit: limit)
            owners[task.taskIdentifier] = owner
            return owner
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(owner(task)?.redirect(request))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        owner(downloadTask)?.received(downloadTask, total: totalBytesWritten, expected: totalBytesExpectedToWrite)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let owner = owner(downloadTask) else { return }
        // A resumed callback must not publish bytes into a superseded generation.
        let model = owner.stage.deletingLastPathComponent().lastPathComponent
        guard let state = try? ModelStore(model).status(), state["generation"] as? String == owner.generation else {
            owner.error = failure(130, "Download belongs to a superseded installation")
            return
        }
        owner.downloaded(downloadTask, to: location)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        owner(task)?.complete(error)
        lock.withLock { _ = owners.removeValue(forKey: task.taskIdentifier) }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            let completion = self.lock.withLock {
                defer { self.completion = nil }
                return self.completion
            }
            completion?()
        }
    }
}
#endif

@_cdecl("asml_background_events")
public func backgroundEventsC(_ identifier: UnsafePointer<CChar>?, _ completion: (@convention(block) () -> Void)?) -> Int32 {
#if os(iOS)
    if cString(identifier) == BackgroundDownloads.identifier, let completion {
        BackgroundDownloads.shared.setCompletion(completion)
        return 1
    }
#endif
    return 0
}

private func requireInstallThread() throws {
#if os(iOS)
    guard !Thread.isMainThread, !Bundle.main.bundlePath.contains(".appex") else {
        throw failure(75, "Installation requires an off-main caller in the main application")
    }
#endif
}

private func compilationAllowed() throws {
    try requireInstallThread()
#if os(iOS)
    let active = DispatchQueue.main.sync { UIApplication.shared.applicationState == .active }
    guard active else {
        throw failure(75, "Download staged; reopen the application and rerun install to compile and activate")
    }
#endif
}

extension ModelStore {
    private func fetchFile(_ url: URL, _ transfer: Transfer) throws {
        guard webURL(url) else { throw failure(2, "Downloads require HTTPS (literal loopback HTTP is allowed for local catalogs)") }
#if os(iOS)
        let manager = BackgroundDownloads.shared
        let task = manager.session.downloadTask(with: url)
        let digest = String(transfer.stage.lastPathComponent.dropFirst(".staging-".count))
        let meta: JSON = ["model_id": model, "manifest_sha256": digest, "generation": transfer.generation,
                          "name": transfer.destination.lastPathComponent, "limit": transfer.limit]
        task.taskDescription = String(decoding: try jsonData(meta), as: UTF8.self)
        manager.register(transfer, for: task)
#else
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForResource = 120
        configuration.timeoutIntervalForRequest = 30
        let session = URLSession(configuration: configuration, delegate: transfer, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        let task = session.downloadTask(with: url)
        task.taskDescription = transfer.generation
#endif
        task.resume()
        while transfer.finished.wait(timeout: .now() + .milliseconds(100)) == .timedOut {
            if installCancelled(transfer.stage, transfer.generation) { task.cancel() }
        }
        try checkInstall(transfer.stage, transfer.generation)
        if let error = transfer.error { throw error }
    }

    func install(_ location: String, digest: String?) throws -> JSON {
        try requireInstallThread()
        if let digest, !digestOK(digest) { throw failure(2, "Invalid SHA256 pin") }
        let storeLock = try lockFile(".install-lock", LOCK_EX)
        defer { close(storeLock) }
        let transferID = digest ?? hashData(Data(location.utf8))
        let stage = root.appendingPathComponent(".staging-" + transferID, isDirectory: true)
        let generation = UUID().uuidString
        let check: StopCheck = { try checkInstall(stage, generation) }
        try makeDirectory(stage)
        try phase(stage, transferID, generation, "manifest")

        // A failed attempt may leave scratch in its stage. Preserve this attempt's cancel marker.
        for stale in (try? fm.contentsOfDirectory(at: stage, includingPropertiesForKeys: nil)) ?? [] {
            let name = stale.lastPathComponent
            if name.hasPrefix("archive-") || name.hasPrefix("manifest-")
                || (name.hasPrefix("cancel-") && name != "cancel-" + generation) {
                try plainPath(stale)
                try fm.removeItem(at: stale)
            }
        }
        for stale in (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? [] {
            let name = stale.lastPathComponent
            if name.hasPrefix(".staging-"), digestOK(String(name.dropFirst(".staging-".count))), name != stage.lastPathComponent {
                try plainPath(stale)
                try fm.removeItem(at: stale)
            }
        }

        try spaceForPlan(8 * 1024 * 1024)
        let archive = stage.appendingPathComponent("archive-\(generation).download")
        defer { try? fm.removeItem(at: archive) }
        try phase(stage, transferID, generation, "downloading")
        // Like NSURL's original parser, a location that cannot form a URL is a local path.
        if let url = URL(string: location), url.scheme != nil, !url.isFileURL {
            try fetchFile(url, Transfer(destination: archive, stage: stage, generation: generation, limit: packageCeiling))
        } else {
            let url = URL(string: location)
            try copyPackage(url?.isFileURL == true ? url! : URL(fileURLWithPath: location), archive,
                            stage: stage, generation: generation)
        }
        let archiveSHA: String
        do {
            archiveSHA = try hashFile(archive, check: check)
            guard digest == nil || archiveSHA == digest else { throw failure(2, "Archive SHA256 mismatch") }
        } catch {
            try check()
            throw failure(2, "Archive SHA256 mismatch")
        }
        let (plan, manifest) = try extractPackage(archive, stage: stage, generation: generation, check: check)
        let manifestDigest = hashData(manifest)
        try fm.removeItem(at: archive)
        let active = readJSON(currentRecord)
        let activeDigest = active?["active"] as? String
        let old = (try? checkedReceipt(activeDigest, check: check)) == nil ? nil : activeDigest

        if let existing = try? checkedReceipt(manifestDigest, check: check) {
            let commitLock = try lockFile(".commit-lock", LOCK_EX)
            defer { close(commitLock) }
            try checkInstall(stage, generation, "Installation cancelled before activation")
            if old != manifestDigest {
                var record = ["active": manifestDigest]
                record["rollback"] = old
                try writeJSON(record, currentRecord)
                collect(record)
            }
            try? phase(stage, manifestDigest, generation, "active")
            try? fm.removeItem(at: stage)
            return existing
        }

        try spaceForPlan((plan["disk_estimate_bytes"] as? NSNumber)?.uint64Value ?? 0)
        try phase(stage, manifestDigest, generation, "downloading")
        try writeJSON(plan, stage.appendingPathComponent("plan.json"))
        try checkInstall(stage, generation, "Installation cancelled before compilation")
        try phase(stage, manifestDigest, generation, "downloaded")
        try compilationAllowed()
        try phase(stage, manifestDigest, generation, "compiling")
        let contents = stage.appendingPathComponent("package", isDirectory: true)
        let compiled = stage.appendingPathComponent("model.mlmodelc")
        guard let modelFile = plan["model"] as? String else { throw failure(2, "Package model is undeclared") }
        let temporary: URL
        do {
            temporary = try compilePortableModel(contents.appendingPathComponent(modelFile))
        } catch {
            try check()
            throw failure(2, "Portable model compilation rejected: " + error.localizedDescription)
        }
        defer { try? fm.removeItem(at: temporary) }
        if fm.fileExists(atPath: compiled.path) {
            try plainPath(compiled)
            try fm.removeItem(at: compiled)
        }
        try fm.moveItem(at: temporary, to: compiled)
        try exclude(compiled)
        try compilationAllowed()

        try validateCompiled(compiled, content: contents, plan: plan, check: check)
        try checkInstall(stage, generation, "Installation cancelled after compilation")
        let compiledFiles = try treeReceipt(compiled, sync: true, check: check)
        var receipt = plan
        receipt["manifest_sha256"] = manifestDigest
        receipt["compiled_files"] = compiledFiles
        receipt["archive_sha256"] = archiveSHA
        if let license = plan["license_file"] as? String {
            var info = stat()
            _ = stat(contents.appendingPathComponent(license).path, &info)
            receipt["license_bytes"] = info.st_size
        }
        let compiledBytes = compiledFiles.values.reduce(Int64(0)) { $0 + ($1["bytes"] as? Int64 ?? 0) }
        let members = plan["members"] as? [String: JSON] ?? [:]
        let portableBytes = members.values.reduce(Int64(0)) { $0 + ($1["bytes"] as? Int64 ?? 0) }
        receipt["compiled_bytes"] = compiledBytes
        receipt["installed_bytes"] = compiledBytes + portableBytes
        receipt["validation_label"] = isEmbedding(model) ? "embedding-cosine>=0.99" : "7"
        receipt["compiled_os"] = ProcessInfo.processInfo.operatingSystemVersionString
        try atomicData(manifest, stage.appendingPathComponent("manifest.json"))
        try writeJSON(receipt, stage.appendingPathComponent("receipt.json"))
        try phase(stage, manifestDigest, generation, "activating")
        try checkInstall(stage, generation, "Installation cancelled before activation")
        _ = try treeReceipt(stage, sync: true, check: check)

        // A cancellation acknowledged while syncing the tree must prevent activation.
        let commitLock = try lockFile(".commit-lock", LOCK_EX)
        defer { close(commitLock) }
        try checkInstall(stage, generation, "Installation cancelled before activation")
        let published: Set = ["package", "model.mlmodelc", "manifest.json", "receipt.json", "plan.json"]
        for scratch in try fm.contentsOfDirectory(at: stage, includingPropertiesForKeys: nil)
            where !published.contains(scratch.lastPathComponent) {
            try plainPath(scratch)
            try fm.removeItem(at: scratch)
        }
        let destination = version(manifestDigest)
        if fm.fileExists(atPath: destination.path) {
            let fd = try lockFile(".lease-" + manifestDigest, LOCK_EX)
            defer { close(fd) }
            try plainPath(destination)
            try fm.removeItem(at: destination)
        }
        try fm.moveItem(at: stage, to: destination)
        var record = ["active": manifestDigest]
        if let old, old != manifestDigest {
            record["rollback"] = old
        } else if let rollback = active?["rollback"] as? String, (try? checkedReceipt(rollback, check: check)) != nil {
            record["rollback"] = rollback
        }
        try writeJSON(record, currentRecord)
        try? phase(destination, manifestDigest, generation, "active")
        collect(record)
        return try checkedReceipt(manifestDigest, check: check)
    }

    private func validateCompiled(_ compiled: URL, content: URL, plan: JSON, check: StopCheck) throws {
        let admission = runtime.maintenanceBegin()
        guard admission == 0 else {
            try check()
            throw failure(admission, "Inference is busy; retry installation after the active job completes")
        }
        defer { runtime.maintenanceEnd() }
        try autoreleasepool {
            if isEmbedding(model) {
                try EmbeddingModel.validate(compiled: compiled, content: content, plan: plan, check: check)
            } else {
                let config = MLModelConfiguration()
                config.computeUnits = .cpuOnly
                let compiledModel = try MLModel(contentsOf: compiled, configuration: config)
                try validateMNIST(compiledModel, installing: true)
                let pixels = try fixturePixels(plan["validation"] as? JSON ?? [:])
                let prediction = try pixels.withUnsafeBytes {
                    try predictMNIST(compiledModel, pixels: $0.baseAddress!, installing: true)
                }
                guard prediction.label == "7" else { throw failure(2, "Known-answer validation failed") }
            }
        }
    }
}

// The synchronous compiler is required on the command's pthread. It remains
// supported for synchronous callers on the deployment toolchain.
private func compilePortableModel(_ model: URL) throws -> URL {
    try MLModel.compileModel(at: model)
}
