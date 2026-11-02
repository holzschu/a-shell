#!/bin/bash
# macOS command regression: coordination delays the external provider; pthread cancellation is real.
set -euo pipefail
source_file=${1:-"$(dirname "$0")/../a-Shell/ExtraCommands.swift"}
work=$(mktemp -d /tmp/cloud-download-wait.XXXXXX)
trap 'rm -rf "$work"' EXIT
cat > "$work/Session.h" <<'C'
int ios_getCommandStatus(void);
void set_session_errno(int status);
C
cat > "$work/Session.c" <<'C'
#include <stdatomic.h>
// Substitute only ios_system's host status storage; command and pthreads are real.
static _Atomic int status;
int ios_getCommandStatus(void) { return atomic_load(&status); }
void set_session_errno(int value) { atomic_store(&status, value); }
C
cat > "$work/Host.swift" <<'SWIFT'
import Foundation
import Darwin

var thread_stdout: UnsafeMutablePointer<FILE>! { stdout }
var thread_stderr: UnsafeMutablePointer<FILE>! { stderr }
func convertCArguments(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> [String]? {
    guard let argv = argv else { return nil }
    return (0..<Int(argc)).map { String(cString: argv[$0]!) }
}

// Only the external iCloud filesystem boundary is substituted. A real Foundation
// writer holds the original; the provider's coordinated reader marks it current.
enum Provider {
    static let lock = NSLock()
    static var path = ""
    static var secondPath = ""
    static var requestedPaths = Set<String>()
    static var available = false
    static var stale = false
    static let requested = DispatchSemaphore(value: 0)
    static var ready: Bool {
        lock.lock()
        defer { lock.unlock() }
        return available
    }
}
struct ProviderValues {
    let local: Foundation.URLResourceValues
    let remote: Bool
    var isDirectory: Bool? { local.isDirectory }
    var isSymbolicLink: Bool? { local.isSymbolicLink }
    var isUbiquitousItem: Bool? { remote }
    var ubiquitousItemDownloadingStatus: URLUbiquitousItemDownloadingStatus? {
        remote ? (Provider.ready ? .current : (Provider.stale ? .downloaded : .notDownloaded)) : nil
    }
    var ubiquitousItemDownloadingError: Error? { nil }
}
public struct URL {
    var local: Foundation.URL
    init(fileURLWithPath path: String) { local = Foundation.URL(fileURLWithPath: path) }
    init(_ url: Foundation.URL) { local = url }
    var path: String { local.resolvingSymlinksInPath().path }
    var lastPathComponent: String { local.lastPathComponent }
    var isDirectory: Bool { (try? local.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
    func deletingLastPathComponent() -> URL { URL(local.deletingLastPathComponent()) }
    func appendingPathComponent(_ name: String) -> URL { URL(local.appendingPathComponent(name)) }
    mutating func removeAllCachedResourceValues() { local.removeAllCachedResourceValues() }
    func resourceValues(forKeys keys: Set<URLResourceKey>) throws -> ProviderValues {
        ProviderValues(local: try local.resourceValues(forKeys: keys), remote: path == Provider.path || path == Provider.secondPath)
    }
}
// Keep the old coordinator signature so the same fixture also runs pre-fix RED sources.
extension NSFileCoordinator {
    func coordinate(readingItemAt url: URL, options: ReadingOptions, error: NSErrorPointer, byAccessor accessor: (Foundation.URL) -> Void) {
        coordinate(readingItemAt: url.local, options: options, error: error, byAccessor: accessor)
    }
}
struct FileManager {
    static let `default` = FileManager()
    func fileExists(atPath path: String) -> Bool {
        path == Provider.path ? false : Foundation.FileManager.default.fileExists(atPath: path)
    }
    func startDownloadingUbiquitousItem(at url: URL) throws {
        guard url.path == Provider.path || url.path == Provider.secondPath else { throw CocoaError(.fileReadNoSuchFile) }
        Provider.lock.lock()
        Provider.requestedPaths.insert(url.path)
        Provider.lock.unlock()
        Provider.requested.signal()
    }
    func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?, options: Foundation.FileManager.DirectoryEnumerationOptions) throws -> [URL] {
        try Foundation.FileManager.default.contentsOfDirectory(at: url.local, includingPropertiesForKeys: keys, options: options).map(URL.init)
    }
}
SWIFT
awk '/^func downloadRemoteFileFromCloud\(/{p=1} /^private struct PhotoCacheEntry:|^\/\/ hide the on-screen keyboard/{p=0} p' "$source_file" >> "$work/Host.swift"
cat > "$work/main.swift" <<'SWIFT'
import Foundation
import Darwin

let mode = CommandLine.arguments[1]
Provider.stale = mode == "stale-file"
let folder = Foundation.URL(fileURLWithPath: CommandLine.arguments[2])
let hidden = folder.appendingPathComponent(".hidden", isDirectory: true)
try Foundation.FileManager.default.createDirectory(at: hidden, withIntermediateDirectories: true)
let target = hidden.appendingPathComponent("remote.bin")
try Data("provider original\n".utf8).write(to: target)
Provider.path = target.resolvingSymlinksInPath().path
if mode.hasPrefix("cancel") {
    let second = hidden.appendingPathComponent("second.bin")
    try Data("second original\n".utf8).write(to: second)
    Provider.secondPath = second.resolvingSymlinksInPath().path
}
let started = DispatchSemaphore(value: 0)
let finished = DispatchSemaphore(value: 0)
DispatchQueue.global().async {
    var error: NSError?
    NSFileCoordinator().coordinate(writingItemAt: target, options: [], error: &error) { _ in
        started.signal()
        Thread.sleep(forTimeInterval: 6)
    }
    finished.signal()
}
guard started.wait(timeout: .now() + 10) == .success else {
    fatalError("Could not acquire provider write coordination")
}
DispatchQueue.global().async {
    var error: NSError?
    NSFileCoordinator().coordinate(readingItemAt: target, options: [], error: &error) { _ in
        Provider.lock.lock()
        Provider.available = true
        Provider.lock.unlock()
    }
}
func command(_ strings: [String]) -> Int32 {
    var args = strings.map { strdup($0) } + [nil]
    defer { for arg in args { free(arg) } }
    let status: Int32 = args.withUnsafeMutableBufferPointer {
        if strings[0] == "downloadFolder" { return downloadFolder(argc: Int32(strings.count), argv: $0.baseAddress) }
        return downloadFile(argc: Int32(strings.count), argv: $0.baseAddress)
    }
    set_session_errno(status)
    return status
}
let waitArguments = mode.hasSuffix("folder") ? ["downloadFolder", "-w", "-r", folder.path] : ["downloadFile", "--wait", target.path] + (mode.hasPrefix("cancel") ? [Provider.secondPath] : [])
if mode.hasPrefix("cancel") {
    var thread: pthread_t?
    guard pthread_create(&thread, nil, { _ in
        _ = command(waitArguments)
        return nil
    }, nil) == 0 else { fatalError("Could not start command") }
    guard Provider.requested.wait(timeout: .now() + 5) == .success else { fatalError("Command did not request file") }
    // Both remote originals must be requested before waiting on either one.
    for _ in 0..<50 {
        Provider.lock.lock()
        let count = Provider.requestedPaths.count
        Provider.lock.unlock()
        if count == 2 { break }
        usleep(10_000)
    }
    Provider.lock.lock()
    let batchStarted = Provider.requestedPaths.count == 2
    Provider.lock.unlock()
    guard batchStarted else { fatalError("Second original was not requested before waiting") }
    usleep(200_000)
    let begin = ProcessInfo.processInfo.systemUptime
    guard pthread_cancel(thread!) == 0 else { fatalError("Could not interrupt command") }
    var result: UnsafeMutableRawPointer?
    guard pthread_join(thread!, &result) == 0 else { fatalError("Could not join command") }
    let elapsed = ProcessInfo.processInfo.systemUptime - begin
    print("\(mode) cancelled=\(result == UnsafeMutableRawPointer(bitPattern: 1)) status=\(ios_getCommandStatus()) elapsed=\(elapsed) ready=\(Provider.ready)")
    guard result == UnsafeMutableRawPointer(bitPattern: 1) && ios_getCommandStatus() != 0 && elapsed < 1 && !Provider.ready else { exit(1) }
    let recovery = folder.appendingPathComponent("local.txt")
    try Data("next command\n".utf8).write(to: recovery)
    guard command(["downloadFile", recovery.path]) == 0 && ios_getCommandStatus() == 0 else { exit(1) }
} else if mode == "default" {
    let automaticBegin = ProcessInfo.processInfo.systemUptime
    let automatic = downloadRemoteFile(fileURL: URL(target))
    let automaticElapsed = ProcessInfo.processInfo.systemUptime - automaticBegin
    guard !automatic && automaticElapsed < 1 else { fatalError("Automatic main-thread request blocked") }
    for args in [["downloadFile", target.path], ["downloadFolder", "-r", folder.path]] {
        let begin = ProcessInfo.processInfo.systemUptime
        let status = command(args)
        let elapsed = ProcessInfo.processInfo.systemUptime - begin
        print("default \(args[0]) status=\(status) elapsed=\(elapsed) ready=\(Provider.ready)")
        guard status == 0 && elapsed < 1 && !Provider.ready else { exit(1) }
    }
} else {
    let begin = ProcessInfo.processInfo.systemUptime
    let status = command(waitArguments)
    let elapsed = ProcessInfo.processInfo.systemUptime - begin
    print("\(mode) status=\(status) elapsed=\(elapsed) ready=\(Provider.ready)")
    guard status == 0 && elapsed >= 5.8 && Provider.ready else { exit(1) }
}
guard finished.wait(timeout: .now() + 10) == .success else { fatalError("Provider did not finish") }
print("CLOUD_\(mode.uppercased())_GREEN")
SWIFT
xcrun --sdk macosx clang -c "$work/Session.c" -o "$work/Session.o"
xcrun --sdk macosx swiftc -import-objc-header "$work/Session.h" -module-cache-path "$work/modules" "$work/Host.swift" "$work/main.swift" "$work/Session.o" -o "$work/check"
"$work/check" default "$work/default"
"$work/check" wait-file "$work/wait-file"
"$work/check" wait-folder "$work/wait-folder"
"$work/check" stale-file "$work/stale-file"
"$work/check" cancel-file "$work/cancel-file"
"$work/check" cancel-folder "$work/cancel-folder"
