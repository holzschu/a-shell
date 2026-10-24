#if compiler(>=6.4) && canImport(AppIntents)
import Foundation
import AppIntents
import ios_system
@available(iOS 27.0, *)
struct ExecuteLongCommandIntent: LongRunningIntent, CancellableIntent {
    static var title: LocalizedStringResource = "Execute Long Command"
    static var description = IntentDescription("Run a noninteractive command with extended background runtime. Output is returned when it finishes. iOS may cancel work that does not report progress. Scripts can report real progress with the progress command, without adding progress text to the returned output. Cancellation takes effect between commands; the current command may continue until it finishes.")
    static var openAppWhenRun = false
    static var allowedExecutionTargets: IntentExecutionTargets { [.appIntentsExtension] }

    @Parameter(title: "Command")
    var command: String

    @Parameter(title: "Continue After Error", default: false)
    var keepGoing: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Execute \(\.$command)") {
            \.$keepGoing
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let commands = command.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !commands.isEmpty else { throw CommandExecutionError.emptyCommand }
        let handler = LongCommandExecutor()
        let commandProgress = progress
        commandProgress.totalUnitCount = Int64(commands.count)
        let result = try await performBackgroundTask(operation: {
            try Task.checkCancellation()
            return try await handler.runCommands(commands, keepGoing: keepGoing, progress: commandProgress)
        }, onCancel: { _ in handler.cancelExecution() })
        guard result.1 == 0 || keepGoing else { throw CommandExecutionError.exitStatus(result.1) }
        return .result(value: result.0)
    }
}

// Preserve the legacy intent. Commands use ios_system threads, not OS child processes.
enum CommandExecutionError: LocalizedError {
    case emptyCommand, cancelled, outputTooLarge, unavailableDirectory, busy
    case exitStatus(Int32)

    var errorDescription: String? {
        switch self {
        case .emptyCommand: return "Enter a command to execute."
        case .busy: return "Another long command is already running. Try again when it finishes."
        case .cancelled: return "Command execution was cancelled."
        case .outputTooLarge: return "Command output exceeds 8 MiB. Write large results to a file instead."
        case .unavailableDirectory: return "The Shortcuts shared directory is unavailable."
        case .exitStatus(let status): return "Command exited with status \(status)."
        }
    }
}

@available(iOS 27.0, *)
private final class LongCommandExecutor {
    private static let appGroupID = (Bundle.main.infoDictionary?["AppGroupIdentifier"] as? String) ?? "group.AsheKube.a-Shell"
    private static let initialized: Result<Void, Error> = Result {
        initializeEnvironment()
        replaceCommand("progress", "ashell_progress", false)
        // Match AppDelegate: release file coordination before waiting for the command.
        joinMainThread = false
        let host = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent()
        guard let hostBundle = Bundle(url: host),
              let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            throw CommandExecutionError.unavailableDirectory
        }
        // The extension cannot use the app's private Library. Shared user packages live here.
        let libraryURL = groupURL.appendingPathComponent("Library")
        setenv("APPDIR", host.path, 1)
        initializeCommandEnvironment(hostBundle: hostBundle, documentsUrl: groupURL, libraryURL: libraryURL, groupURL: groupURL)
        // ios_system expands ~name using standard defaults; include the app's mirrored bookmarks.
        UserDefaults.standard.addSuite(named: appGroupID)
        ios_setBookmarkDictionaryName("bookmarkNames")
        let path = [host.appendingPathComponent("bin").path,
                    host.appendingPathComponent("Library/bin").path,
                    String(cString: getenv("PATH"))].joined(separator: ":")
        setenv("PATH", path, 1)
    }
    private static let executionLock = NSLock()
    private static var executionActive = false

    private static func acquireExecution() -> Bool {
        executionLock.lock()
        defer { executionLock.unlock() }
        guard !executionActive else { return false }
        executionActive = true
        return true
    }

    private static func releaseExecution() {
        executionLock.lock()
        executionActive = false
        executionLock.unlock()
    }
    // ios_system retains sessions by pointer. Keep each invocation's key for the process lifetime;
    // its public wait API does not prove that every pipeline worker has finished.
    private static var sessionCount = 0
    var response = ""
    private let outputComplete = DispatchSemaphore(value: 0)
    private var outputClosed = false
    private var outputData = Data()
    private var outputLimit: Int?
    private var outputTruncated = false
    private let cancellationLock = NSLock()
    private var cancelled = false

    func cancelExecution() {
        cancellationLock.lock()
        cancelled = true
        cancellationLock.unlock()
    }

    private var isCancelled: Bool {
        cancellationLock.lock()
        defer { cancellationLock.unlock() }
        return cancelled
    }

    // ios_system propagates the session and streams to each command thread.
    func runCommands(_ commands: [String], keepGoing: Bool, progress: Progress) async throws -> (String, Int32) {
        guard Self.acquireExecution() else { throw CommandExecutionError.busy }
        defer { Self.releaseExecution() }
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {
                    try Self.initialized.get()
                } catch {
                    continuation.resume(throwing: error)
                    return
                }
                guard !self.isCancelled else {
                    continuation.resume(throwing: CommandExecutionError.cancelled)
                    return
                }
                guard let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupID) else {
                    continuation.resume(throwing: CommandExecutionError.unavailableDirectory)
                    return
                }
                // Hold security-scoped access for this invocation, including every command thread.
                let bookmarkData = UserDefaults.standard.dictionary(forKey: "fileBookmarks") ?? [:]
                let accessedURLs: [URL] = bookmarkData.values.compactMap { value in
                    guard let data = value as? Data else { return nil }
                    var stale = false
                    guard let url = try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &stale),
                          url.startAccessingSecurityScopedResource() else { return nil }
                    return url
                }
                defer { accessedURLs.forEach { $0.stopAccessingSecurityScopedResource() } }
                progress.localizedAdditionalDescription = nil
                progress.totalUnitCount = Int64(commands.count)
                progress.completedUnitCount = 0
                let sessionIdentifier = strdup("longCommand\(Self.sessionCount)")!
                Self.sessionCount += 1
                ios_switchSession(sessionIdentifier)
                ios_setContext(UnsafeMutableRawPointer(sessionIdentifier))
                let directoryAvailable = FileManager.default.changeCurrentDirectoryPath(directory.path)
                ios_setDirectoryURL(directory)
                defer {
                    ProgressCommand.setHandler(for: sessionIdentifier, nil)
                }
                guard directoryAvailable else {
                    continuation.resume(throwing: CommandExecutionError.unavailableDirectory)
                    return
                }
                self.response = ""
                self.outputLimit = 8 * 1024 * 1024
                self.outputTruncated = false
                var status: Int32 = 0
                for (commandIndex, command) in commands.enumerated() {
                    if self.isCancelled { break }
                    let completedBeforeCommand = progress.completedUnitCount
                    var reportedCompleted: Int64 = 0
                    var reportedTotal: Int64 = 1
                    let remainingCommands = Int64(commands.count) - Int64(commandIndex) - 1
                    ProgressCommand.setHandler(for: sessionIdentifier) { update in
                        var units: (Int64, Int64)?
                        switch update {
                        case .units(let done, let total, let text):
                            units = (done, total)
                            if let text = text { progress.localizedAdditionalDescription = String(text.prefix(240)) }
                        case .percent(let percent, let text):
                            // Avoid overflow while converting a percentage to known work units.
                            let total = reportedTotal == 1 ? 100 : reportedTotal
                            units = (total / 100 * percent + total % 100 * percent / 100, total)
                            if let text = text { progress.localizedAdditionalDescription = String(text.prefix(240)) }
                        case .subtitle(let text): progress.localizedAdditionalDescription = String(text.prefix(240))
                        case .title(let text): progress.localizedDescription = String(text.prefix(240))
                        case .indeterminate(let text):
                            progress.totalUnitCount = -1
                            if let text = text { progress.localizedAdditionalDescription = String(text.prefix(240)) }
                        case .done: units = (reportedTotal, reportedTotal)
                        }
                        if let (done, total) = units {
                            guard done >= reportedCompleted, total <= Int64.max - completedBeforeCommand - remainingCommands else { return false }
                            reportedCompleted = done
                            reportedTotal = total
                            // The scheduler observes root units, not a nested child's fraction.
                            progress.totalUnitCount = completedBeforeCommand + total + remainingCommands
                            progress.completedUnitCount = completedBeforeCommand + done
                        }
                        return true
                    }
                    status = self.executeCommandInExtension(command: command)
                    ProgressCommand.setHandler(for: sessionIdentifier, nil)
                    progress.totalUnitCount = completedBeforeCommand + reportedTotal + remainingCommands
                    progress.completedUnitCount = completedBeforeCommand + reportedTotal
                    if status != 0 && !keepGoing { break }
                }
                if self.isCancelled {
                    continuation.resume(throwing: CommandExecutionError.cancelled)
                } else if self.outputTruncated {
                    continuation.resume(throwing: CommandExecutionError.outputTooLarge)
                } else {
                    continuation.resume(returning: (self.response, status))
                }
            }
        }
    }

    func executeCommandInExtension(command: String) -> Int32 {
        // EOF stdin makes this explicitly noninteractive. Duplicate the pipe descriptor so
        // fclose and FileHandle each close only the descriptor they own.
        guard let stdin_file = fopen("/dev/null", "r") else { return -1 }
        let stdout_pipe = Pipe()
        let outputDescriptor = dup(stdout_pipe.fileHandleForWriting.fileDescriptor)
        guard outputDescriptor >= 0, let stdout_file = fdopen(outputDescriptor, "w") else {
            if outputDescriptor >= 0 { close(outputDescriptor) }
            fclose(stdin_file)
            return -1
        }
        setvbuf(stdout_file, nil, _IONBF, 0)
        outputClosed = false
        outputData.removeAll(keepingCapacity: true)
        stdout_pipe.fileHandleForReading.readabilityHandler = self.onStdout
        thread_stdin = nil
        thread_stdout = nil
        thread_stderr = nil
        ios_setStreams(stdin_file, stdout_file, stdout_file)
        setenv("LC_CTYPE", "UTF-8", 1)
        setlocale(LC_CTYPE, "UTF-8")
        var returnVal: Int32 = 0
        for command in command.components(separatedBy: "\n") {
            if isCancelled { break }
            let pid = ios_fork()
            returnVal = ios_system(command)
            fflush(thread_stdout)
            ios_waitpid(pid)
            if returnVal == 0 { returnVal = ios_getCommandStatus() }
            ios_releaseThreadId(pid)
        }
        fflush(stdout_file)
        fclose(stdout_file)
        try? stdout_pipe.fileHandleForWriting.close()
        // EOF, not an in-band control byte, delimits output. Wait without busy-spinning.
        outputComplete.wait()
        stdout_pipe.fileHandleForReading.readabilityHandler = nil
        try? stdout_pipe.fileHandleForReading.close()
        fclose(stdin_file)
        var text = String(decoding: outputData, as: UTF8.self)
        for pattern in [#"(?:\x1B\[|\x9B)[0-?]*[ -/]*[@-~]"#,
                        #"(?:\x1B\]|\x9D)[^\x07\x1B\x9C]*(?:\x07|\x1B\\|\x9C)"#,
                        #"\x1B[P^_X][\s\S]*?\x1B\\"#,
                        #"\x1B[ -/]*[0-~]"#] {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                text = regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
            }
        }
        // Invalid UTF-8 can expand to three-byte replacement characters during decoding.
        if let limit = outputLimit, text.utf8.count > max(0, limit - response.utf8.count) {
            outputTruncated = true
        } else {
            response += text
        }
        return returnVal
    }

    private func onStdout(_ stdout: FileHandle) {
        if outputClosed { return }
        let data = stdout.availableData
        if data.isEmpty {
            outputClosed = true
            stdout.readabilityHandler = nil
            outputComplete.signal()
            return
        }
        let available = outputLimit.map { max(0, $0 - response.utf8.count - outputData.count) } ?? data.count
        outputData.append(data.prefix(available))
        if available < data.count { outputTruncated = true }
    }
}

#endif
