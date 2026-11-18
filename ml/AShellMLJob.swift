import Foundation

// Job-relative I/O retains the directory descriptor and rejects symlinks.
private func jobDirectory(_ path: String, create: Bool) -> Int32 {
    let name = path as NSString
    guard name.isAbsolutePath, name.length >= 2 else { return -1 }
    let parts = name.pathComponents
    guard !parts.contains(".."), !parts.contains(".") else { return -1 }
    var fd = open(NSHomeDirectory(), O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
    var start = 1
    var home = stat()
    if fd >= 0, fstat(fd, &home) == 0 {
        var prefix = "/"
        for index in parts.indices.dropFirst() {
            prefix = (prefix as NSString).appendingPathComponent(parts[index])
            // Foundation and the command may spell the home differently
            // (/var versus /private/var). Match its trusted OS identity.
            var candidate = stat()
            if stat(prefix, &candidate) == 0, candidate.st_dev == home.st_dev, candidate.st_ino == home.st_ino {
                start = index + 1
                break
            }
        }
    }
    if start == parts.count { close(fd); return -1 }
    if start == 1 {
        if fd >= 0 { close(fd) }
        fd = open("/", O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
    }
    for index in start..<parts.count {
        guard fd >= 0 else { return -1 }
        let part = parts[index]
        if part == "/" || (create && index == parts.count - 1 && mkdirat(fd, part, 0o700) != 0) {
            close(fd)
            return -1
        }
        let next = openat(fd, part, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
        close(fd)
        fd = next
    }
    return fd
}

private func regular(_ directory: Int32, _ name: String, _ flags: Int32) -> Int32 {
    let fd = openat(directory, name, flags | O_NOFOLLOW | O_NONBLOCK, 0o600)
    guard fd >= 0 else { return -1 }
    var info = stat()
    if fstat(fd, &info) != 0 || !isRegular(info) || info.st_nlink != 1 {
        close(fd)
        return -1
    }
    return fd
}

private func readResult(_ directory: Int32) -> JSON? {
    let fd = regular(directory, "result.json", O_RDONLY)
    guard fd >= 0 else { return nil }
    defer { close(fd) }
    var info = stat()
    var data = Data(count: 65536)
    let count = data.withUnsafeMutableBytes { read(fd, $0.baseAddress, $0.count) }
    guard fstat(fd, &info) == 0, count > 0, count == info.st_size else { return nil }
    data.count = count
    return jsonObject(data)
}

private func save(_ directory: Int32, _ value: JSON) -> Bool {
    guard let data = try? jsonData(value) else { return false }
    let temp = ".result-" + UUID().uuidString
    let fd = regular(directory, temp, O_WRONLY | O_CREAT | O_EXCL)
    guard fd >= 0 else { return false }
    let written = data.withUnsafeBytes { write(fd, $0.baseAddress, $0.count) == $0.count }
    let synced = written && fsync(fd) == 0
    close(fd)
    let ok = synced && renameat(directory, temp, directory, "result.json") == 0 && fsync(directory) == 0
    if !ok { unlinkat(directory, temp, 0) }
    return ok
}

// The serial monitor owns this receipt while it runs. The command reads it
// again only after cancellation and a synchronous drain of that queue.
private final class JobCheckpoint: @unchecked Sendable {
    var receipt: JSON

    init(_ receipt: JSON) { self.receipt = receipt }

    func run(_ arguments: [String], directory: Int32, request: String, out: Stream, err: Stream) -> Int32 {
        let queue = DispatchQueue(label: "org.ashell.ml.job-checkpoint", autoreleaseFrequency: .workItem)
        let monitor = DispatchSource.makeTimerSource(queue: queue)
        monitor.schedule(deadline: .now(), repeating: .milliseconds(100), leeway: .milliseconds(10))
        monitor.setEventHandler {
            if let state = try? runtime.requestStatus(request), let chunks = state["completed_chunks"] as? Int,
               chunks != self.receipt["completed_chunks"] as? Int {
                self.receipt["completed_chunks"] = chunks
                _ = save(directory, self.receipt)
            }
        }
        monitor.resume()
        let result = command(arguments, out: out, err: err)
        monitor.cancel()
        queue.sync {}
        return result
    }
}

private func pendingStream(_ directory: Int32, _ name: String) -> Stream? {
    let fd = regular(directory, name, O_WRONLY | O_CREAT | O_EXCL)
    guard fd >= 0 else { return nil }
    if let stream = fdopen(fd, "w") { return stream }
    close(fd)
    return nil
}

private func runJob(_ arguments: [String], directory: Int32, nonce: String, receipt: inout JSON) -> Int32 {
    let output = pendingStream(directory, ".stdout.pending")
    let error = pendingStream(directory, ".stderr.pending")
    guard let jobOut = output, let jobErr = error else {
        if let output { fclose(output) }
        if let error { fclose(error) }
        return 1
    }
    var result: Int32
    do {
        let request = try runtime.request(directory: directory, nonce: nonce)
        defer {
            // Usage failures can occur before admission. Retire prepared requests too.
            _ = try? runtime.cancel(request)
            _ = try? runtime.end(request)
        }
        receipt["request"] = request
        receipt["state"] = "running"
        if save(directory, receipt) {
            let checkpoint = JobCheckpoint(receipt)
            result = checkpoint.run(arguments + ["--request", request], directory: directory, request: request,
                                    out: jobOut, err: jobErr)
            receipt = checkpoint.receipt
        } else {
            result = 1
        }
    } catch {
        result = exitStatus(error)
    }
    if fflush(jobOut) != 0 || fflush(jobErr) != 0 || fsync(fileno(jobOut)) != 0 || fsync(fileno(jobErr)) != 0 { result = 1 }
    if fclose(jobOut) != 0 { result = 1 }
    if fclose(jobErr) != 0 { result = 1 }
    // linkat publishes without replacing a preexisting file. The terminal
    // receipt follows both streams and their directory sync.
    if linkat(directory, ".stdout.pending", directory, "stdout", 0) != 0
        || unlinkat(directory, ".stdout.pending", 0) != 0 { result = 1 }
    if linkat(directory, ".stderr.pending", directory, "stderr", 0) != 0
        || unlinkat(directory, ".stderr.pending", 0) != 0 { result = 1 }
    receipt["state"] = "done"
    receipt["exit_code"] = result
    if !save(directory, receipt) { result = 1 }
    return result
}

func jobCommand(_ arguments: [String], out: Stream, err: Stream) -> Int32 {
    func fail(_ code: Int32, _ message: String) -> Int32 {
        emitError(failure(code, message), out: out, err: err)
    }
    let args = Array(arguments.dropFirst(2))
    guard args.count >= 2 else {
        return fail(2, "Usage: coreml job create|status DIRECTORY | job run DIRECTORY coreml run mnist IMAGE [OPTIONS]")
    }
    let action = args[0], path = args[1]
    let create = action == "create", run = action == "run"
    guard create || run || action == "status", run ? args.count >= 4 : args.count == 2 else {
        return fail(2, "Invalid job arguments")
    }
    let directory = jobDirectory(path, create: create)
    guard directory >= 0 else {
        return fail(2, "Job requires a new (create) or existing canonical absolute directory without symlinks or traversal")
    }
    defer { close(directory) }
    let lock = regular(directory, "lock", O_RDWR | O_CREAT)
    guard lock >= 0 else { return fail(2, "Unsafe job lock") }
    let acquired = flock(lock, LOCK_EX | LOCK_NB) == 0
    var receipt = readResult(directory)
    let result: Int32
    if create && acquired {
        let created: JSON = ["schema": 1, "job": UUID().uuidString, "state": "prepared", "directory": path,
                             "stdout": "stdout", "stderr": "stderr", "cancel": "cancel"]
        result = save(directory, created) ? 0 : 1
        receipt = created
    } else if var existing = receipt, let job = existing["job"] as? String, UUID(uuidString: job) != nil,
              let state = existing["state"] as? String {
        if !run {
            // A dead process releases flock. Preserve the files and mark the
            // unfinished checkpoint interrupted.
            if acquired && state == "running" {
                existing["state"] = "interrupted"
                existing["exit_code"] = 75
                result = save(directory, existing) ? 0 : 1
                receipt = existing
            } else {
                result = 0
            }
        } else if !acquired || state != "prepared" {
            result = 75
        } else if args.count < 6 || !args[2...4].elementsEqual(["coreml", "run", "mnist"]) || args.dropFirst(3).contains("--request") {
            result = 2
        } else {
            result = runJob(Array(args.dropFirst(2)), directory: directory, nonce: job, receipt: &existing)
            receipt = existing
        }
    } else {
        result = 2
    }
    if acquired { flock(lock, LOCK_UN) }
    close(lock)
    if let receipt, result == 0 || (run && receipt["state"] as? String == "done") {
        return emit(receipt, code: result, out: out, err: err)
    }
    return fail(result == 0 ? 1 : result, "Job rejected or result could not be persisted; inspect existing files before retrying")
}

@_cdecl("asml_job")
public func jobC(_ argc: Int32, _ argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?,
                 _ out: UnsafeMutablePointer<FILE>?, _ err: UnsafeMutablePointer<FILE>?) -> Int32 {
    autoreleasepool { jobCommand(commandArguments(argc, argv), out: out ?? stdout, err: err ?? stderr) }
}
