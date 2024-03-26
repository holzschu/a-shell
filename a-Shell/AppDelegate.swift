//
//
//  AppDelegate.swift
//  a-Shell
//
//  Created by Nicolas Holzschuch on 30/06/2019.
//  Copyright © 2019 AsheKube. All rights reserved.
//

import UIKit
import ios_system
import UserNotifications
import Compression
import Intents // for shortcuts
import AVFoundation // for media playback
import TipKit // Display some helpful messages for users

var downloadingTeX = false
var percentTeXDownloadComplete = 0.0
var downloadingOpentype = false
var percentOpentypeDownloadComplete = 0.0
let installQueue = DispatchQueue(label: "installFiles", qos: .userInteractive) // high priority, but not blocking.
// Need SDK install to be over before starting commands.
var appDependentPath: String = "" // part of the path that depends on the App location (home, appdir)
let __known_browsers = ["internalbrowser", "googlechrome", "firefox", "safari", "yandexbrowser", "brave", "opera"]

@objcMembers
@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var TeXEnabled = false;
    var OpentypeEnabled = false;
    // to update Python distribution at each version update
    var versionUpToDate = true
    var libraryFilesUpToDate = true
    let moveFilesQueue = DispatchQueue(label: "moveFiles", qos: .utility) // low priority

    // Which version of the app are we running? a-Shell, a-Shell-mini, a-Shell-pro...? (no spaces in name)
    var appVersion: String? {
        // Bundle.main.infoDictionary?["CFBundleDisplayName"] = a-Shell
        // Bundle.main.infoDictionary?["CFBundleIdentifier"] = AsheKube.a-Shell
        // Bundle.main.infoDictionary?["CFBundleName"] = a-Shell
        return Bundle.main.infoDictionary?["CFBundleName"] as? String
    }
    
    func createDirectory(localURL: URL) -> Bool {
        do {
            if (FileManager().fileExists(atPath: localURL.path) && !localURL.isDirectory) {
                try FileManager().removeItem(at: localURL)
            }
            if (!FileManager().fileExists(atPath: localURL.path)) {
                try FileManager().createDirectory(atPath: localURL.path, withIntermediateDirectories: true)
            }
        } catch {
            // NSLog("Error in creating directory \(localURL.path): \(error)")
            return false
        }
        return true
    }
    
    func needToUpdateCFiles() -> Bool {
        // Check that the C SDK files are present:
        let libraryURL = try! FileManager().url(for: .libraryDirectory,
                                                in: .userDomainMask,
                                                appropriateFor: nil,
                                                create: true)
        // NSLog("Library file exists: \(FileManager().fileExists(atPath: libraryURL.appendingPathComponent("usr/lib/wasm32-wasi/libwasi-emulated-mman.a").path))")
        // NSLog("Header file exists: \(FileManager().fileExists(atPath: libraryURL.appendingPathComponent("usr/include/stdio.h").path))")
        return !(FileManager().fileExists(atPath: libraryURL.appendingPathComponent("usr/lib/wasm32-wasi/libwasi-emulated-mman.a").path)
         && FileManager().fileExists(atPath: libraryURL.appendingPathComponent("usr/include/stdio.h").path))
    }
    
    func versionNumberIncreased() -> Bool {
        // do it with UserDefaults, not storing in files
        UserDefaults.standard.register(defaults: ["versionInstalled" : "0.0"])
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
        let currentBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as! String
        let currentVersionNumbers = currentVersion.split(separator: ".")
        let majorCurrent = Int(currentVersionNumbers[0])!
        let minorCurrent = Int(currentVersionNumbers[1])!
        let installedVersion = UserDefaults.standard.string(forKey: "versionInstalled")
        if (installedVersion == "0.0") {
            return false // it's the 1st time we run the app
        }
        let buildNumberInstalled = Int(UserDefaults.standard.string(forKey: "buildNumber") ?? "0")!
        let currentBuildInt = Int(currentBuild)!
        let installedVersionNumbers = installedVersion!.split(separator: ".")
        let majorInstalled = Int(installedVersionNumbers[0])!
        let minorInstalled = Int(installedVersionNumbers[1])!
        return (majorInstalled < majorCurrent) ||
            ((majorInstalled == majorCurrent) && (minorInstalled < minorCurrent)) ||
            ((majorInstalled == majorCurrent) && (minorInstalled == minorCurrent) &&
                (buildNumberInstalled < currentBuildInt))
    }
    
    func needToRemovePython37Files() -> Bool {
            // Check that the old python files are present:
            let libraryURL = try! FileManager().url(for: .libraryDirectory,
                                                    in: .userDomainMask,
                                                    appropriateFor: nil,
                                                    create: true)
        let fileLocation = libraryURL.appendingPathComponent(PythonFiles[0])
        // fileExists(atPath:) will answer false, because the linked file does not exist.
        do {
            _ = try FileManager().attributesOfItem(atPath: fileLocation.path)
            return true
        }
        catch {
            // The file does not exist, we already cleaned up Python3.7
            return false
        }
    }

    func createCSDK() {
        // This operation copies the C SDK from $APPDIR to $HOME/Library and creates the *.a libraries
        // (we can't ship with .a libraries because of the AppStore rules, but we can ship with *.o
        // object files, provided they are in WASM format.
        installQueue.async{
            // Use a queue so it does not take time at startup:
            NSLog("Starting creating C SDK")
            let libraryURL = try! FileManager().url(for: .libraryDirectory,
                                                    in: .userDomainMask,
                                                    appropriateFor: nil,
                                                    create: true)
            // usr/lib/wasm32-wasi
            var localURL = libraryURL.appendingPathComponent("usr/lib/wasm32-wasi") // $HOME/Library/usr/lib/wasm32-wasi
            do {
                if (FileManager().fileExists(atPath: localURL.path) && !localURL.isDirectory) {
                    try FileManager().removeItem(at: localURL)
                }
                if (!FileManager().fileExists(atPath: localURL.path)) {
                    try FileManager().createDirectory(atPath: localURL.path, withIntermediateDirectories: true)
                }
            } catch {
                NSLog("Error in creating C SDK directory \(localURL): \(error)")
                return
            }
            // usr/lib/clang/14.0.0/lib/wasi/
            localURL = libraryURL.appendingPathComponent("usr/lib/clang/14.0.0/lib/wasi/") // $HOME/Library/usr/lib/clang/14.0.0/lib/wasi/
            do {
                if (FileManager().fileExists(atPath: localURL.path) && !localURL.isDirectory) {
                    try FileManager().removeItem(at: localURL)
                }
                if (!FileManager().fileExists(atPath: localURL.path)) {
                    try FileManager().createDirectory(atPath: localURL.path, withIntermediateDirectories: true)
                }
            } catch {
                NSLog("Error in creating C SDK directory \(localURL): \(error)")
                return
            }
            let linkedCDirectories = ["usr/include",
                                      "usr/share",
                                      "usr/lib/wasm32-wasi/crt1.o",
                                      "usr/lib/wasm32-wasi/libc.imports",
                                      "usr/lib/clang/14.0.0/include",
            ]
            let bundleUrl = URL(fileURLWithPath: Bundle.main.resourcePath!)
            
            for linkedObject in linkedCDirectories {
                let bundleFile = bundleUrl.appendingPathComponent(linkedObject)
                if (!FileManager().fileExists(atPath: bundleFile.path)) {
                    NSLog("createCSDK: requested file \(bundleFile.path) does not exist")
                    continue
                }
                // Symbolic links are both faster to create and use less disk space.
                // We just have to make sure the destination exists
                let homeFile = libraryURL.appendingPathComponent(linkedObject)
                do {
                    let firstFileAttribute = try FileManager().attributesOfItem(atPath: homeFile.path)
                    if (firstFileAttribute[FileAttributeKey.type] as? String == FileAttributeType.typeSymbolicLink.rawValue) {
                        // It's a symbolic link, does the destination exist?
                        let destination = try! FileManager().destinationOfSymbolicLink(atPath: homeFile.path)
                        if (!FileManager().fileExists(atPath: destination)) {
                            try! FileManager().removeItem(at: homeFile)
                            try! FileManager().createSymbolicLink(at: homeFile, withDestinationURL: bundleFile)
                        }
                    } else {
                        // Not a symbolic link, replace:
                        try! FileManager().removeItem(at: homeFile)
                        try! FileManager().createSymbolicLink(at: homeFile, withDestinationURL: bundleFile)
                    }
                }
                catch {
                    // The file does not exist, and maybe the directory doesn't either:
                    let localDirectory = homeFile.deletingLastPathComponent()
                    if (!FileManager().fileExists(atPath: localDirectory.path)) {
                        try! FileManager().createDirectory(atPath: localDirectory.path, withIntermediateDirectories: true)
                    }
                    do {
                        try FileManager().createSymbolicLink(at: homeFile, withDestinationURL: bundleFile)
                    }
                    catch {
                        NSLog("Can't create file: \(homeFile.path): \(error)")
                    }
                }
            }
            // Now create the empty libraries:
            let emptyLibraries = [
                // m rt pthread crypt util xnet resolv dl
                "lib/wasm32-wasi/libcrypt.a",
                "lib/wasm32-wasi/libdl.a",
                "lib/wasm32-wasi/libm.a",
                "lib/wasm32-wasi/libpthread.a",
                "lib/wasm32-wasi/libresolv.a",
                "lib/wasm32-wasi/librt.a",
                "lib/wasm32-wasi/libutil.a",
                "lib/wasm32-wasi/libxnet.a"]
            ios_switchSession("wasiSDKLibrariesCreation")
            for library in emptyLibraries {
                let libraryFileURL = libraryURL.appendingPathComponent("/usr/" + library)
                if (!FileManager().fileExists(atPath: libraryFileURL.path)) {
                    executeCommandAndWait(command: "ar crs " + libraryURL.path + "/usr/" + library)
                }
            }
            // One of the libraries is in a different folder:
            let libraryFileURL = libraryURL.appendingPathComponent("/usr/lib/clang/14.0.0/lib/wasi/libclang_rt.builtins-wasm32.a")
            if (FileManager().fileExists(atPath: libraryFileURL.path)) {
                try! FileManager().removeItem(at: libraryFileURL)
            }
            let rootDir = Bundle.main.resourcePath!
            executeCommandAndWait(command: "ar cq " + libraryFileURL.path + " " + rootDir + "/usr/src/libclang_rt.builtins-wasm32/*")
            executeCommandAndWait(command: "ranlib " + libraryFileURL.path)
            let libraries = ["libc", "libc++", "libc++abi", "libc-printscan-long-double", "libc-printscan-no-floating-point", "libwasi-emulated-mman", "libwasi-emulated-signal", "libwasi-emulated-process-clocks"]
            for library in libraries {
                let libraryFileURL = libraryURL.appendingPathComponent("usr/lib/wasm32-wasi/" + library + ".a")
                if (FileManager().fileExists(atPath: libraryFileURL.path)) {
                    do { try FileManager().removeItem(at: libraryFileURL) }
                    catch { NSLog("Can't remove \(libraryFileURL.path)")}
                }
                executeCommandAndWait(command: "ar cq " + libraryFileURL.path + " " + rootDir + "/usr/src/" + library + "/*")
                executeCommandAndWait(command: "ranlib " + libraryFileURL.path)
            }
            NSLog("Finished creating C SDK") // Approx 2 seconds
        }
    }
    
    func removePython37Files() {
        // This operation removes the copy of the Python 3.7 directory that was kept in $HOME/Library.
        NSLog("Removing python 3.7 files")
        let documentsUrl = try! FileManager().url(for: .documentDirectory,
                                                  in: .userDomainMask,
                                                  appropriateFor: nil,
                                                  create: true)
        let homeUrl = documentsUrl.deletingLastPathComponent().appendingPathComponent("Library")
        let fileList = PythonFiles
        for fileName in fileList {
            let homeFile = homeUrl.appendingPathComponent(fileName)
            do {
                try FileManager().removeItem(at: homeFile)
            }
            catch {
                NSLog("Can't remove file: \(homeFile.path): \(error)")
            }
        }
        self.libraryFilesUpToDate = true
    }
    
    func isM1iPad(modelName: String) -> Bool {
        // modelName for M1 iPad: iPad13,x for x in [4-17] (covers 11" and 12.9" iPad Pro and Air 5th gen)
        // modelName for M2 iPad: iPad14,x for x in [3-6]
        var deviceName = UIDevice.current.modelName
        if (deviceName.hasPrefix("iPad13,")) {
            deviceName.removeFirst("iPad13,".count)
            if let minor = Int(deviceName) {
                if (minor >= 4) && (minor <= 17) {
                    return true
                }
            }
        } else if (deviceName.hasPrefix("iPad14,")) {
            deviceName.removeFirst("iPad14,".count)
            if let minor = Int(deviceName) {
                if (minor >= 3) {
                    return true
                }
            }
        }
        return false
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        NSLog("Application didFinishLaunchingWithOptions \(launchOptions)")
        // Store variables in User Defaults:
        if (appVersion != "a-Shell-mini") {
            UserDefaults.standard.register(defaults: ["TeXEnabled" : false])
            UserDefaults.standard.register(defaults: ["TeXOpenType" : false])
            UserDefaults.standard.register(defaults: ["TeXVersion" : "2000"])
            UserDefaults.standard.register(defaults: ["LuaTeXVersion" : "2000"])
        }
        UserDefaults.standard.register(defaults: ["zshmarks" : true])
        UserDefaults.standard.register(defaults: ["bashmarks" : false])
        UserDefaults.standard.register(defaults: ["escape_preference" : false])
        UserDefaults.standard.register(defaults: ["show_toolbar" : true])
        // Use the system toolbar is the default for iPad M1 and M2, but not for the other models:
        UserDefaults.standard.register(defaults: ["system_toolbar" : isM1iPad(modelName: UIDevice.current.modelName)])
        // What color should the keyboard and system toolbar be? (screen: same mode as the screen itself)
        UserDefaults.standard.register(defaults: ["toolbar_color" : "screen"])
        UserDefaults.standard.register(defaults: ["screen_space" : "default"])
        UserDefaults.standard.register(defaults: ["restart_vim" : false])
        UserDefaults.standard.register(defaults: ["keep_content" : true])
        toolbarShouldBeShown = UserDefaults.standard.bool(forKey: "show_toolbar")
        // system toolbar only applies on iPads:
        if (UIDevice.current.model.hasPrefix("iPad")) {
            useSystemToolbar = UserDefaults.standard.bool(forKey: "system_toolbar")
        } else {
            useSystemToolbar = false
        }
        let screenSpacePref = UserDefaults.standard.string(forKey: "screen_space")
        if (screenSpacePref == "safe") {
            viewBehavior = .original
        } else if (screenSpacePref == "max") {
            viewBehavior = .fullScreen
        } else {
            viewBehavior = .ignoreSafeArea
        }
        initializeEnvironment()
        joinMainThread = false
        ios_setBookmarkDictionaryName("bookmarkNames")
        replaceCommand("history", "history", true)
        replaceCommand("help", "help", true)
        replaceCommand("clear", "clear", true)
        replaceCommand("isForeground", "isForeground", true)
        replaceCommand("credits", "credits", true)
        replaceCommand("pickFolder", "pickFolder", true)
        replaceCommand("config", "config", true)
        replaceCommand("keepDirectoryAfterShortcut", "keepDirectoryAfterShortcut", true)
        replaceCommand("wasm", "wasm", true)
        replaceCommand("jsc", "jsc_internal", false)  // use our own jsc instead of ios_system jsc. Keep the original version
        replaceCommand("call", "call", true)  // call a contact
        replaceCommand("text", "text", true)  // send a text to a contact
        replaceCommand("play", "play_main", true)
        replaceCommand("view", "preview_main", true)
        replaceCommand("z", "z_command", true) // change directory based on frequencys
        replaceCommand("rehash", "rehash", true) // update list of commands for auto-complete
        replaceCommand("downloadFile", "downloadFile", true)
        replaceCommand("downloadFolder", "downloadFolder", true)
        replaceCommand("hideKeyboard", "hideKeyboard", true)
        replaceCommand("hideToolbar", "hideToolbar", true)
        replaceCommand("showToolbar", "showToolbar", true)
        replaceCommand("openurl", "openurl_main", true)  // open URL in local windows
        for browser in __known_browsers {
            replaceCommand(browser, "openurl_main", true)  // open URL using this specific browser.
            // required in case someone sets BROWSER to a particular value.
            // Some packages will then call the command "browser".
        }
        replaceCommand("deactivate", "deactivate", true) // deactivate Python virtual environments
        // Add these two as commands so they appear on the command list, even though we treat them internally:
        if (UIDevice.current.model.hasPrefix("iPad")) {
            replaceCommand("newWindow", "clear", true)
        }
        replaceCommand("exit", "clear", true)
        // for debugging TeX issues:
        // addCommandList(Bundle.main.path(forResource: "texCommandsDictionary", ofType: "plist"))
        // addCommandList(Bundle.main.path(forResource: "luatexCommandsDictionary", ofType: "plist"))
        let libraryURL = try! FileManager().url(for: .libraryDirectory,
                                                in: .userDomainMask,
                                                appropriateFor: nil,
                                                create: true)
        if (appVersion != "a-Shell-mini") {
            if let installedTexVersion = UserDefaults.standard.string(forKey: "TeXVersion") {
                let localURL = libraryURL.appendingPathComponent("texlive") // $HOME/Library/texlive
                let latestTexVersion = "2023"
                let latesttl = localURL.appendingPathComponent(latestTexVersion)
                // use installedTexVersion, move from installedTexVersion to latestVersion (in code)
                if (installedTexVersion != latestTexVersion) && UserDefaults.standard.bool(forKey: "TeXEnabled") {
                    // texlive 20xx is already installed, we move it to 20yy to keep installed packages.
                    // (tlpkg will be confused, and the user cannot run TeX immediately since the format has changed)
                    let installedtl = localURL.appendingPathComponent(installedTexVersion)
                    do {
                        try FileManager().moveItem(at: installedtl, to: latesttl)
                    }
                    catch {
                        debuggingTeXInstall(message: "Error in copying texlive \(installedTexVersion) to texlive \(latestTexVersion): \(error)")
                    }
                    downloadTeX()
                    if let installedLuatexVersion = UserDefaults.standard.string(forKey: "LuaTeXVersion") {
                        if (installedLuatexVersion <= latestTexVersion) {
                            downloadOpentype()
                        }
                    }
                } else if !FileManager().fileExists(atPath: latesttl.path) && UserDefaults.standard.bool(forKey: "TeXEnabled"){
                    // For some reason, the installed version directory is not there. Re-download things.
                    downloadTeX()
                    if let installedLuatexVersion = UserDefaults.standard.string(forKey: "LuaTeXVersion") {
                        if (installedLuatexVersion != "2000") && UserDefaults.standard.bool(forKey: "TeXOpenType") {
                            downloadOpentype()
                        }
                    }
                } else if (installedTexVersion >= latestTexVersion) && UserDefaults.standard.bool(forKey: "TeXEnabled") {
                    // We have TeX files already installed. Activate commands:
                    TeXEnabled = true;
                    addCommandList(Bundle.main.path(forResource: "texCommandsDictionary", ofType: "plist"))
                    if let installedLuatexVersion = UserDefaults.standard.string(forKey: "LuaTeXVersion") {
                        let openTypeDir = libraryURL.appendingPathComponent("texlive/2023/texmf-dist/fonts/opentype")
                        if (installedLuatexVersion >= latestTexVersion) &&
                            (FileManager().fileExists(atPath: openTypeDir.path)) {
                            OpentypeEnabled = true;
                            addCommandList(Bundle.main.path(forResource: "luatexCommandsDictionary", ofType: "plist"))
                        }
                    }
                    // Also copy latexmk over the wrong one (not anymore for 2023) (I hope)
                    /* if let forbidden = Bundle.main.resourceURL?.appendingPathComponent("forbidden_2022/2022/texmf-dist/scripts/latexmk/latexmk.pl") {
                     let latexmk = localURL.appendingPathComponent("2022/texmf-dist/scripts/latexmk/latexmk.pl")
                     do {
                     try FileManager().removeItem(at: latexmk)
                     }
                     catch {
                     NSLog("Did not remove \(latexmk)")
                     }
                     do {
                     try FileManager().copyItem(at: forbidden, to: latexmk)
                     }
                     catch {
                     NSLog("Could not copy \(forbidden) to \(latexmk)")
                     }
                     } */
                }
            }
            if UserDefaults.standard.bool(forKey: "TeXEnabled") {
                // check the scripts and redo-them (install may have failed at some point).
                let localPath = libraryURL.appendingPathComponent("bin") // $HOME/Library/bin
                for script in TeXscripts {
                    let command = localPath.appendingPathComponent(script[0])
                    let location = "../texlive/2023/texmf-dist/" + script[1]
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
                        debuggingTeXInstall(message: "Symbolic link attributes at \(command.path): \(error)")
                        do {
                            try FileManager().createSymbolicLink(atPath: command.path, withDestinationPath: location)
                        }
                        catch {
                            debuggingTeXInstall(message: "Unable to create symbolic link at \(command.path) to \(location): \(error)")
                        }
                    }
                }
            }
            if (TeXEnabled) {
                if let installedLuatexVersion = UserDefaults.standard.string(forKey: "LuaTeXVersion") {
                    if (installedLuatexVersion >= "2023") {
                        // We have LuaTeX files already installed. Activate commands:
                        OpentypeEnabled = true;
                        addCommandList(Bundle.main.path(forResource: "luatexCommandsDictionary", ofType: "plist"))
                    }
                }
            }
            activateFakeTeXCommands()
            if (!TeXEnabled && UserDefaults.standard.bool(forKey: "TeXEnabled")) {
                downloadTeX();
            }
            if (!OpentypeEnabled && UserDefaults.standard.bool(forKey: "TeXOpenType")) {
                downloadOpentype();
            }
        }
        numPythonInterpreters = 2; // so pip can work (it runs python setup.py). Some packages, eg nexusforge need 3 interpreters.
        setenv("VIMRUNTIME", Bundle.main.resourcePath! + "/vim", 1); // main resource for vim files
        setenv("TERM_PROGRAM", "a-Shell", 1) // let's inform users of who we are
        setenv("COLORTERM", "truecolor", 1) // tell programs that we can display 16-bit colors (required by Python package rich).
        setenv("SSL_CERT_FILE", Bundle.main.resourcePath! +  "/cacert.pem", 1); // SLL cacert.pem in $APPDIR/cacert.pem
        setenv("MAGIC", Bundle.main.resourcePath! +  "/usr/share/magic.mgc", 1); // magic file for file command
        setenv("SHORTCUTS", FileManager().containerURL(forSecurityApplicationGroupIdentifier:"group.AsheKube.a-Shell")?.path, 1) // directory used by shortcuts
        setenv("GROUP", FileManager().containerURL(forSecurityApplicationGroupIdentifier:"group.AsheKube.a-Shell")?.path, 1) // directory used by shortcuts
        setenv("MANPATH", Bundle.main.resourcePath! +  "/man:" + libraryURL.path + "/man", 1)
        setenv("PAGER", "less", 1) // send control sequences directly to terminal
        setenv("MAGICK_HOME", Bundle.main.resourcePath! +  "/ImageMagick-7", 1)
        setenv("MAGICK_CONFIGURE_PATH", Bundle.main.resourcePath! +  "/ImageMagick-7/config", 1)
        if (UIDevice.current.model.hasPrefix("iPad")) {
            setenv("PS1", "[\\w]\\$ ", 1) // iPad default prompt: path name
        } else {
            setenv("PS1", "[\\W]\\$ ", 1) // iPhone default prompt: last path component
        }
        setenv("TERMINFO", Bundle.main.resourcePath! +  "/terminfo/", 1) // Provide terminfo so termcap has a database
        setenv("TZ", TimeZone.current.identifier, 1) // TimeZone information, since "systemsetup -gettimezone" won't work.
        let documentsUrl = try! FileManager().url(for: .documentDirectory,
                                                  in: .userDomainMask,
                                                  appropriateFor: nil,
                                                  create: true)
        FileManager().changeCurrentDirectoryPath(documentsUrl.path)
        // Make sure aws (Python package) can work:
        setenv("AWS_SHARED_CREDENTIALS_FILE", documentsUrl.appendingPathComponent(".aws/credentials").path, 1)
        setenv("AWS_CONFIG_FILE", documentsUrl.appendingPathComponent(".aws/config").path, 1)
        // Pip options:
        setenv("PIP_CONFIG_FILE", documentsUrl.appendingPathComponent(".config/pip/pip.conf").path, 1)
        setenv("PIP_NO_BUILD_ISOLATION", "false", 1)
        setenv("SPACEVIMDIR", documentsUrl.appendingPathComponent(".SpaceVim.d").path + "/", 1); // configuration directory for SpaceVim
        // Help aiohttp install itself:
        setenv("YARL_NO_EXTENSIONS", "1", 1)
        setenv("MULTIDICT_NO_EXTENSIONS", "1", 1)
        // This one is not required, but it helps:
        setenv("DISABLE_SQLALCHEMY_CEXT", "1", 1)
        // Do we have the wasi C SDK in place?
        versionUpToDate = !versionNumberIncreased()
        appDependentPath = String(utf8String: getenv("PATH")) ?? ""
        if (appVersion != "a-Shell-mini") {
            // clang options:
            setenv("SYSROOT", libraryURL.path + "/usr", 1) // sysroot for clang compiler
            setenv("CCC_OVERRIDE_OPTIONS", "#^--target=wasm32-wasi", 1) // silently add "--target=wasm32-wasi" at the beginning of arguments
            // TeX variables (for tlmgr to work) = only when installing from scratch
            // default texmf.cnf available:
            // setenv("TEXMFCNF", Bundle.main.resourcePath!, 1)
            // Make:
            setenv("MAKESYSPATH", Bundle.main.resourcePath! +  "/usr/share/mk" , 1)
            // Perl location of modules:
            setenv("PERL5LIB", documentsUrl.appendingPathComponent("perl5/lib/perl5").path + ":" + Bundle.main.resourcePath! +  "/Perl" , 1)
            // set-up for local::lib:
            setenv("PERL_LOCAL_LIB_ROOT", documentsUrl.appendingPathComponent("perl5").path, 1)
            setenv("PERL_CPANM_HOME", documentsUrl.appendingPathComponent(".cpanm").path, 1)
            setenv("PERL_MM_OPT", "'INSTALL_BASE=" + documentsUrl.appendingPathComponent("perl5").path + "'", 1)
            setenv("PERL_MB_OPT", "--install_base \"" + documentsUrl.appendingPathComponent("perl5").path + "\"", 1)
            appDependentPath = documentsUrl.appendingPathComponent("perl5").appendingPathComponent("bin").path + ":" + appDependentPath
            setenv("PATH", appDependentPath, 1)
            setenv("MANPATH", Bundle.main.resourcePath! +  "/man:" + libraryURL.path + "/man:" + documentsUrl.appendingPathComponent("perl5").appendingPathComponent("man").path, 1)
            if (!versionUpToDate || needToUpdateCFiles()) {
                createCSDK()
            }
            // help Sunpy too: https://github.com/sunpy/sunpy/pull/6166
            setenv("SUNPY_NO_BUILD_ANA_EXTENSION", "1", 1)
            // SUNPY_CONFIGDIR is ~/Library/Application Support/sunpy, by default, so it is OK.
            // default sunpy config file, forces working_dir to ~/Documents/sunpy:
            // data_manager.db has an issue with $HOME but not with ~.
            let sunpyDirectory = libraryURL.appendingPathComponent("Application Support/sunpy")
            let sunpyrcFile = sunpyDirectory.appendingPathComponent("sunpyrc")
            if (!FileManager().fileExists(atPath: sunpyrcFile.path)) {
                if (!FileManager().fileExists(atPath: sunpyDirectory.path)) {
                    do {
                        try FileManager().createDirectory(at: sunpyDirectory, withIntermediateDirectories: true)
                    }
                    catch {}
                }
                if (FileManager().fileExists(atPath: sunpyDirectory.path)) {
                    let sunpyrcContent = """
    ;;;;;;;;;;;;;;;;;;;
    ; General Options ;
    ;;;;;;;;;;;;;;;;;;;
    [general]
    
    ; The SunPy working directory is the parent directory where all generated
    ; and download files will be stored.
    ; Default Value: <user's home directory>/sunpy
    ; data_manager.db has an issue with $HOME but not with ~
    working_dir = ~/Documents/sunpy
    """
                    let sunpyrcData: Data = sunpyrcContent.data(using: String.Encoding.utf8)!
                    FileManager().createFile(atPath: sunpyrcFile.path, contents: sunpyrcData, attributes: nil)
                }
            }
            do {
                let documentsUrl = try FileManager().url(for: .documentDirectory,
                                                         in: .userDomainMask,
                                                         appropriateFor: nil,
                                                         create: true)
                let nltkData = documentsUrl.appendingPathComponent("nltk_data")
                setenv("NLTK_DATA", nltkData.path, 1)
                setenv("PIP_CONFIG_FILE", documentsUrl.appendingPathComponent(".config/pip/pip.conf").path, 1)
                // Place downloaded files for sunpy in ~/Documents/sunpy
                setenv("SUNPY_DOWNLOADDIR", documentsUrl.appendingPathComponent("sunpy").path, 1)
            } catch { }
            // PyProj options:
            setenv("PYPROJ_GLOBAL_CONTEXT", "ON", 1) // This helps pyproj in cleaning up.
            let projDir = URL(fileURLWithPath: Bundle.main.resourcePath!).appendingPathComponent("proj")
            setenv("PROJ_LIB", projDir.path, 1)  // proj <= 9.1
            setenv("PROJ_DATA", projDir.path, 1) // proj 9.1+
            setenv("PROJ_NETWORK", "ON", 1)
        } // a-Shell mini
        if (FileManager().fileExists(atPath: libraryURL.path + "/lib/python3.9/site-packages/")) {
            installQueue.async{
                ios_switchSession("wasiSDKLibrariesCreation")
                // Move all site-packages to $HOME/Library/lib/python3.11/site-packages/
                executeCommandAndWait(command: "mkdir -p " + libraryURL.path + "/lib/python3.11/site-packages/")
                executeCommandAndWait(command: "mv " + libraryURL.path + "/lib/python3.9/site-packages/* " + libraryURL.path + "/lib/python3.11/site-packages/")
                // Erase the directory
                executeCommandAndWait(command: "rm -rf " + libraryURL.path + "/lib/python3.9/")
            }
        } else if (needToRemovePython37Files()) {
            installQueue.async{
                ios_switchSession("wasiSDKLibrariesCreation")
                // Remove files and directories created with Python 3.7
                self.removePython37Files()
                // Move all remaining packages to $HOME/Library/lib/python3.9/site-packages/
                executeCommandAndWait(command: "mkdir -p " + libraryURL.path + "/lib/python3.11/site-packages/")
                executeCommandAndWait(command: "mv " + libraryURL.path + "/lib/python3.7/site-packages/* " + libraryURL.path + "/lib/python3.11/site-packages/")
                // Erase the directory
                executeCommandAndWait(command: "rm -rf " + libraryURL.path + "/lib/python3.7/")
            }
        }
        if (!versionUpToDate) {
            installQueue.async{
                // The version number changed, so the App has been re-installed. Clean all pre-compiled Python files:
                NSLog("Cleaning __pycache__ and .cpan/build")
                ios_switchSession("wasiSDKLibrariesCreation")
                if (FileManager().fileExists(atPath: libraryURL.path + "/__pycache__")) {
                    executeCommandAndWait(command: "rm -rf " + libraryURL.path + "/__pycache__/*")
                }
                if (FileManager().fileExists(atPath: documentsUrl.appendingPathComponent(".cpan").path + "/build")) {
                    // Also clean all CPAN build directories (they aren't valid anymore)    :
                    executeCommandAndWait(command: "rm -rf " + documentsUrl.appendingPathComponent(".cpan").path + "/build/*")
                }
            }
        }
        // Now set the version number to the current version:
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
        UserDefaults.standard.set(currentVersion, forKey: "versionInstalled")
        let currentBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as! String
        UserDefaults.standard.set(currentBuild, forKey: "buildNumber")
        self.versionUpToDate = true
        // Main Python install: $APPDIR/Library/lib/python3.x
        let bundleUrl = URL(fileURLWithPath: Bundle.main.resourcePath!).appendingPathComponent("Library")
        setenv("PYTHONHOME", bundleUrl.path.toCString(), 1)
        // Compiled files: ~/Library/__pycache__
        setenv("PYTHONPYCACHEPREFIX", (libraryURL.appendingPathComponent("__pycache__")).path.toCString(), 1)
        setenv("PYTHONUSERBASE", libraryURL.path.toCString(), 1)
        checkBookmarks() // activate all bookmarks in the app
        // iCloud abilities:
        // We check whether the user has iCloud ability here, and that the container exists
        let currentiCloudToken = FileManager().ubiquityIdentityToken
        if let iCloudDocumentsURL = FileManager().url(forUbiquityContainerIdentifier: nil) {
            // Create a document in the iCloud folder to make it visible.
            NSLog("iCloudContainer = \(iCloudDocumentsURL)")
            let iCloudDirectory = iCloudDocumentsURL.appendingPathComponent("Documents")
            let iCloudDirectoryWelcome = iCloudDirectory.appendingPathComponent(".Trash")
            if (!FileManager().fileExists(atPath: iCloudDirectoryWelcome.path)) {
                NSLog("Creating iCloud .trash directory")
                do {
                    try FileManager().createDirectory(atPath: iCloudDirectoryWelcome.path, withIntermediateDirectories: true)
                }
                catch {
                    NSLog("Error in creating folder")
                }
            }
        }
        // print("Available fonts: \(UIFont.familyNames)");
        FileManager().changeCurrentDirectoryPath(documentsUrl.path)
#if false // Disabling request for notifications, since we do not use it.
        let center = UNUserNotificationCenter.current()
        // Request permission to display alerts and play sounds.
        center.requestAuthorization(options: [.alert, .sound])
        { (granted, error) in
            // Enable or disable features based on authorization.
        }
#endif
        // Detect changes in user settings (preferences):
        NotificationCenter.default.addObserver(self, selector: #selector(self.settingsChanged), name: UserDefaults.didChangeNotification, object: nil)
        // Also notification if user changes accessibility settings:
        NotificationCenter.default.addObserver(self, selector: #selector(self.voiceOverChanged), name:  UIAccessibility.voiceOverStatusDidChangeNotification, object: nil)
        if #available(iOS 17.0, *) {
            // No frequency control. Show all tips as soon as eligible (but only once)
            try? Tips.configure([.displayFrequency(.immediate)])
        }
        // Enable media playback:
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .moviePlayback)
        }
        catch {
            // print("Setting category to AVAudioSessionCategoryPlayback failed.")
        }
        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Is called for iPhone apps when the user swipes upward in the app switcher and the app was in the foreground.
        // Is called for iPad apps when the user swipes upward if the app was in the foreground.
        // TODO: delete current/frontmost session, and call exit(0) (hard exit)
        // The current effect is already equivalent to exit(0).
        NSLog("Application will terminate")
    }
    
    
    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        // Also the function called when a shortcut starts the App.
        NSLog("application configurationForConnecting connectingSceneSession \(connectingSceneSession)")
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
        // Delete Vim sessions here using sceneSessions.first.persistentIdentifier
        do {
            let documentsUrl = try FileManager().url(for: .documentDirectory,
                                                     in: .userDomainMask,
                                                     appropriateFor: nil,
                                                     create: true)
            for session in sceneSessions {
                let persistentIdentifier = session.persistentIdentifier
                var sessionFileUrl = documentsUrl.appendingPathComponent(".vim/sessions/" + persistentIdentifier + ".vim")
                if (FileManager().fileExists(atPath: sessionFileUrl.path)) {
                    do {
                        try FileManager().removeItem(at: sessionFileUrl)
                    }
                    catch {
                        NSLog("Unable to remove file: \(sessionFileUrl.path)")
                    }
                }
                sessionFileUrl = documentsUrl.appendingPathComponent(".vim/sessions/" + persistentIdentifier + ".vim.lock")
                if (FileManager().fileExists(atPath: sessionFileUrl.path)) {
                    do {
                        try FileManager().removeItem(at: sessionFileUrl)
                    }
                    catch {
                        NSLog("Unable to remove file: \(sessionFileUrl.path)")
                    }
                }
                sessionFileUrl = documentsUrl.appendingPathComponent(".vim/sessions/" + persistentIdentifier + ".vim.lock.tmp")
                if (FileManager().fileExists(atPath: sessionFileUrl.path)) {
                    do {
                        try FileManager().removeItem(at: sessionFileUrl)
                    }
                    catch {
                        NSLog("Unable to remove file: \(sessionFileUrl.path)")
                    }
                }
            }
        }
        catch {
            NSLog("Could not get documentURL")
        }
        NSLog("application didDiscardSceneSessions sceneSessions \(sceneSessions)")
    }
    
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable:Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
        NSLog("Called didReceiveRemoteNotification with userInfo = \(userInfo)")
        // let session = findSession(for: userInfo)
        // application.requestSceneSessionRefresh(session)
    }

    @objc func voiceOverChanged() {
        // Send the value to all the SceneDelegate connected to this application
        for scene in UIApplication.shared.connectedScenes {
            if let delegate: SceneDelegate = scene.delegate as? SceneDelegate {
                delegate.activateVoiceOver(value: UIAccessibility.isVoiceOverRunning)
            }
        }
    }

    @objc func settingsChanged() {
        // UserDefaults.didChangeNotification is called every time the window becomes active
        // We only act if things have really changed.
        if (appVersion != "a-Shell-mini") {
            // Don't look at TeX settings if running a-Shell mini
            let userSettingsTeX = UserDefaults.standard.bool(forKey: "TeXEnabled")
            // something changed with TeX settings
            if (userSettingsTeX) {
                if (userSettingsTeX != TeXEnabled) {
                    // it was not enabled before, it is requested: we download it
                    downloadTeX()
                }
            } else {
                let TeXVersion = UserDefaults.standard.string(forKey: "TeXVersion")
                if (TeXVersion != "2000") {
                    // it is disabled: make sure it has been removed:
                    disableTeX()
                    UserDefaults.standard.setValue("2000", forKey: "TeXVersion")
                }
            }
            let userSettingsOpentype = UserDefaults.standard.bool(forKey: "TeXOpenType")
            if (userSettingsOpentype) {
                if (userSettingsOpentype != OpentypeEnabled) {
                    // it was not enabled before, it is requested: we download it
                    downloadOpentype()
                }
            } else {
                let LuaTeXVersion = UserDefaults.standard.string(forKey: "LuaTeXVersion")
                if (LuaTeXVersion != "2000") {
                    // it was enabled before, it was disabled: we remove it
                    disableOpentype()
                    UserDefaults.standard.setValue("2000", forKey: "LuaTeXVersion")
                }
            }
        }// a-Shell mini
        // bookmarks management, copied from zshmarks: https://github.com/jocelynmallon/zshmarks
        let zshmarks = UserDefaults.standard.bool(forKey: "zshmarks")
        if (zshmarks) {
            replaceCommand("showmarks", "showmarks", true) //
            replaceCommand("jump", "jump", true) // go to bookmark
            replaceCommand("bookmark", "bookmark", true) // add bookmark for current directory
            replaceCommand("deletemark", "deletemark", true) // delete bookmark (might be dangerous)
            replaceCommand("renamemark", "renamemark", true) // rename bookmark
        }
        let bashmarks = UserDefaults.standard.bool(forKey: "bashmarks")
        if (bashmarks) {
            replaceCommand("l", "showmarks", true) //
            replaceCommand("p", "showmarks", true) //
            replaceCommand("g", "jump", true) // go to bookmark
            replaceCommand("s", "bookmark", true) // add bookmark for current directory
            replaceCommand("d", "deletemark", true) // delete bookmark (might be dangerous)
            replaceCommand("r", "renamemark", true) // rename bookmark
        }
        let toolbarColor = UserDefaults.standard.string(forKey: "toolbar_color")
        if (toolbarColor == "system") {
            for scene in UIApplication.shared.connectedScenes {
                if let delegate: SceneDelegate = scene.delegate as? SceneDelegate {
                    delegate.overrideUserInterfaceStyle(style: .unspecified)
                }
            }
        } else if (toolbarColor == "dark") {
            for scene in UIApplication.shared.connectedScenes {
                if let delegate: SceneDelegate = scene.delegate as? SceneDelegate {
                    delegate.overrideUserInterfaceStyle(style: .dark)
                }
            }
        } else if (toolbarColor == "light") {
            for scene in UIApplication.shared.connectedScenes {
                if let delegate: SceneDelegate = scene.delegate as? SceneDelegate {
                    delegate.overrideUserInterfaceStyle(style: .light)
                }
            }
        } else if (toolbarColor == "screen") {
            if let ColorFgBg = getenv("COLORFGBG") {
                if (String(utf8String: ColorFgBg) == "15;0") {
                    for scene in UIApplication.shared.connectedScenes {
                        if let delegate: SceneDelegate = scene.delegate as? SceneDelegate {
                            delegate.overrideUserInterfaceStyle(style: .dark)
                        }
                    }
                } else {
                    for scene in UIApplication.shared.connectedScenes {
                        if let delegate: SceneDelegate = scene.delegate as? SceneDelegate {
                            delegate.overrideUserInterfaceStyle(style: .light)
                        }
                    }
                }
            }
        }
        let toolbarSettings = UserDefaults.standard.bool(forKey: "show_toolbar")
        if (toolbarShouldBeShown && !toolbarSettings) {
            NSLog("Received call to hide the toolbar through preferences")
            // User has just requested we hide the toolbar
            // Send the value to all the SceneDelegate connected to this application
            toolbarShouldBeShown = false
            // Remove the toolbar on all connected scenes (usually none since the app is in the background):
            for scene in UIApplication.shared.connectedScenes {
                if let delegate: SceneDelegate = scene.delegate as? SceneDelegate {
                    delegate.hideToolbar()
                }
            }
        } else if (!toolbarShouldBeShown && toolbarSettings) {
            NSLog("Received call to show the toolbar through preferences")
            // User has just requested we show the toolbar
            // Send the value to all the SceneDelegate connected to this application
            toolbarShouldBeShown = true
            // Remove the toolbar on all connected scenes (usually none since the app is in the background):
            for scene in UIApplication.shared.connectedScenes {
                if let delegate: SceneDelegate = scene.delegate as? SceneDelegate {
                    delegate.showEditorToolbar()
                }
            }
        }
        toolbarShouldBeShown = toolbarSettings
        // Ability to switch to the iPadOS-style system toolbar. Only available on iPads
        if (UIDevice.current.model.hasPrefix("iPad")) {
            let systemToolbarSettings = UserDefaults.standard.bool(forKey: "system_toolbar")
            if (useSystemToolbar && !systemToolbarSettings) {
                NSLog("Received call to switch to system toolbar through preferences")
                // User has just requested we hide the system toolbar
                // Send the value to all the SceneDelegate connected to this application
                useSystemToolbar = false
                for scene in UIApplication.shared.connectedScenes {
                    if let delegate: SceneDelegate = scene.delegate as? SceneDelegate {
                        if (toolbarShouldBeShown) {
                            delegate.showEditorToolbar()
                        } else {
                            delegate.hideToolbar()
                        }
                    }
                }
            } else if (!useSystemToolbar && systemToolbarSettings) {
                NSLog("Received call to switch to regular toolbar through preferences")
                // User has just requested we show the toolbar
                // Send the value to all the SceneDelegate connected to this application
                useSystemToolbar = true
                for scene in UIApplication.shared.connectedScenes {
                    if let delegate: SceneDelegate = scene.delegate as? SceneDelegate {
                        if (toolbarShouldBeShown) {
                            delegate.showEditorToolbar()
                        } else {
                            delegate.hideToolbar()
                        }
                    }
                }
            }
        }
        // How much of screen space should we use?
        let screenSpacePref = UserDefaults.standard.string(forKey: "screen_space")
        if (screenSpacePref == "safe") {
            viewBehavior = .original
        } else if (screenSpacePref == "max") {
            viewBehavior = .fullScreen
        } else {
            viewBehavior = .ignoreSafeArea
        }
    }
    
    // MARK: Shortcuts / Intents handling
    // Apparently never called because the system call Scene(_ continue:)
    func application(_ application: UIApplication, continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        NSLog("AppDelegate, continue, userActivity.activityType = \(userActivity.activityType)")
        if userActivity.activityType == "AsheKube.app.a-Shell.ExecuteCommand",
            let intent = userActivity.interaction?.intent as? ExecuteCommandIntent {
            NSLog("We received the shortcut! \(intent)")
        }
        return true
    }
    
    func application(_ application: UIApplication, handle intent: INIntent, completionHandler: @escaping (INIntentResponse) -> Void) {
          
        let response: INIntentResponse

        if let commandIntent = intent as? ExecuteCommandIntent {
            NSLog("Received an intent at the application level: \(commandIntent)")
            response = INStartWorkoutIntentResponse(code: .success, userActivity: nil)
        }
        else {
            response = INStartWorkoutIntentResponse(code: .failure, userActivity: nil)
        }
        completionHandler(response)
    }
    
}
