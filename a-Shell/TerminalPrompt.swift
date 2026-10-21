import Foundation

enum TerminalPrompts {
    static let names = ["custom", "minimal", "compact", "path", "two-line", "clock"]

    static var savedName: String {
        let name = UserDefaults.standard.string(forKey: "terminalPrompt") ?? "custom"
        return names.contains(name) ? name : "custom"
    }

    static func synchronizeSelection() -> Bool {
        let name = savedName
        let previous = UserDefaults.standard.string(forKey: "appliedTerminalPrompt")
        guard previous != name else { return false }
        UserDefaults.standard.set(name, forKey: "appliedTerminalPrompt")
        return previous != nil
    }

    static func save(_ name: String) {
        UserDefaults.standard.set(name, forKey: "appliedTerminalPrompt")
        UserDefaults.standard.set(name, forKey: "terminalPrompt")
    }

    static func render(_ name: String, path: String, colored: Bool) -> String? {
        let basename = path.split(separator: "/").last.map(String.init) ?? path
        let style = colored ? "\u{1b}[34m" : "\u{1b}[1m"
        switch name {
        case "minimal": return "\(style)$\u{1b}[0m "
        case "compact": return "\(style)\(basename)\u{1b}[0m $ "
        case "path": return "\(style)\(path)\u{1b}[0m $ "
        case "two-line": return "\(style)\(path)\u{1b}[0m\r\n$ "
        case "clock":
            let format = DateFormatter()
            format.dateFormat = "HH:mm"
            return "\(style)\(format.string(from: Date())) \(basename)\u{1b}[0m $ "
        default: return nil
        }
    }
}
