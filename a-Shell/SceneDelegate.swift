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
import MobileCoreServices
import Combine

var messageHandlerAdded = false
var externalKeyboardPresent: Bool? // still needed?
var inputFileURLBackup: URL?


// Need: dictionary connecting userContentController with output streams (?)

class SceneDelegate: UIViewController, UIWindowSceneDelegate, WKNavigationDelegate, WKScriptMessageHandler, UIDocumentPickerDelegate {
    var window: UIWindow?
    var windowScene: UIWindowScene?
    var webView: WKWebView?
    var contentView: ContentView?
    var history: [String] = []
    var width = 80
    var height = 80
    var stdin_pipe: Pipe? = nil
    var stdout_pipe: Pipe? = nil
    var persistentIdentifier: String? = nil
    var stdin_file: UnsafeMutablePointer<FILE>? = nil
    var stdout_file: UnsafeMutablePointer<FILE>? = nil
    // copies of thread_std*, used when inside a sub-thread, for example executing webAssembly
    var thread_stdin_copy: UnsafeMutablePointer<FILE>? = nil
    var thread_stdout_copy: UnsafeMutablePointer<FILE>? = nil
    var thread_stderr_copy: UnsafeMutablePointer<FILE>? = nil
    var keyboardTimer: Timer!
    private let commandQueue = DispatchQueue(label: "executeCommand", qos: .utility) // low priority, for executing commands
    // Buttons and toolbars:
    var controlOn = false;
    // control codes:
    let interrupt = "\u{0003}"  // control-C, used to kill the process
    let endOfTransmission = "\u{0004}"  // control-D, used to signal end of transmission
    let escape = "\u{001B}"
    // Are we editing a file?
    var closeAfterCommandTerminates = false
    var currentCommand = ""
    // Store these for session restore:
    var currentDirectory = ""
    var previousDirectory = ""
    // Store cancelalble instances
    var cancellables = Set<AnyCancellable>()
    
    // Create a document picker for directories.
    private let documentPicker =
        UIDocumentPickerViewController(documentTypes: [kUTTypeFolder as String],
                                       in: .open)

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
            let minFontSize: CGFloat = screenWidth / 55
            // print("Screen width = \(screenWidth), fontSize = \(minFontSize)")
            if (minFontSize > 16) { return 16.0 }
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
            return 40
        } else {
            return 35
        }
    }
    
    var isVimRunning: Bool {
      return (currentCommand.hasPrefix("vim ")) || (currentCommand == "vim") || (currentCommand.hasPrefix("jump "))
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
        for command in history {
            fputs(command + "\n", thread_stdout)
        }
    }

    func printText(string: String) {
        fputs(string, thread_stdout)
    }
        
    func printError(string: String) {
        fputs(string, thread_stderr)
    }

    func closeWindow() {
        // Only close if all running functions are terminated:
        NSLog("Closing window: \(currentCommand)")
        if (currentCommand != "") {
            // There is a command running. Wait.
            // TODO: trigger cleanup depending on command (exit for nslookup, for ex.)
            closeAfterCommandTerminates = true
            return
        }
        UIApplication.shared.requestSceneSessionDestruction(self.windowScene!.session, options: nil)
    }

    func clearScreen() {
        DispatchQueue.main.async {
            // clear entire display: ^[[2J
            // position cursor on top line: ^[[1;1H 
            self.webView?.evaluateJavaScript("window.term_.io.print('" + self.escape + "[2J'); window.term_.io.print('" + self.escape + "[1;1H'); ") { (result, error) in
                if error != nil {
                    print(error)
                }
                if (result != nil) {
                    print(result)
                }
            }
        }
    }
    
    func executeWebAssembly(arguments: [String]?) -> Int32 {
        guard (arguments != nil) else { return -1 }
        guard (arguments!.count >= 2) else { return -1 } // There must be at least one command
        // copy arguments:
        let command = arguments![1]
        var argumentString = "["
        var fileNamesString = "["
        var fileContentsString = "["
        for c in 1...arguments!.count-1 {
            if let argument = arguments?[c] {
                let sanitizedArgument = argument.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
                // TODO: check this
                // replace quotes and backslashes in arguments:
                argumentString = argumentString + " \"" +  sanitizedArgument + "\","
                if (c > 1) {
                    if FileManager().fileExists(atPath: argument) {
                        if let buffer = NSData(contentsOf: URL(fileURLWithPath: argument)) {
                            fileNamesString = fileNamesString + "\"" + sanitizedArgument + "\","
                            fileContentsString = fileContentsString + "\"" + buffer.base64EncodedString() + "\","
                        }
                    }
                }
            }
        }
        argumentString = argumentString + "]"
        fileNamesString = fileNamesString + "]"
        print(fileNamesString)
        fileContentsString = fileContentsString + "]"
        // read the entire stdin if it is not a tty:
        var stdin = ""
        if (ios_isatty(STDIN_FILENO) == 0) {
            // something is writing to stdin; let's take it.
            let input = FileHandle(fileDescriptor: fileno(thread_stdin))
            let inputData = input.availableData
            let stdinData = NSData(data: inputData)
            stdin = stdinData.base64EncodedString()
        }
        // async functions don't work in WKWebView (so, no fetch, no WebAssembly.instantiateStreaming)
        // Instead, we load the file in swift and send the base64 version to JS
        let currentDirectory = FileManager().currentDirectoryPath
        let fileName = command.hasPrefix("/") ? command : currentDirectory + "/" + command
        guard let buffer = NSData(contentsOf: URL(fileURLWithPath: fileName)) else {
            fputs("wasm: file \(command) not found\n", thread_stderr)
            return -1
        }
        let base64string = buffer.base64EncodedString()
        // TODO: here, add fileNamesString and fileContentsString
        let javascript = "executeWebAssembly(\"\(base64string)\", " + argumentString + ", \"" + stdin + "\", \"" + currentDirectory + "\")"
        var executionDone = false
        var errorCode:Int32 = 0
        thread_stdin_copy = thread_stdin
        thread_stdout_copy = thread_stdout
        thread_stderr_copy = thread_stderr
        DispatchQueue.main.async {
            self.webView?.evaluateJavaScript(javascript) { (result, error) in
                if error != nil {
                    let userInfo = (error! as NSError).userInfo
                    fputs("wasm: Error ", self.thread_stderr_copy)
                    // WKJavaScriptExceptionSourceURL is hterm.html, of course.
                    if let file = userInfo["WKJavaScriptExceptionSourceURL"] as? String {
                        fputs("in file " + file + " ", self.thread_stderr_copy)
                    }
                    if let line = userInfo["WKJavaScriptExceptionLineNumber"] as? Int32 {
                        fputs("at line \(line)", self.thread_stderr_copy)
                    }
                    if let column = userInfo["WKJavaScriptExceptionColumnNumber"] as? Int32 {
                        fputs(", column \(column): ", self.thread_stderr_copy)
                    } else {
                        fputs(": ", self.thread_stderr_copy)
                    }
                    if let message = userInfo["WKJavaScriptExceptionMessage"] as? String {
                        fputs(message + "\n", self.thread_stderr_copy)
                    }
                    fflush(self.thread_stderr_copy)
                    // print(error)
                }
                if (result != nil) {
                    // executeWebAssembly sends back stdout and stderr as two Strings:
                    if let array = result! as? NSMutableArray {
                        if let std_out = array[0] as? String {
                           // fputs(std_out, self.thread_stdout_copy);
                        }
                        if let std_err = array[1] as? String {
                           // fputs(std_err, self.thread_stderr_copy);
                        }
                        if let code = array[2] as? Int32 {
                            errorCode = code
                        }
                        if let volume = array[3] as? NSDictionary {
                            for file in volume {
                                guard var name = file.key as? String else {
                                    continue
                                }
                                if (name == "/dev/stdin") { continue }
                                if (name == "/dev/stdout") { continue }
                                if (name == "/dev/stderr") { continue }
                                // Do not save temporary files:
                                if (name.hasPrefix("/tmp/")) { continue }
                                if (name.hasPrefix("tmp/")) { continue }
                                let localFileData = volume[name]
                                if (name.hasPrefix("/")) {
                                    name = currentDirectory + name
                                }
                                /* do {
                                    let fileUrl = URL(fileURLWithPath: name)
                                    if let localDict = localFileData as? NSDictionary {
                                        let maxCount = localDict.count
                                        var data = Data.init()
                                        for character in 0...maxCount-1 {
                                            if let value = localDict["\(character)"] as? UInt8{
                                                data.append(contentsOf: [value])
                                            }
                                        }
                                        if (!FileManager().fileExists(atPath: name)) {
                                            // Create the file:
                                            try "".write(to: fileUrl, atomically: true, encoding: .utf8)
                                        }
                                        if let file = FileHandle(forWritingAtPath: name) {
                                            file.write(data)
                                            file.closeFile()
                                        }
                                    }
                                }
                                catch {
                                    fputs("\(command): could not write to file \(name): \(error)", self.thread_stderr_copy)
                                } */
                            }
                        }
                    } else if let string = result! as? String {
                        fputs(string, self.thread_stdout_copy);
                    }
                }
                executionDone = true
            }
        }
        // force synchronization:
        while (!executionDone) {
            fflush(thread_stdout)
            fflush(thread_stderr)
        }
        return errorCode
    }
    
    func printJscUsage() {
        fputs("Usage: jsc file.js\n", thread_stdout)
    }

    func executeJavascript(arguments: [String]?) {
        guard (arguments != nil) else {
            printJscUsage()
            return
        }
        guard (arguments!.count == 2) else {
            printJscUsage()
            return
        }
        let command = arguments![1]
        let fileName = FileManager().currentDirectoryPath + "/" + command
        thread_stdout_copy = thread_stdout
        thread_stderr_copy = thread_stderr
        var executionDone = false
        do {
            var javascript = try String(contentsOf: URL(fileURLWithPath: fileName), encoding: String.Encoding.utf8)
            // Code included in {} so variables don't leak. Some variables seem to leak. TODO: investigate
            javascript = "{" + javascript + "}"
            DispatchQueue.main.async {
                self.webView?.evaluateJavaScript(javascript) { (result, error) in
                    if error != nil {
                        // Extract information about *where* the error is, etc.
                        let userInfo = (error! as NSError).userInfo
                        fputs("jsc: Error ", self.thread_stderr_copy)
                        // WKJavaScriptExceptionSourceURL is hterm.html, of course.
                        fputs("in file " + command + " ", self.thread_stderr_copy)
                        if let line = userInfo["WKJavaScriptExceptionLineNumber"] as? Int32 {
                            fputs("at line \(line)", self.thread_stderr_copy)
                        }
                        if let column = userInfo["WKJavaScriptExceptionColumnNumber"] as? Int32 {
                            fputs(", column \(column): ", self.thread_stderr_copy)
                        } else {
                            fputs(": ", self.thread_stderr_copy)
                        }
                        if let message = userInfo["WKJavaScriptExceptionMessage"] as? String {
                            fputs(message + "\n", self.thread_stderr_copy)
                        }
                        fflush(self.thread_stderr_copy)
                    }
                    if (result != nil) {
                        if let string = result! as? String {
                            fputs(string, self.thread_stdout_copy)
                            fputs("\n", self.thread_stdout_copy)
                        }  else if let number = result! as? Int32 {
                            fputs("\(number)", self.thread_stdout_copy)
                            fputs("\n", self.thread_stdout_copy)
                        } else if let number = result! as? Float {
                            fputs("\(number)", self.thread_stdout_copy)
                            fputs("\n", self.thread_stdout_copy)
                        } else {
                            fputs("\(result)", self.thread_stdout_copy)
                            fputs("\n", self.thread_stdout_copy)
                        }
                        fflush(self.thread_stdout_copy)
                        fflush(self.thread_stderr_copy)
                    }
                    executionDone = true
                }
            }
        }
        catch {
         fputs("Error executing JavaScript  file: " + command + ": \(error) \n", thread_stderr)
          executionDone = true
        }
        while (!executionDone) {
            fflush(thread_stdout)
            fflush(thread_stderr)
        }
        thread_stdout_copy = nil
        thread_stderr_copy = nil
    }

    func pickFolder() {
        // https://developer.apple.com/documentation/uikit/view_controllers/providing_access_to_directories
        documentPicker.allowsMultipleSelection = true
        documentPicker.delegate = self

        let rootVC = self.window?.rootViewController
        // Set the initial directory.
        // documentPicker.directoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        // Present the document picker.
        DispatchQueue.main.async {
            rootVC?.present(self.documentPicker, animated: true, completion: nil)
        }
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        // Present the Document View Controller for the first document that was picked.
        // If you support picking multiple items, make sure you handle them all.
        let newDirectory = urls[0]
        // NSLog("changing directory to: \(newDirectory.path.replacingOccurrences(of: " ", with: "\\ "))")
        let isReadableWithoutSecurity = FileManager().isReadableFile(atPath: newDirectory.path)
        let isSecuredURL = newDirectory.startAccessingSecurityScopedResource()
        let isReadable = FileManager().isReadableFile(atPath: newDirectory.path)
        guard isSecuredURL && isReadable else {
            showAlert("Error", message: "Could not access folder.")
            return
        }
        // If it's on iCloud, download the directory content
        if (!downloadRemoteFile(fileURL: newDirectory)) {
            if (isSecuredURL) {
                newDirectory.stopAccessingSecurityScopedResource()
            }
            NSLog("Couldn't download \(newDirectory), stopAccessingSecurityScopedResource")
            return
        }
        // Store two things at the App level:
        // - the bookmark for the URL
        // - a nickname for the bookmark (last component of the URL)
        // The user can edit the nickname later.
        // the bookmark is only stored once, the nickname is stored each time:
        if (!isReadableWithoutSecurity) {
            storeBookmark(fileURL: newDirectory)
        }
        storeName(fileURL: newDirectory, name: newDirectory.lastPathComponent)
        // Call cd_main instead of ios_system("cd dir") to avoid closing streams.
        changeDirectory(path: newDirectory.path) // call cd_main and checks secured bookmarked URLs
        if (newDirectory.path != currentDirectory) {
            previousDirectory = currentDirectory
            currentDirectory = newDirectory.path
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
    
    func executeCommand(command: String) {
        NSLog("executeCommand: \(command)")
        // We can't call exit through ios_system because it creates a new session
        // Also, we want to call it as soon as possible in case something went wrong
        if (command == "exit") {
            closeWindow()
            return
        }
        // save command in history. This duplicates the history array in hterm.html.
        if (history.last != command) {
            // only store command if different from last command
            history.append(command)
        }
        while (history.count > 100) {
            // only keep the last 100 commands
            history.removeFirst()
        }
        // Can't create/close windows through ios_system, because it creates/closes a new session.
        if (command == "newWindow") {
            let activity = NSUserActivity(activityType: "AsheKube.app.a-Shell.OpenDirectory")
            activity.userInfo!["url"] = URL(fileURLWithPath: FileManager().currentDirectoryPath)
            UIApplication.shared.requestSceneSessionActivation(nil, userActivity: activity, options: nil)
            printPrompt() // Needed to that the window is ready for a new command
            return
        }
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
            self.printPrompt();
            return
        }
        // Get file for stdout/stderr that can be written to
        stdout_pipe = Pipe()
        guard stdout_pipe != nil else { return }
        stdout_file = fdopen(stdout_pipe!.fileHandleForWriting.fileDescriptor, "w")
        guard stdout_file != nil else { return }
        // Call the following functions when data is written to stdout/stderr.
        stdout_pipe!.fileHandleForReading.readabilityHandler = self.onStdout
        // "normal" commands can go through ios_system
        commandQueue.async {
            // Make sure we're on the right session:
            ios_switchSession(self.persistentIdentifier?.toCString())
            ios_setContext(UnsafeMutableRawPointer(mutating: self.persistentIdentifier?.toCString()));
            // Set COLUMNS to term width:
            setenv("COLUMNS", "\(self.width)".toCString(), 1);
            setenv("LINES", "\(self.height)".toCString(), 1);
            ios_setWindowSize(Int32(self.width), Int32(self.height))
            thread_stdin  = nil
            thread_stdout = nil
            thread_stderr = nil
            // Make sure we're running the right session
            ios_setStreams(self.stdin_file, self.stdout_file, self.stdout_file)
            // Execute command (remove spaces at the beginning and end):
            // reset the LC_CTYPE (some commands (luatex) can change it):
            setenv("LC_CTYPE", "UTF-8", 1);
            setlocale(LC_CTYPE, "UTF-8");
            // Setting these breaks lualatex -- not setting them might break something else.
            // setenv("LC_ALL", "UTF-8", 1);
            // setlocale(LC_ALL, "UTF-8");
            self.currentCommand = command
            ios_system(self.currentCommand)
            // Send info to the stdout handler that the command has finished:
            // let readOpen = fcntl(self.stdout_pipe!.fileHandleForReading.fileDescriptor, F_GETFD)
            let writeOpen = fcntl(self.stdout_pipe!.fileHandleForWriting.fileDescriptor, F_GETFD)
            if (writeOpen >= 0) {
                // Pipe is still open, send information to close it, once all output has been processed.
                self.stdout_pipe!.fileHandleForWriting.write(self.endOfTransmission.data(using: .utf8)!)
            } else {
                // Pipe has been closed, ready to run new command:
                self.printPrompt();
            }
        }
    }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        let cmd:String = message.body as! String
        // Make sure we're acting on the right session here:
        if (cmd.hasPrefix("shell:")) {
            var command = cmd
            command.removeFirst("shell:".count)
            executeCommand(command: command.trimmingCharacters(in: .whitespacesAndNewlines))
        } else if (cmd.hasPrefix("width:")) {
            var command = cmd
            command.removeFirst("width:".count)
            let newWidth = Int(command) ?? 80
            if (newWidth != width) {
                width = newWidth
                ios_switchSession(self.persistentIdentifier?.toCString())
                ios_setContext(UnsafeMutableRawPointer(mutating: self.persistentIdentifier?.toCString()));
                ios_setWindowSize(Int32(width), Int32(height))
                setenv("COLUMNS", "\(width)".toCString(), 1)
                ios_signal(SIGWINCH);
            }
        } else if (cmd.hasPrefix("height:")) {
            var command = cmd
            command.removeFirst("height:".count)
            let newHeight = Int(command) ?? 80
            if (newHeight != height) {
                height = newHeight
                ios_switchSession(self.persistentIdentifier?.toCString())
                ios_setContext(UnsafeMutableRawPointer(mutating: self.persistentIdentifier?.toCString()));
                NSLog("Calling ios_setWindowSize: \(width) x \(height)")
                ios_setWindowSize(Int32(width), Int32(height))
                setenv("LINES", "\(height)".toCString(), 1)
                ios_signal(SIGWINCH);
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
                guard stdin_pipe != nil else { return }
                stdin_pipe!.fileHandleForWriting.closeFile()
                stdin_pipe = nil
            } else if (command == interrupt) {
                ios_kill()
            } else {
                guard stdin_pipe != nil else { return }
                // TODO: don't send data if pipe already closed (^D followed by another key)
                // (store a variable that says the pipe has been closed)
                stdin_pipe!.fileHandleForWriting.write(data)
            }
        } else if (cmd.hasPrefix("inputInteractive:")) {
            // Interactive commands: just send the input to them. Allows Vim to map control-D to down half a page.
            var command = cmd
            command.removeFirst("inputInteractive:".count)
            guard let data = command.data(using: .utf8) else { return }
            ios_switchSession(self.persistentIdentifier?.toCString())
            ios_setContext(UnsafeMutableRawPointer(mutating: self.persistentIdentifier?.toCString()));
            ios_setStreams(self.stdin_file, self.stdout_file, self.stdout_file)
            guard stdin_pipe != nil else { return }
            // TODO: don't send data if pipe already closed (^D followed by another key)
            // (store a variable that says the pipe has been closed)
            stdin_pipe!.fileHandleForWriting.write(data)
        } else if (cmd.hasPrefix("listDirectory:")) {
            var directory = cmd
            directory.removeFirst("listDirectory:".count)
            if (directory.count == 0) { return }
            do {
                ios_switchSession(self.persistentIdentifier?.toCString())
                ios_setContext(UnsafeMutableRawPointer(mutating: self.persistentIdentifier?.toCString()));
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
        } else if (cmd.hasPrefix("copy:")) {
            // copy text to clipboard. Required since simpler methods don't work with what we want to do with cut in JS.
            var string = cmd
            string.removeFirst("copy:".count)
            let pasteBoard = UIPasteboard.general
            pasteBoard.string = string
        } else if (cmd.hasPrefix("print:")) {
            // print result of JS file:
            var string = cmd
            string.removeFirst("print:".count)
            if (thread_stdout_copy != nil) {
                fputs(string, self.thread_stdout_copy)
            }
        } else if (cmd.hasPrefix("print_error:")) {
            // print result of JS file:
            var string = cmd
            string.removeFirst("print_error:".count)
            if (thread_stderr_copy != nil) {
                fputs(string, self.thread_stderr_copy)
            }
        } else {
            // Usually debugging information
            // NSLog("JavaScript message: \(message.body)")
            print("JavaScript message: \(message.body)")
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
    
    func storeBookmark(fileURL: URL) {
        // Store the bookmark for this object:
        do {
            let fileBookmark = try fileURL.bookmarkData(options: [],
                                                        includingResourceValuesForKeys: nil,
                                                        relativeTo: nil)
            let storedBookmarksDictionary = UserDefaults.standard.dictionary(forKey: "fileBookmarks") ?? [:]
            var mutableBookmarkDictionary : [String:Any] = storedBookmarksDictionary
            mutableBookmarkDictionary.updateValue(fileBookmark, forKey: fileURL.path)
            UserDefaults.standard.set(mutableBookmarkDictionary, forKey: "fileBookmarks")
        }
        catch {
            NSLog("Could not bookmark this file: \(fileURL)")
        }
    }
    
    func storeName(fileURL: URL, name: String) {
        let storedNamesDictionary = UserDefaults.standard.dictionary(forKey: "bookmarkNames") ?? [:]
        // Does "name" alrady exist? If so create a unique name:
        var newName = name
        var counter = 0
        var existingURLPath = storedNamesDictionary[newName]
        while (existingURLPath != nil) {
            var existingPath = existingURLPath as! String
            // the name already exists
            NSLog("Name \(newName) already exists.")
            if (fileURL.sameFileLocation(path: existingPath)) {
                if (thread_stderr != nil) {
                    fputs("Already bookmarked as \(newName).\n", thread_stderr)
                }
                return // it's already there, don't store
            }
            counter += 1;
            newName = name + "_" + "\(counter)"
            existingURLPath = storedNamesDictionary[newName]
        }
        var mutableNamesDictionary : [String:Any] = storedNamesDictionary
        mutableNamesDictionary.updateValue(fileURL.path, forKey: newName)
        UserDefaults.standard.set(mutableNamesDictionary, forKey: "bookmarkNames")
        if (thread_stderr != nil) {
            fputs("Bookmarked as \(newName).\n", thread_stderr)
        }
    }
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnecting:SceneSession` instead).
        // Use a UIHostingController as window root view controller
        NSLog("willConnectTo session: \(connectionOptions)")
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
            webView?.navigationDelegate = self
            webView?.uiDelegate = self;
            // toolbar for everyone because I can't change the aspect of inputAssistantItem buttons
            webView?.addInputAccessoryView(toolbar: self.editorToolbar)
            // initialize command list for autocomplete:
            guard var commandsArray = commandsAsArray() as! [String]? else { return }
            // Also scan PATH for executable files:
            let executablePath = String(cString: getenv("PATH"))
            // NSLog("\(executablePath)")
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
            var javascriptCommand = "var commandList = ["
            for command in commandsArray {
                javascriptCommand += "\"" + command + "\", "
            }
            javascriptCommand += "];"
            webView!.evaluateJavaScript(javascriptCommand) { (result, error) in
                if error != nil {
                    NSLog("Error in creating command list, line = \(javascriptCommand)")
                    // print(error)
                }
                if (result != nil) {
                    // print(result)
                }
            }
            // Was this window created with a purpose?
            // Case 1: url to open is inside urlContexts
            // NSLog("connectionOptions.urlContexts: \(connectionOptions.urlContexts.first)")
            if let urlContext = connectionOptions.urlContexts.first {
                let fileURL = urlContext.url
                let isReadableWithoutSecurity = FileManager().isReadableFile(atPath: fileURL.path)
                let isSecuredURL = fileURL.startAccessingSecurityScopedResource()
                let isReadable = FileManager().isReadableFile(atPath: fileURL.path)
                guard isSecuredURL && isReadable else {
                    showAlert("Error", message: "Could not access file.")
                    return
                }
                // If it's on iCloud, download the directory content
                if (!downloadRemoteFile(fileURL: fileURL)) {
                    if (isSecuredURL) {
                        fileURL.stopAccessingSecurityScopedResource()
                    }
                    NSLog("Couldn't download \(fileURL), stopAccessingSecurityScopedResource")
                    return
                }
                if (!isReadableWithoutSecurity) {
                    storeBookmark(fileURL: fileURL)
                }
                storeName(fileURL: fileURL, name: fileURL.lastPathComponent)
                if (fileURL.isDirectory) {
                    // it's a directory.
                    thread_stderr = stderr
                    changeDirectory(path: fileURL.path) // call cd_main and checks secured bookmarked URLs
                    closeAfterCommandTerminates = false
                } else {
                    // It's a file
                    // TODO: customize the command (vim, microemacs, python, clang, TeX?)
                    executeCommand(command: "vim " + (fileURL.path.removingPercentEncoding!.replacingOccurrences(of: " ", with: "\\ ")))
                    let openFileCommand = "window.commandRunning = 'vim';"
                    self.webView?.evaluateJavaScript(openFileCommand) { (result, error) in
                        if error != nil {
                            print(error)
                        }
                        if (result != nil) {
                            print(result)
                        }
                    }
                    closeAfterCommandTerminates = true
                }
            }
            // Case 2: url to open is inside userActivity
            // NSLog("connectionOptions.userActivities.first: \(connectionOptions.userActivities.first)")
            // NSLog("stateRestorationActivity: \(session.stateRestorationActivity)")
            for userActivity in connectionOptions.userActivities {
                // NSLog("Found userActivity: \(userActivity)")
                // NSLog("Type: \(userActivity.activityType)")
                // NSLog("URL: \(userActivity.userInfo!["url"])")
                // NSLog("UserInfo: \(userActivity.userInfo!)")
                if (userActivity.activityType == "AsheKube.app.a-Shell.EditDocument") {
                    if let fileURL: NSURL = userActivity.userInfo!["url"] as? NSURL {
                        // NSLog("willConnectTo: \(fileURL.path!.replacingOccurrences(of: "%20", with: " "))")
                        executeCommand(command: "vim " + (fileURL.path!.removingPercentEncoding!.replacingOccurrences(of: " ", with: "\\ ")))
                    } else {
                        // NSLog("Empty URL -- using backup")
                        executeCommand(command: "vim " + ((inputFileURLBackup?.path.removingPercentEncoding!.replacingOccurrences(of: " ", with: "\\ "))!))
                        inputFileURLBackup = nil
                    }
                    let openFileCommand = "window.commandRunning = 'vim';"
                    self.webView?.evaluateJavaScript(openFileCommand) { (result, error) in
                        if error != nil {
                            print(error)
                        }
                        if (result != nil) {
                            print(result)
                        }
                    }
                    closeAfterCommandTerminates = true
                } else if (userActivity.activityType == "AsheKube.app.a-Shell.OpenDirectory") {
                    if let fileURL: NSURL = userActivity.userInfo!["url"] as? NSURL {
                        //  ???
                        // .removingPercentEncoding ??
                        changeDirectory(path: fileURL.path!) // call cd_main and checks secured bookmarked URLs
                        closeAfterCommandTerminates = false
                    }
                }
            }

            let didBecomeKey = NotificationCenter.default
                .publisher(for: UIWindow.didBecomeKeyNotification, object: window)
            let didResignKey = NotificationCenter.default
                .publisher(for: UIWindow.didResignKeyNotification, object: window)
            Publishers.Merge(didBecomeKey, didResignKey)
                .handleEvents(receiveOutput: { notification in
                    NSLog("\(notification.name.rawValue): \(session.persistentIdentifier).")
                })
                .sink { _ in
                    // TODO: When two windows open side-by-side on launching the app,
                    // the left window's didResignKeyNotification event is earlier than loading window.term_,
                    // so it cannot focus out the cursor.
                    let command = "window.term_.onFocusChange_(\(window.isKeyWindow));"
                    self.webView?.evaluateJavaScript(command) { result, error in
                        if let error = error {
                            print(error)
                        }
                        if let result = result {
                            print(result)
                        }
                    }
                }
                .store(in: &cancellables)
        }
    }

    
    func scene(_ scene: UIScene, openURLContexts: Set<UIOpenURLContext>) {
        // Ensure the URL is a file URL
        for urlContext in openURLContexts {
            let fileURL = urlContext.url
            if (!fileURL.isFileURL) { continue }
            // NSLog("openURLContexts: \(fileURL.path)")
            let isReadableWithoutSecurity = FileManager().isReadableFile(atPath: fileURL.path)
            let isSecuredURL = fileURL.startAccessingSecurityScopedResource()
            let isReadable = FileManager().isReadableFile(atPath: fileURL.path)
            guard isSecuredURL && isReadable else {
                showAlert("Error", message: "Could not access file.")
                return
            }
            // If it's on iCloud, download the directory content
            if (!downloadRemoteFile(fileURL: fileURL)) {
                if (isSecuredURL) {
                    fileURL.stopAccessingSecurityScopedResource()
                }
                NSLog("Couldn't download \(fileURL), stopAccessingSecurityScopedResource")
                return
            }
            if (!isReadableWithoutSecurity) {
                storeBookmark(fileURL: fileURL)
            }
            storeName(fileURL: fileURL, name: fileURL.lastPathComponent)
            if (fileURL.isDirectory) {
                // it's a directory.
                // TODO: customize the command (cd, other?)
                let activity = NSUserActivity(activityType: "AsheKube.app.a-Shell.OpenDirectory")
                activity.userInfo!["url"] = fileURL
                UIApplication.shared.requestSceneSessionActivation(nil, userActivity: activity, options: nil)
            } else {
                // TODO: customize the command (vim, microemacs, python, clang, TeX?)
                //  NSLog("Storing URL: \(fileURL.path)")
                let activity = NSUserActivity(activityType: "AsheKube.app.a-Shell.EditDocument")
                activity.userInfo!["url"] = fileURL
                inputFileURLBackup = fileURL // userActivity sometimes forgets the URL for iCloud files
                // Open a new tab in Vim:
                let userSettingsVim = UserDefaults.standard.string(forKey: "VimOpenFile")
                if (isVimRunning && (userSettingsVim != "window")) {
                    // NSLog("Vim is already running: \(currentCommand) settings = \(userSettingsVim)")
                    var command = escape
                    if (userSettingsVim == "tab") {
                        command += ":tabnew "
                    } else {
                        command += ":e "
                    }
                    command += fileURL.path.removingPercentEncoding!.replacingOccurrences(of: " ", with: "\\ ") + "\n"
                    let data = command.data(using: .utf8)
                    if (data != nil) {
                        ios_switchSession(self.persistentIdentifier?.toCString())
                        ios_setContext(UnsafeMutableRawPointer(mutating: self.persistentIdentifier?.toCString()));
                        ios_setStreams(self.stdin_file, self.stdout_file, self.stdout_file)
                        if (stdin_pipe != nil) {
                            stdin_pipe!.fileHandleForWriting.write(data!)
                            return
                        }
                    }
                }
                UIApplication.shared.requestSceneSessionActivation(nil, userActivity: activity, options: nil)
            }
        }
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not neccessarily discarded (see `application:didDiscardSceneSessions` instead).
        // If there is a command running, tell it to quit (cleanly):
        NSLog("sceneDidDisconnect: \(self.persistentIdentifier). currentCommand= \(currentCommand)")
        if (currentCommand != "") {
            // time to send an exit code to the command
            var exitCommand = ""
            // Recognize both the raw command and the comman with arguments:
            if ((currentCommand == "bc") || currentCommand.hasPrefix("bc ")) {
                exitCommand = "\nquit"
            } else if ((currentCommand == "python") || currentCommand.hasPrefix("python ")) {
                exitCommand = "\nquit()"
            } else if ((currentCommand == "ipython") || currentCommand.hasPrefix("ipython ")) {
                exitCommand = "\nquit"
            } else if ((currentCommand == "nslookup") || currentCommand.hasPrefix("nslookup ")) {
                exitCommand = "\nexit"
            } else if (isVimRunning) {
                exitCommand = escape + "\n:xa" // save all and quit
            } else if ((currentCommand == "ssh") || currentCommand.hasPrefix("ssh ")) {
                exitCommand = "\nexit"
            } else if ((currentCommand == "ed") || currentCommand.hasPrefix("ed ")) {
                exitCommand = "\n.\nwq" // Won't work if no filename provided. Then again, not much I can do.
            }
            if (exitCommand != "") {
                exitCommand += "\n"
                let data = exitCommand.data(using: .utf8)
                if (data != nil) {
                    ios_switchSession(self.persistentIdentifier?.toCString())
                    ios_setContext(UnsafeMutableRawPointer(mutating: self.persistentIdentifier?.toCString()));
                    ios_setStreams(self.stdin_file, self.stdout_file, self.stdout_file)
                    if (stdin_pipe != nil) {
                        stdin_pipe!.fileHandleForWriting.write(data!)
                        return
                    }
                }
            } else {
                NSLog("Un-recognized command: \(currentCommand)")
            }
            // TODO: restart the command (with the same context) when the session is reconnected.
            currentCommand = ""
        }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
        NSLog("sceneDidBecomeActive: \(self.persistentIdentifier).")
        // Window.term_ does not always exist when sceneDidBecomeActive is called. We *also* set window.foregroundColor, and then use that when we create term.
        let traitCollection = webView!.traitCollection
        var command = "window.term_.setForegroundColor('" + UIColor.placeholderText.resolvedColor(with: traitCollection).toHexString() + "'); window.term_.setBackgroundColor('" + UIColor.systemBackground.resolvedColor(with: traitCollection).toHexString() + "'); window.term_.setCursorColor('" + UIColor.link.resolvedColor(with: traitCollection).toHexString() + "');"
        webView!.evaluateJavaScript(command) { (result, error) in
            if error != nil {
                print(error)
            }
            if (result != nil) {
                print(result)
            }
        }
        command = "window.term_.prefs_.set('foreground-color', '" + UIColor.placeholderText.resolvedColor(with: traitCollection).toHexString() + "'); window.term_.prefs_.set('background-color', '" + UIColor.systemBackground.resolvedColor(with: traitCollection).toHexString() + "'); "
        webView!.evaluateJavaScript(command) { (result, error) in
            if error != nil {
                print(error)
            }
            if (result != nil) {
                print(result)
            }
        }
        // Are we in light mode or dark mode?
        var H_fg: CGFloat = 0
        var S_fg: CGFloat = 0
        var B_fg: CGFloat = 0
        var A_fg: CGFloat = 0
        UIColor.placeholderText.resolvedColor(with: traitCollection).getHue(&H_fg, saturation: &S_fg, brightness: &B_fg, alpha: &A_fg)
        var H_bg: CGFloat = 0
        var S_bg: CGFloat = 0
        var B_bg: CGFloat = 0
        var A_bg: CGFloat = 0
        UIColor.systemBackground.resolvedColor(with: traitCollection).getHue(&H_bg, saturation: &S_bg, brightness: &B_bg, alpha: &A_bg)
        if (B_fg > B_bg) {
            // Dark mode
            setenv("COLORFGBG", "15;0", 1)
        } else {
            // Light mode
            setenv("COLORFGBG", "0;15", 1)
        }
        webView!.allowDisplayingKeyboardWithoutUserAction()
        ios_signal(SIGWINCH); // is this still required?
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
        NSLog("sceneWillResignActive: \(self.persistentIdentifier).")
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
        // Was this window created with a purpose?
        let userActivity = scene.userActivity
        NSLog("sceneWillEnterForeground: \(self.persistentIdentifier). userActivity: \(userActivity)")
        if (scene.session.stateRestorationActivity != nil) {
            if (scene.session.stateRestorationActivity!.userInfo != nil) {
                // NSLog("Restoring history, previousDir, currentDir:")
                let userInfo = scene.session.stateRestorationActivity!.userInfo!
                let historyData = userInfo["history"]
                if (historyData != nil) {
                    history = historyData as! [String]
                    // NSLog("set history to \(history)")
                    var javascriptCommand = "window.commandArray = ["
                    for command in history {
                        javascriptCommand += "\"" + command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\", "
                    }
                    javascriptCommand += "]; window.commandIndex = \(history.count); window.maxCommandIndex = \(history.count)"
                    webView!.evaluateJavaScript(javascriptCommand) { (result, error) in
                        if error != nil {
                            NSLog("Error in recreating history, line = \(javascriptCommand)")
                            print(error)
                        }
                        if (result != nil) {
                            print(result)
                        }
                    }
                }
                let previousDirectoryData = userInfo["prev_wd"]
                if (previousDirectoryData != nil) {
                    previousDirectory = previousDirectoryData as! String
                    if (FileManager().fileExists(atPath: previousDirectory) && FileManager().isReadableFile(atPath: previousDirectory)) {
                        // NSLog("set previousDirectory to \(previousDirectory)")
                        // Call cd_main instead of executeCommand("cd dir") to avoid closing a prompt and history.
                        thread_stderr = stderr
                        changeDirectory(path: previousDirectory) // call cd_main and checks secured bookmarked URLs
                    }
                }
                let currentDirectoryData = userInfo["cwd"]
                if (currentDirectoryData != nil) {
                    currentDirectory = currentDirectoryData as! String
                    if (FileManager().fileExists(atPath: currentDirectory) && FileManager().isReadableFile(atPath: currentDirectory)) {
                        // NSLog("set currentDirectory to \(currentDirectory)")
                        // Call cd_main instead of executeCommand("cd dir") to avoid closing a prompt and history.
                        thread_stderr = stderr
                        changeDirectory(path: currentDirectory) // call cd_main and checks secured bookmarked URLs
                    }
                }
                let terminalData = userInfo["terminal"]
                if (terminalData != nil) {
                    let javascriptCommand = "window.printedContent = \"" + (terminalData as! String).replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\r", with: "\\r").replacingOccurrences(of: "\n", with: "\\n\\r") + "\"; "
                    webView!.evaluateJavaScript(javascriptCommand) { (result, error) in
                        if error != nil {
                            NSLog("Error in resetting terminal, line = \(javascriptCommand)")
                            print(error)
                        }
                        // if (result != nil) { print(result) }
                    }
                }
                // restart the current command if one was running before
                let currentCommandData = userInfo["currentCommand"]
                if (currentCommandData != nil) {
                    let storedCommand = currentCommandData as! String
                    NSLog("Restarting session with \(storedCommand)")
                    // Safety check: is the vim session file still there?
                    // I could have been removed by the system, or by the user.
                    if (storedCommand.hasPrefix("vim -S ")) {
                        var sessionFile = storedCommand
                        sessionFile.removeFirst("vim -S ".count)
                        if (sessionFile.hasPrefix("~")) {
                            sessionFile.removeFirst("~".count)
                            let documentsUrl = try! FileManager().url(for: .documentDirectory,
                                                                      in: .userDomainMask,
                                                                      appropriateFor: nil,
                                                                      create: true)
                            let homeUrl = documentsUrl.deletingLastPathComponent()
                            sessionFile = homeUrl.path + sessionFile
                        }
                        if (!FileManager().fileExists(atPath: sessionFile)) {
                            NSLog("Could not find session file at \(sessionFile)")
                            return
                        }
                    }
                    // NSLog("Restoring command: \(storedCommand)")
                    let restoreCommand = "window.commandToExecute = '" + storedCommand.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "';"
                    // NSLog("Calling command: \(restoreCommand)")
                    self.webView?.evaluateJavaScript(restoreCommand) { (result, error) in
                        if error != nil {
                            print(error)
                        }
                        if (result != nil) {
                            print(result)
                        }
                    }
                }
            }
        }
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
        NSLog("sceneDidEnterBackground: \(self.persistentIdentifier).")
        scene.session.stateRestorationActivity = NSUserActivity(activityType: "AsheKube.app.a-Shell.TermSession")
        if (currentDirectory == "") {
            currentDirectory = FileManager().currentDirectoryPath
        }
        scene.session.stateRestorationActivity?.userInfo!["cwd"] = currentDirectory
        if (previousDirectory == "") {
            previousDirectory = FileManager().currentDirectoryPath
        }
        scene.session.stateRestorationActivity?.userInfo!["prev_wd"] = previousDirectory
        scene.session.stateRestorationActivity?.userInfo!["history"] = history
        webView!.evaluateJavaScript("window.printedContent",
                                    completionHandler: { (printedContent: Any?, error: Error?) in
                                        if error != nil {
                                            // NSLog("Error in capturing terminal content.")
                                            print(error)
                                        }
                                        if (printedContent != nil) {
                                            scene.session.stateRestorationActivity?.userInfo!["terminal"] = printedContent
                                            // print("printedContent: \(printedContent)")
                                        }
        })
        scene.session.stateRestorationActivity?.userInfo!["currentCommand"] = currentCommand
        // NSLog("storing currentCommand= \(currentCommand)")
        // Save all open editor windows
        // TODO: save context (Vim session)
        if (currentCommand != "") {
            // time to send an exit code to the command
            var saveCommand = ""
            // Recognize both the raw command and the command with arguments:
            if (isVimRunning) {
                // This might still fail in some cases. What is the minimal set of commands guaranteed to save all?
                // interrupt should work better than escape in theory but not in practice
                // also, how to remove the swp files? (except by quitting)
                saveCommand = escape + "\n:wa\n:SaveSession! " + scene.session.persistentIdentifier + "\n\n" // save all and create a Vim session
                scene.session.stateRestorationActivity?.userInfo!["currentCommand"] = "vim -S ~/Documents/.vim/sessions/" + scene.session.persistentIdentifier + ".vim" // restore command is modified
            } else if ((currentCommand == "ed") || currentCommand.hasPrefix("ed ")) {
                saveCommand = "\n.\nw\n" // Won't work if no filename provided. Then again, not much I can do.
            }
            if (saveCommand != "") {
                // NSLog("Sending save command: \(saveCommand)")
                let data = saveCommand.data(using: .utf8)
                if (data != nil) {
                    ios_switchSession(self.persistentIdentifier?.toCString())
                    ios_setContext(UnsafeMutableRawPointer(mutating: self.persistentIdentifier?.toCString()));
                    ios_setStreams(self.stdin_file, self.stdout_file, self.stdout_file)
                    if (stdin_pipe != nil) {
                        stdin_pipe!.fileHandleForWriting.write(data!)
                        return
                    }
                }
            }
        }
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
                    // NSLog("Error in print; offending line = \(parsedString)")
                    // print(error)
                }
                if (result != nil) {
                    // print(result)
                }
            }
        }
        return
        while (parsedString.count > 0) {
            guard let firstReturn = parsedString.firstIndex(of: "\n") else {
                let command = "window.term_.io.print(\"" + parsedString + "\");"
                DispatchQueue.main.async {
                    self.webView!.evaluateJavaScript(command) { (result, error) in
                        if error != nil {
                            // NSLog("Error in print; offending line = \(parsedString)")
                            // print(error)
                        }
                        if (result != nil) {
                            // print(result)
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
                        // NSLog("Error in println; offending line = \(firstLine)")
                        // print(error)
                    }
                    if (result != nil) {
                        // print(result)
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
            // NSLog(string)
            outputToWebView(string: string)
            if (string.contains(endOfTransmission)) {
                // Finished processing the output, can get back to prompt:
                if (closeAfterCommandTerminates) {
                    let session = self.windowScene!.session
                    UIApplication.shared.requestSceneSessionDestruction(session, options: nil)
                    // closeAfterCommandTerminates = false
                }
                currentCommand = ""
                printPrompt();
                // Did the command change the current directory?
                let newDirectory = FileManager().currentDirectoryPath
                if (newDirectory != currentDirectory) {
                    previousDirectory = currentDirectory
                    currentDirectory = newDirectory
                }
            }
        } else if let string = String(data: data, encoding: String.Encoding.ascii) {
            NSLog("Couldn't convert data in stdout using UTF-8, resorting to ASCII: \(data)")
            outputToWebView(string: string)
            if (string.contains(endOfTransmission)) {
                // Finished processing the output, can get back to prompt:
                if (closeAfterCommandTerminates) {
                    let session = self.windowScene!.session
                    UIApplication.shared.requestSceneSessionDestruction(session, options: nil)
                    // closeAfterCommandTerminates = false
                }
                currentCommand = ""
                printPrompt();
                let newDirectory = FileManager().currentDirectoryPath
                if (newDirectory != currentDirectory) {
                    previousDirectory = currentDirectory
                    currentDirectory = newDirectory
                }
            }
        } else {
            NSLog("Couldn't convert data in stdout: \(data)")
        }
    }
}


extension SceneDelegate: WKUIDelegate {
    
    // Javascript alert dialog boxes:
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {
        
        let arguments = message.components(separatedBy: "\n")
        if (arguments.count == 0) { return }
        let title = arguments[0]
        var messageMinusTitle = message
        messageMinusTitle.removeFirst(title.count)
                
        let alertController = UIAlertController(title: title, message: messageMinusTitle, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { (action) in
            completionHandler()
        }))
        
        if let presenter = alertController.popoverPresentationController {
            presenter.sourceView = self.view
        }
        
        let rootVC = self.window?.rootViewController
        rootVC?.present(alertController, animated: true, completion: nil)
    }
    
    
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void) {
        
        let arguments = message.components(separatedBy: "\n")
        let title = arguments[0]
        var messageMinusTitle = message
        messageMinusTitle.removeFirst(title.count)

        let alertController = UIAlertController(title: arguments[0], message: messageMinusTitle, preferredStyle: .alert)
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (action) in
            completionHandler(false)
        }))
        
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { (action) in
            completionHandler(true)
        }))
        
        if let presenter = alertController.popoverPresentationController {
            presenter.sourceView = self.view
        }
        
        let rootVC = self.window?.rootViewController
        rootVC?.present(alertController, animated: true, completion: nil)
    }
    
    func fileDescriptor(input: String) -> Int32? {
        guard let fd = Int32(input) else {
            return nil
        }
        if (fd == 0) {
            return fileno(self.thread_stdin_copy)
        }
        if (fd == 1) {
            return fileno(self.thread_stdout_copy)
        }
        if (fd == 2) {
            return fileno(self.thread_stderr_copy)
        }
        return fd
    }
    
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {
        // communication with libc:
        
        let arguments = prompt.components(separatedBy: "\n")
        let title = arguments[0]
        if (title == "libc") {
            if (arguments[1] == "open") {
                if (!FileManager().fileExists(atPath: arguments[2])) {
                    // The file doesn't exist. First, we create it:
                    let fileUrl = URL(fileURLWithPath: arguments[2])
                    do {
                        try "".write(to: fileUrl, atomically: true, encoding: .utf8)
                    }
                    catch {
                        fputs("could not write to file \(arguments[2]): \(error)", self.thread_stderr_copy)
                    }
                }
                let returnValue = open(arguments[2], Int32(arguments[3]) ?? 577)
                if (returnValue == -1 ) {
                    fputs("Could not open file \(arguments[2]): \(strerror(errno))", self.thread_stderr_copy)
                }
                completionHandler("\(returnValue)")
                return
            } else if (arguments[1] == "write") {
                var returnValue = 0;
                if let fd = fileDescriptor(input: arguments[2]) {
                    // arguments[3] == "84,104,105,115,32,116,101,120,116,32,103,111,101,115,32,116,111,32,115,116,100,111,117,116,10"
                    // arguments[4] == nb bytes
                    let values = arguments[3].components(separatedBy:",")
                    var data = Data.init()
                    if let numValues = Int(arguments[4]) {
                        if (numValues > 0) {
                            for c in 0...numValues-1 {
                                if let value = UInt8(values[c]) {
                                    data.append(contentsOf: [value])
                                }
                            }
                            // let returnValue = write(fd, data, numValues)
                            let file = FileHandle(fileDescriptor: fd)
                            file.write(data)
                            returnValue = numValues
                        }
                    }
                }
                completionHandler("\(returnValue)")
                return
            } else if (arguments[1] == "stat") {
                if let fd = fileDescriptor(input: arguments[2]) {
                    let buf = stat.init()
                    var pbuf = UnsafeMutablePointer<stat>.allocate(capacity: 1)
                    pbuf.initialize(to: buf)
                    let returnValue = fstat(fd, pbuf)
                    if (returnValue == 0) { completionHandler("\(pbuf.pointee)") }
                    else { completionHandler("\(strerror(errno))")}
                    return
                }
                
            }
            completionHandler("defaulttext")
            return
        }
        var messageMinusTitle = prompt
        messageMinusTitle.removeFirst(title.count)

        let alertController = UIAlertController(title: arguments[0], message: messageMinusTitle, preferredStyle: .alert)
        
        alertController.addTextField { (textField) in
            textField.text = defaultText
        }

        alertController.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: { (action) in
            completionHandler(nil)
        }))
        
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { (action) in
            if let text = alertController.textFields?.first?.text {
                completionHandler(text)
                return
            } else {
                completionHandler(defaultText)
                return
            }
        }))
        
        if let presenter = alertController.popoverPresentationController {
            presenter.sourceView = self.view
        }
        
        let rootVC = self.window?.rootViewController
        rootVC?.present(alertController, animated: true, completion: { () -> Void in
            // TODO: insert here some magical line that will restore focus to the window
            // makeFirstResponder and makeKeyboardActive don't work
        })
    }

}
