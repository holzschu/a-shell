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

var runningInExtension = false

var currentDelegate: SceneDelegate? {
    let opaquePointer = OpaquePointer(ios_getContext())
    guard let stringPointer = UnsafeMutablePointer<CChar>(opaquePointer) else { return nil }
    let currentSessionIdentifier = String(cString: stringPointer)
    for scene in UIApplication.shared.connectedScenes {
        if (scene.session.persistentIdentifier == currentSessionIdentifier) {
            if let delegate: SceneDelegate = scene.delegate as? SceneDelegate {
                return delegate
            }
        }
    }
    // We haven't found a delegate so far, let's take the first scene:
    // TODO: that's a bad sign, the sessionIndentifier should be the correct one.
    // related to when a window is created, then closed
    if (UIApplication.shared.connectedScenes.count > 0) {
        if let scene = UIApplication.shared.connectedScenes.first {
            if let delegate: SceneDelegate = scene.delegate as? SceneDelegate {
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
        fputs("webAssembly commands are not available \"In Extension\".\n", thread_stderr)
        finishedPreparingWebAssemblyCommand();
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
- newWindow: open a new window
- exit: close the current window

- All your files, including configuration files (.bashrc, .profile, .ssh...) are in ~/Documents/
- Files created by Shortcuts are in ~shortcuts/
- a-Shell executes the ~/Documents/.profile and ~/Documents/.bashrc files for each new window

- Single-finger swipes move the cursor or scroll, two-finger swipes send keyboard input (up, down, escape, tab). "man gestures" for more.

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
            delegate.printText(string: "\nSupport: e-mail (another_shell@icloud.com), Twitter (@a_Shell_iOS), github (https://github.com/holzschu/a-shell/issues) and Discord (https://discord.gg/cvYnZm69Gy).\n")
            delegate.printText(string: "\nFor a full list of commands, type help -l\n")
        } else {
            guard let argV = argv?[1] else {
                delegate.printText(string: helpText)
                return 0
            }
            let arg = String(cString: argV)
            if (arg == "-l") {
                guard var commandsArray = commandsAsArray() as! [String]? else { return 0 }
                // Also scan PATH for executable files:
                let executablePath = String(cString: getenv("PATH"))
                for directory in executablePath.components(separatedBy: ":") {
                    if (directory.count == 0) { continue } // Empty directory (::), don't read it.
                    do {
                        // We don't check for exec status, because files inside $APPDIR have no x bit set.
                        for file in try FileManager().contentsOfDirectory(atPath: directory) {
                            let fileUrl = URL(fileURLWithPath: directory).appendingPathComponent(file)
                            if (fileUrl.isDirectory) { continue } // Don't include directories in command list
                            commandsArray.append(fileUrl.lastPathComponent)
                        }
                    } catch {
                        // The directory is unreadable, move to next one
                        continue
                    }
                }
                commandsArray.sort() // make sure it's in alphabetical order
                commandsArray = Array(NSOrderedSet(array: commandsArray)) as! [String]
                if (ios_isatty(STDOUT_FILENO) == 1) {
                    for command in commandsArray {
                        delegate.printText(string: command + ", ")
                    }
                    delegate.printText(string: "\n")
                } else {
                    // stdout is not a tty, so redirecting the output. Probably through grep.
                    // Be nice and present something that can be grepped
                    for command in commandsArray {
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
a-Shell owes to many open-source contributors. The current code contains contributions from: Yury Korolev, Ian McDowell, Louis d'Hauwe, Anders Borum, Adrian Labbé, Kenta Kubo, Ian Willis, Henry Heino and suggestions for improvements from many others.

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
TeX: Donald Knuth and TUG, https://tug.org. TeX distribution is texlive 2024.
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
    // First, let's scan the arguments:
    var terminalFontSize: Float?
    var terminalFontName: String?
    var terminalBackgroundColor: UIColor?
    var terminalForegroundColor: UIColor?
    var terminalCursorColor: UIColor?
    var terminalCursorShape: String?
    var terminalFontLigature: String?
    let shortUsage = "usage: config [-s font size][-n font name][-b background color][-f foreground color][-c cursor color][-dgpr]\n"
    let usageString = """
    usage: config [-s font size][-n font name][-b background color][-f foreground color][-c cursor color][-g][-p][-d][-r]
    For all parameters: "default" to get the default value currently stored, "factory" to get a-Shell factory defaults (\(factoryFontName), \(factoryFontSize) pts, colors from system).
    Colors can be defined by names, RGB triplets "red green blue" or HexStrings "#00FF00"
    -s | --size: set font size
    -n | --name: set font name. Nothing or "picker" to get the system font picker.
    -b | --background: set background color
    -f | --foreground: set foreground color
    -c | --cursor: set cursor and highlight color
    -k | --cursorShape: set cursor shape (beam, block or underline)
    -l | --ligatures: normal, contextual, none...
    -t | --toolbar: create a configuration file to change the toolbar
    -g | --global: extend settings to all windows currently open
    -p | --permanent: store settings as default values
    -d | --default: reset all settings to default values
    -r | --reset: reset all settings to factory default
    --show: show current settings
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
        case "-s", "--size":
            argumentsSet = true
            if (i + 1 < args.count) {
                if !args[i+1].hasPrefix("-") {
                    if let s = Float(args[i+1]) {
                        terminalFontSize = s
                        skipNextArgument = 1
                    } else {
                        if args[i+1] == "default" {
                            if let storedSize = UserDefaults.standard.object(forKey: "fontSize") as? Float {
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
                if let storedName = UserDefaults.standard.object(forKey: "fontName") as? String {
                    terminalFontName = storedName
                } else {
                    terminalFontName = factoryFontName
                }
            } else if name == "factory" {
                terminalFontName = factoryFontName
            } /* else if (FileManager().fileExists(atPath: name) && (name.hasSuffix(".ttf") || name.hasSuffix(".otf"))) {
                 // attempt to load fonts from file. Failed. 
                terminalFontName = name
            } */ else if UIFont(name: name, size: 13) != nil {
                terminalFontName     = name
            } else {
                fputs("Could not load font: \(name)\n", thread_stderr)
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
                name = name.uppercased()
                if (name == "BEAM") || (name == "UNDERLINE") || (name == "BLOCK") {
                    terminalCursorShape = name
                } else {
                    fputs("Did not understand cursor shape: \(name) (possible names are beam, block and underline)\n", thread_stderr)
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
            let configFile = Bundle.main.resourceURL?.appendingPathComponent("defaultToolbar.txt")
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
            delegate?.showConfigWindow()
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
        if let storedSize = UserDefaults.standard.object(forKey: "fontSize") as? Float {
            delegate?.terminalFontSize = storedSize
        } else {
            delegate?.terminalFontSize = factoryFontSize
        }
        if let storedName = UserDefaults.standard.object(forKey: "fontName") as? String {
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
    if (makePermanent) {
        // Store these settings
        // If nothing except "-p" (and possibly -d or -r): make current window settings permanent
        // Otherwise, take settings from current window and make them permanent
        if (!argumentsSet) {
            terminalFontSize = delegate?.terminalFontSize
            terminalFontName = delegate?.terminalFontName
            terminalBackgroundColor = delegate?.terminalBackgroundColor
            terminalForegroundColor = delegate?.terminalForegroundColor
            terminalCursorColor = delegate?.terminalCursorColor
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
        if terminalFontSize != nil {
            UserDefaults.standard.set(terminalFontSize, forKey: "fontSize")
        }
        if terminalFontName != nil {
            UserDefaults.standard.set(terminalFontName, forKey: "fontName")
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
    // let groupNamesDictionary = UserDefaults(suiteName: "group.AsheKube.a-Shell")?.dictionary(forKey: "bookmarkNames")
    var storedNamesDictionary = UserDefaults.standard.dictionary(forKey: "bookmarkNames") ?? [:]
    // if (groupNamesDictionary != nil) {
    //    storedNamesDictionary.merge(groupNamesDictionary!, uniquingKeysWith: { (current, _) in current })
    // }
    // let groupBookmarksDictionary = UserDefaults(suiteName: "group.AsheKube.a-Shell")?.dictionary(forKey: "fileBookmarks")
    var storedBookmarksDictionary =  UserDefaults.standard.dictionary(forKey: "fileBookmarks") ?? [:]
    // if (groupBookmarksDictionary != nil) {
    //    storedBookmarksDictionary.merge(groupBookmarksDictionary!, uniquingKeysWith: { (current, _) in current })
    // }
    var mutableBookmarkDictionary : [String:Any] = storedBookmarksDictionary
    var mutableNamesDictionary : [String:Any] = storedNamesDictionary
    var mustUpdateDictionaries = false
    if (argc == 1) {
        // show all bookmarks
        let sortedKeys = storedNamesDictionary.keys.sorted()
        for key in sortedKeys {
            let urlPath = storedNamesDictionary[key]
            let path = (urlPath as! String)
            let bookmark = storedBookmarksDictionary[path]
            if (bookmark == nil) {
                // not a secured URL, fine:
                fputs("~" + key + ": " + path + "\n", thread_stdout);
            } else {
                var stale = false
                do {
                    _ = try URL(resolvingBookmarkData: bookmark as! Data, bookmarkDataIsStale: &stale)
                }
                catch {
                    NSLog("Could not resolve \(key)")
                    stale = true
                }
                if (!stale) {
                    fputs("~" + key + ": " + path + "\n", thread_stdout);
                } else {
                    // remove the bookmark from both dictionaries:
                    mustUpdateDictionaries = true
                    mutableBookmarkDictionary.removeValue(forKey: path)
                    mutableNamesDictionary.removeValue(forKey: key)
                }
            }
        }
    } else {
        // show bookmarks corresponding to arguments
        for i in 1..<Int(argc) {
            guard let argC = argv?[i] else {
                return 0
            }
            let key = String(cString: argC)
            if let urlPath = storedNamesDictionary[key] {
                let path = (urlPath as! String)
                let bookmark = storedBookmarksDictionary[path]
                if (bookmark == nil) {
                    // not a secured URL, fine:
                    fputs("~" + key + ": " + path + "\n", thread_stdout);
                } else {
                    var stale = false
                    do {
                        _ = try URL(resolvingBookmarkData: bookmark as! Data, bookmarkDataIsStale: &stale)
                    }
                    catch {
                        NSLog("Could not resolve \(key)")
                        stale = true
                    }
                    if (!stale) {
                        fputs("~" + key + ": " + path + "\n", thread_stdout);
                    } else {
                        fputs("\(key): not found (directory removed)", thread_stderr)
                        // remove the bookmark from both dictionaries:
                        mustUpdateDictionaries = true
                        mutableBookmarkDictionary.removeValue(forKey: path)
                        mutableNamesDictionary.removeValue(forKey: key)
                    }
                }
            } else {
                fputs("\(key): not found", thread_stderr)
                if (i == 1) { fputs(usage, thread_stderr) }
            }
        }
    }
    if (mustUpdateDictionaries) {
        UserDefaults.standard.set(mutableBookmarkDictionary, forKey: "fileBookmarks")
        UserDefaults(suiteName: "group.AsheKube.a-Shell")?.set(mutableBookmarkDictionary, forKey: "fileBookmarks")
        UserDefaults.standard.set(mutableNamesDictionary, forKey: "bookmarkNames")
        UserDefaults(suiteName: "group.AsheKube.a-Shell")?.set(mutableNamesDictionary, forKey: "bookmarkNames")
    }
    return 0
}

public func checkBookmarks() {
    // At startup, go through list of bookmarks, check that they are still valid, remove them otherwise
    // and add "home", "shortcuts" and "group".
    var storedNamesDictionary = UserDefaults.standard.dictionary(forKey: "bookmarkNames") ?? [:]
    // let groupNamesDictionary = UserDefaults(suiteName: "group.AsheKube.a-Shell")?.dictionary(forKey: "bookmarkNames")
    // if (groupNamesDictionary != nil) {
    //     storedNamesDictionary.merge(groupNamesDictionary!, uniquingKeysWith: { (current, _) in current })
    // }
    var storedBookmarksDictionary = UserDefaults.standard.dictionary(forKey: "fileBookmarks") ?? [:]
    // let groupBookmarksDictionary = UserDefaults(suiteName: "group.AsheKube.a-Shell")?.dictionary(forKey: "fileBookmarks")
    // if (groupBookmarksDictionary != nil) {
    //     storedBookmarksDictionary.merge(groupBookmarksDictionary!, uniquingKeysWith: { (current, _) in current })
    // }
    var mutableBookmarkDictionary : [String:Any] = storedBookmarksDictionary
    var mutableNamesDictionary : [String:Any] = storedNamesDictionary
    
    for (key, urlPath) in storedNamesDictionary {
        let path = (urlPath as! String)
        if let bookmark = storedBookmarksDictionary[path] {
            var stale = false
            do {
                let bookmarkedUrl = try URL(resolvingBookmarkData: bookmark as! Data, bookmarkDataIsStale: &stale)
                if (!FileManager().isReadableFile(atPath:bookmarkedUrl.path)) {
                    let isSecuredURL = bookmarkedUrl.startAccessingSecurityScopedResource()
                    let isReadable = FileManager().isReadableFile(atPath: bookmarkedUrl.path)
                    if (!(isSecuredURL && isReadable)) {
                        NSLog("Access to \(bookmarkedUrl): isSecuredURL: \(isSecuredURL) isReadable: \(isReadable)")
                        stale = true
                    }
                }
            }
            catch {
                NSLog("Could not resolve \(key)")
                stale = true
            }
            if (stale) {
                // remove the bookmark from both dictionaries:
                mutableBookmarkDictionary.removeValue(forKey: path)
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
    let shortcutsPath = FileManager().containerURL(forSecurityApplicationGroupIdentifier:"group.AsheKube.a-Shell")?.path
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
    UserDefaults(suiteName: "group.AsheKube.a-Shell")?.set(mutableBookmarkDictionary, forKey: "fileBookmarks")
    UserDefaults(suiteName: "group.AsheKube.a-Shell")?.set(mutableNamesDictionary, forKey: "bookmarkNames")
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
    var storedNamesDictionary = UserDefaults.standard.dictionary(forKey: "bookmarkNames") ?? [:]
    // let groupNamesDictionary = UserDefaults(suiteName: "group.AsheKube.a-Shell")?.dictionary(forKey: "bookmarkNames")
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
    UserDefaults(suiteName: "group.AsheKube.a-Shell")?.set(mutableNamesDictionary, forKey: "bookmarkNames")
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
    var storedNamesDictionary = UserDefaults.standard.dictionary(forKey: "bookmarkNames") ?? [:]
    // let groupNamesDictionary = UserDefaults(suiteName: "group.AsheKube.a-Shell")?.dictionary(forKey: "bookmarkNames")
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
    UserDefaults(suiteName: "group.AsheKube.a-Shell")?.set(mutableNamesDictionary, forKey: "bookmarkNames")
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
    var storedNamesDictionary = UserDefaults.standard.dictionary(forKey: "bookmarkNames") ?? [:]
    // let groupNamesDictionary = UserDefaults(suiteName: "group.AsheKube.a-Shell")?.dictionary(forKey: "bookmarkNames")
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
        let shortcutsPath = FileManager().containerURL(forSecurityApplicationGroupIdentifier:"group.AsheKube.a-Shell")?.path
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
        UserDefaults(suiteName: "group.AsheKube.a-Shell")?.set(mutableNamesDictionary, forKey: "bookmarkNames")
    }
    return 0
}

func downloadRemoteFileFromCloud(fileURL: URL) {
    var lastPathComponent = fileURL.lastPathComponent
    // Delete the "." which is at the beginning of the file name
    lastPathComponent.removeFirst()
    let folderPath = fileURL.deletingLastPathComponent().path
    let downloadedFilePath = folderPath + "/" + lastPathComponent.replacingOccurrences(of: ".icloud", with: "")
    do {
        NSLog("Started downloading file \(downloadedFilePath) from iCloud")
        try FileManager().startDownloadingUbiquitousItem(at: URL(fileURLWithPath: downloadedFilePath))
        let startingTime = Date()
        // try downloading the file for 5s, then give up:
        while (!FileManager().fileExists(atPath: fileURL.path) && (Date().timeIntervalSince(startingTime) < 5)) { }
    }
    catch {
        NSLog("Could not download file \(downloadedFilePath) from iCloud")
        // print(error)
    }
}

@_cdecl("downloadFile")
public func downloadFile(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    // download a file from iCloud. Input: filename as ".file.icloud"
    // Possible improvement: also delete the permission bookmark
    guard let commandNameC = argv?[0] else {
        fputs("downloadFile: Can't read command name\n", thread_stderr)
        return 0
    }
    let commandName = String(cString: commandNameC)
    let usage = "downloadFile: force download of files from iCloud\nUsage: " + commandName + " .name.icloud [.name1.icloud .name2.icloud ...]\n"
    guard let args = convertCArguments(argc: argc, argv: argv) else { return 1 }
    if args.count == 1 {
        fputs(usage, thread_stdout)
        return 0
    }
    if ((args[1] == "-h") || (args[1] == "--help")) {
        fputs(usage, thread_stdout)
        return 0
    }
    for i in 1..<args.count {
        downloadRemoteFileFromCloud(fileURL: URL(fileURLWithPath: args[i]))
    }
    return 0
}

@_cdecl("downloadFolder")
public func downloadFolder(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    // download a file from iCloud. Input: filename as ".file.icloud"
    // Possible improvement: also delete the permission bookmark
    guard let commandNameC = argv?[0] else {
        fputs("downloadFolder: Can't read command name\n", thread_stderr)
        return 0
    }
    let commandName = String(cString: commandNameC)
    let usage = "downloadFolder: download all non-downloaded iCloud files for a folder.\nUsage: " + commandName + " [folder1 folder2 ...] (default is current directory)\n"
    guard let args = convertCArguments(argc: argc, argv: argv) else { return 1 }
    if args.count == 1 {
        downloadFilesFromRemoteFolder(fileURL: URL(fileURLWithPath: "."))
        return 0
    }
    if ((args[1] == "-h") || (args[1] == "--help")) {
        fputs(usage, thread_stdout)
        return 0
    }
    for i in 1..<args.count {
        if (FileManager().fileExists(atPath: args[i])) {
            let fileURL = URL(fileURLWithPath: args[i])
            if (fileURL.isDirectory) {
                downloadFilesFromRemoteFolder(fileURL: fileURL)
            } else {
                fputs("downloadFolder: file \(args[i]) is not a directory\n", thread_stdout)
                fputs(usage, thread_stdout)
                return 1
            }
        } else {
            fputs("downloadFolder: file not found: \(args[i])\n", thread_stdout)
            fputs(usage, thread_stdout)
            return 1
        }
    }
    return 0
}

func downloadFilesFromRemoteFolder(fileURL: URL) {
    // If it's a directory, download all files inside
    if let urls = try? FileManager().contentsOfDirectory(at: fileURL, includingPropertiesForKeys: nil, options: []) {
        for myURL in urls {
            // We have our url
            let lastPathComponent = myURL.lastPathComponent
            if lastPathComponent.contains(".icloud") {
                downloadRemoteFileFromCloud(fileURL: myURL)
            }
        }
    }
}

public func downloadRemoteFile(fileURL: URL) -> Bool {
    if (FileManager().fileExists(atPath: fileURL.path)) {
        if (fileURL.isDirectory) {
            downloadFilesFromRemoteFolder(fileURL: fileURL)
        }
        return true
    }
    NSLog("Try downloading file from iCloud: \(fileURL)")
    do {
        // this will work with iCloud, but not Dropbox or Microsoft OneDrive, who have a specific API.
        // TODO: find out how to authorize a-Shell for Dropbox, OneDrive, GoogleDrive.
        try FileManager().startDownloadingUbiquitousItem(at: fileURL)
        let startingTime = Date()
        // try downloading the file for 5s, then give up:
        while (!FileManager().fileExists(atPath: fileURL.path) && (Date().timeIntervalSince(startingTime) < 5)) { }
        // TODO: add an alert, ask if user wants to continue
        // NSLog("Done downloading, new status: \(FileManager().fileExists(atPath: fileURL.path))")
        if (FileManager().fileExists(atPath: fileURL.path)) {
            if (fileURL.isDirectory) {
                downloadFilesFromRemoteFolder(fileURL: fileURL)
            }
            return true
        }
    }
    catch {
        NSLog("Could not download file from iCloud")
        // print(error)
    }
    return false
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
    // var groupBookmarksDictionary = UserDefaults(suiteName: "group.AsheKube.a-Shell")?.dictionary(forKey: "fileBookmarks")
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
        UserDefaults(suiteName: "group.AsheKube.a-Shell")?.set(storedBookmarksDictionary, forKey: "fileBookmarks")
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
    // let groupNamesDictionary = UserDefaults(suiteName: "group.AsheKube.a-Shell")?.dictionary(forKey: "bookmarkNames")
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
        var isDirectory: ObjCBool = false
        let fileExists = FileManager().fileExists(atPath: pathString, isDirectory: &isDirectory)
        if (fileExists && !isDirectory.boolValue) {
            // it's a file: edit it with default editor:
            // TODO: customize editor
            executeCommandAndWait(command: "vim " + pathString.replacingOccurrences(of: " ", with: "\\ "))
        } else {
            // probably a stale bookmark:
            fputs("jump: bookmark for \(name) is no longer valid.\n", thread_stderr)
            storedNamesDictionary.removeValue(forKey: name)
            UserDefaults.standard.set(storedNamesDictionary, forKey: "bookmarkNames")
            UserDefaults(suiteName: "group.AsheKube.a-Shell")?.set(storedNamesDictionary, forKey: "bookmarkNames")
        }
    }
    return 0
}
    
@_cdecl("play_main")
public func play_media(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    let args = convertCArguments(argc: argc, argv: argv)
    if let delegate = currentDelegate {
        delegate.resignFirstResponder()
        return delegate.play_media(arguments: args)
    }
    return 0
}

@_cdecl("preview_main")
public func preview(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    let args = convertCArguments(argc: argc, argv: argv)
    if let delegate = currentDelegate {
        delegate.resignFirstResponder()
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

@_cdecl("openurl_main")
public func openurl_main(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    let usage = "Usage: openurl url\nYou can change the default browser with BROWSER env var:\n" + __known_browsers.joined(separator: ", ") + "\n"
    
    guard let args = convertCArguments(argc: argc, argv: argv) else {
        fputs(usage, thread_stderr)
        return -1
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
        if let browserEnvVar = getenv("BROWSER") {
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
        urlString = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? urlString
        locationUrl = URL(string: urlString)
    }
    guard locationUrl != nil else {
        fputs("Invalid URL: \(urlString).\n", thread_stderr)
        if (genericCall) {
            fputs(usage, thread_stderr)
        } else {
            fputs("Usage: \(args[0]) url\n", thread_stderr)
        }
        return -1
    }
    if let delegate = currentDelegate {
        DispatchQueue.main.async {
            if (browser == "internalbrowser") {
                delegate.openURLInWindow(url: locationUrl!)
            } else {
                let browserAppUrl = __browser_app_url(inputUrl: locationUrl!, browser: browser)
                delegate.windowScene?.open(browserAppUrl, options: .none)
            }
        }
    }
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
    guard args!.count >= 1  else {
        fputs("Usage: \(args![0]) [name]\n", thread_stderr)
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
            delegate.resignFirstResponder()
            delegate.webView?.evaluateJavaScript("window.interactiveCommandRunning = false;") { (result, error) in
                // if let error = error { print(error) }
                // if let result = result { print(result) }
            }
        }
    }
}

@_cdecl("storeInteractive")
public func storeInteractive() -> Int32 {
    if (runningInExtension) {
        return 0
    }
    var returnValue:Int32 = -1;
    var waitingForAnswer = true
    DispatchQueue.main.async {
        if let delegate = currentDelegate {
            delegate.resignFirstResponder()
            delegate.webView?.evaluateJavaScript("window.interactiveCommandRunning;") { (result, error) in
                // if let error = error { print(error); }
                if let result = result as? Int32 { returnValue = result; }
                waitingForAnswer = false
            }
        }
    }
    // We need to place something in this loop, otherwise it gets removed by the optimizer.
    while (waitingForAnswer) {
        if (thread_stdout != nil) { fflush(thread_stdout) }
        if (thread_stderr != nil) { fflush(thread_stderr) }
    }
    // NSLog("Returning from storeInteractive, result= \(returnValue)")
    return returnValue;
}

@_cdecl("startInteractive")
public func startInteractive() {
    if (runningInExtension) {
        return
    }
    DispatchQueue.main.async {
        if let delegate = currentDelegate {
            delegate.resignFirstResponder()
            delegate.webView?.evaluateJavaScript("window.interactiveCommandRunning = true;") { (result, error) in
                // if let error = error { print(error) }
                // if let result = result { print(result) }
            }
        }
    }
}

@_cdecl("needLLVM")
public func needLLVM(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    guard let args = convertCArguments(argc: argc, argv: argv) else { return 1 }
    fputs("In order to use \(args[0]), you need to install or update the C SDK with 'pkg install llvm-18'.\n", thread_stderr)
    return 0
}

@_cdecl("needTeX")
public func needTeX(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    guard let args = convertCArguments(argc: argc, argv: argv) else { return 1 }
    let libraryURL = try! FileManager().url(for: .libraryDirectory,
                                            in: .userDomainMask,
                                            appropriateFor: nil,
                                            create: true)
    let texliveTestFile = libraryURL.appendingPathComponent("texlive/2023/texmf-dist/tex/plain/base/plain.tex")
    if (FileManager().fileExists(atPath: texliveTestFile.path)) {
        fputs("You currently have texlive-2023 installed. In order to to use \(args[0]), you need to update the distribution to texlive-2024 with 'pkg install texlive'.\n", thread_stderr)
    } else {
        fputs("In order to use \(args[0]), you need to install the texlive distribution with 'pkg install texlive'.\n", thread_stderr)
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
    let texliveTestFile = libraryURL.appendingPathComponent("texlive/2024/texmf-dist/tex/plain/base/plain.tex")
    if (FileManager().fileExists(atPath: texliveTestFile.path)) {
        fputs("In order to use \(args[0]), you need to install the OpenType/TrueType fonts with 'pkg install texlive_fonts'.\n", thread_stderr)
    } else {
        fputs("In order to to use \(args[0]), you need to install the texlive distribution 'pkg install texlive' and the OpenType/TrueType fonts with 'pkg install texlive_fonts'.\n", thread_stderr)
    }
    return 0
}

@_cdecl("updateCommands")
public func updateCommands(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    // Small function to activate or deactivate C and TeX commands after installing the auxiliary files
    let usage = "Small command to update the list of commands available after installing or removing LLVM (C/C++) or TeX auxiliary files.\n"
    
    guard let args = convertCArguments(argc: argc, argv: argv) else {
        if (thread_stderr != nil) {
            fputs(usage, thread_stderr)
        }
        return -1
    }
    
    if (argc >= 2) {
        if (thread_stderr != nil) {
            fputs(usage, thread_stderr)
        }
        return -1
    }
    
    let libraryURL = try! FileManager().url(for: .libraryDirectory,
                                            in: .userDomainMask,
                                            appropriateFor: nil,
                                            create: true)
    // LLVM C SDK: check that ~/Library/usr/lib/clang/14.0.0 exists. If yes, activate LLVMcommands. Otherwise, activate fake LLVM commands.
    let headerUrl = libraryURL.appendingPathComponent("usr/lib/clang/18/include/float.h")
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
    let texliveTestFile = libraryURL.appendingPathComponent("texlive/2024/texmf-dist/tex/plain/base/plain.tex")
    if FileManager().fileExists(atPath: texliveTestFile.path) {
        addCommandList(Bundle.main.path(forResource: "texCommandsDictionary", ofType: "plist"))
        // LuaTeX and XeTeX: extra fonts files:
        let luatexTestFile = libraryURL.appendingPathComponent("texlive/2024/texmf-dist/fonts/opentype/public/lm/lmroman10-regular.otf")
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
            let location = "../texlive/2024/texmf-dist/" + script[1]
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
    let executablePath = String(cString: getenv("PATH"))
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
    var javascriptCommand = "commandList = ["
    for command in commandsArray {
        javascriptCommand += "\"" + command + "\", "
    }
    javascriptCommand += "];"
    DispatchQueue.main.async {
        if let delegate = currentDelegate {
            delegate.resignFirstResponder()
            delegate.webView?.evaluateJavaScript(javascriptCommand) { (result, error) in
                if let error = error {
                    NSLog("Error in creating command list, line = \(javascriptCommand) error = \(error)")
                }
                // if let result = result as? Int32 {  }
            }
        }
    }
    return 0
}

public func executeCommandAndWait(command: String) {
    NSLog("executeCommandAndWait: \(command)")
    resultStack.removeAll()
    let pid = ios_fork()
    _ = ios_system(command)
    fflush(thread_stdout)
    ios_waitpid(pid)
    ios_releaseThreadId(pid)
}


