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

@_cdecl("wasm")
public func wasm(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    let args = convertCArguments(argc: argc, argv: argv)
    if let delegate = currentDelegate {
        return delegate.executeWebAssembly(arguments: args)
    }
    return 0
}

@_cdecl("jsc")
public func jsc(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    let args = convertCArguments(argc: argc, argv: argv)
    if let delegate = currentDelegate {
        delegate.executeJavascript(arguments: args)
    }
    return 0
}

@_cdecl("help")
public func help(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    if let delegate = currentDelegate {
        let helpText = """
a-Shell is a terminal emulator for iOS, with many Unix commands: ls, pwd, tar, mkdir, grep....

a-Shell can do most of the things you can do in a terminal, locally on your iPhone or iPad. You can redirect command output to a file with ">" and you can pipe commands with "|".

- customize appearance with config
- pickFolder: open, bookmark and access a directory anywhere (another app, iCloud, WorkingCopy, file providers...)
- newWindow: open a new window
- exit: close the current window

- Edit files with vim and ed.
- Transfer files with curl, tar, scp and sftp.
- Process files with python3, lua, jsc, clang, pdflatex, lualatex.
- Open files in other apps with open, play sound and video with play, preview with view.
- For network queries: nslookup, ping, host, whois, ifconfig...

You can download more commands at: https://github.com/holzschu/a-Shell-commands/
Follow us on Twitter (@a_Shell_iOS) and github (https://github.com/holzschu/a-shell/issues).
"""
        
        if (argc == 1) {
            delegate.printText(string: helpText)
            if (!UserDefaults.standard.bool(forKey: "TeXEnabled")) {
                delegate.printText(string: "\nTo install TeX, just type any tex command and follow the instructions (same with luatex).\n")
            }
            let zshmarks = UserDefaults.standard.bool(forKey: "zshmarks")
            let bashmarks = UserDefaults.standard.bool(forKey: "bashmarks")
            if (zshmarks && bashmarks) {
                delegate.printText(string: "\n- bookmark the current directory with \"bookmark <name>\" or \"s <name>\", and access it later with \"jump <name>\" or \"g <name>\".\n- showmarks, l or p: show current list of bookmarks\n- renamemark or r, deletemark or d: change list of bookmarks\n")
            } else if (zshmarks) {
                delegate.printText(string: "\n- bookmark the current directory with \"bookmark <name>\" and access it later with \"jump <name>\".\n- showmarks: show current list of bookmarks\n- renamemark, deletemark: change list of bookmarks\n")
            } else if (bashmarks) {
                delegate.printText(string: "\n- bookmark the current directory with \"s <name>\", and access it later with \"g <name>\".\n- l or p: show current list of bookmarks\n- r <name1> <name2>: rename a bookmark.\n- d <name>: delete a bookmark\n")
            }
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
                    do {
                        // We don't check for exec status, because files inside $APPDIR have no x bit set.
                        for file in try FileManager().contentsOfDirectory(atPath: directory) {
                            commandsArray.append(URL(fileURLWithPath: file).lastPathComponent)
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
a-Shell owes to many open-source contributors. The current code contains contributions from: Yury Korolev, Ian McDowell, Louis d'Hauwe, Anders Borum, Adrian Labbé, Kenta Kubo, Ian Willis and suggestions for improvements from many others.

Most terminal commands are from the BSD distribution, mainly through the Apple OpenSource program.

bc: Gavin Howard BSD port of bc, https://github.com/gavinhoward/bc
curl: Daniel Stenberg and contributors, https://github.com/curl/curl
ctags: https://github.com/universal-ctags/ctags/
file: https://github.com/file/file/
ImageMagick: ImageMagick Studio LLC, https://imagemagick.org
Lua: lua.org, PUC-Rio, https://www.lua.org/
LuaTeX: The LuaTeX team, http://www.luatex.org
llvm/clang: the LLVM foundation
openSSL and libSSH2: port by Felix Schulze, https://github.com/x2on/libssh2-for-iOS
Python3: Python Software Foundation, https://www.python.org/about/
tar: https://libarchive.org
tree: http://mama.indstate.edu/users/ice/tree/
TeX: Donald Knuth and TUG, https://tug.org. TeX distribution is texlive 2019.
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


@_cdecl("tex")
public func tex(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    let command = argv![0]
    if (downloadingTeXError != "") {
        fputs("There was an error in downloading the TeX distribution: " + downloadingTeXError + "\n", thread_stderr)
        downloadingTeXError = ""
    }
    if (downloadingTeX) {
        let percentString = String(format: "%.02f", percentTeXDownloadComplete)
        fputs("Currently updating the TeX distribution. (" + percentString + " % complete)\n", thread_stderr)
        fputs( command, thread_stderr)
        fputs(" will be activated as soon as the download is finished.\n", thread_stderr)
        return 0
    }
    fputs(command, thread_stderr)
    fputs(" requires the TeX distribution, which is not currently installed.\nDo you want to download and install it? (0.8 GB) (y/N)", thread_stderr)
    fflush(thread_stderr)
    var byte: Int8 = 0
    let count = read(fileno(thread_stdin), &byte, 1)
    if (byte == 121) || (byte == 89) {
        fputs("Downloading the TeX distribution, this may take some time...\n", thread_stderr)
        fputs("(you can  remove it later using Settings)\n", thread_stderr)
        UserDefaults.standard.set(true, forKey: "TeXEnabled")
        return 0
    }
    return 0
}

@_cdecl("luatex")
public func luatex(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    let command = argv![0]
    if (downloadingOpentypeError != "") {
        fputs("There was an error in downloading the LuaTeX extension: ", thread_stderr)
        fputs(downloadingOpentypeError + "\n", thread_stderr)
        downloadingOpentypeError = ""
    }
    if (downloadingTeX) {
        let percentString = String(format: "%.02f", percentTeXDownloadComplete)
        fputs("Currently updating the TeX distribution. (" + percentString + " % complete)\n", thread_stderr)
    }
    if (downloadingOpentype) {
        let percentString = String(format: "%.02f", 100.0 * percentOpentypeDownloadComplete)
        fputs("Currently updating the LuaTeX extension. (" + percentString + " % complete)\n", thread_stderr)
        fputs( command, thread_stderr)
        fputs(" will be activated as soon as the download is finished.\n", thread_stderr)
        return 0
    }
    fputs(command, thread_stderr)
    if (UserDefaults.standard.bool(forKey: "TeXEnabled")) {
        fputs(" requires the LuaTeX extension on top of the TeX distribution\nDo you want to download and install them? (0.3 GB) (y/N)", thread_stderr)
    } else {
        fputs(" requires the TeX distribution, which is not currently installed, along with the LuaTeX extension.\nDo you want to download and install them? (2 GB) (y/N)", thread_stderr)
    }
    fflush(thread_stderr)
    var byte: Int8 = 0
    let count = read(fileno(thread_stdin), &byte, 1)
    if (byte == 121) || (byte == 89) {
        if (UserDefaults.standard.bool(forKey: "TeXEnabled")) {
            fputs("Downloading the LuaTeX extension, this may take some time...", thread_stderr)
        } else {
            fputs("Downloading the TeX distribution with LuaTeX extension, this may take some time...", thread_stderr)
            UserDefaults.standard.set(true, forKey: "TeXEnabled")
        }
        UserDefaults.standard.set(true, forKey: "TeXOpenType")
        fputs("\n(you can  remove them later using Settings)\n", thread_stderr)
        return 0
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
    let shortUsage = "usage: config [-s font size][-n font name][-b background color][-f foreground color][-c cursor color][-dgpr]\n"
    let usageString = """
    usage: config [-s font size][-n font name][-b background color][-f foreground color][-c cursor color][-g][-p][-d][-r]
    For all parameters: "default" to get the default value currently stored, "factory" to get a-Shell factory defaults (\(factoryFontName), \(factoryFontSize) pts, colors from system).
    Colors can be defined by names, RGB triplets "red green blue" or HexStrings "#00FF00"
    -s | --size: set font size
    -n | --name: set font name. Nothing or "picker" to get the system font picker.
    -b | --background: set background color
    -f | --foreground: set foreground color
    -c | --cursor: set cursor and hilight color
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
                    terminalFontName = name
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
        case "--show":
            delegate?.showConfigWindow()
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
        delegate?.writeConfigWindow()
    } else {
        delegate?.configWindow(fontSize: terminalFontSize, fontName: terminalFontName, backgroundColor: terminalBackgroundColor, foregroundColor: terminalForegroundColor, cursorColor: terminalCursorColor)
    }
    if (makeGlobal) {
        // If nothing except "-p" (and possibly -d or -r): extend current window settings to all open windows
        // Otherwise, go through all delegates, and apply the same change to them:
        if (argumentsSet) {
            for scene in UIApplication.shared.connectedScenes {
                if let delegate: SceneDelegate = scene.delegate as? SceneDelegate {
                    delegate.configWindow(fontSize: terminalFontSize, fontName: terminalFontName, backgroundColor: terminalBackgroundColor, foregroundColor: terminalForegroundColor, cursorColor: terminalCursorColor)
                }
            }
        } else {
            for scene in UIApplication.shared.connectedScenes {
                if let delegate2: SceneDelegate = scene.delegate as? SceneDelegate {
                    if (delegate2 != delegate) {
                        delegate2.configWindow(fontSize: delegate?.terminalFontSize, fontName: delegate?.terminalFontName, backgroundColor: delegate?.terminalBackgroundColor, foregroundColor: delegate?.terminalForegroundColor, cursorColor: delegate?.terminalCursorColor)
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
    let storedNamesDictionary = UserDefaults.standard.dictionary(forKey: "bookmarkNames") ?? [:]
    let storedBookmarksDictionary = UserDefaults.standard.dictionary(forKey: "fileBookmarks") ?? [:]
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
                fputs(key + ": " + path + "\n", thread_stdout);
            } else {
                var stale = false
                do {
                    let previousURL = try URL(resolvingBookmarkData: bookmark as! Data, bookmarkDataIsStale: &stale)
                }
                catch {
                    NSLog("Could not resolve \(key)")
                    stale = true
                }
                if (!stale) {
                    fputs(key + ": " + path + "\n", thread_stdout);
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
            let urlPath = storedNamesDictionary[key]
            if (urlPath != nil) {
                let path = (urlPath as! String)
                let bookmark = storedBookmarksDictionary[path]
                if (bookmark == nil) {
                    // not a secured URL, fine:
                    fputs(key + ": " + path + "\n", thread_stdout);
                } else {
                    var stale = false
                    do {
                        let previousURL = try URL(resolvingBookmarkData: bookmark as! Data, bookmarkDataIsStale: &stale)
                    }
                    catch {
                        NSLog("Could not resolve \(key)")
                        stale = true
                    }
                    if (!stale) {
                        fputs(key + ": " + path + "\n", thread_stdout);
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
        UserDefaults.standard.set(mutableNamesDictionary, forKey: "bookmarkNames")
    }
    return 0
}

public func checkBookmarks() {
    // At startup, go through list of bookmarks, check that they are still valid, remove them otherwise
    // and add "home", "shortcuts" and "group".
    let storedNamesDictionary = UserDefaults.standard.dictionary(forKey: "bookmarkNames") ?? [:]
    let storedBookmarksDictionary = UserDefaults.standard.dictionary(forKey: "fileBookmarks") ?? [:]
    var mutableBookmarkDictionary : [String:Any] = storedBookmarksDictionary
    var mutableNamesDictionary : [String:Any] = storedNamesDictionary
    var mustUpdateDictionaries = false
    for (key, urlPath) in storedNamesDictionary {
        let path = (urlPath as! String)
        let bookmark = storedBookmarksDictionary[path]
        if (bookmark != nil) {
            var stale = false
            do {
                let previousURL = try URL(resolvingBookmarkData: bookmark as! Data, bookmarkDataIsStale: &stale)
            }
            catch {
                NSLog("Could not resolve \(key)")
                stale = true
            }
            if (stale) {
                // remove the bookmark from both dictionaries:
                mustUpdateDictionaries = true
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
        mustUpdateDictionaries = true
    }
    let storedShortcuts = mutableNamesDictionary["shortcuts"] as? String
    let shortcutsPath = FileManager().containerURL(forSecurityApplicationGroupIdentifier:"group.AsheKube.a-Shell")?.path
    if (storedShortcuts == nil) || (storedShortcuts != shortcutsPath) {
        mutableNamesDictionary["shortcuts"] = shortcutsPath
        mustUpdateDictionaries = true
    }
    let storedGroup = mutableNamesDictionary["group"] as? String
    if (storedGroup == nil) || (storedGroup != shortcutsPath) {
        mutableNamesDictionary["group"] = shortcutsPath
        mustUpdateDictionaries = true
    }
    if (mustUpdateDictionaries) {
        UserDefaults.standard.set(mutableBookmarkDictionary, forKey: "fileBookmarks")
        UserDefaults.standard.set(mutableNamesDictionary, forKey: "bookmarkNames")
    }
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
    let firstArgC = argv?[1]
    if (firstArgC != nil) {
        if (String(cString: firstArgC!).hasPrefix("-h")) {
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
    // Does "name" alrady exist? If so create a unique name:
    var newName = name
    var counter = 0
    var existingURLPath = storedNamesDictionary[newName]
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
        existingURLPath = storedNamesDictionary[newName]
    }
    var mutableNamesDictionary : [String:Any] = storedNamesDictionary
    mutableNamesDictionary.updateValue(filePath, forKey: newName)
    UserDefaults.standard.set(mutableNamesDictionary, forKey: "bookmarkNames")
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
    let usage = "Usage: " + commandName + " name [name1 name2 name3...]\n"
    let storedNamesDictionary = UserDefaults.standard.dictionary(forKey: "bookmarkNames") ?? [:]
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
    if (mustUpdateDictionary) {
        UserDefaults.standard.set(mutableNamesDictionary, forKey: "bookmarkNames")
    }
    return 0
}

public func downloadRemoteFile(fileURL: URL) -> Bool {
    if (FileManager().fileExists(atPath: fileURL.path)) {
        return true
    }
    // NSLog("Try downloading file from iCloud: \(fileURL)")
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
            return true
        }
    }
    catch {
        NSLog("Could not download file from iCloud")
        print(error)
    }
    return false
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
                        fputs("Could not change directory to \(path)", thread_stderr)
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
            let pid = ios_fork()
            // TODO: customize editor
            ios_system("vim " + pathString.replacingOccurrences(of: " ", with: "\\ "))
            ios_waitpid(pid)
        } else {
            // probably a stale bookmark:
            fputs("jump: bookmark for \(name) is no longer valid.\n", thread_stderr)
            storedNamesDictionary.removeValue(forKey: name)
            UserDefaults.standard.set(storedNamesDictionary, forKey: "bookmarkNames")
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
