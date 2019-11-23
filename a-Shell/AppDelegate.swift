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

    func linkedFileExists(directory: URL, fileName: String) -> Bool {
        // Check whether the file linked by fileName in directory actually exists
        // (if fileName does not exist, we also return false)
        // NSLog("Checking existence of \(fileName)")
        if (!FileManager().fileExists(atPath: directory.appendingPathComponent("lib").path)) {
            // NSLog("no to fileExists \(directory.appendingPathComponent("lib").path)")
            return false
        }
        let fileLocation = directory.appendingPathComponent(fileName)
        do {
            let fileAttribute = try FileManager().attributesOfItem(atPath: fileLocation.path)
            if (!(fileAttribute[FileAttributeKey.type] as? String == FileAttributeType.typeSymbolicLink.rawValue)) { return false }
            // NSLog("It's a symbolic link")
            let destination = try FileManager().destinationOfSymbolicLink(atPath: fileLocation.path)
            // NSLog("Destination = \(destination) exists = \(FileManager().fileExists(atPath: destination))")
            return FileManager().fileExists(atPath: destination)
        }
        catch {
            NSLog("\(fileName) generated an error: \(error)")
            return false
        }
    }
    
    func clearOldDirectories() {
        // packages installed in previous versions. Must remove before anything else or they mess things up.
        let oldPythonDirectories = ["Library/lib/python3.7/multiprocessing",
                                    ]
        let documentsUrl = try! FileManager().url(for: .documentDirectory,
                                                  in: .userDomainMask,
                                                  appropriateFor: nil,
                                                  create: true)
        let homeUrl = documentsUrl.deletingLastPathComponent()
        for directoryName in oldPythonDirectories {
            let homeDirectory = homeUrl.appendingPathComponent(directoryName)
            if (FileManager().fileExists(atPath: homeDirectory.path)) {
                try! FileManager().removeItem(at: homeDirectory)
            }
        }
    }

    
    
    func needToUpdatePythonFiles() -> Bool {
        // do it with UserDefaults, not storing in files
        UserDefaults.standard.register(defaults: ["versionInstalled" : "0.0"])
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
        let currentBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as! String
        let libraryURL = try! FileManager().url(for: .libraryDirectory,
                                                in: .userDomainMask,
                                                appropriateFor: nil,
                                                create: true)
        if (!linkedFileExists(directory: libraryURL, fileName: PythonFiles[0])) {
            return true
        }
        // Python files are present. Which version?
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

    func queueUpdatingPythonFiles() {
        // This operation (copy the files from the bundle directory to the $HOME/Library)
        // has two benefits:
        // 1- all python files are in a user-writeable directory, so the user can install
        // more modules as needed
        // 2- we remove the .pyc files from the application archive, bringing its size
        // under the 150 MB limit.
        // Possible trouble: the user *can* screw up the directory. We should detect that,
        // and offer (through user preference) the possibility to reset the install.
        // Maybe: major version = erase everything (except site-packages?), minor version = just copy?
        NSLog("Updating python files")
        let bundleUrl = URL(fileURLWithPath: Bundle.main.resourcePath!).appendingPathComponent("Library")
        // setting up PYTHONPATH (temporary) so Jupyter can start while we copy items:
        let originalPythonpath = getenv("PYTHONPATH")
        let mainPythonUrl = bundleUrl.appendingPathComponent("lib/python3.7")
        var newPythonPath = mainPythonUrl.path
        let pythonDirectories = ["lib/python3.7/site-packages",
                                 "lib/python3.7/site-packages/cffi-1.11.5-py3.7-macosx-12.1-iPad6,7.egg",
                                 "lib/python3.7/site-packages/cycler-0.10.0-py3.7.egg",
                                 "lib/python3.7/site-packages/kiwisolver-1.0.1-py3.7-macosx-10.9-x86_64.egg",
                                 "lib/python3.7/site-packages/matplotlib-3.0.3-py3.7-macosx-10.9-x86_64.egg",
                                 "lib/python3.7/site-packages/numpy-1.16.0-py3.7-macosx-10.9-x86_64.egg",
                                 "lib/python3.7/site-packages/pyparsing-2.3.1-py3.7.egg",
                                 "lib/python3.7/site-packages/setuptools-40.8.0-py3.7.egg",
                                 "lib/python3.7/site-packages/tornado-6.0.1-py3.7-macosx-12.1-iPad6,7.egg",
                                 "lib/python3.7/site-packages/Pillow-6.0.0-py3.7-macosx-10.9-x86_64.egg",
                                 "lib/python3.7/site-packages/cryptography-2.7-py3.7-macosx-10.9-x86_64.egg",
        ]
        
        for otherPythonDirectory in pythonDirectories {
            let secondaryPythonUrl = bundleUrl.appendingPathComponent(otherPythonDirectory)
            newPythonPath = newPythonPath.appending(":").appending(secondaryPythonUrl.path)
        }
        if (originalPythonpath != nil) {
            newPythonPath = newPythonPath.appending(":").appending(String(cString: originalPythonpath!))
        }
        setenv("PYTHONPATH", newPythonPath.toCString(), 1)
        //
        let documentsUrl = try! FileManager().url(for: .documentDirectory,
                                                  in: .userDomainMask,
                                                  appropriateFor: nil,
                                                  create: true)
        let homeUrl = documentsUrl.deletingLastPathComponent().appendingPathComponent("Library")
        let fileList = PythonFiles
        for fileName in fileList {
            let bundleFile = bundleUrl.appendingPathComponent(fileName)
            if (!FileManager().fileExists(atPath: bundleFile.path)) {
                NSLog("queueUpdatingPythonFiles: requested file \(bundleFile.path) does not exist")
                continue
            }
            // Symbolic links are both faster to create and use less disk space.
            // We just have to make sure the destination exists
            moveFilesQueue.async{
                let homeFile = homeUrl.appendingPathComponent(fileName)
                let homeDirectory = homeFile.deletingLastPathComponent()
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
        }
        // Done, now update the installed version:
        moveFilesQueue.async{
            NSLog("Finished updating python files.")
            if (originalPythonpath != nil) {
                setenv("PYTHONPATH", originalPythonpath, 1)
            } else {
                let returnValue = unsetenv("PYTHONPATH")
                if (returnValue == -1) { NSLog("Could not unsetenv PYTHONPATH") }
            }
            self.libraryFilesUpToDate = true
        }
    }
    
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        NSLog("Application didFinishLaunchingWithOptions \(launchOptions)")
        // Store variables in User Defaults:
        UserDefaults.standard.register(defaults: ["TeXEnabled" : false])
        UserDefaults.standard.register(defaults: ["TeXOpenType" : false])
        UserDefaults.standard.register(defaults: ["zshmarks" : true])
        UserDefaults.standard.register(defaults: ["bashmarks" : false])
        UserDefaults.standard.register(defaults: ["escape_preference" : false])
        initializeEnvironment()
        clearOldDirectories()
        replaceCommand("history", "history", true)
        replaceCommand("help", "help", true)
        replaceCommand("clear", "clear", true)
        replaceCommand("credits", "credits", true)
        replaceCommand("pickFolder", "pickFolder", true)
        // Add these as commands so they appear on the command list, even though we treat them internally:
        replaceCommand("newWindow", "clear", true)
        replaceCommand("exit", "clear", true)
        // replaceCommand("wasm", "wasm", true)
        activateFakeTeXCommands()
        if (UserDefaults.standard.bool(forKey: "TeXEnabled")) {
            downloadTeX();
        }
        if (UserDefaults.standard.bool(forKey: "TeXOpenType")) {
            downloadOpentype();
        }
        numPythonInterpreters = 2; // so pip can work (it runs python setup.py)
        setenv("VIMRUNTIME", Bundle.main.resourcePath! + "/vim", 1); // main resource for vim files
        setenv("TERM_PROGRAM", "a-Shell", 1) // let's inform users of who we are
        setenv("SSL_CERT_FILE", Bundle.main.resourcePath! +  "/cacert.pem", 1); // SLL cacert.pem in $APPDIR/cacert.pem
        let documentsUrl = try! FileManager().url(for: .documentDirectory,
                                                  in: .userDomainMask,
                                                  appropriateFor: nil,
                                                  create: true)
        // Link Python files from $APPDIR/Library to $HOME/Library/
        if (needToUpdatePythonFiles()) {
            // start copying python files from App bundle to $HOME/Library
            // queue the copy operation so we can continue working.
            versionUpToDate = false
            libraryFilesUpToDate = false
            queueUpdatingPythonFiles()
        }
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
        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    
    
    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
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
}

