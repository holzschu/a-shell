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

- pickFolder: open, bookmark and access a directory anywhere (another app, iCloud, WorkingCopy, file providers...)
- newWindow: open a new window
- exit: close the current window

- Edit files with vim and ed.
- Transfer files with curl, tar, scp and sftp.
- Process files with python3, lua, pdflatex, lualatex.
- For network queries: nslookup, ping, host, whois, ifconfig...
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
TeX: Donald Knuth and TUG, https://tug.org. TeX distribution is texlive 2019.
Vim: Bram Moolenaar and the Vim community, https://www.vim.org
Vim-session: Peter Odding, http://peterodding.com/code/vim/session

zshmarks-style bookmarks inspired by zshmarks: https://github.com/jocelynmallon/zshmarks
bashmarks-style bookmarks inspired by bashmarks: https://github.com/huyng/bashmarks
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
    let storedBookmarksDictionary = UserDefaults.standard.dictionary(forKey: "fileBookmarks") ?? [:]
    // bookmark could also be for a parent directory of fileURK --> we loop over all of them
    while (fileURL.pathComponents.count > 7) {
        // "7" corresponds to: /var/mobile/Containers/Data/Application/4AA730AE-A7CF-4A6F-BA65-BD2ADA01F8B4/Documents/
        // (shortest possible path authorized)
        NSLog("Trying with \(fileURL.path)")
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
                fclose(thread_stderr)
                thread_stderr = old_thread_stderr
                fputs("Could not resolve secure bookmark for \(newPath)", thread_stderr)
                continue // maybe there is another bookmark that will work?
            }
            if (!stale) {
                let isSecuredURL = bookmarkedURL.startAccessingSecurityScopedResource()
                let isReadable = FileManager().isReadableFile(atPath: path)
                guard isSecuredURL && isReadable else {
                    fclose(thread_stderr)
                    thread_stderr = old_thread_stderr
                    fputs("Could not access \(path)", thread_stderr)
                    continue // maybe there is another bookmark that will work?
                    // return true
                }
                // If it's on iCloud, download the directory content
                if (!downloadRemoteFile(fileURL: bookmarkedURL)) {
                    if (isSecuredURL) {
                        bookmarkedURL.stopAccessingSecurityScopedResource()
                    }
                    fclose(thread_stderr)
                    thread_stderr = old_thread_stderr
                    fputs("Could not download \(path)", thread_stderr)
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
            }
        }
    }
    fclose(thread_stderr)
    thread_stderr = old_thread_stderr
    return originalFileURL.isDirectory
}

@_cdecl("jump")
public func jump(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    // List the bookmark already stored:
    guard let commandNameC = argv?[0] else {
        fputs("deletemark: Can't read command name\n", thread_stderr)
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
    let storedNamesDictionary = UserDefaults.standard.dictionary(forKey: "bookmarkNames") ?? [:]
    guard let path = storedNamesDictionary[name] else {
        fputs("jump: \(name) not found.\n", thread_stderr)
        return 1
    }
    let pathString = path as! String
    // We call cd_main so that "cd -" can still work.
    if (changeDirectory(path: pathString)) {
        return 0
    } else {
        // it's a file: edit it with default editor:
        let pid = ios_fork()
        // TODO: customize editor
        ios_system("vim " + pathString.replacingOccurrences(of: " ", with: "\\ "))
        ios_waitpid(pid)
    }
    return 0
}
    
