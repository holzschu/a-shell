// Substitute only ios_system's external runtime; commands read the actual environment.
import Foundation
import Darwin
public var joinMainThread = true
public var numPythonInterpreters = 0
public var thread_stdin: UnsafeMutablePointer<FILE>?
public var thread_stdout: UnsafeMutablePointer<FILE>?
public var thread_stderr: UnsafeMutablePointer<FILE>?
private var context: UnsafeMutableRawPointer?
public func initializeEnvironment() { setenv("PATH", "/usr/bin", 1) }
public func replaceCommand(_ name: String, _ symbol: String, _ all: Bool) {}
public func ios_setBookmarkDictionaryName(_ name: String) {}
public func ios_switchSession(_ name: UnsafeMutablePointer<CChar>) {}
public func ios_setContext(_ value: UnsafeMutableRawPointer) { context = value }
public func ios_getContext() -> UnsafeMutableRawPointer? { context }
public func ios_setDirectoryURL(_ url: URL) {}
public func ios_setStreams(_ input: UnsafeMutablePointer<FILE>, _ output: UnsafeMutablePointer<FILE>, _ error: UnsafeMutablePointer<FILE>) {
    thread_stdin = input; thread_stdout = output; thread_stderr = error
}
public func ios_fork() -> Int32 { 1 }
public func ios_waitpid(_ pid: Int32) {}
public func ios_getCommandStatus() -> Int32 { 0 }
public func ios_releaseThreadId(_ pid: Int32) {}
public func ios_system(_ command: String) -> Int32 {
    guard let output = thread_stdout else { return 1 }
    for name in command.split(separator: " ") {
        fputs("\(name)=\(getenv(String(name)).map { String(cString: $0) } ?? "<unset>")\n", output)
    }
    return 0
}
