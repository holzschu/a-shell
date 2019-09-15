//
//  SceneDelegate.swift
//  a-Shell
//
//  Created by Nicolas Holzschuch on 30/06/2019.
//  Copyright © 2019 AsheKube. All rights reserved.
//

import UIKit
import SwiftUI
import WebKit
import ios_system

var messageHandlerAdded = false
var externalKeyboardPresent: Bool? // still needed?

// Need: dictionary connecting userContentController with output streams (?)

class SceneDelegate: UIResponder, UIWindowSceneDelegate, WKScriptMessageHandler {
    var window: UIWindow?
    var windowScene: UIWindowScene?
    var webView: WKWebView?
    var contentView: ContentView?
    var width = 80
    var height = 80
    var stdin_pipe: Pipe? = nil
    var stdout_pipe: Pipe? = nil
    var persistentIdentifier: String? = nil
    var stdin_file: UnsafeMutablePointer<FILE>? = nil
    var stdout_file: UnsafeMutablePointer<FILE>? = nil
    private let commandQueue = DispatchQueue(label: "executeCommand", qos: .utility) // low priority
    // Buttons and toolbars:
    var controlOn = false;
    // control codes:
    let interrupt = "\u{0003}"  // control-C, used to kill the process
    let endOfTransmission = "\u{0004}"  // control-D, used to signal end of transmission
    let escape = "\u{001B}"


    var screenWidth: CGFloat {
        if windowScene!.interfaceOrientation.isPortrait {
            return UIScreen.main.bounds.size.width
        } else {
            return UIScreen.main.bounds.size.height
        }
    }
    var screenHeight: CGFloat {
        if windowScene!.interfaceOrientation.isPortrait {
            return UIScreen.main.bounds.size.height
        } else {
            return UIScreen.main.bounds.size.width
        }
    }
    
    var fontSize: CGFloat {
        let deviceModel = UIDevice.current.model
        if (deviceModel.hasPrefix("iPad")) {
            let minFontSize: CGFloat = screenWidth / 50
            // print("Screen width = \(screenWidth), fontSize = \(minFontSize)")
            if (minFontSize > 18) { return 18.0 }
            else { return minFontSize }
        } else {
            let minFontSize: CGFloat = screenWidth / 23
            // print("Screen width = \(screenWidth), fontSize = \(minFontSize)")
            if (minFontSize > 15) { return 15.0 }
            else { return minFontSize }
        }
    }
    
    var toolbarHeight: CGFloat {
        let deviceModel = UIDevice.current.model
        if (deviceModel.hasPrefix("iPad")) {
            return 50
        } else {
            return 35
        }
    }
    
    @objc private func tabAction(_ sender: UIBarButtonItem) {
        webView?.evaluateJavaScript("window.term_.io.onVTKeystroke(\"" + "\u{0009}" + "\");") { (result, error) in
            if error != nil {
                print(error)
            }
            if (result != nil) {
                print(result)
            }
        }
    }

    @objc private func controlAction(_ sender: UIBarButtonItem) {
        controlOn = !controlOn;
        let configuration = UIImage.SymbolConfiguration(pointSize: fontSize, weight: .regular, scale: .large)
        if (controlOn) {
            editorToolbar.items?[1].image = UIImage(systemName: "chevron.up.square.fill")!.withConfiguration(configuration)
            webView?.evaluateJavaScript("window.controlOn = true;") { (result, error) in
                if error != nil {
                    print(error)
                }
                if (result != nil) {
                    print(result)
                }
            }
        } else {
            editorToolbar.items?[1].image = UIImage(systemName: "chevron.up.square")!.withConfiguration(configuration)
            webView?.evaluateJavaScript("window.controlOn = false;") { (result, error) in
                if error != nil {
                    print(error)
                }
                if (result != nil) {
                    print(result)
                }
            }
        }
    }
    
    @objc private func escapeAction(_ sender: UIBarButtonItem) {
        webView?.evaluateJavaScript("window.term_.io.onVTKeystroke(\"" + escape + "\");") { (result, error) in
            if error != nil {
                print(error)
            }
            if (result != nil) {
                print(result)
            }
        }
    }

    @objc private func upAction(_ sender: UIBarButtonItem) {
        webView?.evaluateJavaScript("window.term_.io.onVTKeystroke(\"" + escape + "[A\");") { (result, error) in
            if error != nil {
                print(error)
            }
            if (result != nil) {
                print(result)
            }
        }
    }
    
    @objc private func downAction(_ sender: UIBarButtonItem) {
        webView?.evaluateJavaScript("window.term_.io.onVTKeystroke(\"" + escape + "[B\");") { (result, error) in
            if error != nil {
                print(error)
            }
            if (result != nil) {
                print(result)
            }
            
        }
    }
    
    @objc private func leftAction(_ sender: UIBarButtonItem) {
        webView?.evaluateJavaScript("window.term_.io.onVTKeystroke(\"" + escape + "[D\");") { (result, error) in
            if error != nil {
                print(error)
            }
            if (result != nil) {
                print(result)
            }
            
        }
    }

    @objc private func rightAction(_ sender: UIBarButtonItem) {
        webView?.evaluateJavaScript("window.term_.io.onVTKeystroke(\"" + escape + "[C\");") { (result, error) in
            if error != nil {
                print(error)
            }
            if (result != nil) {
                print(result)
            }
            
        }
    }
    
    var tabButton: UIBarButtonItem {
        let configuration = UIImage.SymbolConfiguration(pointSize: fontSize, weight: .regular)
        let tabButton = UIBarButtonItem(image: UIImage(systemName: "arrow.right.to.line.alt")!.withConfiguration(configuration), style: .plain, target: self, action: #selector(tabAction(_:)))
        return tabButton
    }

    var controlButton: UIBarButtonItem {
        let configuration = UIImage.SymbolConfiguration(pointSize: fontSize, weight: .regular, scale: .large)
        // Image used to be control
        let imageControl = (controlOn == true) ? UIImage(systemName: "chevron.up.square.fill")! : UIImage(systemName: "chevron.up.square")!
        let controlButton = UIBarButtonItem(image: imageControl.withConfiguration(configuration), style: .plain, target: self, action: #selector(controlAction(_:)))
        return controlButton
    }
    
    var escapeButton: UIBarButtonItem {
        let configuration = UIImage.SymbolConfiguration(pointSize: fontSize, weight: .regular)
        let escapeButton = UIBarButtonItem(image: UIImage(systemName: "escape")!.withConfiguration(configuration), style: .plain, target: self, action: #selector(escapeAction(_:)))
        return escapeButton
    }
    

    var upButton: UIBarButtonItem {
        let configuration = UIImage.SymbolConfiguration(pointSize: fontSize, weight: .regular)
        let upButton = UIBarButtonItem(image: UIImage(systemName: "arrow.up")!.withConfiguration(configuration), style: .plain, target: self, action: #selector(upAction(_:)))
        return upButton
    }
    
    var downButton: UIBarButtonItem {
        let configuration = UIImage.SymbolConfiguration(pointSize: fontSize, weight: .regular)
        let downButton = UIBarButtonItem(image: UIImage(systemName: "arrow.down")!.withConfiguration(configuration), style: .plain, target: self, action: #selector(downAction(_:)))
        return downButton
    }
    
    var leftButton: UIBarButtonItem {
        let configuration = UIImage.SymbolConfiguration(pointSize: fontSize, weight: .regular)
        let leftButton = UIBarButtonItem(image: UIImage(systemName: "arrow.left")!.withConfiguration(configuration), style: .plain, target: self, action: #selector(leftAction(_:)))
        return leftButton
    }

    var rightButton: UIBarButtonItem {
        let configuration = UIImage.SymbolConfiguration(pointSize: fontSize, weight: .regular)
        let rightButton = UIBarButtonItem(image: UIImage(systemName: "arrow.right")!.withConfiguration(configuration), style: .plain, target: self, action: #selector(rightAction(_:)))
        return rightButton
    }

    
    public lazy var editorToolbar: UIToolbar = {
        var toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: (self.webView?.bounds.width)!, height: toolbarHeight))
        toolbar.tintColor = .label
        toolbar.items = [tabButton, controlButton, escapeButton, UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: self, action: nil), upButton, downButton, leftButton, rightButton]
        return toolbar
    }()
    
    
    
    func printPrompt() {
        DispatchQueue.main.async {
            self.webView?.evaluateJavaScript("window.printPrompt(); window.updatePromptPosition(); window.commandRunning = ''; ") { (result, error) in
                if error != nil {
                    print(error)
                }
                if (result != nil) {
                    print(result)
                }
            }
        }
    }
    
    func printHistory() {
        DispatchQueue.main.async {
            self.webView?.evaluateJavaScript("window.commandArray.forEach(item => window.term_.io.println(item));") { (result, error) in
                if error != nil {
                    print(error)
                }
                if (result != nil) {
                    print(result)
                }
            }
        }
    }
    // Even if Caps-Lock is activated, send lower case letters.
    @objc func insertKey(_ sender: UIKeyCommand) {
        guard (sender.input != nil) else { return }
        // This function only gets called if we are in a notebook, in edit_mode:
        // Only remap the keys if we are in a notebook, editing cell:
        webView?.evaluateJavaScript("window.term_.io.onVTKeystroke(\"" + sender.input! + "\");") { (result, error) in
            if error != nil {
                print(error)
            }
            if (result != nil) {
                print(result)
            }
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        let cmd:String = message.body as! String
        if (cmd.hasPrefix("shell:")) {
            // Set COLUMNS to term width:
            setenv("COLUMNS", "\(width)".toCString(), 1);
            setenv("LINES", "\(height)".toCString(), 1);
            var command = cmd
            command.removeFirst("shell:".count)
            // set up streams for feedback:
            // Create new pipes for our own stdout/stderr
            // Get file for stdin that can be read from
            // Create new pipes for our own stdout/stderr
            stdin_pipe = Pipe()
            guard stdin_pipe != nil else { return }
            stdin_file = fdopen(stdin_pipe!.fileHandleForReading.fileDescriptor, "r")
            // TODO: Having stdin_file == nil requires more than just return. Think about it.
            guard stdin_file != nil else {
                NSLog("Can't open stdin_file: \(String(cString: strerror(errno)))")
                return
            }
            // Get file for stdout/stderr that can be written to
            stdout_pipe = Pipe()
            guard stdout_pipe != nil else { return }
            stdout_file = fdopen(stdout_pipe!.fileHandleForWriting.fileDescriptor, "w")
            guard stdout_file != nil else { return }
            // Call the following functions when data is written to stdout/stderr.
            stdout_pipe!.fileHandleForReading.readabilityHandler = self.onStdout
            commandQueue.async {
                // testing for luatex:
                thread_stdin  = nil
                thread_stdout = nil
                thread_stderr = nil
                // Make sure we're running the right session
                ios_switchSession(self.persistentIdentifier?.toCString())
                ios_setContext(UnsafeMutableRawPointer(mutating: self.persistentIdentifier?.toCString()));
                ios_setStreams(self.stdin_file, self.stdout_file, self.stdout_file)
                // Execute command (remove spaces at the beginning and end):
                // reset the LC_CTYPE (some commands (luatex) can change it):
                setenv("LC_CTYPE", "UTF-8", 1);
                setlocale(LC_CTYPE, "UTF-8");
                // Setting these breaks lualatex -- not setting them might break something else.
                // setenv("LC_ALL", "UTF-8", 1);
                // setlocale(LC_ALL, "UTF-8");
                ios_system(command.trimmingCharacters(in: .whitespacesAndNewlines))
                // Send info to the stdout handler that the command has finished:
                let writeOpen = fcntl(self.stdout_pipe!.fileHandleForWriting.fileDescriptor, F_GETFD)
                let readOpen = fcntl(self.stdout_pipe!.fileHandleForReading.fileDescriptor, F_GETFD)
                if (writeOpen >= 0) {
                    // Pipe is still open, send information to close it, once all output has been processed.
                    self.stdout_pipe!.fileHandleForWriting.write(self.endOfTransmission.data(using: .utf8)!)
                } else {
                    // Pipe has been closed, ready to run new command:
                    self.printPrompt();
                }
            }
        } else if (cmd.hasPrefix("width:")) {
            var command = cmd
            command.removeFirst("width:".count)
            let newWidth = Int(command) ?? 80
            if (newWidth != width) {
                width = newWidth
                setenv("COLUMNS", "\(width)".toCString(), 1)
                kill(getpid(), SIGWINCH)
            }
        } else if (cmd.hasPrefix("height:")) {
            var command = cmd
            command.removeFirst("height:".count)
            let newHeight = Int(command) ?? 80
            if (newHeight != height) {
                height = newHeight
                setenv("LINES", "\(height)".toCString(), 1)
                kill(getpid(), SIGWINCH)
            }
        } else if (cmd.hasPrefix("controlOff")) {
            controlOn = false
            let configuration = UIImage.SymbolConfiguration(pointSize: fontSize, weight: .regular, scale: .large)
            editorToolbar.items?[1].image = UIImage(systemName: "chevron.up.square")!.withConfiguration(configuration)
        } else if (cmd.hasPrefix("input:")) {
            var command = cmd
            command.removeFirst("input:".count)
            guard let data = command.data(using: .utf8) else { return }
            ios_switchSession(self.persistentIdentifier?.toCString())
            ios_setContext(UnsafeMutableRawPointer(mutating: self.persistentIdentifier?.toCString()));
            ios_setStreams(self.stdin_file, self.stdout_file, self.stdout_file)
            if (command == endOfTransmission) {
                // Stop standard input for the command:
                self.stdin_pipe!.fileHandleForWriting.closeFile()
            } else if (command == interrupt) {
                ios_kill()
            } else {
                guard stdin_pipe != nil else { return }
                // TODO: don't send data if pipe already closed (^D followed by another key)
                // (store a variable that says the pipe has been closed)
                stdin_pipe!.fileHandleForWriting.write(data)
            }
        } else if (cmd.hasPrefix("listDirectory:")) {
            var directory = cmd
            directory.removeFirst("listDirectory:".count)
            if (directory.count == 0) { return }
            do {
                // NSLog("about to list: \(directory)")
                var filePaths = try FileManager().contentsOfDirectory(atPath: directory.replacingOccurrences(of: "\\ ", with: " ")) // un-escape spaces
                filePaths.sort()
                var javascriptCommand = "fileList = ["
                for filePath in filePaths {
                    // print(filePath)
                    // escape spaces, replace "\r" in filenames with "?"
                    javascriptCommand += "\"" + filePath.replacingOccurrences(of: " ", with: "\\\\ ").replacingOccurrences(of: "\r", with: "?")
                    let fullPath = directory.replacingOccurrences(of: "\\ ", with: " ") + "/" + filePath
                    // NSLog("path = \(fullPath) , isDirectory: \(URL(fileURLWithPath: fullPath).isDirectory)")
                    if URL(fileURLWithPath: fullPath).isDirectory {
                        javascriptCommand += "/"
                    }
                    else {
                        javascriptCommand += " "
                    }
                    javascriptCommand += "\", "
                }
                // We need to re-escapce spaces for string comparison to work in JS:
                javascriptCommand += "]; lastDirectory = \"" + directory.replacingOccurrences(of: " ", with: "\\ ") + "\"; updateFileMenu(); "
                // print(javascriptCommand)
                DispatchQueue.main.async {
                    self.webView?.evaluateJavaScript(javascriptCommand) { (result, error) in
                        if error != nil {
                            print(error)
                        }
                        if (result != nil) {
                            print(result)
                        }
                    }
                }
                // print("Found files: \(fileURLs)")
            } catch {
                NSLog("Error getting files from directory: \(directory): \(error.localizedDescription)")
            }
        } else {
            // Usually debugging information
            NSLog("JavaScript message: \(message.body)")
        }
    }
    
    private var webContentView: UIView? {
        for subview in (webView?.scrollView.subviews)! {
            if subview.classForCoder.description() == "WKContentView" {
                return subview
            }
            // on iPhones, adding the toolbar has changed the name of the view:
            if subview.classForCoder.description() == "WKApplicationStateTrackingView_CustomInputAccessoryView" {
                return subview
            }
        }
        return nil
    }
    

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnecting:SceneSession` instead).
        // Use a UIHostingController as window root view controller
        if let windowScene = scene as? UIWindowScene {
            self.windowScene = windowScene
            let window = UIWindow(windowScene: windowScene)
            contentView = ContentView()
            window.rootViewController = UIHostingController(rootView: contentView)
            window.autoresizesSubviews = true
            self.window = window
            window.makeKeyAndVisible()
            self.persistentIdentifier = session.persistentIdentifier
            ios_switchSession(self.persistentIdentifier?.toCString())
            ios_setContext(UnsafeMutableRawPointer(mutating: self.persistentIdentifier?.toCString()));
            webView = contentView?.webview.webView
            // add a contentController that is specific to each webview
            webView?.configuration.userContentController = WKUserContentController()
            webView?.configuration.userContentController.add(self, name: "aShell") 
            // toolbar for everyone because I can't change the aspect of inputAssistantItem buttons
            webView?.addInputAccessoryView(toolbar: self.editorToolbar)
            // Add a callback to change the buttons every time the user changes the input method:
            NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidChange), name: UITextInputMode.currentInputModeDidChangeNotification, object: nil)
            // And another to be called each time the keyboard is resized (including when an external KB is connected):
            NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidChange), name: UIResponder.keyboardDidChangeFrameNotification, object: nil)
            // initialize command list for autocomplete:
            // TODO: also scan PATH for executable files. Difficult
            guard var commandsArray = commandsAsArray() as! [String]? else { return }
            commandsArray.sort() // make sure it's in alphabetical order
            var javascriptCommand = "var commandList = ["
            for command in commandsArray {
                javascriptCommand += "\"" + command + "\", "
            }
            javascriptCommand += "];"
            webView!.evaluateJavaScript(javascriptCommand) { (result, error) in
                if error != nil {
                    NSLog("Error in creating command list, line = \(javascriptCommand)")
                    print(error)
                }
                if (result != nil) {
                    print(result)
                }
            }
        }
    }

    
    @objc private func keyboardDidChange(notification: NSNotification) {
        let info = notification.userInfo
        let keyboardFrame = (info?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
        guard (keyboardFrame != nil) else { return }
        // resize webview

        // Is there a toolbar at the bottom?
        if (keyboardFrame!.size.height <= toolbarHeight) {
            // Only the toolbar is left, hide it:
            self.editorToolbar.isHidden = true
            self.editorToolbar.isUserInteractionEnabled = false
        } else {
            self.editorToolbar.isHidden = false
            self.editorToolbar.isUserInteractionEnabled = true
        }
        
        // iPads:
        // Is there an external keyboard connected?
        if (UIDevice.current.model.hasPrefix("iPad")) {
            if (info != nil) {
            // "keyboardFrameEnd" is a CGRect corresponding to the size of the keyboard plus the button bar.
            // It's 55 when there is an external keyboard connected, 300+ without.
            // Actual values may vary depending on device, but 60 seems a good threshold.
                // externalKeyboardPresent = keyboardFrame!.size.height < 60
            }
        }
    }

    
    
    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not neccessarily discarded (see `application:didDiscardSceneSessions` instead).
        NSLog("sceneDidDisconnect: \(self.persistentIdentifier).")
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
        NSLog("sceneDidBecomeActive: \(self.persistentIdentifier).")
        // Window.term_ does not always exist when sceneDidBecomeActive is called. We *also* set window.foregroundColor, and then use that when we create term.
        let traitCollection = webView!.traitCollection
        var command = "window.term_.setForegroundColor('" + UIColor.placeholderText.resolvedColor(with: traitCollection).toHexString() + "'); window.term_.setBackgroundColor('" + UIColor.systemBackground.resolvedColor(with: traitCollection).toHexString() + "'); "
        webView!.evaluateJavaScript(command) { (result, error) in
            if error != nil {
                NSLog("Error in sceneDidBecomeActive, line = \(command)")
                print(error)
            }
            if (result != nil) {
                print(result)
            }
        }
        command = "window.term_.prefs_.set('foreground-color', '" + UIColor.placeholderText.resolvedColor(with: traitCollection).toHexString() + "'); window.term_.prefs_.set('background-color', '" + UIColor.systemBackground.resolvedColor(with: traitCollection).toHexString() + "'); "
        webView!.evaluateJavaScript(command) { (result, error) in
            if error != nil {
                NSLog("Error in sceneDidBecomeActive, line = \(command)")
                print(error)
            }
            if (result != nil) {
                print(result)
            }
        }
        webView!.allowDisplayingKeyboardWithoutUserAction()
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
        NSLog("sceneWillResignActive: \(self.persistentIdentifier).")
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
        NSLog("sceneWillEnterForeground: \(self.persistentIdentifier).")
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
        
        // TODO: save command history
        // TODO: + currently running command? (if it is an editor, say)
        NSLog("sceneDidEnterBackground: \(self.persistentIdentifier).")
    }

    // Called when the stdout file handle is written to
    private var dataBuffer = Data()

    private func outputToWebView(string: String) {
        guard (webView != nil) else { return }
        // Sanitize the output string to it can be sent to javascript:
        var parsedString = string.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\r", with: "\\r").replacingOccurrences(of: "\n", with: "\\n\\r")
        // NSLog("\(parsedString)")
        // This may cause several \r in a row
        let command = "window.term_.io.print(\"" + parsedString + "\");"
        DispatchQueue.main.async {
            self.webView!.evaluateJavaScript(command) { (result, error) in
                if error != nil {
                    NSLog("Error in print; offending line = \(parsedString)")
                    print(error)
                }
                if (result != nil) {
                    print(result)
                }
            }
        }
        return
        // I know
        while (parsedString.count > 0) {
            guard let firstReturn = parsedString.firstIndex(of: "\n") else {
                let command = "window.term_.io.print(\"" + parsedString + "\");"
                DispatchQueue.main.async {
                    self.webView!.evaluateJavaScript(command) { (result, error) in
                        if error != nil {
                            NSLog("Error in print; offending line = \(parsedString)")
                            print(error)
                        }
                        if (result != nil) {
                            print(result)
                        }
                    }
                }
                return
            }
            let firstLine = parsedString[..<firstReturn]
            let command = "window.term_.io.println(\"" + firstLine + "\");"
            DispatchQueue.main.async {
                self.webView!.evaluateJavaScript(command) { (result, error) in
                    if error != nil {
                        NSLog("Error in println; offending line = \(firstLine)")
                        print(error)
                    }
                    if (result != nil) {
                        print(result)
                    }
                }
            }
            parsedString.removeFirst(firstLine.count + 1)
        }
    }
    
    private func onStdout(_ stdout: FileHandle) {
        let data = stdout.availableData
        guard (data.count > 0) else {
            return
        }
        if let string = String(data: data, encoding: String.Encoding.utf8) {
            outputToWebView(string: string)
            if (string.contains(endOfTransmission)) {
                // Finished processing the output, can get back to prompt:
                printPrompt();
            }
        } else {
            NSLog("Couldn't convert data in stdout: \(data)")
        }
    }
    
}

