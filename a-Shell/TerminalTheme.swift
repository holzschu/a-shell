import Foundation

struct TerminalTheme {
    static let colorKeys = ["background", "foreground", "cursorColor", "black", "red", "green", "yellow", "blue", "purple", "cyan", "white", "brightBlack", "brightRed", "brightGreen", "brightYellow", "brightBlue", "brightPurple", "brightCyan", "brightWhite"]
    let colors: [String]

    init(data: Data) throws {
        guard let values = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TerminalThemeError.invalid("Expected a Windows Terminal color scheme object.")
        }
        colors = try Self.colorKeys.map { key in
            guard let value = values[key] as? String, value.count == 7, value.first == "#",
                  value.dropFirst().allSatisfy({ $0.isASCII && $0.isHexDigit }) else {
                throw TerminalThemeError.invalid("Theme color \(key) must be #RRGGBB.")
            }
            return value
        }
    }
}

enum TerminalThemeError: LocalizedError {
    case invalid(String)

    var errorDescription: String? {
        switch self {
        case .invalid(let message): return message
        }
    }
}

enum TerminalThemes {
    static var userDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Themes", isDirectory: true)
    }

    static var bundledDirectory: URL? {
        Bundle.main.url(forResource: "Themes", withExtension: nil)
    }

    static func files(in directory: URL?) -> [URL] {
        guard let directory = directory,
              let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return [] }
        return files.filter { $0.pathExtension.lowercased() == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    static func names() -> [String] {
        Array(Set((files(in: bundledDirectory) + files(in: userDirectory)).map { $0.deletingPathExtension().lastPathComponent.lowercased() })).sorted()
    }

    static func file(named name: String) -> URL? {
        (files(in: bundledDirectory) + files(in: userDirectory)).first {
            $0.lastPathComponent.caseInsensitiveCompare(name) == .orderedSame ||
            $0.deletingPathExtension().lastPathComponent.caseInsensitiveCompare(name) == .orderedSame
        }
    }

    static func load(_ name: String) throws -> TerminalTheme {
        guard !name.isEmpty, name != ".", name != "..", name.count <= 128,
              !name.contains("/"), !name.contains("\\") else {
            throw TerminalThemeError.invalid("Use a theme file name with or without .json, without a directory path.")
        }
        guard let selectedFile = file(named: name) else {
            let available = files(in: userDirectory).map { $0.lastPathComponent }.joined(separator: ", ")
            throw TerminalThemeError.invalid("Unknown theme \(name). Available Themes files: \(available.isEmpty ? "(none)" : available).")
        }
        let directory = selectedFile.deletingLastPathComponent()
        let file = selectedFile.resolvingSymlinksInPath()
        guard file.deletingLastPathComponent() == directory.resolvingSymlinksInPath() else {
            throw TerminalThemeError.invalid("The theme file must be inside the Themes folder.")
        }
        let attributes = try file.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard attributes.isRegularFile == true, (attributes.fileSize ?? 0) <= 65536 else {
            throw TerminalThemeError.invalid("Theme files must be regular JSON files of at most 64 KiB.")
        }
        return try TerminalTheme(data: Data(contentsOf: file))
    }

    static var savedName: String? {
        let selected = UserDefaults.standard.string(forKey: "terminalTheme") ?? ""
        if selected == "custom" { return UserDefaults.standard.string(forKey: "customTerminalTheme") ?? "" }
        return selected.isEmpty ? nil : selected
    }

    static func synchronizeSelection() -> Bool {
        let name = savedName
        let previous = UserDefaults.standard.string(forKey: "appliedTerminalTheme")
        let failed = UserDefaults.standard.bool(forKey: "terminalThemeSelectionFailed")
        do { _ = try name.map { try load($0) } } catch {
            guard previous != (name ?? "") || !failed else { return false }
            UserDefaults.standard.set(name ?? "", forKey: "appliedTerminalTheme")
            UserDefaults.standard.set(true, forKey: "terminalThemeSelectionFailed")
            return true
        }
        guard previous != (name ?? "") || failed else { return false }
        UserDefaults.standard.set(name ?? "", forKey: "appliedTerminalTheme")
        UserDefaults.standard.removeObject(forKey: "terminalThemeSelectionFailed")
        if failed && previous == (name ?? "") { return true }
        guard previous != nil else { return false }
        for key in ["backgroundColor", "foregroundColor", "cursorColor"] {
            UserDefaults.standard.removeObject(forKey: key)
        }
        return true
    }

    static func save(_ name: String) {
        let file = file(named: name)
        let savedName = file?.deletingPathExtension().lastPathComponent ?? name
        UserDefaults.standard.set(savedName, forKey: "appliedTerminalTheme")
        UserDefaults.standard.removeObject(forKey: "terminalThemeSelectionFailed")
        if name.isEmpty || file?.deletingLastPathComponent().path == bundledDirectory?.path {
            UserDefaults.standard.set(savedName, forKey: "terminalTheme")
        } else {
            UserDefaults.standard.set(savedName, forKey: "customTerminalTheme")
            UserDefaults.standard.set("custom", forKey: "terminalTheme")
        }
    }
}
