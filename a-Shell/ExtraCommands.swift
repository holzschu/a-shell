//
//  extraCommands.swift
//  a-Shell: file for extra commands added to a-Shell.
//  Part of the difficulty is identifying which window scene is active. See history() for an example. 
//
//  Created by Nicolas Holzschuch on 30/08/2019.
//  Copyright © 2019 AsheKube. All rights reserved.
//

import Foundation
import UIKit
import ios_system
import Photos
import PhotosUI
import CryptoKit

private let appGroupID = (Bundle.main.infoDictionary?["AppGroupIdentifier"] as? String) ?? "group.AsheKube.a-Shell"

// Shortcut intents run commands in the app process, next to the terminal windows.
// Only the commands of their ios_system sessions run "in extension".
// Counted, since a context can be registered twice: Execute Command registers in handle() and again for each command.
private let extensionContextsLock = NSLock()
private var extensionContexts = [UnsafeRawPointer: Int]()
private var extensionGeneration = 0
var runningInExtension: Bool {
    guard let context = ios_getContext() else { return false }
    extensionContextsLock.lock()
    defer { extensionContextsLock.unlock() }
    return extensionContexts[context] != nil
}

func setRunningInExtension(_ running: Bool, context: UnsafeRawPointer) {
    extensionContextsLock.lock()
    defer { extensionContextsLock.unlock() }
    if running {
        extensionContexts[context, default: 0] += 1
    } else if let count = extensionContexts[context] {
        extensionContexts[context] = count > 1 ? count - 1 : nil
    }
    extensionGeneration += 1
}

// These sessions also move the process directory, which the terminal windows share.
// An unchanged generation with no active session means that no intent ran in between.
func intentSessionsState() -> (generation: Int, active: Bool) {
    extensionContextsLock.lock()
    defer { extensionContextsLock.unlock() }
    return (extensionGeneration, !extensionContexts.isEmpty)
}
// Multiple calls to currentDelegate (through waitpid(..., W_NOHANG) cost us memory and time.
var cachedDelegate: SceneDelegate? = nil

var currentDelegate: SceneDelegate? {
    // Intent sessions have no window. Without this, the fallback below would give them the first terminal window,
    // so that pickFolder from Execute Long Command waited for a document picker in that window.
    if runningInExtension { return nil }
    let opaquePointer = OpaquePointer(ios_getContext())
    if let stringPointer = UnsafeMutablePointer<CChar>(opaquePointer) {
        let currentSessionIdentifier = String(cString: stringPointer)
        if (cachedDelegate?.persistentIdentifier == currentSessionIdentifier) {
            return cachedDelegate
        }
        for scene in UIApplication.shared.connectedScenes {
            if (scene.session.persistentIdentifier == currentSessionIdentifier) {
                if let delegate: SceneDelegate = scene.delegate as? SceneDelegate {
                    cachedDelegate = delegate
                    return delegate
                }
            }
        }
    }
    // We haven't found a delegate so far, or opaquePointer was nil, so let's take the first scene:
    // TODO: that's a bad sign, the sessionIndentifier should be the correct one.
    // related to when a window is created, then closed
    if (UIApplication.shared.connectedScenes.count > 0) {
        if let scene = UIApplication.shared.connectedScenes.first {
            if let delegate: SceneDelegate = scene.delegate as? SceneDelegate {
                cachedDelegate = delegate
                return delegate
            }
        }
    }
    return nil
}


@_cdecl("history")
public func history(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    if let delegate = currentDelegate {
        delegate.printHistory()
    }
    return 0
}

@_cdecl("clear")
public func clear(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    if let delegate = currentDelegate {
        delegate.clearScreen()
    }
    return 0
}

@_cdecl("isForeground")
public func isForeground(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    let opaquePointer = OpaquePointer(ios_getContext())
    guard let stringPointer = UnsafeMutablePointer<CChar>(opaquePointer) else { return 0 }
    let currentSessionIdentifier = String(cString: stringPointer)
    for scene in UIApplication.shared.connectedScenes {
        if (scene.session.persistentIdentifier == currentSessionIdentifier) {
            // dash expects 0 for success, 1 for failure
            return (scene.activationState == .foregroundActive) ? 0 : 1
        }
    }
    return 1
}

@_cdecl("wasm")
public func wasm(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    if (runningInExtension) {
        if #available(iOS 18.0, *) {
            fputs("Apple webAssembly is not available \"In Extension\". Try \"wasmkit\".\n", thread_stderr)
        } else {
            fputs("Apple webAssembly is not available \"In Extension\". Try \"wasm3\".\n", thread_stderr)
        }
        finishedPreparingWebAssemblyCommand()
        return -1
    } else {
        let args = convertCArguments(argc: argc, argv: argv)
        if let delegate = currentDelegate {
            return delegate.executeWebAssembly(arguments: args)
        }
        return 0
    }
}

@_cdecl("executeWebAssemblyCommands")
public func executeWebAssemblyCommands() {
    if let delegate = currentDelegate {
        return delegate.executeWebAssemblyCommands()
    }
}

@_cdecl("jsc_internal")
public func jsc(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    if (runningInExtension) {
        // If running "in extension" or "in the background", execute JS using JavaScriptCore
        // This reliably works, but it's slower:
        return jsc_core(argc: argc, argv: argv)
    } else {
        // Inside the main app, use WkWebView:evaluateJavaScript (faster)
        let args = convertCArguments(argc: argc, argv: argv)
        if let delegate = currentDelegate {
            delegate.executeJavascript(arguments: args)
        }
    }
    return 0
}

@_cdecl("help")
public func help(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    if let delegate = currentDelegate {
        let helpText = """
a-Shell is a terminal emulator for iOS, with many Unix commands: ls, pwd, tar, mkdir, grep....

a-Shell can do most of the things you can do in a terminal, locally on your iPhone or iPad. You can redirect command output to a file with ">" (append with ">>") and you can pipe commands with "|".

- customize appearance with config
- pickFolder: open, bookmark and access a directory anywhere (another app, iCloud, WorkingCopy, file providers...)
- photos: export accessible Photos originals to a read-only cache in ~/Documents/Photos
- newWindow: open a new window
- exit: close the current window

- All your files, including configuration files (.bashrc, .profile, .ssh/...) are in ~/Documents/
- Files created by Shortcuts are in ~shortcuts/
- a-Shell executes the ~/Documents/.profile and ~/Documents/.bashrc files for each new window

- single-finger swipe scrolls the terminal and selects text, two-fingers swipe sends arrows.

- Edit files with vim and pico.
- Transfer files with curl, tar, scp and sftp.
- Clone repositories and do version control with lg2 (similar to git)
- Install more commands with "pkg"
- Process files with python3, lua, jsc, clang, pdflatex, lualatex.
- Open files in other apps with open, play sound and video with play, preview with view.
- For network queries: nslookup, ping, host, whois, ifconfig...

"""
        
        if (argc == 1) {
            delegate.printText(string: helpText)
            let zshmarks = UserDefaults.standard.bool(forKey: "zshmarks")
            let bashmarks = UserDefaults.standard.bool(forKey: "bashmarks")
            if (zshmarks && bashmarks) {
                delegate.printText(string: "\n- bookmark the current directory with \"bookmark <name>\" or \"s <name>\", and access it later with \"cd ~name\", \"jump <name>\" or \"g <name>\".\n- showmarks, l or p: show current list of bookmarks\n- renamemark or r, deletemark or d: change list of bookmarks\n")
            } else if (zshmarks) {
                delegate.printText(string: "\n- bookmark the current directory with \"bookmark <name>\" and access it later with \"cd ~name\" or \"jump <name>\".\n- showmarks: show current list of bookmarks\n- renamemark, deletemark: change list of bookmarks\n")
            } else if (bashmarks) {
                delegate.printText(string: "\n- bookmark the current directory with \"s <name>\", and access it later with \"cd ~name\" or \"g <name>\".\n- l or p: show current list of bookmarks\n- r <name1> <name2>: rename a bookmark.\n- d <name>: delete a bookmark\n")
            }
            delegate.printText(string: "\nUser guide: https://bianshen00009.gitbook.io/a-guide-to-a-shell/")
            delegate.printText(string: "\nSupport: e-mail (another_shell@icloud.com), Bluesky (@a-shell-ios.bsky.social‬), github (https://github.com/holzschu/a-shell/issues) and Discord (https://discord.gg/cvYnZm69Gy).\n")
            delegate.printText(string: "\nFor a full list of commands, type help -l\n")
        } else {
            guard let argV = argv?[1] else {
                delegate.printText(string: helpText)
                return 0
            }
            let arg = String(cString: argV)
            if (arg == "-l") {
                if (ios_isatty(STDOUT_FILENO) == 1) {
                    for command in delegate.commandsArray() {
                        delegate.printText(string: command + ", ")
                    }
                    delegate.printText(string: "\n")
                } else {
                    // stdout is not a tty, so redirecting the output. Probably through grep.
                    // Be nice and present something that can be grepped
                    for command in delegate.commandsArray() {
                        delegate.printText(string: command + "\n")
                    }
                }
                return 0
            }
            delegate.printText(string: "Usage: help [-l]\n")
        }
    }
    return 0
}

@_cdecl("credits")
public func credits(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    if let delegate = currentDelegate {
        let creditText = """
a-Shell owes to many open-source contributors. The current code contains contributions from: Yury Korolev, Ian McDowell, Louis d'Hauwe, Anders Borum, Adrian Labbé, Kenta Kubo, Ian Willis, Henry Heino, Demian Romanenko and suggestions for improvements from many others.

Most terminal commands are from the BSD distribution, mainly through the Apple OpenSource program.

bc: Gavin Howard BSD port of bc, https://github.com/gavinhoward/bc
curl: Daniel Stenberg and contributors, https://github.com/curl/curl
ctags: https://github.com/universal-ctags/ctags/
dash: Almquist Shell, ported by Herbert Xu: http://gondor.apana.org.au/~herbert/dash/
file: https://github.com/file/file/
jsi: Henry Heino, https://github.com/personalizedrefrigerator
ImageMagick: ImageMagick Studio LLC, https://imagemagick.org
libgit2: https://libgit2.org 
Lua: lua.org, PUC-Rio, https://www.lua.org/
LuaTeX: The LuaTeX team, http://www.luatex.org
llvm/clang: the LLVM foundation
make: bmake, http://www.crufty.net/help/sjg/bmake.html
multiMarkdown: Fletcher Penney, https://fletcherpenney.net/multimarkdown/
markdown-it.js: https://github.com/markdown-it/markdown-it
openSSL and libSSH2: port by Yury Korolev, https://github.com/blinksh/libssh2-apple
Perl: Larry Wall, http://www.perl.org/, type perldoc perlintro
Python3: Python Software Foundation, https://www.python.org/about/
ssh, scp, sftp: OpenSSH, https://www.openssh.com
tar: https://libarchive.org
tree: http://mama.indstate.edu/users/ice/tree/
TeX: Donald Knuth and TUG, https://tug.org. TeX distribution is texlive 2026.
Vim: Bram Moolenaar and the Vim community, https://www.vim.org
Vim-session: Peter Odding, http://peterodding.com/code/vim/session
webAssembly: wasmer.io and the wasi SDK https://github.com/WebAssembly/wasi-sdk

zshmarks-style bookmarks inspired by zshmarks: https://github.com/jocelynmallon/zshmarks
bashmarks-style bookmarks inspired by bashmarks: https://github.com/huyng/bashmarks

"""
        delegate.printText(string: creditText)
    }
    return 0
}


@_cdecl("pickFolder")
public func pickFolder(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    if let delegate = currentDelegate {
        delegate.resignFirstResponder()
        delegate.pickFolder()
    }
    return 0
}


func colorFromArgument(arg: [String], position: Int) -> UIColor? {
    if !(position + 3 < arg.count) { return nil }
    let red = arg[position + 1]
    let green = arg[position + 2 ]
    let blue = arg[position + 3]
    if (red.hasPrefix("-") || green.hasPrefix("-") || blue.hasPrefix("-") ) { return nil }
    
    if let redF = Float(red), let greenF = Float(green), let blueF = Float(blue) {
        return UIColor(red: CGFloat(redF), green: CGFloat(greenF), blue: CGFloat(blueF), alpha: 1.0)
    }
    return nil
}

@_cdecl("config")
public func config(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    // Configuration: setting font, font size, BG color, FG color...
    for error in TerminalFonts.refresh() { fputs(error + "\n", thread_stderr) }
    currentDelegate?.writeConfigWindow()
    // First, let's scan the arguments:
    var selectedPrompt: String?
    var selectedTheme: (String, TerminalTheme?)?
    var restoreSavedTheme = false
    var showSettings = false
    var terminalFontSize: Float?
    var terminalFontName: String?
    var terminalBackgroundColor: UIColor?
    var terminalForegroundColor: UIColor?
    var terminalCursorColor: UIColor?
    var terminalCursorShape: String?
    var terminalFontLigature: String?
    let shortUsage = "usage: config [-s font size][-n font name][-b background color][-f foreground color][-c cursor color][-dgpr][--theme [name]][--prompt [name]][--show]\n"
    let usageString = """
    usage: config [-s font size][-n font name][-b background color][-f foreground color][-c cursor color][-g][-p][-d][-r][--theme [name]][--prompt [name]][--show]
    For all parameters: "default" to get the default value currently stored, "factory" to get a-Shell factory defaults (\(factoryFontName), \(factoryFontSize) pts, colors from system).
    Colors can be defined by names, RGB triplets "red green blue" or HexStrings "#00FF00"
    -s | --size: set font size
    -n | --name: set a font name or a file name from Documents/Fonts. Nothing or "picker" opens the font picker.
    --fonts: refresh Documents/Fonts (.ttf/.otf) and list available face names
    Font and size changes with -g also save the selection in Settings.
    -b | --background: set background color
    -f | --foreground: set foreground color
    -c | --cursor: set cursor and highlight color
    -k | --cursorShape: set cursor shape (beam, block or underline, steady or blinking)
    -l | --ligatures: normal, contextual, none...
    -t | --toolbar: create a configuration file to change the toolbar
    -g | --global: extend settings to all windows currently open; with --theme or --prompt, also save the selection
    -p | --permanent: store settings as default values
    -d | --default: reset all settings to default values
    -r | --reset: reset all settings to factory default
    --theme [name]: list themes, or select a bundled preset or ~/Documents/Themes/name.json
    Custom themes: put name.json in Documents/Themes; config --theme lists them.
    config --theme name -g applies and saves; Settings shows Custom file and its name.
    Theme names accept an optional .json extension and ignore case.
    --theme factory: use system colors and the default ANSI palette
    --theme default: restore the saved theme and color overrides without changing font settings
    --prompt [name]: list prompt presets, or select one for this window
    --prompt custom: use PS1 unchanged (including a PS1 set in .profile)
    --prompt default: use the prompt saved in Settings; -g applies it to all windows
    Presets use the theme ANSI palette and take precedence over PS1 until Custom is selected.
    --show: show current settings and the selected ANSI palette
    Sample uses:
    config -p: make settings for current window the default for future windows.
    config -dgp: revert all open and future windows to stored default.
    config -b 0 0 0 -f #00ff00: get a green-on-black VT100 look.
    
    """

    guard let args = convertCArguments(argc: argc, argv: argv) else { return 1 }
    if args.count == 1 {
        fputs(shortUsage, thread_stdout)
        return 0
    }
    var skipNextArgument = 0
    var makePermanent = false
    var makeGlobal = false
    var revertToDefault = false
    var revertToFactory = false
    var argumentsSet = false   // did this command line include an attempt to set arguments (even if it failed)
    let delegate = currentDelegate

    for i in 1..<args.count {
        if (skipNextArgument > 0) {
            skipNextArgument -= 1
            continue
        }
        let arg = args[i]
        if (!arg.hasPrefix("-")) { continue }
        switch (arg) {
        case "-h", "--help":
            fputs(usageString, thread_stdout)
            return 0
        case "--prompt":
            guard i + 1 < args.count, !args[i + 1].hasPrefix("-") else {
                for name in TerminalPrompts.names { fputs(name + "\n", thread_stdout) }
                return 0
            }
            let requested = args[i + 1].lowercased()
            let name = requested == "default" ? TerminalPrompts.savedName : (requested == "factory" ? "custom" : requested)
            guard TerminalPrompts.names.contains(name) else {
                fputs("Unknown prompt: \(requested). Use config --prompt to list presets.\n", thread_stderr)
                return 1
            }
            selectedPrompt = name
            argumentsSet = true
            skipNextArgument = 1
            continue
        case "--theme":
            guard i + 1 < args.count, !args[i + 1].hasPrefix("-") else {
                for name in TerminalThemes.names() { fputs(name + "\n", thread_stdout) }
                return 0
            }
            let requested = args[i + 1]
            restoreSavedTheme = requested == "default"
            let name = requested == "factory" ? nil : (requested == "default" ? TerminalThemes.savedName : requested)
            do {
                selectedTheme = (name ?? "", try name.map { try TerminalThemes.load($0) })
            } catch {
                fputs("Theme \(requested): \(error.localizedDescription)\n", thread_stderr)
                return 1
            }
            argumentsSet = true
            skipNextArgument = 1
            continue
        case "--fonts":
            for name in TerminalFonts.names() { fputs(name + "\n", thread_stdout) }
            return 0
        case "-s", "--size":
            argumentsSet = true
            if (i + 1 < args.count) {
                if !args[i+1].hasPrefix("-") {
                    if let s = Float(args[i+1]), s.isFinite, s > 0 {
                        terminalFontSize = s
                        skipNextArgument = 1
                    } else {
                        if args[i+1] == "default" {
                            if let storedSize = TerminalFonts.savedSize {
                                terminalFontSize = storedSize
                            } else {
                                terminalFontSize = factoryFontSize
                            }
                        } else if args[i+1] == "factory" {
                            terminalFontSize = factoryFontSize
                        } else {
                            fputs("Could not read argument for size: \(args[i+1])\n", thread_stderr)
                        }
                    }
                } else {
                    fputs("Size not defined.\n", thread_stderr)
                    continue
                }
            } else {
                fputs("No parameter for size.\n", thread_stderr)
                return 0
            }
            continue
        case "-n", "--name":
            argumentsSet = true
            var name = "picker"
            if (i + 1 < args.count) {
                if !args[i+1].hasPrefix("-") {
                    name = args[i+1]
                    skipNextArgument = 1
                }
            }
            if (name == "picker") {
                if let newName = delegate?.pickFont() {
                    terminalFontName = newName
                    // NSLog("Name received: \(terminalFontName)")
                }
            } else if name == "default" {
                if let storedName = TerminalFonts.savedName {
                    terminalFontName = storedName
                } else {
                    terminalFontName = factoryFontName
                }
            } else if name == "factory" {
                terminalFontName = factoryFontName
            } else if let font = TerminalFonts.font(named: name, size: 13) {
                terminalFontName = font.fontName
            } else {
                fputs("Could not load font: \(name)\n", thread_stderr)
                return 1
            }
            continue
        case "-b", "--background":
            argumentsSet = true
            var name = ""
            if (i + 1 < args.count) {
                if !args[i+1].hasPrefix("-") {
                    name = args[i+1]
                    skipNextArgument = 1
                } else {
                    fputs("Background color not defined.\n", thread_stderr)
                    continue
                }
            } else {
                fputs("No parameter for background color.\n", thread_stderr)
                continue
            }
            if name == "default" {
                if let storedName = UserDefaults.standard.object(forKey: "backgroundColor") as? String {
                    terminalBackgroundColor = UIColor(hexString: storedName)
                } else {
                    terminalBackgroundColor = .systemBackground
                }
            } else if name == "factory" {
                terminalBackgroundColor = .systemBackground
            } else if let color = colorFromName(name: name) {
                terminalBackgroundColor = color
            } else if let color = colorFromArgument(arg: args, position: i) {
                terminalBackgroundColor = color
                skipNextArgument = 3
            } else {
                fputs("Could not retrieve background color.\n", thread_stderr)
            }
            continue
        case "-f", "--foreground":
            argumentsSet = true
            var name = ""
            if (i + 1 < args.count) {
                if !args[i+1].hasPrefix("-") {
                    name = args[i+1]
                    skipNextArgument = 1
                } else {
                    fputs("Foreground color not defined.\n", thread_stderr)
                    continue
                }
            } else {
                fputs("No parameter for foreground color.\n", thread_stderr)
                continue
            }
            if name == "default" {
                if let storedName = UserDefaults.standard.object(forKey: "foregroundColor") as? String {
                    terminalForegroundColor = UIColor(hexString: storedName)
                } else {
                    terminalForegroundColor = .placeholderText
                }
            } else if name == "factory" {
                terminalForegroundColor = .placeholderText
            } else if let color = colorFromName(name: name) {
                terminalForegroundColor = color
            } else if let color = colorFromArgument(arg: args, position: i) {
                terminalForegroundColor = color
                skipNextArgument = 3
            } else {
                fputs("Could not retrieve foreground color.\n", thread_stderr)
            }
            continue
        case "-c", "--cursor":
            argumentsSet = true
            var name = ""
            if (i + 1 < args.count) {
                if !args[i+1].hasPrefix("-") {
                    name = args[i+1]
                    skipNextArgument = 1
                } else {
                    fputs("Cursor color not defined.\n", thread_stderr)
                    continue
                }
            } else {
                fputs("No parameter for cursor color.\n", thread_stderr)
                continue
            }
            if name == "default" {
                if let storedName = UserDefaults.standard.object(forKey: "cursorColor") as? String {
                    terminalCursorColor = UIColor(hexString: storedName)
                } else {
                    terminalCursorColor = .link
                }
            } else if name == "factory" {
                terminalCursorColor = .link
            } else if let color = colorFromName(name: name) {
                terminalCursorColor = color
            } else if let color = colorFromArgument(arg: args, position: i) {
                terminalCursorColor = color
                skipNextArgument = 3
            } else {
                fputs("Could not retrieve cursor color.\n", thread_stderr)
            }
            continue
        case "-k", "--cursorShape":
            argumentsSet = true
            var name = ""
            if (i + 1 < args.count) {
                if !args[i+1].hasPrefix("-") {
                    name = args[i+1]
                    skipNextArgument = 1
                } else {
                    fputs("Cursor shape not defined.\n", thread_stderr)
                    continue
                }
            }
            if (name == "") {
                fputs("No parameter for cursor shape.\n", thread_stderr)
                continue
            } else if name == "default" {
                if let storedName = UserDefaults.standard.object(forKey: "cursorShape") as? String {
                    terminalCursorShape = storedName
                } else {
                    terminalCursorShape = factoryCursorShape
                }
            } else if name == "factory" {
                terminalCursorShape = factoryCursorShape
            } else {
                name = name.lowercased()
                if (name == "bar") || (name == "beam") || (name == "underline") || (name == "block") ||
                    (name == "blinking-bar") || (name == "blinking-beam") || (name == "blinking-underline") || (name == "blinking-block") {
                    terminalCursorShape = name
                } else {
                    fputs("Did not understand cursor shape: \(name) (possible names are bar, beam, block, underline, blinking-bar, blinking-beam, blinking-block and blinking-underline)\n", thread_stderr)
                }
            }
            continue
        case "-l", "--ligatures":
            argumentsSet = true
            var name = ""
            if (i + 1 < args.count) {
                if !args[i+1].hasPrefix("-") {
                    name = args[i+1]
                    skipNextArgument = 1
                } else {
                    fputs("Font ligature not defined.\n", thread_stderr)
                    continue
                }
            }
            if (name == "") {
                fputs("No parameter for font ligature.\n", thread_stderr)
                continue
            } else if name == "default" {
                if let storedName = UserDefaults.standard.object(forKey: "fontLigature") as? String {
                    terminalFontLigature = storedName
                } else {
                    terminalFontLigature = factoryFontLigature
                }
            } else if name == "factory" {
                terminalFontLigature = factoryFontLigature
            } else {
                terminalFontLigature = name.lowercased()
            }
            continue
        case "-t", "--toolbar":
            var configFile = Bundle.main.resourceURL?.appendingPathComponent("defaultToolbar.txt")
            if (UIDevice.current.model.hasPrefix("iPad") || UIAccessibility.isVoiceOverRunning) {
                configFile = Bundle.main.resourceURL?.appendingPathComponent("defaultToolbar_iPad.txt")
            }
            do {
                let documentsUrl = try FileManager().url(for: .documentDirectory,
                                                         in: .userDomainMask,
                                                         appropriateFor: nil,
                                                         create: true)
                let localConfigFile = documentsUrl.appendingPathComponent(".toolbarDefinition")
                if FileManager().fileExists(atPath: localConfigFile.path) {
                    fputs("The configuration file .toolbarDefinition already exists. Do you want to overwrite it? (y/N)", thread_stderr)
                    fflush(thread_stderr)
                    var byte: Int8 = 0
                    _ = read(fileno(thread_stdin), &byte, 1)
                    if (byte != 121) && (byte != 89) {
                        continue
                    }
                    try FileManager().removeItem(at: localConfigFile)
                }
                try FileManager().copyItem(at: configFile!, to: localConfigFile)
                fputs("I have created a toolbar configuration file: ~/Documents/.toolbarDefinition\nYou can now edit it to add or remove buttons to the toolbar.\nChanges will take effect when the app restarts.\n", thread_stdout)
            }
            catch {
                fputs("An error occured when copying the toolbar configuration file.", thread_stderr)
            }
            continue

        case "--show":
            showSettings = true
            continue
        case "--default":
            revertToDefault = true
            continue
        case "--permanent":
            makePermanent = true
            continue
        case "--global":
            makeGlobal = true
            continue
        case "--reset":
            revertToFactory = true
            continue
        default:
            // -g, -p, -gp, -pg are all valid options
            var string = arg
            string.removeFirst(1)
            let allowedCharacterSet = CharacterSet(charactersIn: "rgpd")
            let characterSet = CharacterSet(charactersIn: string)
            if allowedCharacterSet.isSuperset(of: characterSet) {
                if (string.contains("g")) { makeGlobal = true }
                if (string.contains("p")) { makePermanent = true }
                if (string.contains("d")) { revertToDefault = true }
                if (string.contains("r")) { revertToFactory = true }
            } else {
                fputs("Could not understand argument: \(arg)\n", thread_stderr)
                fputs(shortUsage, thread_stderr)
                return 0
            }
        }
    }
    //
    if (revertToFactory) {
        delegate?.terminalFontSize = factoryFontSize
        delegate?.terminalFontName = factoryFontName
        delegate?.terminalBackgroundColor = nil
        delegate?.terminalForegroundColor = nil
        delegate?.terminalCursorColor = nil
        delegate?.terminalCursorShape = factoryCursorShape
        delegate?.terminalFontLigature = factoryFontLigature
        delegate?.writeConfigWindow()
    } else if (revertToDefault) {
        // "default" = what is stored in User Preferences, if it exists, and factory default otherwise.
        if let storedSize = TerminalFonts.savedSize {
            delegate?.terminalFontSize = storedSize
        } else {
            delegate?.terminalFontSize = factoryFontSize
        }
        if let storedName = TerminalFonts.savedName {
            delegate?.terminalFontName = storedName
        } else {
            delegate?.terminalFontName = factoryFontName
        }
        if let storedName = UserDefaults.standard.object(forKey: "backgroundColor") as? String {
            delegate?.terminalBackgroundColor = UIColor(hexString: storedName)
        } else {
            delegate?.terminalBackgroundColor = nil
        }
        if let storedName = UserDefaults.standard.object(forKey: "foregroundColor") as? String {
            delegate?.terminalForegroundColor = UIColor(hexString: storedName)
        } else {
            delegate?.terminalForegroundColor = nil
        }
        if let storedName = UserDefaults.standard.object(forKey: "cursorColor") as? String {
            delegate?.terminalCursorColor = UIColor(hexString: storedName)
        } else {
            delegate?.terminalCursorColor = nil
        }
        if let storedName = UserDefaults.standard.object(forKey: "cursorShape") as? String {
            delegate?.terminalCursorShape = storedName
        } else {
            delegate?.terminalCursorShape = factoryCursorShape
        }
        if let storedName = UserDefaults.standard.object(forKey: "fontLigature") as? String {
            delegate?.terminalFontLigature = storedName
        } else {
            delegate?.terminalFontLigature = factoryFontLigature
        }
        delegate?.writeConfigWindow()
    } else {
        delegate?.configWindow(fontSize: terminalFontSize, fontName: terminalFontName, backgroundColor: terminalBackgroundColor, foregroundColor: terminalForegroundColor, cursorColor: terminalCursorColor, cursorShape: terminalCursorShape, fontLigature: terminalFontLigature)
    }
    if (makeGlobal) {
        // If nothing except "-p" (and possibly -d or -r): extend current window settings to all open windows
        // Otherwise, go through all delegates, and apply the same change to them:
        if (argumentsSet) {
            for scene in UIApplication.shared.connectedScenes {
                if let delegate: SceneDelegate = scene.delegate as? SceneDelegate {
                    delegate.configWindow(fontSize: terminalFontSize, fontName: terminalFontName, backgroundColor: terminalBackgroundColor, foregroundColor: terminalForegroundColor, cursorColor: terminalCursorColor, cursorShape: terminalCursorShape, fontLigature: terminalFontLigature)
                }
            }
        } else {
            for scene in UIApplication.shared.connectedScenes {
                if let delegate2: SceneDelegate = scene.delegate as? SceneDelegate {
                    if (delegate2 != delegate) {
                        delegate2.configWindow(fontSize: delegate?.terminalFontSize, fontName: delegate?.terminalFontName, backgroundColor: delegate?.terminalBackgroundColor, foregroundColor: delegate?.terminalForegroundColor, cursorColor: delegate?.terminalCursorColor, cursorShape: delegate?.terminalCursorShape, fontLigature: delegate?.terminalFontLigature)
                    }
                }
            }
        }
    }
    if revertToFactory {
        selectedTheme = ("", nil)
    } else if revertToDefault {
        let name = TerminalThemes.savedName
        do {
            selectedTheme = (name ?? "", try name.map { try TerminalThemes.load($0) })
        } catch {
            fputs("Theme \(name ?? ""): \(error.localizedDescription) Using stored or system colors.\n", thread_stderr)
            selectedTheme = ("", nil)
        }
    }
    if let (name, theme) = selectedTheme {
        delegate?.applyTheme(theme, name: name)
        if makeGlobal {
            for scene in UIApplication.shared.connectedScenes {
                (scene.delegate as? SceneDelegate)?.applyTheme(theme, name: name)
            }
        }
    } else if makeGlobal && !argumentsSet, let source = delegate {
        let update = {
            for scene in UIApplication.shared.connectedScenes {
                if let target = scene.delegate as? SceneDelegate, target !== source {
                    target.terminalThemeName = source.terminalThemeName
                    target.terminalTheme = source.terminalTheme
                    target.terminalBackgroundColor = source.terminalBackgroundColor
                    target.terminalForegroundColor = source.terminalForegroundColor
                    target.terminalCursorColor = source.terminalCursorColor
                    target.writeConfigWindow()
                }
            }
        }
        if Thread.isMainThread { update() } else { DispatchQueue.main.async(execute: update) }
    }
    if revertToDefault {
        terminalBackgroundColor = (UserDefaults.standard.string(forKey: "backgroundColor")).map { UIColor(hexString: $0) }
        terminalForegroundColor = (UserDefaults.standard.string(forKey: "foregroundColor")).map { UIColor(hexString: $0) }
        terminalCursorColor = (UserDefaults.standard.string(forKey: "cursorColor")).map { UIColor(hexString: $0) }
    }
    if restoreSavedTheme && !revertToFactory && !revertToDefault {
        terminalBackgroundColor = terminalBackgroundColor ?? UserDefaults.standard.string(forKey: "backgroundColor").map { UIColor(hexString: $0) }
        terminalForegroundColor = terminalForegroundColor ?? UserDefaults.standard.string(forKey: "foregroundColor").map { UIColor(hexString: $0) }
        terminalCursorColor = terminalCursorColor ?? UserDefaults.standard.string(forKey: "cursorColor").map { UIColor(hexString: $0) }
    }
    if selectedTheme != nil && !revertToFactory {
        var targets = makeGlobal ? UIApplication.shared.connectedScenes.compactMap { $0.delegate as? SceneDelegate } : []
        if !makeGlobal, let delegate = delegate { targets = [delegate] }
        for target in targets {
            target.configWindow(fontSize: nil, fontName: nil, backgroundColor: terminalBackgroundColor, foregroundColor: terminalForegroundColor, cursorColor: terminalCursorColor, cursorShape: nil, fontLigature: nil)
        }
    }
    if revertToFactory { selectedPrompt = "custom" }
    else if revertToDefault { selectedPrompt = TerminalPrompts.savedName }
    if let name = selectedPrompt {
        delegate?.applyPrompt(name)
        if makeGlobal {
            for scene in UIApplication.shared.connectedScenes {
                (scene.delegate as? SceneDelegate)?.applyPrompt(name)
            }
        }
    } else if makeGlobal && !argumentsSet, let source = delegate {
        for scene in UIApplication.shared.connectedScenes {
            (scene.delegate as? SceneDelegate)?.applyPrompt(source.terminalPromptName)
        }
    }
    if (makePermanent && (!argumentsSet || selectedPrompt != nil)) || (makeGlobal && selectedPrompt != nil && !revertToDefault && !revertToFactory) {
        let name = delegate?.terminalPromptName ?? "custom"
        let savePrompt = {
            TerminalPrompts.save(name)
        }
        if Thread.isMainThread { savePrompt() } else { DispatchQueue.main.sync(execute: savePrompt) }
    }
    if !Thread.isMainThread { DispatchQueue.main.sync {} }
    if showSettings { delegate?.showConfigWindow() }
    if (makePermanent && (!argumentsSet || selectedTheme != nil)) || (makeGlobal && selectedTheme != nil && !revertToDefault && !revertToFactory && !restoreSavedTheme) {
        let name = delegate?.terminalThemeName ?? ""
        let saveTheme = {
            TerminalThemes.save(name)
        }
        if Thread.isMainThread { saveTheme() } else { DispatchQueue.main.sync(execute: saveTheme) }
        if selectedTheme != nil {
            for key in ["backgroundColor", "foregroundColor", "cursorColor"] {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }
    if makeGlobal && (terminalFontName != nil || terminalFontSize != nil) {
        let save = { TerminalFonts.save(name: terminalFontName, size: terminalFontSize) }
        if Thread.isMainThread { save() } else { DispatchQueue.main.sync(execute: save) }
    }
    if makePermanent {
        // Store these settings
        // If nothing except "-p" (and possibly -d or -r): make current window settings permanent
        // Otherwise, take settings from current window and make them permanent
        if (!argumentsSet) {
            terminalFontSize = delegate?.terminalFontSize
            terminalFontName = delegate?.terminalFontName
            let colors = delegate?.themeColorOverrides()
            terminalBackgroundColor = colors?.background
            terminalForegroundColor = colors?.foreground
            terminalCursorColor = colors?.cursor
            terminalCursorShape = delegate?.terminalCursorShape
            terminalFontLigature = delegate?.terminalFontLigature
            if terminalFontSize == nil {
                UserDefaults.standard.removeObject(forKey: "fontSize")
            }
            if terminalFontName == nil {
                UserDefaults.standard.removeObject(forKey: "fontName")
            }
            if terminalBackgroundColor == nil {
                UserDefaults.standard.removeObject(forKey: "backgroundColor")
            }
            if terminalForegroundColor == nil {
                UserDefaults.standard.removeObject(forKey: "foregroundColor")
            }
            if terminalCursorColor == nil {
                UserDefaults.standard.removeObject(forKey: "cursorColor")
            }
            if terminalCursorShape == nil {
                UserDefaults.standard.removeObject(forKey: "cursorShape")
            }
            if terminalFontLigature == nil {
                UserDefaults.standard.removeObject(forKey: "fontLigature")
            }
        }
        if terminalFontName != nil || terminalFontSize != nil {
            let save = { TerminalFonts.save(name: terminalFontName, size: terminalFontSize) }
            if Thread.isMainThread { save() } else { DispatchQueue.main.sync(execute: save) }
        }
        if terminalBackgroundColor != nil && terminalBackgroundColor != .systemBackground {
            UserDefaults.standard.set(terminalBackgroundColor?.toHexString(), forKey: "backgroundColor")
        }
        if terminalForegroundColor != nil && terminalForegroundColor != .placeholderText {
            UserDefaults.standard.set(terminalForegroundColor?.toHexString(), forKey: "foregroundColor")
        }
        if terminalCursorColor != nil && terminalCursorColor != .link {
            UserDefaults.standard.set(terminalCursorColor?.toHexString(), forKey: "cursorColor")
        }
        if terminalCursorShape != nil {
            UserDefaults.standard.set(terminalCursorShape, forKey: "cursorShape")
        }
        if terminalFontLigature != nil {
            UserDefaults.standard.set(terminalFontLigature, forKey: "fontLigature")
        }
    }
    return 0
}

@_cdecl("keepDirectoryAfterShortcut")
public func keepDirectoryAfterShortcut(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    if let delegate = currentDelegate {
        delegate.keepDirectoryAfterShortcut()
    }
    return 0
}

// Q: Should I move this to ios_system? Implies also having storeBookmark() in ios_system.
@_cdecl("showmarks")
public func listBookmarks(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    // List the bookmark already stored:
    guard let commandNameC = argv?[0] else {
        fputs("showmarks: Can't read command name\n", thread_stderr)
        return 0
    }
    let commandName = String(cString: commandNameC)
    let usage = "Usage: " + commandName + " (show all bookmarks) \n" + commandName + " shortName (show bookmark for shortName)\n"
    // let groupNamesDictionary = UserDefaults(suiteName: appGroupID)?.dictionary(forKey: "bookmarkNames")
    let storedNamesDictionary = UserDefaults.standard.dictionary(forKey: "bookmarkNames") ?? [:]
    // if (groupNamesDictionary != nil) {
    //    storedNamesDictionary.merge(groupNamesDictionary!, uniquingKeysWith: { (current, _) in current })
    // }
    // Update the bookmarks whose directory moved, remove those that are no longer valid:
    checkBookmarks()
    let namesDictionary = UserDefaults.standard.dictionary(forKey: "bookmarkNames") ?? [:]
    if (argc == 1) {
        // show all bookmarks
        for key in namesDictionary.keys.sorted() {
            fputs("~" + key + ": " + (namesDictionary[key] as! String) + "\n", thread_stdout);
        }
    } else {
        // show bookmarks corresponding to arguments
        for i in 1..<Int(argc) {
            guard let argC = argv?[i] else {
                return 0
            }
            let key = String(cString: argC)
            if let urlPath = namesDictionary[key] {
                fputs("~" + key + ": " + (urlPath as! String) + "\n", thread_stdout);
            } else if (storedNamesDictionary[key] != nil) {
                fputs("\(key): not found (directory removed)", thread_stderr)
            } else {
                fputs("\(key): not found", thread_stderr)
                if (i == 1) { fputs(usage, thread_stderr) }
            }
        }
    }
    return 0
}

// Returns true if the directory a bookmark resolves to can be read, starting access to it if needed.
func canAccessBookmarkedURL(_ bookmarkedUrl: URL) -> Bool {
    if (!FileManager().isReadableFile(atPath:bookmarkedUrl.path)) {
        let isSecuredURL = bookmarkedUrl.startAccessingSecurityScopedResource()
        let isReadable = FileManager().isReadableFile(atPath: bookmarkedUrl.path)
        if (!(isSecuredURL && isReadable)) {
            NSLog("Access to \(bookmarkedUrl): isSecuredURL: \(isSecuredURL) isReadable: \(isReadable)")
            return false
        }
    }
    return true
}

// The bookmark stored for path resolves to bookmarkedUrl, which is reachable. If it is at another path
// (e.g. the app that owns it got a new container), or the bookmark data is stale, then, as Apple recommends,
// store a new bookmark, and point the names (and names of subdirectories) to the new path.
// storedNames and storedBookmarks are the dictionaries before any change, names and bookmarks the updated ones.
// Returns the path the bookmark is now stored under.
@discardableResult
func refreshBookmark(path: String, bookmark: Data, bookmarkedUrl: URL, stale: Bool,
                     storedNames: [String:Any], storedBookmarks: [String:Any],
                     names: inout [String:Any], bookmarks: inout [String:Any], healedPaths: inout Set<String>) -> String {
    let moved = !bookmarkedUrl.sameFileLocation(path: path)
    if (!stale && !moved) {
        return path
    }
    let newPath = moved ? bookmarkedUrl.path : path
    NSLog("Bookmark for \(path) resolves to \(bookmarkedUrl.path), stale: \(stale)")
    let newBookmark = try? bookmarkedUrl.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
    if (!healedPaths.contains(path)) {
        bookmarks.removeValue(forKey: path)
    }
    bookmarks[newPath] = newBookmark ?? bookmark
    healedPaths.insert(newPath)
    if (moved) {
        // iOS sometimes adds "/private" in front of paths, compare without it:
        let withoutPrivate = { (p: String) -> String in p.hasPrefix("/private/") ? String(p.dropFirst("/private".count)) : p }
        let oldPath = withoutPrivate(path)
        // compare with the stored names, not the ones already healed in this pass:
        for (name, value) in storedNames where names[name] != nil {
            if let namePath = value as? String {
                let shortPath = withoutPrivate(namePath)
                if (shortPath == oldPath) {
                    names[name] = newPath
                } else if (shortPath.hasPrefix(oldPath + "/") && storedBookmarks[namePath] == nil) {
                    names[name] = newPath + String(shortPath.dropFirst(oldPath.count))
                }
            }
        }
    }
    return newPath
}

public func checkBookmarks() {
    // At startup, go through list of bookmarks, check that they are still valid, remove them otherwise
    // and add "home", "shortcuts" and "group".
    let storedNamesDictionary = UserDefaults.standard.dictionary(forKey: "bookmarkNames") ?? [:]
    // let groupNamesDictionary = UserDefaults(suiteName: appGroupID)?.dictionary(forKey: "bookmarkNames")
    // if (groupNamesDictionary != nil) {
    //     storedNamesDictionary.merge(groupNamesDictionary!, uniquingKeysWith: { (current, _) in current })
    // }
    let storedBookmarksDictionary = UserDefaults.standard.dictionary(forKey: "fileBookmarks") ?? [:]
    // let groupBookmarksDictionary = UserDefaults(suiteName: appGroupID)?.dictionary(forKey: "fileBookmarks")
    // if (groupBookmarksDictionary != nil) {
    //     storedBookmarksDictionary.merge(groupBookmarksDictionary!, uniquingKeysWith: { (current, _) in current })
    // }
    var mutableBookmarkDictionary : [String:Any] = storedBookmarksDictionary
    var mutableNamesDictionary : [String:Any] = storedNamesDictionary
    var healedPaths = Set<String>()
    
    for (key, urlPath) in storedNamesDictionary {
        let path = (urlPath as! String)
        if let bookmark = storedBookmarksDictionary[path] {
            var stale = false
            var invalid = false
            do {
                let bookmarkedUrl = try URL(resolvingBookmarkData: bookmark as! Data, bookmarkDataIsStale: &stale)
                if (!canAccessBookmarkedURL(bookmarkedUrl)) {
                    invalid = true
                }
                if (!invalid) {
                    refreshBookmark(path: path, bookmark: bookmark as! Data, bookmarkedUrl: bookmarkedUrl, stale: stale,
                                    storedNames: storedNamesDictionary, storedBookmarks: storedBookmarksDictionary,
                                    names: &mutableNamesDictionary, bookmarks: &mutableBookmarkDictionary, healedPaths: &healedPaths)
                }
            }
            catch {
                NSLog("Could not resolve \(key)")
                invalid = true
            }
            if (invalid) {
                // remove the bookmark from both dictionaries (unless another name healed into this path):
                if (!healedPaths.contains(path)) {
                    mutableBookmarkDictionary.removeValue(forKey: path)
                }
                mutableNamesDictionary.removeValue(forKey: key)
            }
        }
    }
    let documentsUrl = try! FileManager().url(for: .documentDirectory,
                                              in: .userDomainMask,
                                              appropriateFor: nil,
                                              create: true)
    let homeUrl = documentsUrl.deletingLastPathComponent()
    let storedHome = mutableNamesDictionary["home"] as? String
    if (storedHome == nil) || (storedHome != homeUrl.path) {
        mutableNamesDictionary["home"] = homeUrl.path
    }
    let storedHome2 = mutableNamesDictionary[""] as? String
    if (storedHome2 == nil) || (storedHome2 != homeUrl.path) {
        mutableNamesDictionary[""] = homeUrl.path
    }
    let storedShortcuts = mutableNamesDictionary["shortcuts"] as? String
    let shortcutsPath = FileManager().containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?.path
    if (storedShortcuts == nil) || (storedShortcuts != shortcutsPath) {
        mutableNamesDictionary["shortcuts"] = shortcutsPath
    }
    let storedGroup = mutableNamesDictionary["group"] as? String
    if (storedGroup == nil) || (storedGroup != shortcutsPath) {
        mutableNamesDictionary["group"] = shortcutsPath
    }
    if let iCloudUrl = FileManager().url(forUbiquityContainerIdentifier: nil) {
        let storedCloud = mutableNamesDictionary["cloud"] as? String
        if (storedCloud == nil) || (storedCloud != iCloudUrl.appendingPathComponent("Documents").path) {
            mutableNamesDictionary["cloud"] = iCloudUrl.appendingPathComponent("Documents").path
        }
        let storediCloud = mutableNamesDictionary["iCloud"] as? String
        if (storediCloud == nil) || (storediCloud != iCloudUrl.appendingPathComponent("Documents").path) {
            mutableNamesDictionary["iCloud"] = iCloudUrl.appendingPathComponent("Documents").path
        }
    }
    UserDefaults.standard.set(mutableBookmarkDictionary, forKey: "fileBookmarks")
    UserDefaults.standard.set(mutableNamesDictionary, forKey: "bookmarkNames")
    UserDefaults(suiteName: appGroupID)?.set(mutableBookmarkDictionary, forKey: "fileBookmarks")
    UserDefaults(suiteName: appGroupID)?.set(mutableNamesDictionary, forKey: "bookmarkNames")
}

@_cdecl("renamemark")
public func renamemark(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    // rename a specific bookmark
    guard let commandNameC = argv?[0] else {
        fputs("renamemark: Can't read command name\n", thread_stderr)
        return 0
    }
    let commandName = String(cString: commandNameC)
    let usage = "Usage: " + commandName + " oldName newName\n"
    let storedNamesDictionary = UserDefaults.standard.dictionary(forKey: "bookmarkNames") ?? [:]
    // let groupNamesDictionary = UserDefaults(suiteName: appGroupID)?.dictionary(forKey: "bookmarkNames")
    // if (groupNamesDictionary != nil) {
    //     storedNamesDictionary.merge(groupNamesDictionary!, uniquingKeysWith: { (current, _) in current })
    // }
    var mutableNamesDictionary : [String:Any] = storedNamesDictionary
    if (argc != 3) {
        fputs(usage, thread_stderr)
        return 0
    }
    guard let oldKeyC = argv?[1] else {
        fputs("renamemark: Can't read old name\n", thread_stderr)
        return 0
    }
    guard let newKeyC = argv?[2] else {
        fputs("renamemark: Can't read new name\n", thread_stderr)
        return 0
    }
    let oldKey = String(cString: oldKeyC)
    let urlPath = storedNamesDictionary[oldKey]
    mutableNamesDictionary.removeValue(forKey: oldKey)
    let newKey = String(cString: newKeyC)
    mutableNamesDictionary[newKey] = urlPath
    
    UserDefaults.standard.set(mutableNamesDictionary, forKey: "bookmarkNames")
    UserDefaults(suiteName: appGroupID)?.set(mutableNamesDictionary, forKey: "bookmarkNames")
   return 0
}

@_cdecl("bookmark")
public func bookmark(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32  {
    // create a bookmark for current directory
    guard let commandNameC = argv?[0] else {
        fputs("bookmark: Can't read command name\n", thread_stderr)
        return 0
    }
    let commandName = String(cString: commandNameC)
    let usage = "Usage: " + commandName + " [name]\n"
    if (argc > 2) {
        fputs(usage, thread_stderr)
        return 0
    }
    if let firstArgC = argv?[1] {
        if (String(cString: firstArgC).hasPrefix("-h")) {
            fputs(usage, thread_stderr)
            return 0
        }
    }
    var name = ""
    let filePath = FileManager().currentDirectoryPath
    let fileURL = URL(fileURLWithPath: filePath)
    if (argc == 2) {
        guard let nameC = argv?[1] else {
            fputs("bookmark: Can't read new name\n", thread_stderr)
            fputs(usage, thread_stderr)
            return 0
        }
        name = String(cString: nameC)
    } else {
        name = fileURL.lastPathComponent
    }
    let storedNamesDictionary = UserDefaults.standard.dictionary(forKey: "bookmarkNames") ?? [:]
    // let groupNamesDictionary = UserDefaults(suiteName: appGroupID)?.dictionary(forKey: "bookmarkNames")
    // if (groupNamesDictionary != nil) {
    //     storedNamesDictionary.merge(groupNamesDictionary!, uniquingKeysWith: { (current, _) in current })
    // }
    var mutableNamesDictionary : [String:Any] = storedNamesDictionary
    // Does "name" alrady exist? If so create a unique name:
    var newName = name
    var counter = 0
    var existingURLPath = mutableNamesDictionary[newName]
    while (existingURLPath != nil) {
        let existingPath = existingURLPath as! String
        // the name already exists
        NSLog("Name \(newName) already exists.")
        if (fileURL.sameFileLocation(path: existingPath)) {
            fputs("Already bookmarked as \(newName).\n", thread_stderr)
            return 0 // it's already there, don't store
        }
        counter += 1;
        newName = name + "_" + "\(counter)"
        existingURLPath = mutableNamesDictionary[newName]
    }
    mutableNamesDictionary.updateValue(filePath, forKey: newName)
    UserDefaults.standard.set(mutableNamesDictionary, forKey: "bookmarkNames")
    UserDefaults(suiteName: appGroupID)?.set(mutableNamesDictionary, forKey: "bookmarkNames")
    fputs("Bookmarked as \(newName).\n", thread_stderr)
    return 0
}

@_cdecl("deletemark")
public func deletemark(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    // delete a specific bookmark.
    // Possible improvement: also delete the permission bookmark
    guard let commandNameC = argv?[0] else {
        fputs("deletemark: Can't read command name\n", thread_stderr)
        return 0
    }
    let commandName = String(cString: commandNameC)
    let usage = "Usage: " + commandName + " name [name1 name2 name3...] or " + commandName + " --all\n"
    let storedNamesDictionary = UserDefaults.standard.dictionary(forKey: "bookmarkNames") ?? [:]
    // let groupNamesDictionary = UserDefaults(suiteName: appGroupID)?.dictionary(forKey: "bookmarkNames")
    // if (groupNamesDictionary != nil) {
    //     storedNamesDictionary.merge(groupNamesDictionary!, uniquingKeysWith: { (current, _) in current })
    // }
    var mutableNamesDictionary : [String:Any] = storedNamesDictionary

    var mustUpdateDictionary = false
    if (argc < 2) {
        fputs(usage, thread_stderr)
        return 0
    }
    guard let firstArgC = argv?[1] else {
        return 0
    }
    if (String(cString: firstArgC).hasPrefix("-h")) {
        fputs(usage, thread_stderr)
        return 0
    }
    if (String(cString: firstArgC) == "--all") {
        // delete all bookmarks (except system bookmarks):
        // home, shortcuts, cloud, iCloud, group
        mustUpdateDictionary = true
        mutableNamesDictionary.removeAll()
        let documentsUrl = try! FileManager().url(for: .documentDirectory,
                                                  in: .userDomainMask,
                                                  appropriateFor: nil,
                                                  create: true)
        let homeUrl = documentsUrl.deletingLastPathComponent()
        mutableNamesDictionary["home"] = homeUrl.path
        let shortcutsPath = FileManager().containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?.path
        mutableNamesDictionary["shortcuts"] = shortcutsPath
        mutableNamesDictionary["group"] = shortcutsPath
        if let iCloudUrl = FileManager().url(forUbiquityContainerIdentifier: nil) {
            mutableNamesDictionary["cloud"] = iCloudUrl.appendingPathComponent("Documents").path
            mutableNamesDictionary["iCloud"] = iCloudUrl.appendingPathComponent("Documents").path
        }
    } else {
        for i in 1..<Int(argc) {
            guard let argC = argv?[i] else {
                return 0
            }
            let key = String(cString: argC)
            let result = mutableNamesDictionary.removeValue(forKey: key)
            if (result == nil) {
                fputs("deletemark: \(key) not found\n", thread_stderr)
                if (i == 1) {
                    fputs(usage, thread_stderr)
                }
            } else {
                mustUpdateDictionary = true
            }
        }
    }
    if (mustUpdateDictionary) {
        UserDefaults.standard.set(mutableNamesDictionary, forKey: "bookmarkNames")
        UserDefaults(suiteName: appGroupID)?.set(mutableNamesDictionary, forKey: "bookmarkNames")
    }
    return 0
}

@discardableResult
func downloadRemoteFileFromCloud(fileURL: URL, waitForDownload: Bool = true, reportErrors: Bool = false) -> Bool {
    var target = fileURL
    let name = fileURL.lastPathComponent
    // Strip only the placeholder wrapper, preserving dots in the original name.
    if name.count > 8 && name.hasPrefix(".") && name.hasSuffix(".icloud") {
        target = fileURL.deletingLastPathComponent().appendingPathComponent(String(name.dropFirst().dropLast(7)))
    }
    do {
        let manager = FileManager.default
        let values = try? target.resourceValues(forKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey])
        if manager.fileExists(atPath: target.path) && values?.isUbiquitousItem != true {
            return true
        }
        if values?.ubiquitousItemDownloadingStatus == .current { return true }
        try manager.startDownloadingUbiquitousItem(at: target)
        if !waitForDownload { return true }
        while true {
            // Ctrl-C uses pthread cancellation for native a-Shell commands.
            pthread_testcancel()
            target.removeAllCachedResourceValues()
            let state = try? target.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey, .ubiquitousItemDownloadingErrorKey])
            if let error = state?.ubiquitousItemDownloadingError { throw error }
            if state?.ubiquitousItemDownloadingStatus == .current {
                return true
            }
            usleep(50_000)
        }
    } catch {
        if reportErrors {
            fputs("\(target.path): \(error.localizedDescription)\n", thread_stderr)
        } else {
            NSLog("Could not start iCloud download: \(error.localizedDescription)")
        }
        return false
    }
}

@_cdecl("downloadFile")
public func downloadFile(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    guard let commandNameC = argv?[0] else {
        fputs("downloadFile: Can't read command name\n", thread_stderr)
        return 1
    }
    let commandName = String(cString: commandNameC)
    let usage = "downloadFile: start iCloud downloads and return.\nUsage: " + commandName + " [-w|--wait] [--] name [.name.icloud ...]\n-w, --wait: wait until contents are available; Ctrl-C stops waiting, not the download.\n"
    guard let args = convertCArguments(argc: argc, argv: argv) else { return 1 }
    if args.count == 1 {
        fputs(usage, thread_stdout)
        return 0
    }
    var paths = Array(args.dropFirst())
    var waitForDownload = false
    while let option = paths.first {
        if option == "--" { paths.removeFirst(); break }
        if option == "-w" || option == "--wait" {
            waitForDownload = true
            paths.removeFirst()
            continue
        }
        if option == "-h" || option == "--help" {
            fputs(usage, thread_stdout)
            return 0
        }
        if option.hasPrefix("-") { fputs(usage, thread_stderr); return 1 }
        break
    }
    guard !paths.isEmpty else { fputs(usage, thread_stderr); return 1 }
    if waitForDownload { set_session_errno(130) }
    var succeeded = true
    for path in paths {
        if !downloadRemoteFileFromCloud(fileURL: URL(fileURLWithPath: path), waitForDownload: false, reportErrors: true) {
            succeeded = false
        }
    }
    if waitForDownload && succeeded {
        for path in paths {
            if !downloadRemoteFileFromCloud(fileURL: URL(fileURLWithPath: path), waitForDownload: true, reportErrors: true) { succeeded = false }
        }
    }
    return succeeded ? 0 : 1
}

@_cdecl("downloadFolder")
public func downloadFolder(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    guard let commandNameC = argv?[0] else {
        fputs("downloadFolder: Can't read command name\n", thread_stderr)
        return 1
    }
    let commandName = String(cString: commandNameC)
    let usage = "downloadFolder: start iCloud downloads, including hidden files, and return.\nUsage: " + commandName + " [-r] [-w|--wait] [--] [folder ...] (default is current directory)\n-r: include subfolders; symbolic links are not followed.\n-w, --wait: wait until contents are available; Ctrl-C stops waiting, not the downloads.\n"
    guard let args = convertCArguments(argc: argc, argv: argv) else { return 1 }
    var paths = Array(args.dropFirst())
    var recursive = false
    var waitForDownload = false
    while let option = paths.first {
        if option == "--" { paths.removeFirst(); break }
        if option == "-r" { recursive = true; paths.removeFirst(); continue }
        if option == "-w" || option == "--wait" {
            waitForDownload = true
            paths.removeFirst()
            continue
        }
        if option == "-h" || option == "--help" {
            fputs(usage, thread_stdout)
            return 0
        }
        if option.hasPrefix("-") { fputs(usage, thread_stderr); return 1 }
        break
    }
    if paths.isEmpty { paths = ["."] }
    if waitForDownload { set_session_errno(130) }
    var succeeded = true
    for path in paths {
        if !downloadFilesFromRemoteFolder(fileURL: URL(fileURLWithPath: path), recursive: recursive, waitForDownload: false, reportErrors: true) {
            succeeded = false
        }
    }
    if waitForDownload && succeeded {
        for path in paths {
            if !downloadFilesFromRemoteFolder(fileURL: URL(fileURLWithPath: path), recursive: recursive, waitForDownload: true, reportErrors: true) { succeeded = false }
        }
    }
    return succeeded ? 0 : 1
}

@discardableResult
func downloadFilesFromRemoteFolder(fileURL: URL, recursive: Bool = false, waitForDownload: Bool = true, reportErrors: Bool = false) -> Bool {
    do {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey, .isUbiquitousItemKey]
        let urls = try FileManager.default.contentsOfDirectory(at: fileURL, includingPropertiesForKeys: Array(keys), options: [])
        var succeeded = true
        for myURL in urls {
            do {
                let values = try myURL.resourceValues(forKeys: keys)
                if values.isSymbolicLink == true { continue }
                let name = myURL.lastPathComponent
                let placeholder = name.count > 8 && name.hasPrefix(".") && name.hasSuffix(".icloud")
                if values.isDirectory != true && (placeholder || values.isUbiquitousItem == true) {
                    if !downloadRemoteFileFromCloud(fileURL: myURL, waitForDownload: waitForDownload, reportErrors: reportErrors) { succeeded = false }
                }
                if recursive && values.isDirectory == true {
                    if !downloadFilesFromRemoteFolder(fileURL: myURL, recursive: true, waitForDownload: waitForDownload, reportErrors: reportErrors) { succeeded = false }
                }
            } catch {
                if reportErrors {
                    fputs("downloadFolder: \(myURL.path): \(error.localizedDescription)\n", thread_stderr)
                } else {
                    NSLog("Could not inspect iCloud item: \(error.localizedDescription)")
                }
                succeeded = false
            }
        }
        return succeeded
    } catch {
        if reportErrors {
            fputs("downloadFolder: \(fileURL.path): \(error.localizedDescription)\n", thread_stderr)
        } else {
            NSLog("Could not enumerate iCloud folder: \(error.localizedDescription)")
        }
        return false
    }
}

public func downloadRemoteFile(fileURL: URL) -> Bool {
    if FileManager.default.fileExists(atPath: fileURL.path) {
        if fileURL.isDirectory {
            // Picker, bookmark and URL-open paths keep best-effort shallow downloads.
            downloadFilesFromRemoteFolder(fileURL: fileURL, waitForDownload: false)
        }
        return true
    }
    return downloadRemoteFileFromCloud(fileURL: fileURL, waitForDownload: !Thread.isMainThread) && FileManager.default.fileExists(atPath: fileURL.path)
}

private struct PhotoCacheEntry: Codable {
    let modified: Date?
    let files: [String: UInt64]
}

private let photosLock = NSLock()

private func photoCacheName(_ identifier: String) -> String {
    return SHA256.hash(data: Data(identifier.utf8)).map { String(format: "%02x", $0) }.joined()
}

private func writePhotoResource(_ resource: PHAssetResource, to url: URL) throws {
    guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
        throw CocoaError(.fileWriteUnknown)
    }
    let file = try FileHandle(forWritingTo: url)
    let lock = NSLock()
    let finished = DispatchSemaphore(value: 0)
    var failure: Error?
    var closed = false
    let options = PHAssetResourceRequestOptions()
    options.isNetworkAccessAllowed = true
    let manager = PHAssetResourceManager.default()
    let request = manager.requestData(for: resource, options: options, dataReceivedHandler: { data in
        lock.lock()
        defer { lock.unlock() }
        if !closed && failure == nil {
            do { try file.write(contentsOf: data) } catch { failure = error }
        }
    }, completionHandler: { error in
        lock.lock()
        if failure == nil { failure = error }
        lock.unlock()
        finished.signal()
    })
    let timedOut = finished.wait(timeout: .now() + 300) == .timedOut
    lock.lock()
    closed = true
    let error = failure
    lock.unlock()
    if timedOut { manager.cancelDataRequest(request) }
    try file.close()
    if timedOut { throw URLError(.timedOut) }
    if let error = error { throw error }
}

private func removePhotoCacheItem(_ url: URL) throws {
    let values = try url.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
    if values.isDirectory == true && values.isSymbolicLink != true {
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
    }
    try FileManager.default.removeItem(at: url)
}

@_cdecl("photos_main")
public func photosMain(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    guard let args = convertCArguments(argc: argc, argv: argv) else { return 1 }
    let usage = "photos: sync accessible Photos originals to ~/Documents/Photos and print its path.\nUsage: photos [--select | --help]\n--select: change the limited Photos selection, then sync.\nRequests system Photos access (full or limited). Includes Live Photo video and RAW originals.\nFiles are read-only copies, reused on later syncs; edits do not change Photos.\nA sync removes cached assets no longer accessible. Copies made elsewhere remain.\niCloud resources may download; each resource has a 5-minute timeout.\n"
    if args.count == 2 && (args[1] == "--help" || args[1] == "-h") {
        fputs(usage, thread_stdout)
        return 0
    }
    let select = args.count == 2 && args[1] == "--select"
    guard args.count == 1 || select else {
        fputs(usage, thread_stderr)
        return 1
    }
    guard !runningInExtension && !Thread.isMainThread else {
        fputs("photos: run this command in the a-Shell app.\n", thread_stderr)
        return 1
    }
    guard photosLock.try() else {
        fputs("photos: a sync is already running.\n", thread_stderr)
        return 1
    }
    defer { photosLock.unlock() }
    var authorization = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    if authorization == .notDetermined {
        let answered = DispatchSemaphore(value: 0)
        DispatchQueue.main.async {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in answered.signal() }
        }
        guard answered.wait(timeout: .now() + 120) == .success else {
            fputs("photos: permission request timed out; run again after answering the system prompt.\n", thread_stderr)
            return 1
        }
        authorization = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }
    if select {
        guard authorization == .limited else {
            fputs("photos: --select requires limited Photos access. Choose limited access in Settings.\n", thread_stderr)
            return 1
        }
        let finished = DispatchSemaphore(value: 0)
        var presented = false
        DispatchQueue.main.async {
            guard var controller = currentDelegate?.window?.rootViewController else {
                finished.signal()
                return
            }
            while let next = controller.presentedViewController { controller = next }
            guard controller.view?.window != nil else {
                finished.signal()
                return
            }
            presented = true
            PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: controller) { _ in finished.signal() }
        }
        finished.wait()
        guard presented else {
            fputs("photos: cannot present the selection picker. Open an a-Shell window and try again.\n", thread_stderr)
            return 1
        }
        authorization = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }
    let allowed = authorization == .authorized || authorization == .limited
    do {
        let manager = FileManager.default
        var root = manager.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Photos", isDirectory: true)
        let marker = root.appendingPathComponent(".photos-cache")
        let index = root.appendingPathComponent(".photos-index.json")
        if manager.fileExists(atPath: root.path) {
            let values = try root.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
            guard values.isSymbolicLink != true && values.isDirectory == true && (try? String(contentsOf: marker, encoding: .utf8)) == "a-Shell Photos cache 1\n" else {
                throw NSError(domain: "photos", code: 1, userInfo: [NSLocalizedDescriptionKey: "~/Documents/Photos already exists and is not a managed Photos cache. Move it before running photos."])
            }
        } else if allowed {
            try manager.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            try "a-Shell Photos cache 1\n".write(to: marker, atomically: true, encoding: .utf8)
        } else {
            fputs("photos: Photos access denied. Allow full or limited access in Settings.\n", thread_stderr)
            return 1
        }
        var rootValues = URLResourceValues()
        rootValues.isExcludedFromBackup = true
        try root.setResourceValues(rootValues)
        let assets = allowed ? PHAsset.fetchAssets(with: nil) : PHAsset.fetchAssets(withLocalIdentifiers: [], options: nil)
        var visible = Set<String>()
        for i in 0..<assets.count { visible.insert(photoCacheName(assets.object(at: i).localIdentifier)) }
        // Prune before downloading so a failed network request cannot retain revoked assets.
        for child in try manager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) {
            let name = child.lastPathComponent
            let assetDirectory = name.count == 64 && name.allSatisfy { "0123456789abcdef".contains($0) }
            if (assetDirectory && !visible.contains(name)) || name.hasPrefix(".photos-stage-") {
                try removePhotoCacheItem(child)
            }
        }
        let previous = (try? JSONDecoder().decode([String: PhotoCacheEntry].self, from: Data(contentsOf: index))) ?? [:]
        var entries: [String: PhotoCacheEntry] = [:]
        var failed = false
        for i in 0..<assets.count {
            let asset = assets.object(at: i)
            let name = photoCacheName(asset.localIdentifier)
            let destination = root.appendingPathComponent(name, isDirectory: true)
            let resources = PHAssetResource.assetResources(for: asset).filter {
                [.photo, .video, .audio, .alternatePhoto, .pairedVideo].contains($0.type)
            }
            let names = resources.enumerated().map { offset, resource -> String in
                let filename: String
                #if compiler(>=6.4)
                if #available(iOS 27.0, *) {
                    filename = resource.filename ?? "original"
                } else {
                    filename = resource.originalFilename
                }
                #else
                filename = resource.originalFilename
                #endif
                return "\(resource.type.rawValue)-\(offset)-\((filename as NSString).lastPathComponent)"
            }
            let old = previous[name]
            let directoryValues = try? destination.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
            if let old = old, old.modified == asset.modificationDate && Set(old.files.keys) == Set(names) && directoryValues?.isDirectory == true && directoryValues?.isSymbolicLink != true {
                let intact = names.allSatisfy { filename in
                    let values = try? destination.appendingPathComponent(filename).resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey])
                    return values?.isRegularFile == true && values?.isSymbolicLink != true && values?.fileSize.map { UInt64($0) } == old.files[filename]
                }
                if intact { entries[name] = old; continue }
            }
            let stage = root.appendingPathComponent(".photos-stage-" + UUID().uuidString, isDirectory: true)
            do {
                try manager.createDirectory(at: stage, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
                var files: [String: UInt64] = [:]
                for (offset, resource) in resources.enumerated() {
                    let file = stage.appendingPathComponent(names[offset])
                    try writePhotoResource(resource, to: file)
                    let attributes = try manager.attributesOfItem(atPath: file.path)
                    files[names[offset]] = (attributes[.size] as? NSNumber)?.uint64Value
                    try manager.setAttributes([.posixPermissions: 0o400], ofItemAtPath: file.path)
                }
                if manager.fileExists(atPath: destination.path) { try removePhotoCacheItem(destination) }
                try manager.moveItem(at: stage, to: destination)
                try manager.setAttributes([.posixPermissions: 0o500], ofItemAtPath: destination.path)
                entries[name] = PhotoCacheEntry(modified: asset.modificationDate, files: files)
            } catch {
                try? removePhotoCacheItem(stage)
                fputs("photos: could not export asset \(name): \(error.localizedDescription)\n", thread_stderr)
                failed = true
            }
        }
        try JSONEncoder().encode(entries).write(to: index, options: .atomic)
        if !allowed {
            fputs("photos: Photos access denied; cached originals removed. Allow full or limited access in Settings.\n", thread_stderr)
            return 1
        }
        fputs(String(cString: ios_getBookmarkedVersion(root.path.utf8CString)) + "\n", thread_stdout)
        return failed ? 1 : 0
    } catch {
        fputs("photos: \(error.localizedDescription)\n", thread_stderr)
        return 1
    }
}

// hide the on-screen keyboard
@_cdecl("hideKeyboard")
public func hideKeyboard(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    showKeyboardAtStartup = false
    // iOS 16.7: we need to hide the keyboard in all scenes (??)
    for scene in UIApplication.shared.connectedScenes {
        if let delegate: SceneDelegate = scene.delegate as? SceneDelegate {
            delegate.hideKeyboard()
        }
    }
    /* if let delegate = currentDelegate {
        delegate.hideKeyboard()
    } */
    return 0
}

// hide the toolbar above the keyboard
@_cdecl("hideToolbar")
public func hideToolbar(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    UserDefaults.standard.set(false, forKey: "show_toolbar")
    fputs("hideToolbar will become effective after the next refocus event.\n", thread_stdout)
    return 0
}

// show the toolbar above the keyboard
@_cdecl("showToolbar")
public func showToolbar(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    UserDefaults.standard.set(true, forKey: "show_toolbar")
    fputs("showToolbar will become effective after the next refocus event.\n", thread_stdout)
    return 0
}

// deactivate a Python virtual environment created with "source env/bin/activate":
@_cdecl("deactivate")
public func deactivate(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    let libraryURL = try! FileManager().url(for: .libraryDirectory,
                                            in: .userDomainMask,
                                            appropriateFor: nil,
                                            create: true)
    setenv("PYTHONPYCACHEPREFIX", (libraryURL.appendingPathComponent("__pycache__")).path.toCString(), 1)
    setenv("PYTHONUSERBASE", libraryURL.path.toCString(), 1)
    if let oldPath = getenv("_OLD_VIRTUAL_PATH") {
        setenv("PATH", String(utf8String: oldPath), 1)
        unsetenv("_OLD_VIRTUAL_PATH")
    }
    if let oldPrompt = getenv("_OLD_VIRTUAL_PS1") {
        setenv("PS1", String(utf8String: oldPrompt), 1)
        unsetenv("_OLD_VIRTUAL_PS1")
    }
    unsetenv("VIRTUAL_ENV")
    return 0
}

// tries to change the directory, returns false if path is a file:
public func changeDirectory(path: String) -> Bool {
    NSLog("calling changeDirectory with \(path)")
    var fileURL = URL(fileURLWithPath: path)
    let originalFileURL = URL(fileURLWithPath: path)
    let argv: [UnsafeMutablePointer<Int8>?] = [UnsafeMutablePointer(mutating: "cd".toCString()!), UnsafeMutablePointer(mutating: path.removingPercentEncoding!.toCString()!)]
    // temporarily redirect stderr
    let old_thread_stderr = thread_stderr
    thread_stderr = fopen("/dev/null", "w")
    let p_argv: UnsafeMutablePointer = UnsafeMutablePointer(mutating: argv)
    cd_main(2, p_argv);
    if (originalFileURL.sameFileLocation(path: FileManager().currentDirectoryPath)) {
        fclose(thread_stderr)
        thread_stderr = old_thread_stderr
        return true // success
    }
    // We could not change directory. Is it something we bookmarked?
    var storedBookmarksDictionary = UserDefaults.standard.dictionary(forKey: "fileBookmarks") ?? [:]
    // var groupBookmarksDictionary = UserDefaults(suiteName: appGroupID)?.dictionary(forKey: "fileBookmarks")
    // if (groupBookmarksDictionary != nil) {
    //     storedBookmarksDictionary.merge(groupBookmarksDictionary!, uniquingKeysWith: { (current, _) in current })
    // }
    var listOfStaleBookmarks: [String] = []
    // bookmark could also be for a parent directory of fileURK --> we loop over all of them
    while (fileURL.pathComponents.count > 7) {
        // "7" corresponds to: /var/mobile/Containers/Data/Application/4AA730AE-A7CF-4A6F-BA65-BD2ADA01F8B4/Documents/
        // (shortest possible path authorized)
        // NSLog("Trying with \(fileURL.path)")
        var newPath = fileURL.path
        var bookmark = storedBookmarksDictionary[newPath]
        // we systematically try with /private added in front of both paths:
        if (bookmark == nil) {
            if (newPath.hasPrefix("/private")) {
                newPath.removeFirst("/private".count)
            } else if (newPath.hasPrefix("/var")) {
                newPath = "/private" + newPath
            }
            bookmark = storedBookmarksDictionary[newPath]
        }
        let bookmarkDepth = fileURL.pathComponents.count
        // If it fails, we loop, so we remove one component now:
        fileURL = fileURL.deletingLastPathComponent()
        if (bookmark != nil) {
            var stale = false
            var bookmarkedURL: URL
            do {
                bookmarkedURL = try URL(resolvingBookmarkData: bookmark as! Data, bookmarkDataIsStale: &stale)
            }
            catch {
                if (old_thread_stderr != nil) {
                    NSLog("Error in resolving secure bookmark for \(newPath): \(error)")
                    fputs("Could not resolve secure bookmark for \(newPath)\n", old_thread_stderr)
                    listOfStaleBookmarks.append(newPath)
                }
                continue // maybe there is another bookmark that will work?
            }
            if ((stale || !bookmarkedURL.sameFileLocation(path: newPath)) && canAccessBookmarkedURL(bookmarkedURL)) {
                // As in checkBookmarks(), update a bookmark whose directory is still reachable, but at another path
                // (e.g. the app that owns it got a new container) or with stale data, then go to the new path:
                let storedNamesDictionary = UserDefaults.standard.dictionary(forKey: "bookmarkNames") ?? [:]
                var mutableNamesDictionary = storedNamesDictionary
                let previousBookmarksDictionary = storedBookmarksDictionary
                var healedPaths = Set<String>()
                let healedPath = refreshBookmark(path: newPath, bookmark: bookmark as! Data, bookmarkedUrl: bookmarkedURL, stale: stale,
                                                 storedNames: storedNamesDictionary, storedBookmarks: previousBookmarksDictionary,
                                                 names: &mutableNamesDictionary, bookmarks: &storedBookmarksDictionary, healedPaths: &healedPaths)
                var targetURL = URL(fileURLWithPath: healedPath)
                for component in originalFileURL.pathComponents.dropFirst(bookmarkDepth) {
                    targetURL.appendPathComponent(component)
                }
                for staleBookmark in listOfStaleBookmarks {
                    storedBookmarksDictionary.removeValue(forKey: staleBookmark)
                }
                UserDefaults.standard.set(storedBookmarksDictionary, forKey: "fileBookmarks")
                UserDefaults(suiteName: appGroupID)?.set(storedBookmarksDictionary, forKey: "fileBookmarks")
                UserDefaults.standard.set(mutableNamesDictionary, forKey: "bookmarkNames")
                UserDefaults(suiteName: appGroupID)?.set(mutableNamesDictionary, forKey: "bookmarkNames")
                if (!targetURL.sameFileLocation(path: path)) {
                    fclose(thread_stderr)
                    thread_stderr = old_thread_stderr
                    return changeDirectory(path: targetURL.path)
                }
                stale = false
            }
            if (!stale) {
                let isSecuredURL = bookmarkedURL.startAccessingSecurityScopedResource()
                let isReadable = FileManager().isReadableFile(atPath: path)
                guard isSecuredURL && isReadable else {
                    if (old_thread_stderr != nil) {
                        fputs("Could not access \(path)\n", old_thread_stderr)
                    }
                    continue // maybe there is another bookmark that will work?
                    // return true
                }
                // If it's on iCloud, download the directory content
                if (!downloadRemoteFile(fileURL: bookmarkedURL)) {
                    if (isSecuredURL) {
                        bookmarkedURL.stopAccessingSecurityScopedResource()
                    }
                    if (old_thread_stderr != nil) {
                        fputs("Could not download \(path)\n", old_thread_stderr)
                    }
                    continue // maybe there is another bookmark that will work?
                    // return fileURL.isDirectory
                }
                cd_main(2, p_argv);
                fclose(thread_stderr)
                thread_stderr = old_thread_stderr
                if (originalFileURL.sameFileLocation(path: FileManager().currentDirectoryPath)) {
                    return originalFileURL.isDirectory // success
                } else {
                    if (originalFileURL.isDirectory) {
                        if (thread_stderr != nil) {
                            fputs("Could not change directory to \(path)", thread_stderr)
                        }
                        return true
                    } else {
                        return false
                    }
                }
            } else {
                listOfStaleBookmarks.append(newPath)
            }
        }
    }
    if (listOfStaleBookmarks.count > 0) {
        for staleBookmark in listOfStaleBookmarks {
            // stale bookmark. Remove from dictionary.
            storedBookmarksDictionary.removeValue(forKey: staleBookmark)
        }
        UserDefaults.standard.set(storedBookmarksDictionary, forKey: "fileBookmarks")
        UserDefaults(suiteName: appGroupID)?.set(storedBookmarksDictionary, forKey: "fileBookmarks")
    }
    fclose(thread_stderr)
    thread_stderr = old_thread_stderr
    return originalFileURL.isDirectory && (originalFileURL.sameFileLocation(path: FileManager().currentDirectoryPath))
}

@_cdecl("jump")
public func jump(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    // List the bookmark already stored:
    guard let commandNameC = argv?[0] else {
        fputs("jump: Can't read command name\n", thread_stderr)
        return 0
    }
    let commandName = String(cString: commandNameC)
    let usage = "Usage: " + commandName + " bookmarkName\n"
    if ((argc == 1) || (argc > 2)) {
        fputs(usage, thread_stderr)
        return 0
    }
    let nameC = argv?[1]
    if (nameC == nil) {
        fputs(usage, thread_stderr)
        return 0
    }
    let name = String(cString: nameC!)
    if (name.hasPrefix("-h")) {
        fputs(usage, thread_stderr)
        return 0
    }
    var storedNamesDictionary = UserDefaults.standard.dictionary(forKey: "bookmarkNames") ?? [:]
    // let groupNamesDictionary = UserDefaults(suiteName: appGroupID)?.dictionary(forKey: "bookmarkNames")
    // if (groupNamesDictionary != nil) {
    //     storedNamesDictionary.merge(groupNamesDictionary!, uniquingKeysWith: { (current, _) in current })
    // }
    guard let path = storedNamesDictionary[name] else {
        fputs("jump: \(name) not found.\n", thread_stderr)
        return 1
    }
    let pathString = path as! String
    // We call cd_main so that "cd -" can still work.
    if (changeDirectory(path: pathString)) {
        // changeDirectory also goes through all the list of bookmarks.
        return 0 // it worked
    } else {
        // changeDirectory may have moved the bookmark to a new path, read the names again:
        storedNamesDictionary = UserDefaults.standard.dictionary(forKey: "bookmarkNames") ?? [:]
        let currentPath = (storedNamesDictionary[name] as? String) ?? pathString
        var isDirectory: ObjCBool = false
        let fileExists = FileManager().fileExists(atPath: currentPath, isDirectory: &isDirectory)
        if (fileExists && !isDirectory.boolValue) {
            // it's a file: edit it with default editor:
            // TODO: customize editor
            if let delegate = currentDelegate {
                delegate.executeCommand(command: "vim " + currentPath.replacingOccurrences(of: " ", with: "\\ "))
            }
        } else {
            // probably a stale bookmark:
            fputs("jump: bookmark for \(name) is no longer valid.\n", thread_stderr)
            storedNamesDictionary.removeValue(forKey: name)
            UserDefaults.standard.set(storedNamesDictionary, forKey: "bookmarkNames")
            UserDefaults(suiteName: appGroupID)?.set(storedNamesDictionary, forKey: "bookmarkNames")
        }
    }
    return 0
}
    
@_cdecl("play_main")
public func play_media(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    let args = convertCArguments(argc: argc, argv: argv)
    if let delegate = currentDelegate {
        return delegate.play_media(arguments: args)
    }
    return 0
}

@_cdecl("preview_main")
public func preview(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    let args = convertCArguments(argc: argc, argv: argv)
    if let delegate = currentDelegate {
        return delegate.preview(arguments: args)
    }
    return 0
}

// Copied from ios_system, translated from Objective-C to Swift

func __browser_app_url(inputUrl: URL, browser: String) -> URL {

    let scheme = inputUrl.scheme
    if (!(scheme == "http") && !(scheme == "https")) {
        // Not an actual web link.
        return inputUrl
    }

    if !(__known_browsers.contains(browser)) {
        return inputUrl
    }

    if (browser == "safari") {
        return inputUrl
    }

    let absSrcURLStr = inputUrl.absoluteString
    
    // browsers with the open-url scheme:
    if ((browser == "firefox") || (browser == "brave") || (browser == "opera")) {
        if let urlString = absSrcURLStr.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            return URL(string: browser + "://open-url?url=" + urlString)  ?? inputUrl
        }
    } else if (browser == "yandexbrowser") {
        if let urlString = absSrcURLStr.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            return URL(string: "yandexbrowser-open-url://" + urlString) ?? inputUrl
        }
    } else if (browser == "googlechrome") {
        var shortenedAbsSrcURLStr = absSrcURLStr
        // googlechrome: replace "http" or "https" with "googlechrome"
        if (shortenedAbsSrcURLStr.hasPrefix("http")) {
            shortenedAbsSrcURLStr.removeFirst("http".count)
        }
        return URL(string: browser + shortenedAbsSrcURLStr) ?? inputUrl
    }
    return inputUrl
}

public func openurl_internal(browser: String, url: URL) {
    if let delegate = currentDelegate {
        DispatchQueue.main.async {
            if (browser == "internalbrowser") {
                delegate.openURLInWindow(url: url)
            } else {
                let browserAppUrl = __browser_app_url(inputUrl: url, browser: browser)
                delegate.windowScene?.open(browserAppUrl, options: .none)
            }
        }
    }
}


@_cdecl("openurl_main")
public func openurl_main(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    let usage = "Usage: openurl url\nYou can change the default browser with BROWSER env var:\n" + __known_browsers.joined(separator: ", ") + "\n"
    
    guard let args = convertCArguments(argc: argc, argv: argv) else {
        fputs(usage, thread_stderr)
        return -1
    }
    
    // if the internal browser was already started, internalbrowser makes it visible (same as the showBrowser button)
    if (args[0] == "internalbrowser") && internalBrowserStarted && (argc == 1) {
        if let delegate = currentDelegate {
            DispatchQueue.main.async {
                delegate.activateBrowserAction()
            }
            return 0
        }
    }
    
    let genericCall = (args[0] == "openurl")
    
    if ((argc < 2) || (args[1] == "-h") || (args[1] == "--help")) {
        if (genericCall) {
            fputs(usage, thread_stderr)
        } else {
            fputs("Usage: \(args[0]) url\n", thread_stderr)
        }
        return -1
    }
    
    var browser = "safari"
    if (genericCall) {
        if let browserEnvVar = ios_getenv("BROWSER") {
            browser = (String(utf8String: browserEnvVar) ?? "safari").lowercased()
        }
    } else {
        browser = args[0]
    }
    
    var urlString = args[1]
    // if there are several arguments, we assume they are part of a path and add escaped spaces
    if (argc > 2) {
        for i in 2...argc-1 {
            urlString += " " + args[Int(i)]
        }
    }
    // Transform everything to url-safe encoding:
    var locationUrl: URL?
    if (FileManager().fileExists(atPath: urlString)) {
        locationUrl = URL(fileURLWithPath: urlString)
    } else {
        // only add percent-encoding to strings that are not already percent-encoded:
        if urlString.removingPercentEncoding == urlString {
            urlString = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? urlString
        }
        locationUrl = URL(string: urlString)
    }
    // locationUrl is always non-nil with modern iOS, so we also check if the scheme is not nil.
    guard locationUrl != nil && locationUrl?.scheme != nil else {
        fputs("Invalid URL: \(urlString).\n", thread_stderr)
        if (genericCall) {
            fputs(usage, thread_stderr)
        } else {
            fputs("Usage: \(args[0]) url\n", thread_stderr)
        }
        return -1
    }
    
    openurl_internal(browser: browser, url: locationUrl!)
    
    return 0
}


//
// Functions to call / text contacts and phone numbers
//
import Contacts

private func fullName(contact: CNContact) -> String {
    let name = "\(contact.givenName) \(contact.familyName)"
    let organization = contact.organizationName
    var fullName = ""
    if name.count > 1 {
        fullName = name
        if (organization.count > 0) {
            return fullName + " — " + organization
        }
    } else {
        return organization
    }
    return fullName
}

private func phoneNumberFromContacts(key: String, action: String) -> String? {
    let store = CNContactStore()
    let keysToFetch = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactOrganizationNameKey, CNContactPhoneNumbersKey] as [CNKeyDescriptor]
    let predicate = CNContact.predicateForContacts(matchingName: key)
    do {
        let contacts = try store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)
        if (contacts.count == 0) {
            // No matching contacts found, check if key is a phone number:
            var number = key
            if (number.hasPrefix("+")) {
                number.removeFirst()
            }
            number = number.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "")
            if Int(number) != nil {
                fputs("\(action) \(key)\n", thread_stdout)
                return key
            }
            return nil
        }
        if (contacts.count == 1) {
            fputs("\(action) \(fullName(contact: contacts[0]))\n", thread_stdout)
            let phoneNumber = contacts[0].phoneNumbers[0].value.stringValue
            return phoneNumber.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "")
        }
        // More than 1 contact. How many phone numbers?
        var phoneNumber: String? = nil
        for contact in contacts {
            if (contact.phoneNumbers.count > 0) {
                let newNumber = contact.phoneNumbers[0].value.stringValue.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "")
                if (phoneNumber == nil) {
                    phoneNumber = newNumber
                } else if (phoneNumber != newNumber) {
                    phoneNumber = nil
                    break
                }
            }
        }
        if (phoneNumber != nil) {
            fputs("\(action) \(fullName(contact: contacts[0]))\n", thread_stdout)
            return phoneNumber
        } else {
            fputs("Cannot separate between multiple contacts:\n", thread_stdout)
            for contact in contacts {
                fputs("- \(fullName(contact: contact))\n", thread_stdout)
            }
            return nil
        }
    }
    catch {
        fputs("No contacts found for \(key)\n", thread_stdout)
        return nil
    }
}

@_cdecl("call")
public func call(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    let args = convertCArguments(argc: argc, argv: argv)
    guard args != nil  else {
        return -1
    }
    guard args!.count >= 2  else {
        fputs("Usage: \(args![0]) name\n", thread_stderr)
        return -1
    }
    var key = args![1]
    if (args!.count > 2) {
        for i in 2...args!.count-1 {
            key += " " + args![i]
        }
    }
    if let phoneNumber = phoneNumberFromContacts(key: key, action: "Calling") {
        if let url = URL(string: "tel://" + phoneNumber) {
            DispatchQueue.main.async {
                UIApplication.shared.open(url, options: [.universalLinksOnly: false], completionHandler: nil)
            }
        }
        return 0
    }
    return -1
}

@_cdecl("text")
public func text(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    let args = convertCArguments(argc: argc, argv: argv)
    guard args != nil  else {
        return -1
    }
    guard args!.count >= 2  else {
        fputs("Usage: \(args![0]) [name] [message]\n", thread_stderr)
        return -1
    }
    if let phoneNumber = phoneNumberFromContacts(key: args![1], action: "Texting") {
        if (args!.count == 2) { // No message:
            if let url = URL(string: "sms://" + phoneNumber) {
                DispatchQueue.main.async {
                    UIApplication.shared.open(url, options: [.universalLinksOnly: false], completionHandler: nil)
                }
                return 0
            }
            return -1
        }
        var message = args![2]
        if (args!.count > 3) {
            for i in 3...args!.count-1 {
                message += " "
                message += args![i]
            }
        }
        if let messageFixed = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            if let url = URL(string: "sms://" + phoneNumber + "&body=" + messageFixed) {
                DispatchQueue.main.async {
                    UIApplication.shared.open(url, options: [.universalLinksOnly: false], completionHandler: nil)
                }
                return 0
            }
        } else {
            fputs("Error converting \(message). Could not send.", thread_stderr)
        }
    }
    return -1
}

@_cdecl("stopInteractive")
public func stopInteractive() {
    if (runningInExtension) {
        return
    }
    DispatchQueue.main.async {
        if let delegate = currentDelegate {
            delegate.interactiveCommandRunning = false
        }
    }
}

@_cdecl("storeInteractive")
public func storeInteractive() -> Int32 {
    if (runningInExtension) {
        return 0
    }
    var returnValue: Int32 = 0
    let readMode = {
        if let delegate = currentDelegate {
            returnValue = delegate.interactiveCommandRunning ? 1 : 0
        }
    }
    if Thread.isMainThread {
        readMode()
    } else {
        DispatchQueue.main.sync(execute: readMode)
    }
    return returnValue
}

@_cdecl("startInteractive")
public func startInteractive() {
    if (runningInExtension) {
        return
    }
    DispatchQueue.main.async {
        if let delegate = currentDelegate {
            delegate.interactiveCommandRunning = true
        }
    }
}

@_cdecl("needLLVM")
public func needLLVM(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    guard let args = convertCArguments(argc: argc, argv: argv) else { return 1 }
    fputs("In order to use \(args[0]), you need to install or update the C SDK with 'pkg install llvm-22'.\n", thread_stderr)
    return 0
}

@_cdecl("needTeX")
public func needTeX(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    guard let args = convertCArguments(argc: argc, argv: argv) else { return 1 }
    let libraryURL = try! FileManager().url(for: .libraryDirectory,
                                            in: .userDomainMask,
                                            appropriateFor: nil,
                                            create: true)
    let texliveTestFile2023 = libraryURL.appendingPathComponent("texlive/2023/texmf-dist/tex/plain/base/plain.tex")
    let texliveTestFile2024 = libraryURL.appendingPathComponent("texlive/2024/texmf-dist/tex/plain/base/plain.tex")
    let texliveTestFile2025 = libraryURL.appendingPathComponent("texlive/2025/texmf-dist/tex/plain/base/plain.tex")
    if (FileManager().fileExists(atPath: texliveTestFile2023.path)) {
        fputs("You currently have texlive-2023 installed. In order to to use \(args[0]), you need to update the distribution to texlive-2026 with 'pkg install texlive-2026'.\n", thread_stderr)
    } else if (FileManager().fileExists(atPath: texliveTestFile2024.path)) {
        fputs("You currently have texlive-2024 installed. In order to to use \(args[0]), you need to update the distribution to texlive-2026 with 'pkg install texlive-2026'.\n", thread_stderr)
    } else if (FileManager().fileExists(atPath: texliveTestFile2025.path)) {
        fputs("You currently have texlive-2025 installed. In order to to use \(args[0]), you need to update the distribution to texlive-2026 with 'pkg install texlive-2026'.\n", thread_stderr)
    } else {
        fputs("In order to use \(args[0]), you need to install the texlive distribution with 'pkg install texlive-2026'.\n", thread_stderr)
    }
    return 0
}

@_cdecl("needLuaTeX")
public func needLuaTeX(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    guard let args = convertCArguments(argc: argc, argv: argv) else { return 1 }
    let libraryURL = try! FileManager().url(for: .libraryDirectory,
                                            in: .userDomainMask,
                                            appropriateFor: nil,
                                            create: true)
    let texliveTestFile = libraryURL.appendingPathComponent("texlive/2026/texmf-dist/tex/plain/base/plain.tex")
    if (FileManager().fileExists(atPath: texliveTestFile.path)) {
        fputs("In order to use \(args[0]), you need to install the OpenType/TrueType fonts with 'pkg install texlive_fonts-2026'.\n", thread_stderr)
    } else {
        fputs("In order to to use \(args[0]), you need to install the texlive distribution 'pkg install texlive-2026' and the OpenType/TrueType fonts with 'pkg install texlive_fonts-2026'.\n", thread_stderr)
    }
    return 0
}

@_cdecl("updateCommands")
public func updateCommands(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    // Small function to activate or deactivate C and TeX commands after installing the auxiliary files
    // Don't convert arguments, it only causes issues.
    
    let libraryURL = try! FileManager().url(for: .libraryDirectory,
                                            in: .userDomainMask,
                                            appropriateFor: nil,
                                            create: true)
    // LLVM C SDK: check that ~/Library/usr/lib/clang/14.0.0 exists. If yes, activate LLVMcommands. Otherwise, activate fake LLVM commands.
    let headerUrl = libraryURL.appendingPathComponent("usr/lib/clang/22/include/float.h")
    if FileManager().fileExists(atPath: headerUrl.path) {
        addCommandList(Bundle.main.path(forResource: "llvmDictionary", ofType: "plist"))
    } else {
        // "llvm-dis", "opt", "llvm-link", "lli", "llc": bitcode-based commands. Removed now.
        for command in ["lld", "ld", "ar", "ranlib", "wasm-ld", "lld-link", "ld.lld", "ld64.lld", "clang", "clang++"] {
            // All these commands use "main", so "false" so as not to replace all "main" commands:
            replaceCommand(command, "needLLVM", false)
        }
    }
    // texlive files:
    let texliveTestFile = libraryURL.appendingPathComponent("texlive/2026/texmf-dist/tex/plain/base/plain.tex")
    if FileManager().fileExists(atPath: texliveTestFile.path) {
        addCommandList(Bundle.main.path(forResource: "texCommandsDictionary", ofType: "plist"))
        // LuaTeX and XeTeX: extra fonts files:
        let luatexTestFile = libraryURL.appendingPathComponent("texlive/2026/texmf-dist/fonts/opentype/public/lm/lmroman10-regular.otf")
        if FileManager().fileExists(atPath: luatexTestFile.path) {
            addCommandList(Bundle.main.path(forResource: "luatexCommandsDictionary", ofType: "plist"))
        } else {
            for command in ["dvilualatex", "dviluatex", "lualatex", "luatex", "luahbtex", "xetex", "xelatex"] {
                // All these commands use "main", so "false" so as not to replace all "main" commands:
                replaceCommand(command, "needLuaTeX", false)
            }
        }
        // Create all the TeX scripts commands:
        let libraryURL = try! FileManager().url(for: .libraryDirectory,
                                                   in: .userDomainMask,
                                                   appropriateFor: nil,
                                                   create: true)
        let localPath = libraryURL.appendingPathComponent("bin") // $HOME/Library/bin
        if (!FileManager().fileExists(atPath: localPath.path)) {
            do {
                try (FileManager().createDirectory(at: localPath, withIntermediateDirectories: true))
            }
            catch {
                NSLog("Unable to create binary directory \(localPath.path): \(error)")
            }
        }
        for script in TeXscripts {
            let command = localPath.appendingPathComponent(script[0])
            let location = "../texlive/2026/texmf-dist/" + script[1]
            // fileExists doesn't work, because it follows symbolic links
            do {
                let fileAttribute = try FileManager().attributesOfItem(atPath: command.path)
                if (fileAttribute[FileAttributeKey.type] as? String == FileAttributeType.typeSymbolicLink.rawValue) {
                    // It's a symbolic link, does the destination exist?
                    if (!FileManager().fileExists(atPath: command.path)) {
                        try FileManager().removeItem(at: command)
                        try FileManager().createSymbolicLink(atPath: command.path, withDestinationPath: location)
                    }
                }
            }
            catch {
                do {
                    try FileManager().createSymbolicLink(atPath: command.path, withDestinationPath: location)
                }
                catch {
                    NSLog("Unable to create symbolic link at \(command.path) to \(location): \(error)")
                }
            }
        }
    } else {
        for command in ["amstex", "bibtex", "cslatex", "csplain", "eplain", "etex", "jadetex", "latex", "makeindex", "mex", "mllatex", "mltex", "pdfcslatex", "pdfcsplain", "pdfetex", "pdfjadetex", "pdflatex", "pdfmex", "pdftex", "pdfxmltex", "tex", "texsis", "utf8mex", "xmltex", "texlua", "texluac", "dvipdfmx", "xdvipdfmx", "euptex", "uptex", "uplatex"] {
            // All these commands use "main", so "false" so as not to replace all "main" commands:
            replaceCommand(command, "needTeX", false)
        }
        for command in ["dvilualatex", "dviluatex", "lualatex", "luatex", "luahbtex", "xetex", "xelatex"] {
            // All these commands use "main", so "false" so as not to replace all "main" commands:
            replaceCommand(command, "needLuaTeX", false)
        }
    }
    return 0
}


// Used both by z and by auto-complete for directories
public func rankDirectory(dir: String, base: String?) -> Int {
    var key = dir
    if (base != nil) {
        key = base!
        if (!key.hasSuffix("/")) {
            key += "/"
        }
        key += dir
    }
    if let used = directoriesUsed[key] {
        return used
    }
    if dir.hasPrefix(".") {
        return -2
    }
    return -1
}

// Called by "cd", used to store the directory where we go, so we can sort them based on frequency
@_cdecl("storeDirectoryUsed")
public func storeDirectoryUsed(directory: String) {
    var key = directory
    if (key.hasSuffix("/")) {
        key.removeLast()
    }
    if let seenBefore = directoriesUsed[key] {
        directoriesUsed[key] = seenBefore + 1;
    } else {
        directoriesUsed[key] = 0;
    }
    // NSLog("Storing directory: \(key) : \(directoriesUsed[key])")
}

// z command: change to the most recent directory that matches the argument(s)
// TODO: autocomplete for z
@_cdecl("z_command")
public func z_command(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    guard let args = convertCArguments(argc: argc, argv: argv) else { return 1 }
    if args.count <= 1 {
        fputs("usage: z [keyword]\nwill change directory to the most frequently used directory matching argument.\n", thread_stdout)
        return 0
    }
    // If argument is a directory that exists, change to that:
    // (usually as a result of auto-complete)
    if (FileManager().fileExists(atPath: args[1])) {
        let fileUrl = URL(fileURLWithPath: args[1])
        if (fileUrl.isDirectory) {
            fputs("cd \(args[1])\n", thread_stdout)
            executeCommandAndWait(command: "cd \"" + args[1] + "\"")
            return 0
        }
    }
    // If that didn't work
    // we build a regex from the args, to make sure args are in order.
    var matchingRegexp = args[1].replacingOccurrences(of: ".", with: "\\.").replacingOccurrences(of: "/", with: ".*/.*")
    if (args.count > 2) {
        for i in 2...args.count - 1 {
            matchingRegexp += ".*" + args[i].replacingOccurrences(of: ".", with: "\\.").replacingOccurrences(of: "/", with: ".*/.*")
        }
    }
    do {
        let regex = try NSRegularExpression(pattern: matchingRegexp, options: [])
        // select keys from dictionary that match argument. Using partial match.
        let result = directoriesUsed.filter( { regex.matches(in: $0.key, range: NSRange($0.key.startIndex..<$0.key.endIndex, in: $0.key)).count > 0 } )
        if (result.count == 0) {
            // No matches in history. Search local directory, same regexp.
            let filePaths = try FileManager().contentsOfDirectory(atPath: FileManager().currentDirectoryPath)
            var result = filePaths.filter( { regex.matches(in: $0, range: NSRange($0.startIndex..<$0.endIndex, in: $0)).count > 0 } )
            NSLog("local search: \(result)")
            NSLog("Current directory: \(FileManager().currentDirectoryPath)")
            if (result.count == 0) {
                fputs("No matches for ", thread_stdout)
                for i in 1...args.count - 1 {
                    fputs(args[i] + " ", thread_stdout)
                }
                fputs("\n", thread_stdout)
                return -1
            }
            if (result.count > 1) {
                let localDirCompact = String(cString: ios_getBookmarkedVersion(FileManager().currentDirectoryPath.utf8CString)) + "/"
                result = result.sorted(by: { current, next in rankDirectory(dir: current, base: localDirCompact) > rankDirectory(dir: next, base: localDirCompact)})
            }
            fputs("cd \(result[0])\n", thread_stdout)
            executeCommandAndWait(command: "cd " + result[0])
            newPreviousDirectory()
            return 0
        }
        if (result.count == 1) {
            if let directory = result.first?.key {
                fputs("cd \(directory)\n", thread_stdout)
                executeCommandAndWait(command: "cd " + directory)
                newPreviousDirectory()
                return 0
            }
            return 1
        }
        var keys = result.keys.sorted()
        keys = keys.sorted(by: { current, next in rankDirectory(dir: current, base: nil) > rankDirectory(dir: next, base: nil)})
        fputs("cd \(keys[0])\n", thread_stdout)
        executeCommandAndWait(command: "cd " + keys[0])
        newPreviousDirectory()
        return 0
    }
    catch {
        NSLog("Could not create regexp for: \(matchingRegexp)", thread_stderr)
        return -1
    }
    return 1
}


// TODO: autocomplete for z
/*
@_cdecl("rehash")
public func rehash(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    guard let args = convertCArguments(argc: argc, argv: argv) else { return 1 }
    if args.count > 1 {
        fputs("usage: rehash\nRecomputes list of executables in $PATH for auto-complete.\n", thread_stdout)
        return 0
    }
    // First get list of builtin commnds:
    guard var commandsArray = commandsAsArray() as! [String]? else { return -1 }
    // Then scan PATH for executable files:
    let executablePath = String(cString: ios_getenv("PATH"))
    // NSLog("\(executablePath)")
    for directory in executablePath.components(separatedBy: ":") {
        if (directory == "") {
            continue
        }
        if (directory == ".") {
            continue
        }
        do {
            // We don't check for exec status, because files inside $APPDIR have no x bit set.
            for file in try FileManager().contentsOfDirectory(atPath: directory) {
                let newCommand = URL(fileURLWithPath: file).lastPathComponent
                // Do not add a command if it is already present:
                if (!commandsArray.contains(newCommand)) {
                    commandsArray.append(newCommand)
                }
            }
        } catch {
            // The directory is unreadable, move to next one
            continue
        }
    }
    commandsArray.sort() // make sure it's in alphabetical order
    return 0
} */

@_cdecl("repeatCommand")
public func repeatCommand(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    guard let args = convertCArguments(argc: argc, argv: argv) else { return 1 }
    let usageString = "usage: repeatCommand interval command\n    Executes the command \"command\" every \"interval\" seconds.\nusage: repeatCommand\n    Shows the current running command, interval, last time it was executed and next scheduled execution.\nusage: repeatCommand --stop\n    Stops the repetition.\n"
    if (args.count == 2) && ((args[1] == "-h") || (args[1] == "--help") || (args[1] == "-help")) {
        fputs(usageString, thread_stdout)
        return -1
    }
    if (args.count == 2) && ((args[1] == "-stop") || (args[1] == "--stop") || (args[1] == "-end") || (args[1] == "--end")) {
        if let delegate = currentDelegate {
            delegate.stopRepeating()
        }
        return 0
    }
    if (args.count == 1) {
        if let delegate = currentDelegate {
            delegate.showRepeatingCommand()
            return 0
        }
    }
    if (args.count < 3) {
        fputs(usageString, thread_stderr)
        return -1
    }
    if let interval = Float(args[1]) {
        var command = ""
        for i in 2..<args.count {
            command += args[i] + " "
        }
        if let delegate = currentDelegate {
            delegate.repeatCommand(interval: interval, command: command)
        }
    } else {
        fputs("repeatCommand: unable to convert argument to time interval: \(args[1]).\n",thread_stderr)
        fputs(usageString, thread_stderr)
        return -1
    }
    return 0
}

@_cdecl("codexUnavailable")
public func codexUnavailable(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    fputs("codex requires iOS 26.2 or later.\n", thread_stderr)
    return 1
}

@_cdecl("wasmkitUnavailable")
public func wasmkitUnavailable(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    fputs("wasmkit is only available for iOS 18 and above.\n", thread_stdout)
    return 0
}

public func executeCommandAndWait(command: String) {
    NSLog("executeCommandAndWait: \(command)")
    let pid = ios_fork()
    _ = ios_system(command.decomposedStringWithCanonicalMapping)
    fflush(thread_stdout)
    ios_waitpid(pid)
    ios_releaseThreadId(pid)
}


