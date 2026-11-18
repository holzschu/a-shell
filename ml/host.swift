import Foundation

@main
enum CoreMLHost {
    static func main() {
        // Framework diagnostics can bypass FILE streams. Keep them off the
        // command's original stdout.
        guard let out = fdopen(dup(STDOUT_FILENO), "w"), dup2(STDERR_FILENO, STDOUT_FILENO) >= 0 else { exit(1) }
        let arguments = CommandLine.arguments
        DispatchQueue.global(qos: .userInitiated).async {
            exit(command(arguments, out: out, err: stderr))
        }
        dispatchMain()
    }
}
