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


@_cdecl("history")
public func history(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    let opaquePointer = OpaquePointer(ios_getContext())
    guard let stringPointer = UnsafeMutablePointer<CChar>(opaquePointer) else { return 0 }
    let currentSessionIdentifier = String(cString: stringPointer)
    for scene in UIApplication.shared.connectedScenes {
        if (scene.session.persistentIdentifier == currentSessionIdentifier) {
            let delegate: SceneDelegate = scene.delegate as! SceneDelegate
            delegate.printHistory()
            return 0
        }
    }
    return 0
}

@_cdecl("clear")
public func clear(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    let opaquePointer = OpaquePointer(ios_getContext())
    guard let stringPointer = UnsafeMutablePointer<CChar>(opaquePointer) else { return 0 }
    let currentSessionIdentifier = String(cString: stringPointer)
    for scene in UIApplication.shared.connectedScenes {
        if (scene.session.persistentIdentifier == currentSessionIdentifier) {
            let delegate: SceneDelegate = scene.delegate as! SceneDelegate
            delegate.clearScreen()
            return 0
        }
    }
    return 0
}

@_cdecl("wasm")
public func wasm(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    let args = convertCArguments(argc: argc, argv: argv)
    let opaquePointer = OpaquePointer(ios_getContext())
    guard let stringPointer = UnsafeMutablePointer<CChar>(opaquePointer) else { return 0 }
    let currentSessionIdentifier = String(cString: stringPointer)
    for scene in UIApplication.shared.connectedScenes {
        if (scene.session.persistentIdentifier == currentSessionIdentifier) {
            let delegate: SceneDelegate = scene.delegate as! SceneDelegate
            delegate.executeWebAssembly(arguments: args)
            return 0
        }
    }
    return 0
}

@_cdecl("help")
public func help(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    let opaquePointer = OpaquePointer(ios_getContext())
    guard let stringPointer = UnsafeMutablePointer<CChar>(opaquePointer) else { return 0 }
    let currentSessionIdentifier = String(cString: stringPointer)
    for scene in UIApplication.shared.connectedScenes {
        if (scene.session.persistentIdentifier == currentSessionIdentifier) {
            let delegate: SceneDelegate = scene.delegate as! SceneDelegate
            let helpText = """
a-Shell is a terminal emulator for iOS, with many Unix commands: ls, pwd, tar, mkdir, grep....

a-Shell can do most of the things you can do in a terminal, locally on your iPhone or iPad. You can redirect command output to a file with ">" and you can pipe commands with "|".

Edit files with vim and ed.
Transfer files with curl, tar, scp and sftp.
Process files with python3, lua, pdflatex, lualatex.
For network queries: nslookup, ping, host, whois, ifconfig.

For a full list of commands, type help -l

"""
            if (argc == 1) {
                delegate.printText(string: helpText)
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
                    NSLog("\(executablePath)")
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
            return 0
        }
    }
    return 0
}

@_cdecl("credits")
public func credits(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    // let rootVC:UIViewController? = nil
    let opaquePointer = OpaquePointer(ios_getContext())
    guard let stringPointer = UnsafeMutablePointer<CChar>(opaquePointer) else { return 0 }
    let currentSessionIdentifier = String(cString: stringPointer)
    for scene in UIApplication.shared.connectedScenes {
        if (scene.session.persistentIdentifier == currentSessionIdentifier) {
            let delegate: SceneDelegate = scene.delegate as! SceneDelegate
            let creditText = """
a-Shell owes to many open-source contributors. The current code contains contributions from: Yury Korolev, Ian McDowell, Louis d'Hauwe, Anders Borum, Adrian Labbé and suggestions for improvements from many others.

Most terminal commands are from the BSD distribution, mainly through the Apple OpenSource program.

bc: Gavin Howard BSD port of bc, https://github.com/gavinhoward/bc
curl: Daniel Stenberg and contributors, https://github.com/curl/curl
Lua: lua.org, PUC-Rio, https://www.lua.org/l
LuaTeX: The LuaTeX team, http://www.luatex.org
openSSL and libSSH2: port by Felix Schulze, https://github.com/x2on/libssh2-for-iOS
Python3: Python Software Foundation, https://www.python.org/about/
tar: https://libarchive.org
TeX: Donald Knuth and TUG, https://tug.org
Vim: Bram Moolenaar and the Vim community, https://www.vim.org

"""
                delegate.printText(string: creditText)
            return 0
        }
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
    fputs(" requires the TeX distribution, which is not currently installed.\nDo you want to download and install it? (1.8 GB) (y/N)", thread_stderr)
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
        fputs(" requires the LuaTeX extension on top of the TeX distribution\nDo you want to download and install them? (0.5 GB) (y/N)", thread_stderr)
    } else {
        fputs(" requires the TeX distribution, which is not currently installed, along with the LuaTeX extension.\nDo you want to download and install them? (2.3 GB) (y/N)", thread_stderr)
    }
    fflush(thread_stderr)
    var byte: Int8 = 0
    let count = read(fileno(thread_stdin), &byte, 1)
    if (byte == 121) || (byte == 89) {
        if (UserDefaults.standard.bool(forKey: "TeXEnabled")) {
            fputs("Downloading the LuaTeX extension, this may take some time...", thread_stderr)
        } else {
            fputs("Downloading the TeX distribution with LuaTeX extnesion, this may take some time...", thread_stderr)
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
    let opaquePointer = OpaquePointer(ios_getContext())
    guard let stringPointer = UnsafeMutablePointer<CChar>(opaquePointer) else { return 0 }
    let currentSessionIdentifier = String(cString: stringPointer)
    for scene in UIApplication.shared.connectedScenes {
        if (scene.session.persistentIdentifier == currentSessionIdentifier) {
            let delegate: SceneDelegate = scene.delegate as! SceneDelegate
            delegate.resignFirstResponder()
            delegate.pickFolder()
            return 0
        }
    }

    return 0
}
