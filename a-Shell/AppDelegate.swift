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

var downloadingTeX = false
var downloadingTeXError = ""
var percentTeXDownloadComplete = 0.0
var downloadingOpentype = false
var downloadingOpentypeError = ""
var percentOpentypeDownloadComplete = 0.0

@objcMembers
@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var TeXEnabled = false;
    var OpentypeEnabled = false;
    // to update Python distribution at each version update
    var versionUpToDate = true
    var libraryFilesUpToDate = true
    let moveFilesQueue = DispatchQueue(label: "moveFiles", qos: .utility) // low priority

    // Which version of the app are we running? a-Shell, a-Shell mini, a-Shell pro...?
    var appVersion: String? {
        // Bundle.main.infoDictionary?["CFBundleDisplayName"] = a-Shell
        // Bundle.main.infoDictionary?["CFBundleIdentifier"] = AsheKube.a-Shell
        // Bundle.main.infoDictionary?["CFBundleName"] = a-Shell
        return Bundle.main.infoDictionary?["CFBundleName"] as? String
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
            let fileAttribute = try FileManager().attributesOfItem(atPath: fileLocation.path)
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
        // usr/lib/clang/10.0.0/lib/wasi/
        localURL = libraryURL.appendingPathComponent("usr/lib/clang/10.0.0/lib/wasi/") // $HOME/Library/usr/lib/clang/10.0.0/lib/wasi/
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
                                 "usr/lib/clang/10.0.0/include",
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
            "lib/wasm32-wasi/libcrypt.a",
            "lib/wasm32-wasi/libdl.a",
            "lib/wasm32-wasi/libm.a",
            "lib/wasm32-wasi/libpthread.a",
            "lib/wasm32-wasi/libresolv.a",
            "lib/wasm32-wasi/librt.a",
            "lib/wasm32-wasi/libutil.a",
            "lib/wasm32-wasi/llibxnetibm.a"]
        ios_switchSession("wasiSDKLibrariesCreation")
        for library in emptyLibraries {
            let libraryFileURL = libraryURL.appendingPathComponent("/usr/" + library)
            if (!FileManager().fileExists(atPath: libraryFileURL.path)) {
                let pid = ios_fork()
                ios_system("ar crs " + libraryURL.path + "/usr/" + library)
                ios_waitpid(pid)
            }
        }
        // One of the libraries is in a different folder:
        let libraryFileURL = libraryURL.appendingPathComponent("/usr/lib/clang/10.0.0/lib/wasi/libclang_rt.builtins-wasm32.a")
        if (FileManager().fileExists(atPath: libraryFileURL.path)) {
            try! FileManager().removeItem(at: libraryFileURL)
        }
        let rootDir = Bundle.main.resourcePath!
        var pid = ios_fork()
        ios_system("ar cq " + libraryFileURL.path + " " + rootDir + "/usr/src/libclang_rt.builtins-wasm32/*")
        ios_waitpid(pid)
        pid = ios_fork()
        ios_system("ranlib " + libraryFileURL.path)
        ios_waitpid(pid)
        let libraries = ["libc", "libc++", "libc++abi", "libc-printscan-long-double", "libc-printscan-no-floating-point", "libwasi-emulated-mman"]
        for library in libraries {
            let libraryFileURL = libraryURL.appendingPathComponent("usr/lib/wasm32-wasi/" + library + ".a")
            if (FileManager().fileExists(atPath: libraryFileURL.path)) {
                try! FileManager().removeItem(at: libraryFileURL)
            }
            var pid = ios_fork()
            ios_system("ar cq " + libraryFileURL.path + " " + rootDir + "/usr/src/" + library + "/*")
            ios_waitpid(pid)
            pid = ios_fork()
            ios_system("ranlib " + libraryFileURL.path)
            ios_waitpid(pid)
        }
        NSLog("Finished creating C SDK") // Approx 2 seconds
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
    
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        NSLog("Application didFinishLaunchingWithOptions \(launchOptions)")
        // Store variables in User Defaults:
        if (appVersion != "a-Shell mini") {
            UserDefaults.standard.register(defaults: ["TeXEnabled" : false])
            UserDefaults.standard.register(defaults: ["TeXOpenType" : false])
        }
        UserDefaults.standard.register(defaults: ["zshmarks" : true])
        UserDefaults.standard.register(defaults: ["bashmarks" : false])
        UserDefaults.standard.register(defaults: ["escape_preference" : false])
        initializeEnvironment()
        joinMainThread = false
        replaceCommand("history", "history", true)
        replaceCommand("help", "help", true)
        replaceCommand("clear", "clear", true)
        replaceCommand("credits", "credits", true)
        replaceCommand("pickFolder", "pickFolder", true)
        replaceCommand("config", "config", true)
        replaceCommand("keepDirectoryAfterShortcut", "keepDirectoryAfterShortcut", true)
        replaceCommand("wasm", "wasm", true)
        replaceCommand("jsc", "jsc", true)  // use our own jsc instead of ios_system jsc
        // Add these as commands so they appear on the command list, even though we treat them internally:
        replaceCommand("newWindow", "clear", true)
        replaceCommand("exit", "clear", true)
        // for debugging TeX issues:
        // addCommandList(Bundle.main.path(forResource: "texCommandsDictionary", ofType: "plist"))
        // addCommandList(Bundle.main.path(forResource: "luatexCommandsDictionary", ofType: "plist"))
        if (appVersion != "a-Shell mini") {
            activateFakeTeXCommands()
            if (UserDefaults.standard.bool(forKey: "TeXEnabled")) {
                downloadTeX();
            }
            if (UserDefaults.standard.bool(forKey: "TeXOpenType")) {
                downloadOpentype();
            }
        }
        numPythonInterpreters = 2; // so pip can work (it runs python setup.py). Some packages, eg nexusforge need 3 interpreters.
        setenv("VIMRUNTIME", Bundle.main.resourcePath! + "/vim", 1); // main resource for vim files
        setenv("TERM_PROGRAM", "a-Shell", 1) // let's inform users of who we are
        setenv("SSL_CERT_FILE", Bundle.main.resourcePath! +  "/cacert.pem", 1); // SLL cacert.pem in $APPDIR/cacert.pem
        setenv("MAGIC", Bundle.main.resourcePath! +  "/usr/share/magic.mgc", 1); // magic file for file command
        setenv("SHORTCUTS", FileManager().containerURL(forSecurityApplicationGroupIdentifier:"group.AsheKube.a-Shell")?.path, 1) // directory used by shortcuts
        setenv("GROUP", FileManager().containerURL(forSecurityApplicationGroupIdentifier:"group.AsheKube.a-Shell")?.path, 1) // directory used by shortcuts
        let libraryURL = try! FileManager().url(for: .libraryDirectory,
                                                in: .userDomainMask,
                                                appropriateFor: nil,
                                                create: true)
        setenv("SYSROOT", libraryURL.path + "/usr", 1) // sysroot for clang compiler
        setenv("CCC_OVERRIDE_OPTIONS", "#^--target=wasm32-wasi", 1) // silently add "--target=wasm32-wasi" at the beginning of arguments
        setenv("MANPATH", Bundle.main.resourcePath! +  "/man:" + libraryURL.path + "/man", 1)
        setenv("PAGER", "less", 1)
        let documentsUrl = try! FileManager().url(for: .documentDirectory,
                                                  in: .userDomainMask,
                                                  appropriateFor: nil,
                                                  create: true)
        // Do we have the wasi C SDK in place?
        versionUpToDate = !versionNumberIncreased()
        if (appVersion != "a-Shell mini") {
            if (!versionUpToDate || needToUpdateCFiles()) {
                createCSDK()
            }
            if (needToRemovePython37Files()) {
                // Remove files and directories created with Python 3.7
                removePython37Files()
                // Move all remaining packages to $HOME/Library/lib/python3.9/site-packages/
                var pid = ios_fork()
                ios_system("mv " + libraryURL.path + "/lib/python3.7/site-packages/* " + libraryURL.path + "/lib/python3.9/site-packages/")
                ios_waitpid(pid)
                // Erase the directory
                pid = ios_fork()
                ios_system("rm -rf " + libraryURL.path + "/lib/python3.7/")
                ios_waitpid(pid)
            }
        }
        if (!versionUpToDate) {
            // The version number changed, so the App has been re-installed. Clean all pre-compiled Python files:
            NSLog("Cleaning __pycache__")
            let pid = ios_fork()
            ios_system("rm -rf " + libraryURL.path + "/__pycache__/*")
            ios_waitpid(pid)
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
        // iCloud abilities:
        // We check whether the user has iCloud ability here, and that the container exists
        let currentiCloudToken = FileManager().ubiquityIdentityToken
        // print("Available fonts: \(UIFont.familyNames)");
        FileManager().changeCurrentDirectoryPath(documentsUrl.path)
        let center = UNUserNotificationCenter.current()
        // Request permission to display alerts and play sounds.
        center.requestAuthorization(options: [.alert, .sound])
        { (granted, error) in
            // Enable or disable features based on authorization.
        }
        // Detect changes in user settings (preferences):
        NotificationCenter.default.addObserver(self, selector: #selector(self.settingsChanged), name: UserDefaults.didChangeNotification, object: nil)
        // Also notification if user changes accessibility settings:
        NotificationCenter.default.addObserver(self, selector: #selector(self.voiceOverChanged), name:  UIAccessibility.voiceOverStatusDidChangeNotification, object: nil)
        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
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
        let documentsUrl = try! FileManager().url(for: .documentDirectory,
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
        let userSettingsTeX = UserDefaults.standard.bool(forKey: "TeXEnabled")
        // something changed with TeX settings
        if (userSettingsTeX) {
            if (userSettingsTeX != TeXEnabled) {
                // it was not enabled before, it is requested: we download it
                downloadTeX()
            }
        } else {
            // it is disabled: make sure it has been removed:
            disableTeX()
        }
        let userSettingsOpentype = UserDefaults.standard.bool(forKey: "TeXOpenType")
        if (userSettingsOpentype) {
            if (userSettingsOpentype != OpentypeEnabled) {
                // it was not enabled before, it is requested: we download it
                downloadOpentype()
            }
        } else {
            // it was enabled before, it was disabled: we remove it
            disableOpentype()
        }
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
