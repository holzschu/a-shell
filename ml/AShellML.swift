import Foundation
import CoreML
import CoreVideo
#if os(iOS)
import UIKit
import ios_system
#endif

typealias JSON = [String: Any]
typealias StopCheck = () throws -> Void
typealias ErrorCheckBlock = @convention(block) () -> NSError?
typealias Stream = UnsafeMutablePointer<FILE>
typealias Arguments = UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>

func failure(_ code: Int32, _ message: String) -> NSError {
    NSError(domain: "AShellML", code: Int(code), userInfo: [NSLocalizedDescriptionKey: message])
}

func exitStatus(_ error: Error) -> Int32 {
    let error = error as NSError
    return error.domain == "AShellML" ? Int32(truncatingIfNeeded: error.code) : 1
}

func jsonData(_ value: JSON) throws -> Data {
    try JSONSerialization.data(withJSONObject: value, options: .sortedKeys)
}

func jsonObject(_ data: Data) -> JSON? {
    (try? JSONSerialization.jsonObject(with: data)) as? JSON
}

func cString(_ value: UnsafePointer<CChar>?) -> String? {
    value.flatMap { String(validatingUTF8: $0) }
}

func borrowedObject(_ value: UnsafeRawPointer?) -> AnyObject? {
    value.map { Unmanaged<AnyObject>.fromOpaque($0).takeUnretainedValue() }
}

func checkBlock(_ check: ErrorCheckBlock?) throws {
    if let stop = check?() { throw stop }
}

func bridgeJSON(_ error: UnsafeMutablePointer<UnsafeMutableRawPointer?>?, _ operation: () throws -> JSON) -> UnsafeMutableRawPointer? {
    do {
        let result = try operation() as NSDictionary
        return Unmanaged.passRetained(result).autorelease().toOpaque()
    } catch let thrown {
        error?.pointee = Unmanaged.passRetained(thrown as NSError).autorelease().toOpaque()
        return nil
    }
}

func isRegular(_ info: stat) -> Bool {
    info.st_mode & S_IFMT == S_IFREG
}

func writeAll(_ fd: Int32, _ bytes: UnsafeRawBufferPointer, retryInterrupted: Bool = true) -> Bool {
    var offset = 0
    while offset < bytes.count {
        let count = write(fd, bytes.baseAddress!.advanced(by: offset), bytes.count - offset)
        if retryInterrupted && count < 0 && errno == EINTR { continue }
        if count <= 0 { return false }
        offset += count
    }
    return true
}

private func errorJSON(_ error: Error) -> JSON {
    ["error": error.localizedDescription, "status": exitStatus(error)]
}

private func respond(_ status: UnsafeMutablePointer<Int32>?, _ operation: () throws -> JSON) -> UnsafeMutablePointer<CChar>? {
    autoreleasepool {
        let data: Data
        do {
            data = try jsonData(operation())
            status?.pointee = 0
        } catch {
            status?.pointee = exitStatus(error)
            guard let encoded = try? jsonData(errorJSON(error)) else { return nil }
            data = encoded
        }
        return strdup(String(decoding: data, as: UTF8.self))
    }
}

func emit(_ value: JSON, code: Int32 = 0, out: Stream, err: Stream) -> Int32 {
    guard let data = try? jsonData(value) else { return 1 }
    let stream = code == 0 ? out : err
    let written = data.withUnsafeBytes { fwrite($0.baseAddress, 1, $0.count, stream) }
    return written == data.count && fputc(10, stream) != EOF && fflush(stream) == 0 ? code : 1
}

func emitError(_ error: Error, out: Stream, err: Stream) -> Int32 {
    emit(errorJSON(error), code: exitStatus(error), out: out, err: err)
}

private func requireOffMainThread(_ message: String = "Core ML operations must run off the main thread") throws {
#if os(iOS)
    if Thread.isMainThread { throw failure(75, message) }
#endif
}

private func requireForeground() throws {
#if os(iOS)
    guard !Bundle.main.bundlePath.contains(".appex") else {
        throw failure(75, "Core ML requires the main application process")
    }
    let active = DispatchQueue.main.sync {
        UIApplication.shared.applicationState == .active && UIApplication.shared.isProtectedDataAvailable
    }
    guard active else { throw failure(75, "Core ML skeleton requires an active application scene") }
#endif
}

private func commandSession() -> String? {
#if os(iOS)
    guard let context = ios_getContext() else { return nil }
    return String(validatingUTF8: context.assumingMemoryBound(to: CChar.self))
#else
    return nil
#endif
}

private func memory() -> JSON {
    var info = task_vm_info_data_t()
    let fullCount = MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size
    var count = mach_msg_type_number_t(fullCount)
    let result = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: fullCount) {
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
        }
    }
    var values: JSON = ["physical_ram": ProcessInfo.processInfo.physicalMemory, "pid": getpid()]
    if result == KERN_SUCCESS {
        values["footprint"] = info.phys_footprint
        if let offset = MemoryLayout<task_vm_info_data_t>.offset(of: \.ledger_phys_footprint_peak),
           Int(count) * MemoryLayout<integer_t>.size >= offset + MemoryLayout<mach_vm_size_t>.size {
            values["lifetime_peak"] = info.ledger_phys_footprint_peak
        }
    }
#if os(iOS)
    values["available"] = os_proc_available_memory()
#endif
    return values
}

func validateMNIST(_ model: MLModel, installing: Bool = false) throws {
    let inputs = model.modelDescription.inputDescriptionsByName
    let outputs = model.modelDescription.outputDescriptionsByName
    guard inputs.count == 1, let image = inputs["image"], image.type == .image,
          let constraint = image.imageConstraint, constraint.pixelsWide == 28, constraint.pixelsHigh == 28,
          constraint.pixelFormatType == kCVPixelFormatType_OneComponent8 else {
        throw failure(2, installing ? "Compiled features do not match MNIST uint8[28,28]"
                      : "Unsupported model features; this adapter requires MNIST image uint8[28,28]")
    }
    guard outputs["classLabel"]?.type == .int64, outputs["labelProbabilities"]?.type == .dictionary,
          !installing || (outputs.count == 2 && outputs["labelProbabilities"]?.dictionaryConstraint?.keyType == .int64) else {
        throw failure(2, installing ? "Compiled output types do not match the declared drawing-classification adapter"
                      : "Unsupported model features; this adapter requires MNIST image uint8[28,28]")
    }
}

func predictMNIST(_ model: MLModel, pixels: UnsafeRawPointer, installing: Bool = false,
                  check: StopCheck = {}) throws -> (label: String, scores: [String: Double]) {
    var buffer: CVPixelBuffer?
    guard CVPixelBufferCreate(kCFAllocatorDefault, 28, 28, kCVPixelFormatType_OneComponent8, nil, &buffer) == kCVReturnSuccess,
          let buffer else {
        throw failure(1, installing ? "Cannot allocate validation image" : "Cannot allocate MNIST pixel buffer")
    }
    guard CVPixelBufferLockBaseAddress(buffer, []) == kCVReturnSuccess else {
        throw failure(1, installing ? "Cannot lock validation image" : "Cannot lock MNIST pixel buffer")
    }
    if let base = CVPixelBufferGetBaseAddress(buffer) {
        let stride = CVPixelBufferGetBytesPerRow(buffer)
        for row in 0..<28 { memcpy(base.advanced(by: row * stride), pixels.advanced(by: row * 28), 28) }
    }
    CVPixelBufferUnlockBaseAddress(buffer, [])
    let output: any MLFeatureProvider
    do {
        let input = try MLDictionaryFeatureProvider(dictionary: ["image": MLFeatureValue(pixelBuffer: buffer)])
        output = try model.prediction(from: input)
    } catch {
        try check()
        throw error
    }
    try check()
    let raw = output.featureValue(for: "labelProbabilities")?.dictionaryValue ?? [:]
    let label = String(output.featureValue(for: "classLabel")?.int64Value ?? -1)
    var scores: [String: Double] = [:]
    var sum = 0.0
    for digit in 0..<10 {
        guard let score = raw[AnyHashable(NSNumber(value: digit))]?.doubleValue,
              score.isFinite, (0...1).contains(score) else { break }
        sum += score
        scores[String(digit)] = score
    }
    let validSum = installing ? abs(sum - 1) < 1e-4 : abs(sum - 1) <= 1e-4
    guard raw.count == 10, scores.count == 10, scores[label] != nil, validSum else {
        throw installing ? failure(2, "Known-answer validation failed") : failure(1, "Model produced invalid probabilities")
    }
    return (label, scores)
}

private final class CommandContext: NSObject {
    let session: String?
    var stopped = false

    init(session: String?) { self.session = session }

    static let key = "ASMLCommand"
    static var current: CommandContext? { Thread.current.threadDictionary[key] as? CommandContext }
}

private final class Request {
    enum State: String { case prepared, queued, running, finished }
    var state = State.prepared
    var stop: Int32 = 0
    var thread: pthread_t?
    var session: String?
    var completedChunks = 0
    let directory: FileHandle?
    let nonce: String?

    init(directory: FileHandle? = nil, nonce: String? = nil) {
        self.directory = directory
        self.nonce = nonce
    }

    // Read only the job's fixed, nonce-scoped cancellation file.
    func pollStop() -> Int32 {
        guard stop == 0, let directory, let nonce else { return stop }
        let fd = openat(directory.fileDescriptor, "cancel", O_RDONLY | O_NOFOLLOW | O_NONBLOCK)
        if fd < 0 {
            if errno != ENOENT { stop = 2 }
            return stop
        }
        defer { close(fd) }
        var info = stat()
        var bytes = [UInt8](repeating: 0, count: 37)
        if fstat(fd, &info) != 0 || !isRegular(info) || info.st_nlink != 1 {
            stop = 2
        } else if info.st_size == 36, read(fd, &bytes, bytes.count) == 36, bytes.prefix(36).elementsEqual(nonce.utf8) {
            stop = 130
        }
        return stop
    }
}

private struct WarmModel {
    enum Graph {
        case mnist(MLModel)
        case embedding(EmbeddingModel)
    }

    let graph: Graph
    let key: String
    let cacheID = UUID().uuidString
    let receipt: JSON
    let memoryBefore: JSON
}

let runtime = MLRuntime()

// The condition protects admission and cancellation. The serial worker owns
// Core ML objects, their store leases, and all cache metadata.
final class MLRuntime: @unchecked Sendable {
    private let admission = NSCondition()
    private let worker = DispatchQueue(label: "org.ashell.coreml", autoreleaseFrequency: .workItem)
    private let permit = DispatchSemaphore(value: 1)
    private let generation = UUID().uuidString
    private let idleTimer: DispatchSourceTimer

    private var requests: [String: Request] = [:]
    private var commandSessions: [CommandContext] = []
    private var waiting: [String] = []
    private var owner: String?
    private var maintenance = false

    private var warm: WarmModel?
    private var runningToken: String?
    private var cacheHit = false
    private var loadMS = 0.0
    private var verificationMS = 0.0
    private var modelLoadMS = 0.0
    private var verificationCached = false

    fileprivate init() {
        idleTimer = DispatchSource.makeTimerSource(queue: worker)
        idleTimer.schedule(deadline: .distantFuture)
        idleTimer.setEventHandler { [weak self] in
            if self?.runningToken == nil { self?.evict() }
        }
        idleTimer.resume()
#if os(iOS)
        let center = NotificationCenter.default
        for name in [UIApplication.didEnterBackgroundNotification, UIApplication.didReceiveMemoryWarningNotification,
                     UIApplication.protectedDataWillBecomeUnavailableNotification] {
            _ = center.addObserver(forName: name, object: nil, queue: nil) { [weak self] _ in self?.stop(75) }
        }
        _ = center.addObserver(forName: UIScene.willDeactivateNotification, object: nil, queue: nil) { [weak self] note in
            let deactivating = note.object as? UIScene
            // UIKit posts scene lifecycle notifications on the main thread.
            MainActor.assumeIsolated {
                if UIApplication.shared.connectedScenes.contains(where: {
                    $0 !== deactivating && $0.activationState == .foregroundActive
                }) { return }
                self?.stop(75)
            }
        }
#endif
    }

    private func evict() {
        let lease = warm?.receipt["lease_id"] as? String
        warm = nil
        if let lease { ModelStore.release(lease) }
    }

    private func finish(_ token: String) {
        guard runningToken == token else { return }
        runningToken = nil
        let cancelled = admission.withLock {
            let cancelled = (requests[token]?.stop ?? 0) != 0
            if cancelled { requests[token]?.state = .finished } else { requests.removeValue(forKey: token) }
            owner = nil
            admission.broadcast()
            return cancelled
        }
        if cancelled { evict() }
        idleTimer.schedule(deadline: .now() + .seconds(60), leeway: .seconds(1))
        permit.signal()
    }

    private func check(_ token: String) throws {
        let code = admission.withLock { requests[token]?.pollStop() ?? 0 }
        if code != 0 {
            throw failure(code, code == 130 ? "Inference cancelled" : "Inference stopped by lifecycle or memory pressure")
        }
    }

    func request(directory: Int32? = nil, nonce: String? = nil) throws -> String {
        let handle: FileHandle?
        if let directory {
            guard nonce?.utf8.count == 36 else { throw failure(2, "Invalid job nonce") }
            let fd = dup(directory)
            guard fd >= 0 else { throw failure(1, "Cannot retain job directory") }
            handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        } else {
            handle = nil
        }
        return try admission.withLock {
            guard requests.count < 16 else { throw failure(75, "Inference request queue is full (16)") }
            let token = UUID().uuidString
            requests[token] = Request(directory: handle, nonce: nonce)
            return token
        }
    }

    func requestStatus(_ token: String?) throws -> JSON {
        try admission.withLock {
            guard let token, let job = requests[token] else { throw failure(2, "Unknown or completed inference request") }
            return ["state": job.state.rawValue, "completed_chunks": job.completedChunks]
        }
    }

    func status() -> JSON {
        admission.withLock {
            // The C runtime boxed this comparison as an integer in JSON.
            ["queued": waiting.count, "active": owner == nil ? 0 : 1, "completed_chunks": owner.flatMap { requests[$0]?.completedChunks } ?? 0,
             "maintenance": maintenance, "requests": requests.count, "generation": generation]
        }
    }

    func maintenanceBegin() -> Int32 {
        if (try? requireOffMainThread()) == nil { return 75 }
        guard permit.wait(timeout: .now()) == .success else { return 75 }
        admission.withLock { maintenance = true }
        worker.sync { autoreleasepool { evict() } }
        return 0
    }

    func maintenanceEnd() {
        admission.withLock {
            if maintenance {
                maintenance = false
                permit.signal()
                admission.broadcast()
            }
        }
    }

    func cancel(_ token: String?) throws -> JSON {
        let token = try admission.withLock {
            guard let token, let job = requests[token] else { throw failure(2, "Unknown or completed inference request") }
            job.stop = 130
            if job.state == .prepared { requests.removeValue(forKey: token) }
            admission.broadcast()
            return token
        }
        // Serial cleanup follows the native prediction and release of its buffers.
        worker.async { self.finish(token) }
        return ["cancel_requested": token]
    }

    func stop(_ status: Int32) {
        admission.withLock {
            for job in requests.values where job.stop == 0 { job.stop = status == 130 ? 130 : 75 }
            requests = requests.filter { $0.value.state != .prepared }
            admission.broadcast()
        }
        worker.async {
            if let token = self.runningToken, (try? self.check(token)) == nil { self.finish(token) }
            if self.runningToken == nil { self.evict() }
        }
    }

    func interrupt(_ session: String?) -> Bool {
        guard let session else { return false }
        let (hadCommand, tokens) = admission.withLock {
            let commands = commandSessions.filter { $0.session == session }
            for command in commands { command.stopped = true }
            let tokens = requests.compactMap { token, job in
                job.session == session && job.state != .finished ? token : nil
            }
            return (!commands.isEmpty, tokens)
        }
        for token in tokens { _ = try? cancel(token) }
        return hadCommand || !tokens.isEmpty
    }

    func commandInterrupted() -> Bool {
        let command = CommandContext.current
        return admission.withLock { command?.stopped == true }
    }

    fileprivate func withCommand(_ body: () -> Int32) -> Int32 {
        let context = CommandContext(session: commandSession())
        let dictionary = Thread.current.threadDictionary
        dictionary[CommandContext.key] = context
        admission.withLock { commandSessions.append(context) }
        defer {
            admission.withLock { commandSessions.removeAll { $0 === context } }
            dictionary.removeObject(forKey: CommandContext.key)
        }
        return body()
    }

    private func admit(_ supplied: String?) throws -> String {
        let token: String
        if let supplied {
            token = supplied
        } else {
            do { token = try request() }
            catch { throw failure(exitStatus(error), "Inference request queue is full") }
        }
        let session = commandSession()
        let command = CommandContext.current
        admission.lock()
        defer { admission.unlock() }
        guard let job = requests[token], job.state == .prepared else {
            throw failure(2, "Request is unknown or already submitted")
        }
        let caller = pthread_self()
        if let owner, let thread = requests[owner]?.thread, pthread_equal(thread, caller) != 0 {
            if supplied == nil { requests.removeValue(forKey: token) }
            throw failure(75, "This thread already owns an inference context; close it before loading again")
        }
        job.thread = caller
        job.state = .queued
        if command?.stopped == true { job.stop = 130 }
        job.session = session
        waiting.append(token)
        while job.pollStop() == 0 {
            if waiting.first == token, permit.wait(timeout: .now()) == .success { break }
            _ = admission.wait(until: Date(timeIntervalSinceNow: 0.05))
        }
        waiting.removeAll { $0 == token }
        if job.stop != 0 {
            requests.removeValue(forKey: token)
            admission.broadcast()
            throw failure(job.stop, job.stop == 130 ? "Queued inference cancelled before load" : "Queued inference unavailable")
        }
        owner = token
        job.state = .running
        return token
    }

    func begin(_ model: String?, units: String?, request: String?) throws -> JSON {
        guard let model, model == "mnist" || isEmbedding(model), let units else {
            throw failure(2, "Unsupported model id")
        }
        try requireOffMainThread("Core ML must run off the main thread")
        try requireForeground()
        let compute: MLComputeUnits
        switch units {
        case "all": compute = .all
        case "cpu": compute = .cpuOnly
        case "cpu-gpu": compute = .cpuAndGPU
        case "cpu-ane":
            guard #available(iOS 16, macOS 13, *) else { throw failure(75, "cpu-ane requires iOS 16 or macOS 13") }
            compute = .cpuAndNeuralEngine
        default: throw failure(2, "units must be all, cpu, cpu-gpu or cpu-ane")
        }
        let token = try admit(request)
        do {
            return try worker.sync {
                try autoreleasepool {
                    try load(model, units: units, compute: compute, token: token)
                    guard let warm else { throw failure(1, "Core ML operation returned no result") }
                    runningToken = token
                    var result = describe(token, warm: warm)
                    result["token"] = token
                    return result
                }
            }
        } catch {
            admission.withLock {
                requests.removeValue(forKey: token)
                owner = nil
                admission.broadcast()
            }
            permit.signal()
            throw error
        }
    }

    private func load(_ model: String, units: String, compute: MLComputeUnits, token: String) throws {
        let started = ProcessInfo.processInfo.systemUptime
        modelLoadMS = 0
        verificationCached = false
        try check(token)
        try requireForeground()
        let record: JSON
        do {
            record = try ModelStore(model).acquire { try self.check(token) }
        } catch {
            evict()
            throw error
        }
        verificationMS = (ProcessInfo.processInfo.systemUptime - started) * 1000
        verificationCached = record["verification_cached"] as? Bool == true
        let lease = record["lease_id"] as? String
        var adopted = false
        defer {
            if !adopted, let lease { ModelStore.release(lease) }
        }
        guard let digest = record["manifest_sha256"] as? String, let path = record["path"] as? String else {
            throw failure(2, "Installed model receipt is incomplete")
        }
        let key = "\(digest)/\(path)/CoreML/\(units)/\(model)-v1/\(generation)"
        cacheHit = warm?.key == key
        if !cacheHit {
            evict()
            let before = memory()
#if os(iOS)
            let available = UInt64(os_proc_available_memory())
            let reserve = max(128 * 1024 * 1024, available / 5)
            let profile = record["memory_profile"] as? JSON
            let peak = model == "mnist" ? 64 * 1024 * 1024 : profile?["additional_peak_bytes"] as? UInt64 ?? 0
            guard available >= reserve + peak else {
                throw failure(75, "Insufficient process headroom for model qualification (available=\(available) reserve=\(reserve) additional_peak=\(peak))")
            }
#endif
            let modelStarted = ProcessInfo.processInfo.systemUptime
            let directory = URL(fileURLWithPath: path, isDirectory: true)
            let compiled = directory.appendingPathComponent("model.mlmodelc")
            let graph: WarmModel.Graph
            if isEmbedding(model) {
                graph = .embedding(try EmbeddingModel(compiled: compiled, content: directory.appendingPathComponent("package"),
                                                      plan: record, units: compute))
            } else {
                let configuration = MLModelConfiguration()
                configuration.computeUnits = compute
                let loaded = try MLModel(contentsOf: compiled, configuration: configuration)
                try validateMNIST(loaded)
                graph = .mnist(loaded)
            }
            warm = WarmModel(graph: graph, key: key, receipt: record, memoryBefore: before)
            adopted = true
            modelLoadMS = (ProcessInfo.processInfo.systemUptime - modelStarted) * 1000
        }
        loadMS = (ProcessInfo.processInfo.systemUptime - started) * 1000
        do { try check(token) }
        catch { evict(); throw error }
    }

    private func active(_ token: String?) throws -> WarmModel {
        if let token { try check(token) }
        guard let token, runningToken == token, let warm else {
            throw failure(2, "Model context is closed or belongs to another job")
        }
        return warm
    }

    private func describe(_ token: String, warm: WarmModel) -> JSON {
        let inputs: JSON
        let outputs: JSON
        var profile: JSON
        switch warm.graph {
        case .embedding:
            inputs = warm.receipt["features"] as? JSON ?? [:]
            outputs = warm.receipt["outputs"] as? JSON ?? [:]
            profile = warm.receipt["memory_profile"] as? JSON ?? [:]
        case .mnist:
            inputs = ["image": ["type": "image", "dtype": "uint8", "shape": [28, 28], "contiguous": true]]
            outputs = ["classLabel": "int64", "labelProbabilities": "dictionary<int64,double>"]
            profile = ["kind": "bounded-skeleton-estimate", "additional_peak_bytes": 64 * 1024 * 1024]
        }
        profile["reserve_min_bytes"] = 128 * 1024 * 1024
        profile["reserve_fraction"] = 0.2
        return ["model_id": warm.receipt["model_id"] ?? "", "runtime_abi": 1, "backend": "CoreML",
                "cache_id": warm.cacheID, "cache_hit": cacheHit, "cache_key": warm.key, "load_ms": loadMS,
                "verification_ms": verificationMS, "model_load_ms": modelLoadMS, "verification_cached": verificationCached,
                "receipt": warm.receipt, "inputs": inputs, "outputs": outputs, "memory": memory(),
                "memory_before_load": warm.memoryBefore, "request": token, "memory_profile": profile,
                "os": ProcessInfo.processInfo.operatingSystemVersionString]
    }

    func describe(_ token: String?) throws -> JSON {
        try requireOffMainThread()
        return try worker.sync {
            try autoreleasepool {
                let warm = try active(token)
                return describe(token!, warm: warm)
            }
        }
    }

    func predict(_ token: String?, pixels: UnsafePointer<UInt8>?, length: Int) throws -> JSON {
        try requireOffMainThread()
        guard length == 784, let pixels else {
            throw failure(2, "image must contain exactly 784 uint8 pixels in row-major 28x28 shape")
        }
        return try worker.sync {
            try autoreleasepool {
                let warm = try active(token)
                guard let token, case let .mnist(model) = warm.graph else {
                    throw failure(2, "The grayscale prediction API requires the MNIST adapter")
                }
                let started = ProcessInfo.processInfo.systemUptime
                let prediction = try predictMNIST(model, pixels: pixels) { try self.check(token) }
                admission.withLock { requests[token]?.completedChunks += 1 }
                return ["label": prediction.label, "scores": prediction.scores, "cache_id": warm.cacheID,
                        "cache_hit": cacheHit, "cache_key": warm.key, "load_ms": loadMS,
                        "predict_ms": (ProcessInfo.processInfo.systemUptime - started) * 1000, "memory": memory()]
            }
        }
    }

    func embed(_ token: String, units: String, input: JSON) throws -> JSON {
        let started = ProcessInfo.processInfo.systemUptime
        return try worker.sync {
            try autoreleasepool {
                let warm = try active(token)
                guard case let .embedding(model) = warm.graph else { throw failure(2, "Embedding model is not loaded") }
                var receipt = try model.predict(input, check: { try self.check(token) }, progress: { count in
                    self.admission.withLock { self.requests[token]?.completedChunks = count }
                })
                receipt["model_id"] = warm.receipt["model_id"]
                receipt["model_sha256"] = warm.receipt["source_sha256"]
                receipt["manifest_sha256"] = warm.receipt["manifest_sha256"]
                receipt["units"] = units
                receipt["cache_hit"] = cacheHit
                receipt["cache_id"] = warm.cacheID
                receipt["request"] = token
                receipt["load_ms"] = loadMS
                receipt["verification_ms"] = verificationMS
                receipt["model_load_ms"] = modelLoadMS
                receipt["verification_cached"] = verificationCached
                receipt["processing_ms"] = (ProcessInfo.processInfo.systemUptime - started) * 1000
                receipt["memory"] = memory()
                return receipt
            }
        }
    }

    func end(_ token: String?) throws -> JSON {
        try requireOffMainThread()
        guard let token else { return ["closed": true] }
        try worker.sync {
            autoreleasepool { finish(token) }
            try admission.withLock {
                // Cancellation may have performed cleanup before the caller closes.
                if requests[token]?.state == .finished { requests.removeValue(forKey: token) }
                else if requests[token] != nil { throw failure(2, "Request has not completed admission") }
            }
        }
        return ["closed": true]
    }

    func unload() throws -> JSON {
        try requireOffMainThread()
        guard permit.wait(timeout: .now()) == .success else { throw failure(75, "Core ML is busy") }
        worker.sync { autoreleasepool { evict() } }
        permit.signal()
        return ["unloaded": true, "memory": memory()]
    }
}

func commandInterrupted() -> Bool { runtime.commandInterrupted() }

func checkCommand() throws {
    if commandInterrupted() { throw failure(130, "Core ML operation cancelled") }
}

@_cdecl("asml_request")
public func requestC(_ status: UnsafeMutablePointer<Int32>?) -> UnsafeMutablePointer<CChar>? {
    respond(status) { ["request": try runtime.request()] }
}

@_cdecl("asml_request_file")
public func requestFileC(_ directory: Int32, _ nonce: UnsafePointer<CChar>?, _ status: UnsafeMutablePointer<Int32>?) -> UnsafeMutablePointer<CChar>? {
    respond(status) { ["request": try runtime.request(directory: directory, nonce: cString(nonce))] }
}

@_cdecl("asml_request_status")
public func requestStatusC(_ request: UnsafePointer<CChar>?, _ status: UnsafeMutablePointer<Int32>?) -> UnsafeMutablePointer<CChar>? {
    respond(status) { try runtime.requestStatus(cString(request)) }
}

@_cdecl("asml_maintenance_begin")
public func maintenanceBeginC() -> Int32 { runtime.maintenanceBegin() }

@_cdecl("asml_maintenance_end")
public func maintenanceEndC() { runtime.maintenanceEnd() }

@_cdecl("asml_status")
public func statusC(_ status: UnsafeMutablePointer<Int32>?) -> UnsafeMutablePointer<CChar>? {
    respond(status) { runtime.status() }
}

@_cdecl("asml_cancel")
public func cancelC(_ request: UnsafePointer<CChar>?, _ status: UnsafeMutablePointer<Int32>?) -> UnsafeMutablePointer<CChar>? {
    respond(status) { try runtime.cancel(cString(request)) }
}

@_cdecl("asml_stop")
public func stopC(_ status: Int32) { runtime.stop(status) }

@_cdecl("asml_interrupt_session")
public func interruptSessionC(_ session: UnsafePointer<CChar>?) -> Int32 {
    autoreleasepool { runtime.interrupt(cString(session)) ? 1 : 0 }
}

@_cdecl("asml_command_interrupted")
public func commandInterruptedC() -> Int32 { commandInterrupted() ? 1 : 0 }

@_cdecl("asml_begin")
public func beginC(_ model: UnsafePointer<CChar>?, _ units: UnsafePointer<CChar>?, _ status: UnsafeMutablePointer<Int32>?) -> UnsafeMutablePointer<CChar>? {
    beginRequestC(model, units, nil, status)
}

@_cdecl("asml_begin_request")
public func beginRequestC(_ model: UnsafePointer<CChar>?, _ units: UnsafePointer<CChar>?, _ request: UnsafePointer<CChar>?,
                          _ status: UnsafeMutablePointer<Int32>?) -> UnsafeMutablePointer<CChar>? {
    respond(status) { try runtime.begin(cString(model), units: cString(units), request: cString(request)) }
}

@_cdecl("asml_describe")
public func describeC(_ token: UnsafePointer<CChar>?, _ status: UnsafeMutablePointer<Int32>?) -> UnsafeMutablePointer<CChar>? {
    respond(status) { try runtime.describe(cString(token)) }
}

@_cdecl("asml_predict")
public func predictC(_ token: UnsafePointer<CChar>?, _ pixels: UnsafePointer<UInt8>?, _ length: Int,
                     _ status: UnsafeMutablePointer<Int32>?) -> UnsafeMutablePointer<CChar>? {
    respond(status) { try runtime.predict(cString(token), pixels: pixels, length: length) }
}

@_cdecl("asml_end")
public func endC(_ token: UnsafePointer<CChar>?, _ status: UnsafeMutablePointer<Int32>?) -> UnsafeMutablePointer<CChar>? {
    respond(status) { try runtime.end(cString(token)) }
}

@_cdecl("asml_unload")
public func unloadC(_ status: UnsafeMutablePointer<Int32>?) -> UnsafeMutablePointer<CChar>? {
    respond(status) { try runtime.unload() }
}

@_cdecl("asml_free")
public func freeC(_ value: UnsafeMutableRawPointer?) { free(value) }

private let usage = "Usage: coreml install MODEL PACKAGE [--sha256 DIGEST] | ls [MODEL] | remove MODEL | rollback MODEL | install-status MODEL | cancel-install MODEL GENERATION | info mnist | predict mnist IMAGE.gray [--repeat 1|2] [--iterations N] [--request UUID] | embed MODEL INPUT.json [--units cpu|all|cpu-gpu|cpu-ane] [--request UUID] | request | cancel UUID | status | unload | job create|status DIRECTORY | job run DIRECTORY coreml run mnist IMAGE.gray [OPTIONS]"

func commandArguments(_ argc: Int32, _ argv: Arguments?) -> [String] {
    guard let argv, argc > 0 else { return [] }
    return (0..<Int(argc)).map { index in
        guard let argument = argv[index] else { return "" }
        return String(cString: argument)
    }
}

@_cdecl("coreml_main")
public func coreMLMain(_ argc: Int32, _ argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32 {
    // ios_system delivers pthread cancellation. Release native buffers and all
    // Swift resources before re-enabling cancellation and publishing the exit.
    var previous = PTHREAD_CANCEL_ENABLE
    pthread_setcancelstate(PTHREAD_CANCEL_DISABLE, &previous)
    let status = autoreleasepool {
#if os(iOS)
        // TLS belongs to the invoking ios_system command thread.
        return runtime.withCommand {
            command(commandArguments(argc, argv), out: thread_stdout ?? stdout, err: thread_stderr ?? stderr)
        }
#else
        return runtime.withCommand { command(commandArguments(argc, argv), out: stdout, err: stderr) }
#endif
    }
#if os(iOS)
    set_session_errno(status)
#endif
    pthread_setcancelstate(previous, nil)
    pthread_testcancel()
    return status
}

@_cdecl("asml_command")
public func commandC(_ argc: Int32, _ argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?,
                     _ out: UnsafeMutablePointer<FILE>?, _ err: UnsafeMutablePointer<FILE>?) -> Int32 {
    command(commandArguments(argc, argv), out: out ?? stdout, err: err ?? stderr)
}

func command(_ arguments: [String], out: Stream, err: Stream) -> Int32 {
    autoreleasepool {
        let args = Array(arguments.dropFirst())
        if args == ["--help"] {
            fputs(usage + "\n", out)
            return fflush(out) == 0 ? 0 : 1
        }
        do {
            try requireOffMainThread()
            switch args.first {
            case "job": return jobCommand(arguments, out: out, err: err)
            case "embed": return embeddingCommand(args, out: out, err: err)
            case "run", "predict":
                if args.count >= 3 && args[1] != "mnist" {
                    fputs("predict/run accepts only mnist\n", err)
                    return 2
                }
            default: break
            }
            return emit(try commandResult(args), out: out, err: err)
        } catch {
            return emitError(error, out: out, err: err)
        }
    }
}

private func commandResult(_ args: [String]) throws -> JSON {
    switch (args.first, args.count) {
    case ("request", 1): return ["request": try runtime.request()]
    case ("status", 1): return runtime.status()
    case ("cancel", 2): return try runtime.cancel(args[1])
    case ("unload", 1): return try runtime.unload()
    case ("ls", 1): return try ModelStore("mnist").installed()
    case ("ls", 2): return try ModelStore(args[1]).installed()
    case ("rollback", 2): return try ModelStore(args[1]).rollback()
    case ("install-status", 2): return try ModelStore(args[1]).status()
    case ("cancel-install", 3): return try ModelStore(args[1]).cancel(args[2])
    case ("remove", 2):
        do { _ = try runtime.unload() }
        catch { throw failure(exitStatus(error), "Core ML is busy") }
        return try ModelStore(args[1]).remove()
    case ("install", 3) where args[1] != "--manifest":
        return try ModelStore(args[1]).install(args[2], digest: nil)
    case ("install", 5) where args[1] != "--manifest" && args[3] == "--sha256":
        return try ModelStore(args[1]).install(args[2], digest: args[4])
    case ("install", 2) where args[1] != "--manifest":
        return try ModelStore("mnist").install(args[1], digest: nil)
    case ("install", 4) where args[1] != "--manifest" && args[2] == "--sha256":
        return try ModelStore("mnist").install(args[1], digest: args[3])
    case ("info", 2):
        let result = try runtime.begin(args[1], units: "cpu", request: nil)
        _ = try? runtime.end(result["token"] as? String)
        return result
    case ("predict", 3...), ("run", 3...):
        return try runMNIST(args)
    default:
        throw failure(2, usage)
    }
}

private func runMNIST(_ args: [String]) throws -> JSON {
    let inputError = failure(2, "Input must be a regular 784-byte grayscale file; repeat 1..2, iterations 1..10000000, request requires repeat 1")
    var count = 1
    var iterations = 1
    var request: String?
    for index in stride(from: 3, to: args.count, by: 2) {
        guard index + 1 < args.count else { throw inputError }
        let option = args[index], input = args[index + 1]
        if option == "--request", request == nil {
            request = input
            continue
        }
        let number = input.withCString { value -> UInt? in
            var tail: UnsafeMutablePointer<CChar>?
            let number = strtoul(value, &tail, 10)
            return value.pointee != 0 && tail?.pointee == 0 && number >= 1 ? number : nil
        }
        guard let number else { throw inputError }
        if option == "--repeat", number <= 2 { count = Int(number) }
        else if option == "--iterations", number <= 10000000 { iterations = Int(number) }
        else { throw inputError }
    }
    guard request == nil || count == 1 else { throw inputError }
    // Inspect the file before admission and keep that descriptor until inference ends.
    let fd = open(args[2], O_RDONLY | O_NOFOLLOW | O_NONBLOCK)
    defer { if fd >= 0 { close(fd) } }
    var info = stat()
    guard fd >= 0, fstat(fd, &info) == 0, isRegular(info), info.st_size == 784 else { throw inputError }
    var runs: [JSON] = []
    for _ in 0..<count {
        let context = try runtime.begin("mnist", units: "cpu", request: request)
        let token = context["token"] as? String
        defer { _ = try? runtime.end(token) }
        var pixels = [UInt8](repeating: 0, count: 784)
        guard pread(fd, &pixels, pixels.count, 0) == 784, fstat(fd, &info) == 0, info.st_size == 784 else {
            throw failure(2, "Input changed or could not be read")
        }
        for chunk in 1...iterations {
            var result = try pixels.withUnsafeBufferPointer { pixels in
                try runtime.predict(token, pixels: pixels.baseAddress, length: pixels.count)
            }
            if chunk == iterations {
                result["completed_chunks"] = iterations
                runs.append(result)
            }
        }
    }
    return ["runs": runs]
}

private func embeddingCommand(_ args: [String], out: Stream, err: Stream) -> Int32 {
    func reject(_ message: String, code: Int32 = 2) -> Int32 {
        fputs(message + "\n", err)
        return code
    }
    guard args.count >= 3, isEmbedding(args[1]) else {
        return reject("Usage: coreml embed minilm-l6|qwen3-embedding-0.6b INPUT.json [--units all|cpu|cpu-gpu|cpu-ane] [--request UUID]")
    }
    var units: String?
    var request: String?
    for index in stride(from: 3, to: args.count, by: 2) {
        guard index + 1 < args.count else { return reject("Missing embedding option value") }
        switch args[index] {
        case "--units" where units == nil: units = args[index + 1]
        case "--request" where request == nil: request = args[index + 1]
        default: return reject("Unknown or duplicate embedding option")
        }
    }
    let path = args[2]
    var info = stat()
    guard stat(path, &info) == 0, isRegular(info), (1...1048576).contains(info.st_size) else {
        return reject("Embedding input must be a regular JSON file of 1..1048576 bytes")
    }
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)), data.count <= 1048576,
          let input = jsonObject(data) else { return reject("Invalid embedding JSON object") }
    let compute = units ?? "cpu"
    let context: JSON
    do {
        context = try runtime.begin(args[1], units: compute, request: request)
    } catch {
        return emitError(error, out: out, err: err)
    }
    guard let token = context["token"] as? String else { return reject("Embedding failed", code: 1) }
    let prediction = Result { try runtime.embed(token, units: compute, input: input) }
    // Release admission before a write to a potentially blocked caller stream.
    _ = try? runtime.end(token)
    switch prediction {
    case .success(let receipt):
        return emit(receipt, out: out, err: err)
    case .failure(let error):
        return reject(error.localizedDescription, code: exitStatus(error))
    }
}
