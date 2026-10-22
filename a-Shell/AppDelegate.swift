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
import Network // for our local HTTPS server for WebAssembly

private let appGroupID = (Bundle.main.infoDictionary?["AppGroupIdentifier"] as? String) ?? "group.AsheKube.a-Shell"

let cleanupQueue = DispatchQueue(label: "deleteFiles", qos: .userInteractive) // high priority, but not blocking.
let localServerQueue = DispatchQueue(label: "localWebServer", qos: .userInteractive) // high priority, but not blocking
// Need SDK install to be over before starting commands.
var appDependentPath: String = "" // part of the path that depends on the App location (home, appdir)
let __known_browsers = ["internalbrowser", "googlechrome", "firefox", "safari", "yandexbrowser", "brave", "opera"]
private var localServer: LocalHTTPServer?
var zshmarksActivated = false
var bashmarksActivated = false

func startLocalWebServer() {
    localServerQueue.async {
        guard localServer == nil else { return }
        do {
            let data = try Data(contentsOf: Bundle.main.resourceURL!.appendingPathComponent("localCertificate.pfx"))
            let tls = try RelayTLS(pkcs12: data, passphrase: "password")
            let parameters = try tls.parameters()
            parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: LocalServerPorts.wasm)!)
            let server = LocalHTTPServer(queue: localServerQueue, requiresContentLength: false, connectionLimit: 64)
            server.request = { connection, method, target, _, _ in
                var headers = ["Cross-Origin-Embedder-Policy": "require-corp",
                               "Cross-Origin-Opener-Policy": "same-origin",
                               "Cross-Origin-Resource-Policy": "same-origin"]
                guard method == "GET",
                      let path = target.split(separator: "?", maxSplits: 1).first?.removingPercentEncoding,
                      path.hasPrefix("/"), !path.utf8.contains(0) else {
                    LocalHTTPServer.send(connection, status: 404, body: Data(), headers: [:])
                    return
                }
                let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
                let roots = [library, Bundle.main.resourceURL!]
                var file: URL?
                for root in roots {
                    let candidate = root.appendingPathComponent(String(path.dropFirst())).standardizedFileURL.resolvingSymlinksInPath()
                    let base = root.resolvingSymlinksInPath().path + "/"
                    guard candidate.path.hasPrefix(base) else {
                        LocalHTTPServer.send(connection, status: 403, body: Data(), headers: [:])
                        return
                    }
                    var isDirectory: ObjCBool = false
                    if FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDirectory), !isDirectory.boolValue {
                        file = candidate
                        break
                    }
                }
                guard let file else {
                    LocalHTTPServer.send(connection, status: 404, body: Data(), headers: [:])
                    return
                }
                switch file.pathExtension {
                case "html": headers["Content-Type"] = "text/html"
                case "js": headers["Content-Type"] = "application/javascript"
                case "wasm": headers["Content-Type"] = "application/wasm"
                default: headers["Content-Type"] = "application/octet-stream"
                }
                do {
                    let body = try Data(contentsOf: file, options: .mappedIfSafe)
                    LocalHTTPServer.send(connection, status: 200, body: body, headers: headers)
                } catch {
                    LocalHTTPServer.send(connection, status: 403, body: Data("Loading \(file.path) failed".utf8), headers: headers)
                }
            }
            localServer = server
            try server.start(parameters: parameters) { result in
                if case .failure(let error) = result {
                    NSLog("Local WASM server failed: \(error)")
                    localServer = nil
                }
            }
        } catch {
            localServer = nil
            NSLog("Local WASM server setup failed: \(error)")
        }
    }
}


// Which version of the app are we running? a-Shell, a-Shell-mini, a-Shell-pro...? (no spaces in name)
var appVersion: String? {
    // Bundle.main.infoDictionary?["CFBundleDisplayName"] = a-Shell
    // Bundle.main.infoDictionary?["CFBundleIdentifier"] = AsheKube.app.a-Shell
    // Bundle.main.infoDictionary?["CFBundleName"] = a-Shell
    // Bundle.main.infoDictionary["CFBundleShortVersionString"] = 1.15.2
    // Bundle.main.infoDictionary["CFBundleVersion"] = 422
    // NSLog("appVersion returns: \(Bundle.main.infoDictionary?["CFBundleName"])")
    return Bundle.main.infoDictionary?["CFBundleName"] as? String
}

@objcMembers
@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    // to update Python distribution at each version update
    var versionUpToDate = true
    var libraryFilesUpToDate = true

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
    
    func isM1iPad(modelName: String) -> Bool {
        // modelName for M1 iPad: iPad13,x for x in [4-17] (covers 11" and 12.9" iPad Pro and Air 5th gen)
        // modelName for M2 iPad: iPad14,x for x in [3-6]
        // modelName for M3 iPad: iPad15,x for x in [3-6]
        // modelName for M4 iPad: iPad16,x for x in [3-6]
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
        } else if (deviceName.hasPrefix("iPad15,") || deviceName.hasPrefix("iPad16,")) {
            if let minor = Int(deviceName) {
                if (minor >= 3) && (minor <= 6) {
                    return true
                }
            }
        }
        return false
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        #if DEBUG
        NSLog("Application didFinishLaunchingWithOptions \(String(describing: launchOptions))")
        #endif
        // Store variables in User Defaults:
        UserDefaults.standard.register(defaults: ["zshmarks" : true])
        UserDefaults.standard.register(defaults: ["bashmarks" : false])
        UserDefaults.standard.register(defaults: ["escape_preference" : false])
        UserDefaults.standard.register(defaults: ["show_toolbar" : true])
        UserDefaults.standard.register(defaults: ["legacy_toolbar" : false])
        // What color should the keyboard and system toolbar be? (screen: same mode as the screen itself)
        UserDefaults.standard.register(defaults: ["toolbar_color" : "screen"])
        UserDefaults.standard.register(defaults: ["screen_space" : "default"])
        UserDefaults.standard.register(defaults: ["restart_vim" : false])
        UserDefaults.standard.register(defaults: ["keep_content" : true])
        toolbarShouldBeShown = UserDefaults.standard.bool(forKey: "show_toolbar")
        // system toolbar only applies on iPads:
        useSystemToolbar = UIDevice.current.model.hasPrefix("iPad") && UserDefaults.standard.bool(forKey: "legacy_toolbar")
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
        replaceCommand("relay", "relay_main", true)
        replaceCommand("history", "history", true)
        replaceCommand("help", "help", true)
        replaceCommand("clear", "clear", true)
        replaceCommand("isForeground", "isForeground", true)
        replaceCommand("credits", "credits", true)
        replaceCommand("pickFolder", "pickFolder", true)
        replaceCommand("config", "config", true)
        replaceCommand("keepDirectoryAfterShortcut", "keepDirectoryAfterShortcut", true)
        replaceCommand("wasm", "wasm", true) // Apple's Wasm JIT interpreter. Faster than Wasm3 on CPU-intensive tasks, handles exceptions
        replaceCommand("jsc", "jsc_internal", false)  // use our own jsc instead of ios_system jsc. Keep the original version
        replaceCommand("call", "call", true)  // call a contact
        replaceCommand("text", "text", true)  // send a text to a contact
        replaceCommand("play", "play_main", true)
        replaceCommand("view", "preview_main", true)
        replaceCommand("z", "z_command", true) // change directory based on frequencys
        // replaceCommand("rehash", "rehash", true) // update list of commands for auto-complete
        replaceCommand("repeatCommand", "repeatCommand", true)
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
        // Called when installing/uninstalling LLVM or texlive distribution:
        if (appVersion != "a-Shell-mini") {
            replaceCommand("updateCommands", "updateCommands", true)
            // "updateCommands" is also called at startup:
            updateCommands(argc: 1, argv: nil);
        }
        if #unavailable(iOS 18) {
            replaceCommand("wasmkit", "wasmkitUnavailable", true)
        }
        // for debugging TeX issues / installing a new distribution
        // addCommandList(Bundle.main.path(forResource: "texCommandsDictionary", ofType: "plist"))
        // addCommandList(Bundle.main.path(forResource: "luatexCommandsDictionary", ofType: "plist"))
        let libraryURL = try! FileManager().url(for: .libraryDirectory,
                                                in: .userDomainMask,
                                                appropriateFor: nil,
                                                create: true)
        numPythonInterpreters = 2; // so pip can work (it runs python setup.py). Some packages, eg nexusforge need 3 interpreters.
        //  = a-Shell
        setenv("APPNAME", Bundle.main.infoDictionary?["CFBundleName"] as! String, 1)  // a-Shell or a-Shell-mini
        setenv("APPVERSION", Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String, 1) // 1.15.2
        setenv("APPBUILDNUMBER", Bundle.main.infoDictionary?["CFBundleVersion"] as! String, 1) // 422
        setenv("VIMRUNTIME", Bundle.main.resourcePath! + "/vim", 1); // main resource for vim files
        setenv("TERM_PROGRAM", "a-Shell", 1) // let's inform users of who we are
        setenv("COLORTERM", "truecolor", 1) // tell programs that we can display 16-bit colors (required by Python package rich).
        setenv("SSL_CERT_FILE", Bundle.main.resourcePath! +  "/cacert.pem", 1); // SLL cacert.pem in $APPDIR/cacert.pem
        setenv("MAGIC", Bundle.main.resourcePath! +  "/usr/share/magic.mgc", 1); // magic file for file command
        setenv("SHORTCUTS", FileManager().containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?.path, 1) // directory used by shortcuts
        setenv("GROUP", FileManager().containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?.path, 1) // directory used by shortcuts
        setenv("MANPATH", Bundle.main.resourcePath! +  "/man:" + libraryURL.path + "/man", 1)
        setenv("PAGER", "less", 1) // send control sequences directly to terminal
        setenv("TERM", "xterm-256color", 1); // now that we use SwiftTerm
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
        setenv("AIOHTTP_NO_EXTENSIONS", "1", 1)
        // This one is not required, but it helps:
        setenv("DISABLE_SQLALCHEMY_CEXT", "1", 1)
        versionUpToDate = !versionNumberIncreased()
        appDependentPath = String(utf8String: getenv("PATH")) ?? ""
        if (appVersion != "a-Shell-mini") {
            // clang options:
            setenv("SYSROOT", libraryURL.path + "/usr", 1) // sysroot for clang compiler
            // set up C and C++ compile options: silently add "--target=wasm32-wasi" at the beginning of arguments
            // and "-lunwind" at the end.
            // use legacy exception handling for iOS 14 to 17, new exception handling for iOS 18 and above.
            // - Apple wasm interpreter accepts the new EH on iOS 18 and above,
            // - wasmkit only accepts the new EH and only runs on iOS 18 and above
            // - wasm3 does not accept any kind of exception handling.
            if #available(iOS 18.0, *) {
                setenv("CCC_OVERRIDE_OPTIONS", "#^--target=wasm32-wasip1 ^-fwasm-exceptions ^-mllvm=-wasm-use-legacy-eh=false +-lunwind", 1)
            } else {
                setenv("CCC_OVERRIDE_OPTIONS", "#^--target=wasm32-wasip1 ^-fwasm-exceptions ^-mllvm=-wasm-use-legacy-eh=true  +-lunwind", 1)
            }
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
            let projDirPath = Bundle.main.resourcePath! + "/proj"
            setenv("PROJ_LIB", projDirPath, 1)  // proj <= 9.1
            setenv("PROJ_DATA", projDirPath, 1) // proj 9.1+
            setenv("PROJ_NETWORK", "ON", 1)
            setenv("QUTIP_NUM_PROCESSES", "1", 1) // number of processors in qutip
            let seabornData = libraryURL.appendingPathComponent("seaborn-data")
            setenv("SEABORN_DATA", seabornData.path, 1)
            let sklearnData = libraryURL.appendingPathComponent("scikit_learn_data")
            setenv("SCIKIT_LEARN_DATA", sklearnData.path, 1)
            let statsmodelsData = libraryURL.appendingPathComponent("statsmodels_data")
            setenv("STATSMODELS_DATA", statsmodelsData.path, 1)
            let pysalData = libraryURL.appendingPathComponent("pysal_data")
            setenv("PYSALDATA", pysalData.path, 1)
        } // end !a-Shell mini
        // All calls to setenv() before calls to executeCommandAndWait otherwise we can be redefining the environment
        // while copying it
        // Main Python install: $APPDIR/Library/lib/python3.x
        setenv("PYTHONHOME", Bundle.main.resourcePath! + "/Library", 1)
        // Compiled files: ~/Library/__pycache__
        setenv("PYTHONPYCACHEPREFIX", (libraryURL.appendingPathComponent("__pycache__")).path, 1)
        setenv("PYTHONUSERBASE", libraryURL.path, 1)
        setenv("PYTHON_HISTORY", documentsUrl.appendingPathComponent(".python_history").path, 1)
        setenv("PYZMQ_BACKEND", "cffi", 1)
        // Node modules installed in ~/Library/node_modules resolve from any directory; npm itself is in $APPDIR/npm.
        setenv("NODE_PATH", libraryURL.path + "/node_modules", 1)
        // Frameworks are in $APPDIR/Frameworks:
        setenv("DYLD_FRAMEWORK_PATH", Bundle.main.resourcePath! + "/Frameworks", 1)
        setenv("BLINK_OVERLAYS", (libraryURL.appendingPathComponent("blinkroot").path + ":"), 1)
        // Switch installed Python packages from 3.9 to 3.13:
        if (FileManager().fileExists(atPath: libraryURL.path + "/lib/python3.9/site-packages/")) {
            cleanupQueue.async{
                ios_switchSession("filesCleanup")
                // Move all site-packages to $HOME/Library/lib/python3.11/site-packages/
                executeCommandAndWait(command: "mkdir -p " + libraryURL.path + "/lib/python3.13/site-packages/")
                executeCommandAndWait(command: "mv " + libraryURL.path + "/lib/python3.9/site-packages/* " + libraryURL.path + "/lib/python3.11/site-packages/")
                // Erase the directory
                executeCommandAndWait(command: "rm -rf " + libraryURL.path + "/lib/python3.9/")
            }
        }
        // Switch installed Python packages from 3.11 to 3.13:
        if (FileManager().fileExists(atPath: libraryURL.path + "/lib/python3.11/site-packages/")) {
            cleanupQueue.async{
                ios_switchSession("filesCleanup")
                // Move all site-packages to $HOME/Library/lib/python3.11/site-packages/
                executeCommandAndWait(command: "mkdir -p " + libraryURL.path + "/lib/python3.13/site-packages/")
                executeCommandAndWait(command: "mv " + libraryURL.path + "/lib/python3.11/site-packages/* " + libraryURL.path + "/lib/python3.13/site-packages/")
                // Erase the directory
                executeCommandAndWait(command: "rm -rf " + libraryURL.path + "/lib/python3.11/")
            }
        }
        if (!versionUpToDate) {
            cleanupQueue.async{
                // The version number changed, so the App has been re-installed. Clean all pre-compiled Python files:
                NSLog("Cleaning __pycache__ and .cpan/build")
                ios_switchSession("filesCleanup")
                if (FileManager().fileExists(atPath: libraryURL.path + "/__pycache__")) {
                    executeCommandAndWait(command: "rm -rf " + libraryURL.path + "/__pycache__/*")
                }
                if (FileManager().fileExists(atPath: documentsUrl.appendingPathComponent(".cpan").path + "/build")) {
                    // Also clean all CPAN build directories (they aren't valid anymore)    :
                    executeCommandAndWait(command: "rm -rf " + documentsUrl.appendingPathComponent(".cpan").path + "/build/*")
                }
                // Also clean up the ~/tmp directory, it tends to build up
                executeCommandAndWait(command: "rm -rf " + NSTemporaryDirectory() + "/*")
            }
        }
        // Now set the version number to the current version:
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
        UserDefaults.standard.set(currentVersion, forKey: "versionInstalled")
        let currentBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as! String
        UserDefaults.standard.set(currentBuild, forKey: "buildNumber")
        self.versionUpToDate = true
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
        // print("Available fonts (families): \(UIFont.familyNames)");
        FileManager().changeCurrentDirectoryPath(documentsUrl.path)
        // Detect changes in user settings (preferences):
        NotificationCenter.default.addObserver(self, selector: #selector(self.settingsChanged), name: UserDefaults.didChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.settingsChanged), name: UIApplication.didBecomeActiveNotification, object: nil)
        // Also notification if user changes accessibility settings:
        NotificationCenter.default.addObserver(self, selector: #selector(self.voiceOverChanged), name:  UIAccessibility.voiceOverStatusDidChangeNotification, object: nil)
        if #available(iOS 17.0, *) {
            // For debugging tips (either  one):
            // try? Tips.resetDatastore()
            // Tips.showAllTipsForTesting()
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
        Relay.shared.restore()
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
        #if DEBUG
        NSLog("application configurationForConnecting connectingSceneSession \(connectingSceneSession)")
        #endif
        startLocalWebServer()
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
        // bookmarks management, copied from zshmarks: https://github.com/jocelynmallon/zshmarks
        let zshmarks = UserDefaults.standard.bool(forKey: "zshmarks")
        if (zshmarks && !zshmarksActivated) {
            zshmarksActivated = true
            replaceCommand("showmarks", "showmarks", true) //
            replaceCommand("jump", "jump", true) // go to bookmark
            replaceCommand("bookmark", "bookmark", true) // add bookmark for current directory
            replaceCommand("deletemark", "deletemark", true) // delete bookmark (might be dangerous)
            replaceCommand("renamemark", "renamemark", true) // rename bookmark
        }
        let bashmarks = UserDefaults.standard.bool(forKey: "bashmarks")
        if (bashmarks && !bashmarksActivated) {
            bashmarksActivated = true
            replaceCommand("l", "showmarks", true) //
            replaceCommand("p", "showmarks", true) //
            replaceCommand("g", "jump", true) // go to bookmark
            replaceCommand("s", "bookmark", true) // add bookmark for current directory
            replaceCommand("d", "deletemark", true) // delete bookmark (might be dangerous)
            replaceCommand("r", "renamemark", true) // rename bookmark
        }
        let toolbarColor = UserDefaults.standard.string(forKey: "toolbar_color")
        DispatchQueue.main.async {
            switch (toolbarColor) {
            case "dark":
                for scene in UIApplication.shared.connectedScenes {
                    if let delegate: SceneDelegate = scene.delegate as? SceneDelegate {
                        delegate.overrideUserInterfaceStyle(style: .dark)
                    }
                }
            case "light":
                for scene in UIApplication.shared.connectedScenes {
                    if let delegate: SceneDelegate = scene.delegate as? SceneDelegate {
                        delegate.overrideUserInterfaceStyle(style: .light)
                    }
                }
            case "screen":
                for scene in UIApplication.shared.connectedScenes {
                    if let delegate: SceneDelegate = scene.delegate as? SceneDelegate {
                        if let foregroundColor = delegate.terminalForegroundColor, let backgroundColor = delegate.terminalBackgroundColor {
                            if (foregroundColor.getBrightness() > backgroundColor.getBrightness()) {
                                delegate.overrideUserInterfaceStyle(style: .dark)
                            } else {
                                delegate.overrideUserInterfaceStyle(style: .light)
                            }
                        }
                    }
                }
            case "system":
                fallthrough
            default:
                for scene in UIApplication.shared.connectedScenes {
                    if let delegate: SceneDelegate = scene.delegate as? SceneDelegate {
                        delegate.overrideUserInterfaceStyle(style: .unspecified)
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
            DispatchQueue.main.async {
                for scene in UIApplication.shared.connectedScenes {
                    if let delegate: SceneDelegate = scene.delegate as? SceneDelegate {
                        delegate.hideToolbar()
                    }
                }
            }
        } else if (!toolbarShouldBeShown && toolbarSettings) {
            NSLog("Received call to show the toolbar through preferences")
            // User has just requested we show the toolbar
            // Send the value to all the SceneDelegate connected to this application
            toolbarShouldBeShown = true
            // Remove the toolbar on all connected scenes (usually none since the app is in the background):
            DispatchQueue.main.async {
                for scene in UIApplication.shared.connectedScenes {
                    if let delegate: SceneDelegate = scene.delegate as? SceneDelegate {
                        delegate.showEditorToolbar()
                    }
                }
            }
        }
        toolbarShouldBeShown = toolbarSettings
        // use the old-style toolbar on iPads (mostly as a bug fix for iPads that don't display the new toolbar)
        if UIDevice.current.model.hasPrefix("iPad") {
            let useOldToolbar = UserDefaults.standard.bool(forKey: "legacy_toolbar")
            if (useSystemToolbar && useOldToolbar) {
                useSystemToolbar = false
                if (toolbarShouldBeShown) {
                    DispatchQueue.main.async {
                        for scene in UIApplication.shared.connectedScenes {
                            if let delegate: SceneDelegate = scene.delegate as? SceneDelegate {
                                delegate.showEditorToolbar()
                            }
                        }
                    }
                }
            } else if (!useSystemToolbar && !useOldToolbar) {
                useSystemToolbar = true
                if (toolbarShouldBeShown) {
                    DispatchQueue.main.async {
                        for scene in UIApplication.shared.connectedScenes {
                            if let delegate: SceneDelegate = scene.delegate as? SceneDelegate {
                                delegate.showEditorToolbar()
                            }
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
    
    func application(_ application: UIApplication, handlerFor intent: INIntent) -> Any? {
        // copied from settingsChanged(), as that function is not called when a Shortcut is
        // launched and the app is not running.
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

        switch intent {
        case is GetFileIntent:
            return GetFileIntentHandler(application: application)
        case is PutFileIntent:
            return PutFileIntentHandler(application: application)
        case is ExecuteCommandIntent:
            return ExecuteCommandIntentHandler(application: application)
        default:
            return nil
        }
    }
}
