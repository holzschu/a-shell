#!/bin/bash
# macOS regression: call downloadFile while a real file coordinator delays access.
set -euo pipefail
source_file=${1:-"$(dirname "$0")/../a-Shell/ExtraCommands.swift"}
work=$(mktemp -d /tmp/cloud-download-wait.XXXXXX)
trap 'rm -rf "$work"' EXIT
cat > "$work/Host.swift" <<'SWIFT'
import Foundation
import Darwin

var thread_stdout: UnsafeMutablePointer<FILE>! { stdout }
var thread_stderr: UnsafeMutablePointer<FILE>! { stderr }
func convertCArguments(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> [String]? {
    guard let argv = argv else { return nil }
    return (0..<Int(argc)).map { String(cString: argv[$0]!) }
}
extension URL {
    var isDirectory: Bool { (try? resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
}

// Substitute only the external iCloud request/classification boundary. The real
// Foundation coordinator below controls when this requested file becomes ready.
struct FileManager {
    static let `default` = FileManager()
    static var requestedPath = ""
    func fileExists(atPath path: String) -> Bool {
        return path == Self.requestedPath ? false : Foundation.FileManager.default.fileExists(atPath: path)
    }
    func startDownloadingUbiquitousItem(at url: URL) throws {
        guard url.path == Self.requestedPath else { throw CocoaError(.fileReadNoSuchFile) }
    }
    func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?, options: Foundation.FileManager.DirectoryEnumerationOptions) throws -> [URL] {
        return try Foundation.FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: options)
    }
}
SWIFT
awk '/^func downloadRemoteFileFromCloud\(/{p=1} /^private struct PhotoCacheEntry:|^\/\/ hide the on-screen keyboard/{p=0} p' "$source_file" >> "$work/Host.swift"
cat > "$work/main.swift" <<'SWIFT'
import Foundation
import Darwin

let target = URL(fileURLWithPath: CommandLine.arguments[1])
try Data("provider original\n".utf8).write(to: target)
FileManager.requestedPath = target.path
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
var arguments = [strdup("downloadFile"), strdup(target.path), nil]
let begin = ProcessInfo.processInfo.systemUptime
let status = arguments.withUnsafeMutableBufferPointer { downloadFile(argc: 2, argv: $0.baseAddress) }
let elapsed = ProcessInfo.processInfo.systemUptime - begin
guard finished.wait(timeout: .now() + 10) == .success else { fatalError("Provider did not finish") }
print("downloadFile status=\(status) elapsed=\(elapsed)")
guard status == 0 && elapsed >= 5.8 else { exit(1) }
print("CLOUD_DELAYED_DOWNLOAD_GREEN")
SWIFT
nice -n 15 xcrun --sdk macosx swiftc -j 4 -module-cache-path "$work/modules" "$work/Host.swift" "$work/main.swift" -o "$work/check"
"$work/check" "$work/remote.bin"
