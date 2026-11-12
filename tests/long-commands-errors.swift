import Foundation
import Darwin

// Inject failures only at the OS bundle and shared-container boundaries.
final class Bundle {
    static let main = Foundation.Bundle.main
    private let bundle: Foundation.Bundle
    init?(url: URL) {
        let failure = ProcessInfo.processInfo.environment["LONG_COMMANDS_FAILURE"]
        // The mode 311 fixture is only meaningful if Foundation itself refuses the app.
        if failure == "unlistable" && url.pathExtension == "app" && Foundation.Bundle(url: url) != nil {
            fputs("FAIL unlistable: Bundle(url:) succeeded\n", stderr)
            exit(1)
        }
        guard !["host", "bundle"].contains(failure),
              let bundle = Foundation.Bundle(url: url) else { return nil }
        self.bundle = bundle
    }
    var infoDictionary: [String: Any]? { bundle.infoDictionary }
    var resourcePath: String? { bundle.resourcePath }
}
class FileManager: Foundation.FileManager, @unchecked Sendable {
    static let fixture = FileManager()
    override class var `default`: FileManager { fixture }
    override func containerURL(forSecurityApplicationGroupIdentifier: String) -> URL? {
        guard ProcessInfo.processInfo.environment["LONG_COMMANDS_FAILURE"] != "group" else { return nil }
        return URL(fileURLWithPath: ProcessInfo.processInfo.environment["LONG_COMMANDS_GROUP"]!)
    }
}
struct UIDevice {
    static let current = UIDevice()
    var model: String { "iPad" }
}

@main struct ErrorTest {
    @MainActor static func main() async {
        guard ["appex", "app"].contains(Foundation.Bundle.main.bundleURL.pathExtension) else {
            fputs("FAIL fixture is not an extension or app bundle\n", stderr)
            exit(1)
        }
        let failure = ProcessInfo.processInfo.environment["LONG_COMMANDS_FAILURE"]!
        do {
            var intent = ExecuteLongCommandIntent()
            intent.command = ["unlistable": "APPDIR APPNAME APPVERSION VIMRUNTIME", "host": "APPDIR APPNAME APPVERSION"][failure] ?? "APPDIR APPNAME"
            intent.keepGoing = false
            let result = try await intent.perform()
            guard ["none", "bundle", "unlistable", "host"].contains(failure) else {
                fputs("FAIL \(failure): intent succeeded\n", stderr)
                exit(1)
            }
            let root = ProcessInfo.processInfo.environment["LONG_COMMANDS_RESOURCES"]!
            // Without a Bundle the resources are read from the app directory itself. Info.plist gives the host values;
            // without it only the name from the directory is known, and APPVERSION stays unset.
            let host = failure == "host" ? "APPNAME=NoPlist\nAPPVERSION=<unset>\n" : "APPNAME=a-Shell-mini\n"
            let extra = ["unlistable": "APPVERSION=1.0\nVIMRUNTIME=\(root)/vim\n"][failure] ?? ""
            guard result.value == "APPDIR=\(root)\n\(host)\(extra)" else {
                fputs("FAIL host environment: \(result.value)\n", stderr)
                exit(1)
            }
            print("PASS host environment")
        } catch {
            let expected: String
            switch failure {
            case "detached": expected = "Could not locate the a-Shell app bundle containing \(Foundation.Bundle.main.bundleURL.path)."
            case "group": expected = "The Shortcuts shared directory is unavailable."
            default:
                fputs("FAIL iOS intent: \(error.localizedDescription)\n", stderr)
                exit(1)
            }
            guard error.localizedDescription == expected else {
                fputs("FAIL \(failure): expected \(expected), received \(error.localizedDescription)\n", stderr)
                exit(1)
            }
            print("PASS \(failure): \(error.localizedDescription)")
        }
    }
}
