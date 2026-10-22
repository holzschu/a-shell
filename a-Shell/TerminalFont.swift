import UIKit
import CoreText

enum TerminalFonts {
    static let presets = ["Menlo", "Courier", "CourierNewPSMT"]
    private static let lock = NSLock()
    private static var registered: [URL: Date] = [:]
    private static var appliedSettings: [String]?

    static var userDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Fonts", isDirectory: true)
    }

    // Keep registration alive for this process only. Files remain owned by the user.
    static func refresh() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        let files = (try? FileManager.default.contentsOfDirectory(at: userDirectory, includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey])) ?? []
        var current: [URL: Date] = [:]
        for file in files where ["ttf", "otf"].contains(file.pathExtension.lowercased()) {
            let resolved = file.resolvingSymlinksInPath()
            guard resolved.deletingLastPathComponent() == userDirectory.resolvingSymlinksInPath(),
                  let values = try? resolved.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
                  values.isRegularFile == true else { continue }
            current[file] = values.contentModificationDate ?? .distantPast
        }
        var errors: [String] = []
        for (file, date) in registered where current[file] != date {
            let result = changeRegistration(file, register: false)
            errors += result
            if result.isEmpty { registered.removeValue(forKey: file) }
        }
        for (file, date) in current where registered[file] != date {
            let faces = faceNames(in: file)
            // Do not take ownership of a face already supplied by another source.
            if !faces.isEmpty && faces.allSatisfy({ font(named: $0, size: 13) != nil }) { continue }
            let result = changeRegistration(file, register: true)
            errors += result
            if result.isEmpty { registered[file] = date }
        }
        return errors
    }

    private static func changeRegistration(_ file: URL, register: Bool) -> [String] {
        let started = ProcessInfo.processInfo.systemUptime
        let completed = DispatchSemaphore(value: 0)
        var messages: [String] = []
        let handler: (CFArray, Bool) -> Bool = { errors, done in
            for error in errors as! [CFError] {
                let attributes = (try? FileManager.default.attributesOfItem(atPath: file.path)) ?? [:]
                let protection = attributes[.protectionKey] ?? "unknown"
                let readable = FileManager.default.isReadableFile(atPath: file.path)
                let elapsed = ProcessInfo.processInfo.systemUptime - started
                messages.append("Font \(file.lastPathComponent): \(CFErrorCopyDescription(error) as String? ?? "Registration failed") [\(CFErrorGetDomain(error) as String):\(CFErrorGetCode(error)), scope=process, readable=\(readable), protection=\(protection), process=\(ProcessInfo.processInfo.processName), pid=\(ProcessInfo.processInfo.processIdentifier), elapsed=\(elapsed)s] userInfo=\(String(describing: CFErrorCopyUserInfo(error)))")
            }
            if done { completed.signal() }
            return true
        }
        if register {
            CTFontManagerRegisterFontURLs([file] as CFArray, .process, true, handler)
        } else {
            CTFontManagerUnregisterFontURLs([file] as CFArray, .process, handler)
        }
        completed.wait()
        return messages
    }

    static func names() -> [String] {
        let files = (try? FileManager.default.contentsOfDirectory(at: userDirectory, includingPropertiesForKeys: nil)) ?? []
        let supplied = files.flatMap { faceNames(in: $0) }.filter { font(named: $0, size: 13) != nil }
        return Set(UIFont.familyNames.flatMap { UIFont.fontNames(forFamilyName: $0) } + supplied).sorted()
    }

    private static func faceNames(in file: URL) -> [String] {
        guard ["ttf", "otf"].contains(file.pathExtension.lowercased()),
              file.resolvingSymlinksInPath().deletingLastPathComponent() == userDirectory.resolvingSymlinksInPath(),
              let values = try? file.resourceValues(forKeys: [.isRegularFileKey]),
              values.isRegularFile == true,
              let descriptors = CTFontManagerCreateFontDescriptorsFromURL(file as CFURL) as? [CTFontDescriptor] else { return [] }
        return descriptors.compactMap { CTFontDescriptorCopyAttribute($0, kCTFontNameAttribute) as? String }
    }

    static func font(named name: String, size: CGFloat) -> UIFont? {
        // UIKit can cache a UIFont after CoreText has unregistered its file.
        if let font = UIFont(name: name, size: size),
           UIFont.fontNames(forFamilyName: font.familyName).contains(font.fontName) { return font }
        // A dropped file can contain faces whose PostScript names differ from its filename.
        let files = (try? FileManager.default.contentsOfDirectory(at: userDirectory, includingPropertiesForKeys: nil)) ?? []
        guard let file = files.first(where: { $0.lastPathComponent.caseInsensitiveCompare(name) == .orderedSame }),
              let postScriptName = faceNames(in: file).first else { return nil }
        guard let font = UIFont(name: postScriptName, size: size),
              UIFont.fontNames(forFamilyName: font.familyName).contains(font.fontName) else { return nil }
        return font
    }

    static var savedName: String? {
        let defaults = UserDefaults.standard
        let selection = defaults.string(forKey: "terminalFont") ?? "custom"
        return selection == "custom" ? defaults.string(forKey: "fontName") : selection
    }

    static var savedSize: Float? {
        guard UserDefaults.standard.object(forKey: "fontSize") != nil else { return nil }
        let size = UserDefaults.standard.float(forKey: "fontSize")
        return size.isFinite && size > 0 ? size : nil
    }

    private static var settings: [String] {
        [savedName ?? "", savedSize.map { String($0) } ?? ""]
    }

    // Called on the main queue with the existing Settings observer.
    static func synchronizeSettings() -> Bool {
        let current = settings
        defer { appliedSettings = current }
        guard let previous = appliedSettings else { return false }
        return previous != current
    }

    static func save(name: String?, size: Float?) {
        let defaults = UserDefaults.standard
        if let name = name {
            defaults.set(name, forKey: "fontName")
            let preset = presets.first { $0 == name || UIFont(name: $0, size: 13)?.fontName == name }
            defaults.set(preset ?? "custom", forKey: "terminalFont")
        }
        if let size = size { defaults.set(size, forKey: "fontSize") }
        appliedSettings = settings
    }
}
