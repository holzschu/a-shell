import Foundation

// macOS has no a-Shell UIKit scene. Exercise the actual command boundary and
// its unavailable-terminal behavior without pretending to emulate iOS input.
@main
struct TermHost {
    static func main() {
        exit(TermCommand.run(Array(CommandLine.arguments.dropFirst()), perform: { _, reply in
            reply(.error(503, "no connected terminal"))
        }, write: { bytes, failed in
            (failed ? FileHandle.standardError : FileHandle.standardOutput).write(bytes)
        }))
    }
}
