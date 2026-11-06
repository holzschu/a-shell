import Foundation
import ios_system

enum CommandProgressUpdate {
    case units(Int64, Int64, String?)
    case percent(Int64, String?)
    case subtitle(String)
    case title(String)
    case indeterminate(String?)
    case done
}

// The executor installs this only while its command owns the ios_system session.
enum ProgressCommand {
    private static let lock = NSLock()
    private static var handlers: [UInt: (CommandProgressUpdate) -> Bool] = [:]

    static func setHandler(for context: UnsafeMutablePointer<CChar>, _ value: ((CommandProgressUpdate) -> Bool)?) {
        lock.lock()
        defer { lock.unlock() }
        handlers[UInt(bitPattern: context)] = value
    }

    static func execute(_ arguments: [String]) -> Int32 {
        lock.lock()
        defer { lock.unlock() }
        // Shared scripts can call progress unchanged in the ordinary terminal.
        guard let context = ios_getContext(), let handler = handlers[UInt(bitPattern: context)] else { return 0 }
        guard let first = arguments.first else { return usage() }
        let update: CommandProgressUpdate
        let text = arguments.count > 1 ? arguments.dropFirst().joined(separator: " ") : nil
        switch first {
        case "--done":
            guard arguments.count == 1 else { return usage() }
            update = .done
        case "--indeterminate": update = .indeterminate(text)
        case "--title":
            guard let text = text else { return usage() }
            update = .title(text)
        default:
            let units = first.split(separator: "/", omittingEmptySubsequences: false)
            if units.count == 2 {
                guard let done = Int64(units[0]), let total = Int64(units[1]), total > 0, done >= 0, done <= total else { return usage() }
                update = .units(done, total, text)
            } else if first.hasSuffix("%") {
                guard let percent = Int64(first.dropLast()), (0...100).contains(percent) else { return usage() }
                update = .percent(percent, text)
            } else {
                guard !first.hasPrefix("--") else { return usage() }
                update = .subtitle(arguments.joined(separator: " "))
            }
        }
        guard handler(update) else {
            fputs("progress: completed work cannot go backwards or overflow.\n", thread_stderr)
            return 2
        }
        return 0
    }

    private static func usage() -> Int32 {
        fputs("Usage: progress N/M [text] | P% [text] | text | --title text | --indeterminate [text] | --done\n", thread_stderr)
        return 2
    }
}

@_cdecl("ashell_progress")
public func ashellProgress(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32 {
    let arguments = (1..<max(1, Int(argc))).compactMap { index -> String? in
        guard let argument = argv?[index] else { return nil }
        return String(cString: argument)
    }
    return ProgressCommand.execute(arguments)
}
