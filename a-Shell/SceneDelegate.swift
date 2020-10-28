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

let factoryFontSize = Float(13)
let factoryFontName = "Menlo"

// Need: dictionary connecting userContentController with output streams (?)

class SceneDelegate: UIViewController, UIWindowSceneDelegate, WKNavigationDelegate, WKScriptMessageHandler, UIDocumentPickerDelegate, UIPopoverPresentationControllerDelegate, UIFontPickerViewControllerDelegate {
    var window: UIWindow?
    var windowScene: UIWindowScene?
    var webView: WKWebView?
    var contentView: ContentView?
    var history: [String] = []
    var width = 80
    var height = 80
    var stdout_active = false
    var persistentIdentifier: String? = nil
    var stdin_file: UnsafeMutablePointer<FILE>? = nil
    var stdin_file_input: FileHandle? = nil
    var stdout_file: UnsafeMutablePointer<FILE>? = nil
    var tty_file: UnsafeMutablePointer<FILE>? = nil
    var tty_file_input: FileHandle? = nil
    // copies of thread_std*, used when inside a sub-thread, for example executing webAssembly
    var thread_stdin_copy: UnsafeMutablePointer<FILE>? = nil
    var thread_stdout_copy: UnsafeMutablePointer<FILE>? = nil
    var thread_stderr_copy: UnsafeMutablePointer<FILE>? = nil
    // var keyboardTimer: Timer!
    private let commandQueue = DispatchQueue(label: "executeCommand", qos: .utility) // low priority, for executing commands
    private var javascriptRunning = false // We can't execute JS while we are already executing JS.
    // Buttons and toolbars:
    var controlOn = false;
    // control codes:
    let interrupt = "\u{0003}"  // control-C, used to kill the process
    let endOfTransmission = "\u{0004}"  // control-D, used to signal end of transmission
    let escape = "\u{001B}"
    // Are we editing a file?
    var closeAfterCommandTerminates = false
    var resetDirectoryAfterCommandTerminates = ""
    var currentCommand = ""
    private var selectedDirectory = ""
    private var selectedFont = ""
    // Store these for session restore:
    var currentDirectory = ""
    var previousDirectory = ""
    // Store cancelalble instances
    var cancellables = Set<AnyCancellable>()
    // Customizable user interface:
    var terminalFontSize: Float?
    var terminalFontName: String?
    var terminalBackgroundColor: UIColor?
    var terminalForegroundColor: UIColor?
    var terminalCursorColor: UIColor?
    
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
                // print(error)
            }
            if (result != nil) {
                // print(result)
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
                    // print(error)
                }
                if (result != nil) {
                    // print(result)
                }
            }
        } else {
            editorToolbar.items?[1].image = UIImage(systemName: "chevron.up.square")!.withConfiguration(configuration)
            webView?.evaluateJavaScript("window.controlOn = false;") { (result, error) in
                if error != nil {
                    // print(error)
                }
                if (result != nil) {
                    // print(result)
                }
            }
        }
    }
    
    @objc private func escapeAction(_ sender: UIBarButtonItem) {
        webView?.evaluateJavaScript("window.term_.io.onVTKeystroke(\"" + escape + "\");") { (result, error) in
            if error != nil {
                // print(error)
            }
            if (result != nil) {
                // print(result)
            }
        }
    }

    @objc private func upAction(_ sender: UIBarButtonItem) {
        webView?.evaluateJavaScript("window.term_.io.onVTKeystroke(\"" + escape + "[A\");") { (result, error) in
            if error != nil {
                // print(error)
            }
            if (result != nil) {
                // print(result)
            }
        }
    }
    
    @objc private func downAction(_ sender: UIBarButtonItem) {
        webView?.evaluateJavaScript("window.term_.io.onVTKeystroke(\"" + escape + "[B\");") { (result, error) in
            if error != nil {
                // print(error)
            }
            if (result != nil) {
                // print(result)
            }
            
        }
    }
    
    @objc private func leftAction(_ sender: UIBarButtonItem) {
        webView?.evaluateJavaScript("window.term_.io.onVTKeystroke(\"" + escape + "[D\");") { (result, error) in
            if error != nil {
                // print(error)
            }
            if (result != nil) {
                // print(result)
            }
            
        }
    }

    @objc private func rightAction(_ sender: UIBarButtonItem) {
        webView?.evaluateJavaScript("window.term_.io.onVTKeystroke(\"" + escape + "[C\");") { (result, error) in
            if error != nil {
                // print(error)
            }
            if (result != nil) {
                // print(result)
            }
            
        }
    }
    
    var tabButton: UIBarButtonItem {
        let configuration = UIImage.SymbolConfiguration(pointSize: fontSize, weight: .regular)
        let tabButton = UIBarButtonItem(image: UIImage(systemName: "arrow.right.to.line.alt")!.withConfiguration(configuration), style: .plain, target: self, action: #selector(tabAction(_:)))
        tabButton.isAccessibilityElement = true
        tabButton.accessibilityLabel = "Tab"
        return tabButton
    }

    var controlButton: UIBarButtonItem {
        let configuration = UIImage.SymbolConfiguration(pointSize: fontSize, weight: .regular, scale: .large)
        // Image used to be control
        let imageControl = (controlOn == true) ? UIImage(systemName: "chevron.up.square.fill")! : UIImage(systemName: "chevron.up.square")!
        let controlButton = UIBarButtonItem(image: imageControl.withConfiguration(configuration), style: .plain, target: self, action: #selector(controlAction(_:)))
        controlButton.isAccessibilityElement = true
        controlButton.accessibilityLabel = "Control"
        return controlButton
    }
    
    var escapeButton: UIBarButtonItem {
        let configuration = UIImage.SymbolConfiguration(pointSize: fontSize, weight: .regular)
        let escapeButton = UIBarButtonItem(image: UIImage(systemName: "escape")!.withConfiguration(configuration), style: .plain, target: self, action: #selector(escapeAction(_:)))
        escapeButton.isAccessibilityElement = true
        escapeButton.accessibilityLabel = "Escape"
        return escapeButton
    }
    
    
    var upButton: UIBarButtonItem {
        let configuration = UIImage.SymbolConfiguration(pointSize: fontSize, weight: .regular)
        let upButton = UIBarButtonItem(image: UIImage(systemName: "arrow.up")!.withConfiguration(configuration), style: .plain, target: self, action: #selector(upAction(_:)))
        upButton.isAccessibilityElement = true
        upButton.accessibilityLabel = "Up arrow"
        return upButton
    }
    
    var downButton: UIBarButtonItem {
        let configuration = UIImage.SymbolConfiguration(pointSize: fontSize, weight: .regular)
        let downButton = UIBarButtonItem(image: UIImage(systemName: "arrow.down")!.withConfiguration(configuration), style: .plain, target: self, action: #selector(downAction(_:)))
        downButton.isAccessibilityElement = true
        downButton.accessibilityLabel = "Down arrow"
        return downButton
    }
    
    var leftButton: UIBarButtonItem {
        let configuration = UIImage.SymbolConfiguration(pointSize: fontSize, weight: .regular)
        let leftButton = UIBarButtonItem(image: UIImage(systemName: "arrow.left")!.withConfiguration(configuration), style: .plain, target: self, action: #selector(leftAction(_:)))
        leftButton.isAccessibilityElement = true
        leftButton.accessibilityLabel = "Left arrow"
        return leftButton
    }

    var rightButton: UIBarButtonItem {
        let configuration = UIImage.SymbolConfiguration(pointSize: fontSize, weight: .regular)
        let rightButton = UIBarButtonItem(image: UIImage(systemName: "arrow.right")!.withConfiguration(configuration), style: .plain, target: self, action: #selector(rightAction(_:)))
        rightButton.isAccessibilityElement = true
        rightButton.accessibilityLabel = "Right arrow"
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
                    // print(error)
                }
                if (result != nil) {
                    // print(result)
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
                    // print(error)
                }
                if (result != nil) {
                    // print(result)
                }
            }
            // self.webView?.accessibilityLabel = ""
        }
    }
    
    func executeWebAssembly(arguments: [String]?) -> Int32 {
        guard (arguments != nil) else { return -1 }
        guard (arguments!.count >= 2) else { return -1 } // There must be at least one command
        // copy arguments:
        let command = arguments![1]
        var argumentString = "["
        for c in 1...arguments!.count-1 {
            if let argument = arguments?[c] {
                // replace quotes and backslashes in arguments:
                let sanitizedArgument = argument.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
                argumentString = argumentString + " \"" +  sanitizedArgument + "\","
            }
        }
        argumentString = argumentString + "]"
        // async functions don't work in WKWebView (so, no fetch, no WebAssembly.instantiateStreaming)
        // Instead, we load the file in swift and send the base64 version to JS
        let currentDirectory = FileManager().currentDirectoryPath
        let fileName = command.hasPrefix("/") ? command : currentDirectory + "/" + command
        guard let buffer = NSData(contentsOf: URL(fileURLWithPath: fileName)) else {
            fputs("wasm: file \(command) not found\n", thread_stderr)
            return -1
        }
        let base64string = buffer.base64EncodedString()
        let javascript = "executeWebAssembly(\"\(base64string)\", " + argumentString + ", \"" + currentDirectory + "\", \(ios_isatty(STDIN_FILENO)))"
        if (javascriptRunning) {
            fputs("We can't execute webAssembly while we are already executing webAssembly.", thread_stderr)
            return -1
        }
        javascriptRunning = true
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
                        if let code = array[0] as? Int32 {
                            // return value from program
                            errorCode = code
                        }
                        if let errorMessage = array[1] as? String {
                            // webAssembly compile error:
                           fputs(errorMessage, self.thread_stderr_copy);
                        }
                    } else if let string = result! as? String {
                        fputs(string, self.thread_stdout_copy);
                    }
                }
                self.javascriptRunning = false
            }
        }
        // force synchronization:
        while (javascriptRunning) {
            if (thread_stdout != nil && stdout_active) { fflush(thread_stdout) }
            if (thread_stderr != nil && stdout_active) { fflush(thread_stderr) }
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
        if (javascriptRunning) {
            fputs("We can't execute JavaScript from a script already running JavaScript.", thread_stderr)
            return
        }
        javascriptRunning = true
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
                            fputs("\(result!)", self.thread_stdout_copy)
                            fputs("\n", self.thread_stdout_copy)
                        }
                        fflush(self.thread_stdout_copy)
                        fflush(self.thread_stderr_copy)
                    }
                    self.javascriptRunning = false
                }
            }
        }
        catch {
         fputs("Error executing JavaScript  file: " + command + ": \(error) \n", thread_stderr)
          javascriptRunning = false
        }
        while (javascriptRunning) {
            if (thread_stdout != nil && stdout_active) { fflush(thread_stdout) }
            if (thread_stderr != nil && stdout_active) { fflush(thread_stderr) }
        }
        thread_stdout_copy = nil
        thread_stderr_copy = nil
    }

    // display the current configuration of the window.
    func showConfigWindow() {
        if (terminalFontName != nil) {
            fputs(terminalFontName! + " ", thread_stdout)
        } else {
            fputs(factoryFontName + " ", thread_stdout)
        }
        if (terminalFontSize != nil) {
            fputs("\(terminalFontSize!) pt, ", thread_stdout)
        } else {
            fputs("\(factoryFontSize) pt, ", thread_stdout)
        }
        if (terminalBackgroundColor == nil) {
            fputs(" background: system ", thread_stdout)
        } else if (terminalBackgroundColor == .systemBackground) {
            fputs(" background: system ", thread_stdout)
        } else {
            var r:CGFloat = 0
            var g:CGFloat = 0
            var b:CGFloat = 0
            var a:CGFloat = 0
            terminalBackgroundColor!.getRed(&r, green: &g, blue: &b, alpha: &a)
            fputs(String(format: "background: %.2f %.2f %.2f ", r, g, b), thread_stdout)
        }
        if (terminalForegroundColor == nil) {
            fputs(" foreground: system ", thread_stdout)
        } else if (terminalForegroundColor == .placeholderText) {
            fputs(" foreground: system ", thread_stdout)
        } else {
            var r:CGFloat = 0
            var g:CGFloat = 0
            var b:CGFloat = 0
            var a:CGFloat = 0
            terminalForegroundColor!.getRed(&r, green: &g, blue: &b, alpha: &a)
            fputs(String(format: "foreground: %.2f %.2f %.2f ", r, g, b), thread_stdout)
        }
        if (terminalCursorColor == nil) {
            fputs(" cursor: system ", thread_stdout)
        } else if (terminalCursorColor == .link) {
            fputs(" cursor: system ", thread_stdout)
        } else {
            var r:CGFloat = 0
            var g:CGFloat = 0
            var b:CGFloat = 0
            var a:CGFloat = 0
            terminalCursorColor!.getRed(&r, green: &g, blue: &b, alpha: &a)
            fputs(String(format: "cursor: %.2f %.2f %.2f ", r, g, b), thread_stdout)
        }
        fputs("\n", thread_stdout)
    }

    func writeConfigWindow() {
        // Force rewrite of all color parameters. Used for reset.
        let traitCollection = webView!.traitCollection
        // Set scene parameters (unless they were set before)
        let backgroundColor = terminalBackgroundColor ?? UIColor.systemBackground.resolvedColor(with: traitCollection)
        let foregroundColor = terminalForegroundColor ?? UIColor.placeholderText.resolvedColor(with: traitCollection)
        let cursorColor = terminalCursorColor ?? UIColor.link.resolvedColor(with: traitCollection)
        // TODO: add font size and font name
        let fontSize = terminalFontSize ?? factoryFontSize
        let fontName = terminalFontName ?? factoryFontName
        // Force writing all config to term. Used when we changed many parameters.
        var command = "window.term_.setForegroundColor('" + foregroundColor.toHexString() + "'); window.term_.setBackgroundColor('" + backgroundColor.toHexString() + "'); window.term_.setCursorColor('" + cursorColor.toHexString() + "'); window.term_.setFontSize(\(fontSize)); window.term_.setFontFamily('\(fontName)');"
        DispatchQueue.main.async {
            self.webView?.evaluateJavaScript(command) { (result, error) in
                if error != nil {
                   // print(error)
                }
                if (result != nil) {
                   // print(result)
                }
            }
            command = "window.term_.prefs_.set('foreground-color', '" + foregroundColor.toHexString() + "'); window.term_.prefs_.set('background-color', '" + backgroundColor.toHexString() + "'); window.term_.prefs_.set('cursor-color', '" + cursorColor.toHexString() + "'); window.term_.prefs_.set('font-size', '\(fontSize)'); window.term_.prefs_.set('font-family', '\(fontName)');"
            self.webView?.evaluateJavaScript(command) { (result, error) in
                if error != nil {
                   // print(error)
                }
                if (result != nil) {
                   // print(result)
                }
            }
        }
    }

    func configWindow(fontSize: Float?, fontName: String?, backgroundColor: UIColor?, foregroundColor: UIColor?, cursorColor: UIColor?) {
        if (fontSize != nil) {
            terminalFontSize = fontSize
            let fontSizeCommand = "window.term_.setFontSize(\(fontSize!));"
            DispatchQueue.main.async {
                self.webView?.evaluateJavaScript(fontSizeCommand) { (result, error) in
                    if error != nil {
                      //  print(error)
                    }
                    if (result != nil) {
                       // print(result)
                    }
                }
            }
        }
        if (fontName != nil) {
            terminalFontName = fontName
            if (!terminalFontName!.hasSuffix(".ttf") && !terminalFontName!.hasSuffix(".otf")) {
                // System fonts, defined by their names:
                let fontNameCommand = "window.term_.setFontFamily(\"\(fontName!)\");"
                DispatchQueue.main.async {
                    self.webView?.evaluateJavaScript(fontNameCommand) { (result, error) in
                        if error != nil {
                            print(error)
                        }
                        if (result != nil) {
                            print(result)
                        }
                    }
                }
            } else {
                // local fonts, defined by a file:
                // Currently does not work.
                let localFontURL = URL(fileURLWithPath: terminalFontName!)
                var localFontName = localFontURL.lastPathComponent
                localFontName.removeLast(".ttf".count)
                NSLog("Local Font Name: \(localFontName)")
                DispatchQueue.main.async {
                    let fontNameCommand = "var newStyle = document.createElement('style'); newStyle.appendChild(document.createTextNode(\"@font-face { font-family: '\(localFontName)' ; src: url('\(localFontURL.path)') format('truetype'); }\")); document.head.appendChild(newStyle); window.term_.setFontFamily(\"\(localFontName)\");"
                    NSLog(fontNameCommand)
                    self.webView?.evaluateJavaScript(fontNameCommand) { (result, error) in
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
        if (backgroundColor != nil) {
            terminalBackgroundColor = backgroundColor
            webView!.backgroundColor = backgroundColor
            let terminalColorCommand = "window.term_.setBackgroundColor(\"\(backgroundColor!.toHexString())\");"
            DispatchQueue.main.async {
                self.webView?.evaluateJavaScript(terminalColorCommand) { (result, error) in
                    if error != nil {
                        print(error)
                    }
                    if (result != nil) {
                        print(result)
                    }
                }
            }
        }
        if (foregroundColor != nil) {
            terminalForegroundColor = foregroundColor
            webView!.tintColor = foregroundColor
            let terminalColorCommand = "window.term_.setForegroundColor(\"\(foregroundColor!.toHexString())\");"
            DispatchQueue.main.async {
                self.webView?.evaluateJavaScript(terminalColorCommand) { (result, error) in
                    if error != nil {
                        print(error)
                    }
                    if (result != nil) {
                        print(result)
                    }
                }
            }
        }
        if (cursorColor != nil) {
            terminalCursorColor = cursorColor
            let terminalColorCommand = "window.term_.setCursorColor(\"\(cursorColor!.toHexString())\");"
            DispatchQueue.main.async {
                self.webView?.evaluateJavaScript(terminalColorCommand) { (result, error) in
                    if error != nil {
                        print(error)
                    }
                    if (result != nil) {
                        print(result)
                    }
                }
            }
        }
        // Update COLORFGBG depending on new color:
        if (foregroundColor != nil ) || (backgroundColor != nil) {
            let fg = foregroundColor ?? terminalForegroundColor ?? UIColor.placeholderText.resolvedColor(with: traitCollection)
            let bg = backgroundColor ?? terminalBackgroundColor ?? UIColor.systemBackground.resolvedColor(with: traitCollection)
            setEnvironmentFGBG(foregroundColor: fg, backgroundColor: bg)
        }
    }
    
    func keepDirectoryAfterShortcut() {
        resetDirectoryAfterCommandTerminates = ""
    }
    
    // Creates the iOS 13 Font picker, returns the name of the font selected.
    func pickFont() -> String? {
        let rootVC = self.window?.rootViewController

        let fontPickerConfig = UIFontPickerViewController.Configuration()
        fontPickerConfig.includeFaces = true
        fontPickerConfig.filteredTraits = .traitMonoSpace
        // Create the font picker
        let fontPicker = UIFontPickerViewController(configuration: fontPickerConfig)
        fontPicker.delegate = self
        // Present the font picker
        selectedFont = ""
        // Main issue: the user can dismiss the fontPicker by sliding upwards.
        // So we need to check if it was, indeed dismissed:
        DispatchQueue.main.sync {
            rootVC?.present(fontPicker, animated: true, completion: nil)
        }
        while (!fontPicker.isBeingDismissed) { } // Wait until fontPicker is dismissed.
        // Once the fontPicker is dismissed, wait to decide whether a font has been selected:
        // NSLog("Dismissed. selectedFont= \(selectedFont)")
        var timerDone = false
        let seconds = 0.7 // roughly 2x slower observed time
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            timerDone = true
        }
        while (selectedFont == "") && !timerDone { }
        // NSLog("Done. selectedFont= \(selectedFont)")
        if (selectedFont != "cancel") && (selectedFont != "") {
            return selectedFont
        }
        return nil
    }
    
    func fontPickerViewControllerDidCancel(_ viewController: UIFontPickerViewController) {
        // User cancelled the font picker delegate
        selectedFont = "cancel"
    }

    
    func fontPickerViewControllerDidPickFont(_ viewController: UIFontPickerViewController) {
        // We got a font!
        if let descriptor = viewController.selectedFontDescriptor {
            if let name = descriptor.fontAttributes[.family] as? String {
                // "Regular" variants of the font:
                selectedFont = name
                return
            } else if let name = descriptor.fontAttributes[.name] as? String {
                // This is for Light, Medium, ExtraLight variants of the font:
                selectedFont = name
                return
            }
        }
        selectedFont = "cancel"
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        selectedDirectory = "cancelled"
    }
    
    func pickFolder() {
        // https://developer.apple.com/documentation/uikit/view_controllers/providing_access_to_directories
        documentPicker.allowsMultipleSelection = true
        documentPicker.delegate = self

        let rootVC = self.window?.rootViewController
        // Set the initial directory.
        // documentPicker.directoryURL = URL(fileURLWithPath: FileManager().default.currentDirectoryPath)
        // Present the document picker.
        selectedDirectory = ""
        DispatchQueue.main.async {
            rootVC?.present(self.documentPicker, animated: true, completion: nil)
        }
        while (selectedDirectory == "") { } // wait until a directory is selected, for Shortcuts.
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
            selectedDirectory = newDirectory.path
            return
        }
        // If it's on iCloud, download the directory content
        if (!downloadRemoteFile(fileURL: newDirectory)) {
            if (isSecuredURL) {
                newDirectory.stopAccessingSecurityScopedResource()
            }
            NSLog("Couldn't download \(newDirectory), stopAccessingSecurityScopedResource")
            selectedDirectory = newDirectory.path
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
        selectedDirectory = newDirectory.path
    }


    // Even if Caps-Lock is activated, send lower case letters.
    @objc func insertKey(_ sender: UIKeyCommand) {
        guard (sender.input != nil) else { return }
        // This function only gets called if we are in a notebook, in edit_mode:
        // Only remap the keys if we are in a notebook, editing cell:
        webView?.evaluateJavaScript("window.term_.io.onVTKeystroke(\"" + sender.input! + "\");") { (result, error) in
            if error != nil {
                // print(error)
            }
            if (result != nil) {
                // print(result)
            }
        }
    }
    
    func executeCommand(command: String) {
        NSLog("executeCommand: \(command)")
        // We can't call exit through ios_system because it creates a new session
        // Also, we want to call it as soon as possible in case something went wrong
        if (command == "exit") || (command.hasPrefix("exit ")) {
            closeWindow()
            // If we're here, closeWindow did not work. Clear screen:
            let infoCommand = "window.term_.wipeContents() ; window.printedContent = ''; window.term_.io.print('" + self.escape + "[2J'); window.term_.io.print('" + self.escape + "[1;1H'); "
            self.webView?.evaluateJavaScript(infoCommand) { (result, error) in
                if error != nil {
                    print(error)
                }
                if (result != nil) {
                    print(result)
                }
            }
            // Also reset directory:
            if (resetDirectoryAfterCommandTerminates != "") {
                NSLog("Calling resetDirectoryAfterCommandTerminates in exit to \(resetDirectoryAfterCommandTerminates)")
                changeDirectory(path: self.resetDirectoryAfterCommandTerminates)
                changeDirectory(path: self.resetDirectoryAfterCommandTerminates)
                self.resetDirectoryAfterCommandTerminates = ""
            } else {
                let documentsUrl = try! FileManager().url(for: .documentDirectory,
                                                          in: .userDomainMask,
                                                          appropriateFor: nil,
                                                          create: true)
                changeDirectory(path: documentsUrl.path)
                changeDirectory(path: documentsUrl.path)
            }
            printPrompt()
            return
        } // exit()
        if (!command.contains("\n")) {
            // save command in history. This duplicates the history array in hterm.html.
            // We don't store multi-line commands in history, as they create issues.
            if (history.last != command) {
                // only store command if different from last command
                history.append(command)
            }
            while (history.count > 100) {
                // only keep the last 100 commands
                history.removeFirst()
            }
        }
        // Can't create/close windows through ios_system, because it creates/closes a new session.
        if (command == "newWindow") || (command.hasPrefix("newWindow ")) {
            let activity = NSUserActivity(activityType: "AsheKube.app.a-Shell.OpenDirectory")
            activity.userInfo!["url"] = URL(fileURLWithPath: FileManager().currentDirectoryPath)
            UIApplication.shared.requestSceneSessionActivation(nil, userActivity: activity, options: nil)
            printPrompt() // Needed to show that the window is ready for a new command
            return
        }
        // set up streams for feedback:
        // Create new pipes for our own stdout/stderr
        // Get file for stdin that can be read from
        // Create new pipes for our own stdout/stderr
        var stdin_pipe = Pipe()
        stdin_file = fdopen(stdin_pipe.fileHandleForReading.fileDescriptor, "r")
        while (stdin_file == nil) {
            stdin_pipe = Pipe()
            stdin_file = fdopen(stdin_pipe.fileHandleForReading.fileDescriptor, "r")
        }
        stdin_file_input = stdin_pipe.fileHandleForWriting
        let tty_pipe = Pipe()
        tty_file = fdopen(tty_pipe.fileHandleForReading.fileDescriptor, "r")
        tty_file_input = tty_pipe.fileHandleForWriting
        // Get file for stdout/stderr that can be written to
        var stdout_pipe = Pipe()
        stdout_file = fdopen(stdout_pipe.fileHandleForWriting.fileDescriptor, "w")
        while (stdout_file == nil) {
            stdout_pipe = Pipe()
            stdout_file = fdopen(stdout_pipe.fileHandleForWriting.fileDescriptor, "w")
        }
        // Call the following functions when data is written to stdout/stderr.
        stdout_pipe.fileHandleForReading.readabilityHandler = self.onStdout
        stdout_active = true
        // "normal" commands can go through ios_system
        commandQueue.async {
            // Make sure we're on the right session:
            ios_switchSession(self.persistentIdentifier?.toCString())
            ios_setContext(UnsafeMutableRawPointer(mutating: self.persistentIdentifier?.toCString()));
            // Set COLUMNS to term width:
            setenv("COLUMNS", "\(self.width)".toCString(), 1);
            setenv("LINES", "\(self.height)".toCString(), 1);
            ios_setWindowSize(Int32(self.width), Int32(self.height), self.persistentIdentifier?.toCString())
            thread_stdin  = nil
            thread_stdout = nil
            thread_stderr = nil
            // Make sure we're running the right session
            ios_setStreams(self.stdin_file, self.stdout_file, self.stdout_file)
            ios_settty(self.tty_file)
            // Execute command (remove spaces at the beginning and end):
            // reset the LC_CTYPE (some commands (luatex) can change it):
            setenv("LC_CTYPE", "UTF-8", 1);
            setlocale(LC_CTYPE, "UTF-8");
            // Setting these breaks lualatex -- not setting them might break something else.
            // setenv("LC_ALL", "UTF-8", 1);
            // setlocale(LC_ALL, "UTF-8");
            let commands = command.components(separatedBy: "\n")
            for command in commands {
                if (command == "exit") || (command.hasPrefix("exit ")) {
                    self.closeWindow()
                    break // if "exit" didn't work, still don't execute the rest of the commands. 
                }
                if (command == "newWindow") || (command.hasPrefix("newWindow ")) {
                    self.executeCommand(command: command)
                    continue
                }
                self.currentCommand = command
                let pid = ios_fork()
                ios_system(self.currentCommand)
                ios_waitpid(pid)
                NSLog("Done executing command: \(command)")
                NSLog("Current directory: \(FileManager().currentDirectoryPath)")
            }
            close(stdin_pipe.fileHandleForReading.fileDescriptor)
            self.stdin_file_input = nil
            close(tty_pipe.fileHandleForReading.fileDescriptor)
            self.tty_file_input = nil
            // Send info to the stdout handler that the command has finished:
            let writeOpen = fcntl(stdout_pipe.fileHandleForWriting.fileDescriptor, F_GETFD)
            if (writeOpen >= 0) {
                // Pipe is still open, send information to close it, once all output has been processed.
                stdout_pipe.fileHandleForWriting.write(self.endOfTransmission.data(using: .utf8)!)
                while (self.stdout_active) {
                    fflush(thread_stdout)
                }
            }
            // Experimental: If it works, try removing the 4 lines above
            close(stdout_pipe.fileHandleForWriting.fileDescriptor)
            if (self.closeAfterCommandTerminates) {
                self.closeAfterCommandTerminates = false
                let session = self.windowScene!.session
                UIApplication.shared.requestSceneSessionDestruction(session, options: nil)
            }
            // Did the command change the current directory?
            let newDirectory = FileManager().currentDirectoryPath
            if (newDirectory != self.currentDirectory) {
                self.previousDirectory = self.currentDirectory
                self.currentDirectory = newDirectory
            }
            // Did we set up a directory to restore at the end? (shortcuts do that)
            if (self.resetDirectoryAfterCommandTerminates != "") {
                NSLog("Calling resetDirectoryAfterCommandTerminates to \(self.resetDirectoryAfterCommandTerminates)")
                if (!changeDirectory(path: self.resetDirectoryAfterCommandTerminates)) {
                    ios_switchSession(self.persistentIdentifier?.toCString())
                    ios_setContext(UnsafeMutableRawPointer(mutating: self.persistentIdentifier?.toCString()))
                    changeDirectory(path: self.resetDirectoryAfterCommandTerminates)
                }
                self.resetDirectoryAfterCommandTerminates = ""
            }
            self.currentCommand = ""
            self.printPrompt();
        }
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let cmd:String = message.body as? String else {
            NSLog("Could not convert Javascript message: \(message.body)")
            return
        }
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
                ios_setWindowSize(Int32(width), Int32(height), self.persistentIdentifier?.toCString())
                setenv("COLUMNS", "\(width)".toCString(), 1)
                ios_signal(SIGWINCH);
            }
        } else if (cmd.hasPrefix("height:")) {
            var command = cmd
            command.removeFirst("height:".count)
            let newHeight = Int(command) ?? 80
            if (newHeight != height) {
                height = newHeight
                NSLog("Calling ios_setWindowSize: \(width) x \(height)")
                ios_setWindowSize(Int32(width), Int32(height), self.persistentIdentifier?.toCString())
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
                guard stdin_file_input != nil else {
                    // no command running, maybe it ended without us knowing:
                    printPrompt()
                    return
                }
                do {
                    try stdin_file_input?.close()
                }
                catch {
                    NSLog("Could not close stdin input.")
                }
                stdin_file_input = nil
            } else if (command == interrupt) {
                ios_kill() // TODO: add printPrompt() here if no command running
            } else {
                guard stdin_file_input != nil else { return }
                // TODO: don't send data if pipe already closed (^D followed by another key)
                // (store a variable that says the pipe has been closed)
                stdin_file_input?.write(data)
            }
        } else if (cmd.hasPrefix("inputInteractive:")) {
            // Interactive commands: just send the input to them. Allows Vim to map control-D to down half a page.
            var command = cmd
            command.removeFirst("inputInteractive:".count)
            guard let data = command.data(using: .utf8) else { return }
            ios_switchSession(self.persistentIdentifier?.toCString())
            ios_setContext(UnsafeMutableRawPointer(mutating: self.persistentIdentifier?.toCString()));
            ios_setStreams(self.stdin_file, self.stdout_file, self.stdout_file)
            guard stdin_file_input != nil else { return }
            // TODO: don't send data if pipe already closed (^D followed by another key)
            // (store a variable that says the pipe has been closed)
            stdin_file_input?.write(data)
        } else if (cmd.hasPrefix("inputTTY:")) {
            var command = cmd
            command.removeFirst("inputTTY:".count)
            guard let data = command.data(using: .utf8) else { return }
            ios_switchSession(self.persistentIdentifier?.toCString())
            ios_setContext(UnsafeMutableRawPointer(mutating: self.persistentIdentifier?.toCString()));
            guard tty_file_input != nil else { return }
            tty_file_input?.write(data)
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
                            // print(error)
                        }
                        if (result != nil) {
                            // print(result)
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
    
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        NSLog("Scene, continue: userActivity.activityType = \(userActivity.activityType)")
        if userActivity.activityType == "AsheKube.app.a-Shell.ExecuteCommand" {
            NSLog("scene/continue, userActivity.userInfo = \(userActivity.userInfo)")
            if (currentCommand != "") {
                // a command is already running in this window. Open a new one:
                UIApplication.shared.requestSceneSessionActivation(nil, userActivity: userActivity, options: nil)
                return
            }
            // set directory to a safer place:
            resetDirectoryAfterCommandTerminates = FileManager().currentDirectoryPath
            if let groupUrl = FileManager().containerURL(forSecurityApplicationGroupIdentifier:"group.AsheKube.a-Shell") {
                changeDirectory(path: groupUrl.path)
            }
            if let fileURL: NSURL = userActivity.userInfo!["url"] as? NSURL {
                // single command (probably won't be needed after)
                if var commandSent = fileURL.absoluteString {
                    commandSent.removeFirst("ashell:".count)
                    commandSent = commandSent.removingPercentEncoding!
                    // Set working directory to a safer place (also used by URL calls and extension shortcuts):
                    closeAfterCommandTerminates = false
                    if let closeAtEnd = userActivity.userInfo!["closeAtEnd"] as? String {
                        if (closeAtEnd == "true") {
                            closeAfterCommandTerminates = true
                        }
                    }
                    NSLog("Command to execute: " + commandSent)
                    // window.commandToExecute: too late for that (term_ is already created)
                    // executeCommand: too early for that. (keyboard is not ready yet)
                    commandSent = commandSent.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: "\\n")
                    let restoreCommand = "window.term_.io.println(\"Executing Shortcut: \(commandSent.replacingOccurrences(of: "\\n", with: "\\n\\r"))\");\nwindow.webkit.messageHandlers.aShell.postMessage('shell:' + '\(commandSent)');\nwindow.commandRunning = '\(commandSent)';\nwindow.commandToExecute = '';"
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
    
    func scene(_ scene: UIScene, didUpdate userActivity: NSUserActivity) {
        NSLog("Scene, didUpdate: userActivity.activityType = \(userActivity.activityType)")
    }
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnecting:SceneSession` instead).
        // Use a UIHostingController as window root view controller
        NSLog("Scene, willConnectTo session: \(connectionOptions)")
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
            webView?.isAccessibilityElement = false
            // toolbar for everyone because I can't change the aspect of inputAssistantItem buttons
            webView?.addInputAccessoryView(toolbar: self.editorToolbar)
            // Restore colors and settings from preference (if set):
            if let size = UserDefaults.standard.value(forKey: "fontSize") as? Float {
                terminalFontSize = size
            }
            if let name = UserDefaults.standard.value(forKey: "fontName") as? String {
                terminalFontName = name
            }
            if let hexColor = UserDefaults.standard.value(forKey: "backgroundColor") as? String {
                terminalBackgroundColor = UIColor(hexString: hexColor)
            }
            if let hexColor = UserDefaults.standard.value(forKey: "foregroundColor") as? String {
                terminalForegroundColor = UIColor(hexString: hexColor)
            }
            if let hexColor = UserDefaults.standard.value(forKey: "cursorColor") as? String {
                terminalCursorColor = UIColor(hexString: hexColor)
            }
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
            // If .profile exists, load it:
            var dotProfileUrl = try! FileManager().url(for: .documentDirectory,
                                                      in: .userDomainMask,
                                                      appropriateFor: nil,
                                                      create: true)
            dotProfileUrl = dotProfileUrl.appendingPathComponent(".profile")
            // A big issue is that, at this point, the window does not exist yet. So stdin, stdout, stderr also do not exist.
            if (FileManager().fileExists(atPath: dotProfileUrl.path)) {
                do {
                    let contentOfFile = try String(contentsOf: dotProfileUrl, encoding: String.Encoding.utf8)
                    let commands = contentOfFile.split(separator: "\n")
                    ios_switchSession(self.persistentIdentifier?.toCString())
                    ios_setContext(UnsafeMutableRawPointer(mutating: self.persistentIdentifier?.toCString()));
                    thread_stdin  = stdin
                    thread_stdout = stdout
                    thread_stderr = stderr
                    for command in commands {
                        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
                        if (trimmedCommand.count == 0) { continue } // skip white lines
                        if (trimmedCommand.hasPrefix("#")) { continue } // skip comments
                        // reset the LC_CTYPE (some commands (luatex) can change it):
                        setenv("LC_CTYPE", "UTF-8", 1);
                        setlocale(LC_CTYPE, "UTF-8");
                        let pid = ios_fork()
                        ios_system(trimmedCommand)
                        ios_waitpid(pid)
                        // NSLog("Done executing command from .profile: \(command)")
                        // NSLog("Current directory: \(FileManager().currentDirectoryPath)")
                    }
                }
                catch {
                    NSLog("Could not load .profile: \(error.localizedDescription)")
                }
            }
            // Was this window created with a purpose?
            // Case 1: url to open is inside urlContexts
            NSLog("connectionOptions.urlContexts: \(connectionOptions.urlContexts.first)")
            if let urlContext = connectionOptions.urlContexts.first {
                // let sendingAppID = urlContext.options.sourceApplication
                let fileURL = urlContext.url
                // NSLog("url from urlContexts = \(fileURL)")
                if (fileURL.isFileURL) {
                    let isReadableWithoutSecurity = FileManager().isReadableFile(atPath: fileURL.path)
                    let isSecuredURL = fileURL.startAccessingSecurityScopedResource()
                    let isReadable = FileManager().isReadableFile(atPath: fileURL.path)
                    guard isSecuredURL && isReadable else {
                        showAlert("Error", message: "Could not access file: \(fileURL.absoluteString).")
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
                        changeDirectory(path: fileURL.path) // call cd_main and checks secured bookmarked URLs
                        closeAfterCommandTerminates = false
                    } else {
                        // It's a file
                        // TODO: customize the command (vim, microemacs, python, clang, TeX?)
                        executeCommand(command: "vim " + (fileURL.path.removingPercentEncoding!.replacingOccurrences(of: " ", with: "\\ ")))
                        let openFileCommand = "window.commandRunning = 'vim';"
                        self.webView?.evaluateJavaScript(openFileCommand) { (result, error) in
                            if error != nil {
                                // print(error)
                            }
                            if (result != nil) {
                                // print(result)
                            }
                        }
                        closeAfterCommandTerminates = true
                    }
                } else if (fileURL.scheme == "ashell") {
                    NSLog("We received an URL: \(fileURL)") // received "ashell:ls"
                    // The window is not yet fully opened, so executeCommand might fail.
                    // Instead, we use commandToExecute sent to JavaScript.
                    var command = fileURL.absoluteString
                    command.removeFirst("ashell:".count)
                    command = command.removingPercentEncoding!
                    // Set the working directory to somewhere safe:
                    // (but do not reset afterwards, since this is a new window)
                    closeAfterCommandTerminates = false
                    if let groupUrl = FileManager().containerURL(forSecurityApplicationGroupIdentifier:"group.AsheKube.a-Shell") {
                        changeDirectory(path: groupUrl.path)
                    }
                    command = command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: "\\n")
                    let restoreCommand = "window.term_.io.println(\"Executing URL: \(command)\"); window.commandToExecute = '" + command + "';"
                    self.webView?.evaluateJavaScript(restoreCommand) { (result, error) in
                        if error != nil {
                            // print(error)
                        }
                        if (result != nil) {
                            // print(result)
                        }
                    }
                }
            }
            // Case 2: url to open is inside userActivity
            // NSLog("connectionOptions.userActivities.first: \(connectionOptions.userActivities.first)")
            // NSLog("stateRestorationActivity: \(session.stateRestorationActivity)")
            for userActivity in connectionOptions.userActivities {
                NSLog("Found userActivity: \(userActivity)")
                NSLog("Type: \(userActivity.activityType)")
                NSLog("URL: \(userActivity.userInfo!["url"])")
                NSLog("UserInfo: \(userActivity.userInfo!)")
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
                            // print(error)
                        }
                        if (result != nil) {
                            // print(result)
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
                } else if (userActivity.activityType == "AsheKube.app.a-Shell.ExecuteCommand") {
                    // If the app wasn't running, we arrive here:
                    // This can be either from open URL (ashell:command) or from Shortcuts
                    // Set working directory to a safer place (also used by shortcuts):
                    // But do not reset afterwards, since this is a new window
                    NSLog("Scene, willConnectTo: userActivity.userInfo = \(userActivity.userInfo)")
                    if let groupUrl = FileManager().containerURL(forSecurityApplicationGroupIdentifier:"group.AsheKube.a-Shell") {
                        changeDirectory(path: groupUrl.path)
                    }
                    if let fileURL: NSURL = userActivity.userInfo!["url"] as? NSURL {
                        // single command:
                        if var commandSent = fileURL.absoluteString {
                            commandSent.removeFirst("ashell:".count)
                            commandSent = commandSent.removingPercentEncoding!
                            closeAfterCommandTerminates = false
                            if let closeAtEnd = userActivity.userInfo!["closeAtEnd"] as? String {
                                if (closeAtEnd == "true") {
                                    closeAfterCommandTerminates = true
                                }
                            }
                            NSLog("Command to execute: " + commandSent)
                            // We can't go through executeCommand because the window is not fully created yet.
                            // Same reason we can't print the shortcut that is about to be executed.
                            commandSent = commandSent.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: "\\n")
                            let restoreCommand = "window.commandToExecute = '" + commandSent + "';"
                            self.webView?.evaluateJavaScript(restoreCommand) { (result, error) in
                                if error != nil {
                                    let userInfo = (error! as NSError).userInfo
                                    NSLog("error: " + (userInfo["WKJavaScriptExceptionMessage"] as? String)!)
                                    // print(error)
                                }
                                if (result != nil) {
                                    NSLog("result: " + (result as! String))
                                    // print(result)
                                }
                            }
                        }
                    }
                }
            }

            NotificationCenter.default
                .publisher(for: UIWindow.didBecomeKeyNotification, object: window)
                .handleEvents(receiveOutput: { notification in
                    NSLog("didBecomeKey: \(notification.name.rawValue): \(session.persistentIdentifier).")
                })
                .sink { _ in self.webView?.focus() }
                .store(in: &cancellables)
            NotificationCenter.default
                .publisher(for: UIWindow.didResignKeyNotification, object: window)
                .merge(with: NotificationCenter.default
                    .publisher(for: UIResponder.keyboardWillHideNotification))
                .handleEvents(receiveOutput: { notification in
                    NSLog("didResignKey: \(notification.name.rawValue): \(session.persistentIdentifier).")
                })
                .sink { _ in self.webView?.blur() }
                .store(in: &cancellables)
        }
    }

    
    func scene(_ scene: UIScene, openURLContexts: Set<UIOpenURLContext>) {
        NSLog("Calling openURLContexts with \(openURLContexts)")
        for urlContext in openURLContexts {
            // Is it one of our URLs?
            let fileURL = urlContext.url
            if (fileURL.scheme == "ashell") {
                NSLog("We received an URL: \(fileURL)") // received "ashell:ls"
                let activity = NSUserActivity(activityType: "AsheKube.app.a-Shell.ExecuteCommand")
                activity.userInfo!["url"] = fileURL
                // create a window and execute the command:
                UIApplication.shared.requestSceneSessionActivation(nil, userActivity: activity, options: nil)
                continue
            }
            // Otherwise, ensure the URL is a file URL
            if (!fileURL.isFileURL) { continue }
            NSLog("openURLContexts: \(fileURL.path)")
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
                        if (stdin_file_input != nil) {
                            stdin_file_input?.write(data!)
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
                    if (stdin_file_input != nil) {
                        stdin_file_input?.write(data!)
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
    
    func setEnvironmentFGBG(foregroundColor: UIColor, backgroundColor: UIColor)  {
        // Are we in light mode or dark mode?
        // This could be improved now that we can be in a whole set of situations
        // If the user is running one window in light mode and one in dark mode,
        // it will be the same environment for both.
        // unless I make COLORFGBG a scene-dependent environment variable, like COLUMN and LINES.
        var H_fg: CGFloat = 0
        var S_fg: CGFloat = 0
        var B_fg: CGFloat = 0
        var A_fg: CGFloat = 0
        foregroundColor.getHue(&H_fg, saturation: &S_fg, brightness: &B_fg, alpha: &A_fg)
        var H_bg: CGFloat = 0
        var S_bg: CGFloat = 0
        var B_bg: CGFloat = 0
        var A_bg: CGFloat = 0
        backgroundColor.getHue(&H_bg, saturation: &S_bg, brightness: &B_bg, alpha: &A_bg)
        if (B_fg > B_bg) {
            // Dark mode
            setenv("COLORFGBG", "15;0", 1)
        } else {
            // Light mode
            setenv("COLORFGBG", "0;15", 1)
        }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
        NSLog("sceneDidBecomeActive: \(self.persistentIdentifier).")
        let traitCollection = webView!.traitCollection
        // Set scene parameters (unless they were set before)
        let backgroundColor = terminalBackgroundColor ?? UIColor.systemBackground.resolvedColor(with: traitCollection)
        let foregroundColor = terminalForegroundColor ?? UIColor.placeholderText.resolvedColor(with: traitCollection)
        let cursorColor = terminalCursorColor ?? UIColor.link.resolvedColor(with: traitCollection)
        // TODO: add font size and font name
        let fontSize = terminalFontSize ?? factoryFontSize
        let fontName = terminalFontName ?? factoryFontName

        // Window.term_ does not always exist when sceneDidBecomeActive is called. We *also* set window.foregroundColor, and then use that when we create term.
        webView!.tintColor = foregroundColor
        webView!.backgroundColor = backgroundColor
        var command = "window.foregroundColor = '" + foregroundColor.toHexString() + "'; window.backgroundColor = '" + backgroundColor.toHexString() + "'; window.cursorColor = '" + cursorColor.toHexString() + "'; window.fontSize = '\(fontSize)' ; window.fontFamily = '\(fontName)';"
        webView!.evaluateJavaScript(command) { (result, error) in
            if error != nil {
                NSLog("Error in sceneDidBecomeActive, line = \(command)")
                print(error)
            }
            if (result != nil) {
                // sprint(result)
            }
        }
        
        command = "window.term_ != undefined"
        webView!.evaluateJavaScript(command) { (result, error) in
            if error != nil {
                print(error)
            }
            if let resultN = result as? Int {
                if (resultN == 1) {
                    // window.term_ exists, let's send commands:
                    command = "window.term_.setForegroundColor('" + foregroundColor.toHexString() + "'); window.term_.setBackgroundColor('" + backgroundColor.toHexString() + "'); window.term_.setCursorColor('" + cursorColor.toHexString() + "'); window.term_.setFontSize(\(fontSize)); window.term_.setFontFamily('\(fontName)');"
                    self.webView!.evaluateJavaScript(command) { (result, error) in
                        if error != nil {
                            NSLog("Error in sceneDidBecomeActive, line = \(command)")
                            print(error)
                        }
                        if (result != nil) {
                            // print(result)
                        }
                    }
                    command = "window.term_.prefs_.set('foreground-color', '" + foregroundColor.toHexString() + "'); window.term_.prefs_.set('background-color', '" + backgroundColor.toHexString() + "'); window.term_.prefs_.set('cursor-color', '" + cursorColor.toHexString() + "'); window.term_.prefs_.set('font-size', '\(fontSize)'); window.term_.prefs_.set('font-family', '\(fontName)');"
                    self.webView!.evaluateJavaScript(command) { (result, error) in
                        if error != nil {
                            print(error)
                        }
                        if (result != nil) {
                            // print(result)
                        }
                    }
                }
            }
        }
        setEnvironmentFGBG(foregroundColor: foregroundColor, backgroundColor: backgroundColor)
        webView!.allowDisplayingKeyboardWithoutUserAction()
        activateVoiceOver(value: UIAccessibility.isVoiceOverRunning)
        ios_signal(SIGWINCH); // is this still required?
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
        NSLog("sceneWillResignActive: \(self.persistentIdentifier).")
    }

    func sceneWillEnterForegraund(_ scene: UIScene) {
        NSLog("Entered the a-Shell:sceneWillEnterForeground")
    }
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
        // Was this window created with a purpose?
        let userActivity = scene.userActivity
        // Do not restore if a command is already running.
        if (userActivity?.activityType == "AsheKube.app.a-Shell.ExecuteCommand") { return }
        if (userActivity?.activityType == "AsheKube.app.a-Shell.EditDocument") { return }
        if (userActivity?.activityType == "AsheKube.app.a-Shell.OpenDirectory") { return }
        // Otherwise, go for it:
        NSLog("sceneWillEnterForeground: \(self.persistentIdentifier). userActivity: \(userActivity)")
        guard (scene.session.stateRestorationActivity != nil) else { return }
        guard let userInfo = scene.session.stateRestorationActivity!.userInfo else { return }
        NSLog("Restoring history, previousDir, currentDir:")
        if let historyData = userInfo["history"] {
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
                    // print(error)
                }
                if (result != nil) {
                    // print(result)x
                }
            }
        }
        if let previousDirectoryData = userInfo["prev_wd"] {
            if let previousDirectory = previousDirectoryData as? String {
                NSLog("got previousDirectory as \(previousDirectory)")
                if (FileManager().fileExists(atPath: previousDirectory) && FileManager().isReadableFile(atPath: previousDirectory)) {
                    NSLog("set previousDirectory to \(previousDirectory)")
                    // Call cd_main instead of executeCommand("cd dir") to avoid closing a prompt and history.
                    changeDirectory(path: previousDirectory) // call cd_main and checks secured bookmarked URLs
                }
            }
        }
        if let currentDirectoryData = userInfo["cwd"] {
            if let currentDirectory = currentDirectoryData as? String {
                NSLog("got currentDirectory as \(currentDirectory)")
                if (FileManager().fileExists(atPath: currentDirectory) && FileManager().isReadableFile(atPath: currentDirectory)) {
                    NSLog("set currentDirectory to \(currentDirectory)")
                    // Call cd_main instead of executeCommand("cd dir") to avoid closing a prompt and history.
                    changeDirectory(path: currentDirectory) // call cd_main and checks secured bookmarked URLs
                }
            }
        }
        // Window preferences, stored on a per-session basis:
        if let fontSize = userInfo["fontSize"] as? Float {
            terminalFontSize = fontSize
        }
        if let fontName = userInfo["fontName"] as? String {
            terminalFontName = fontName
        }
        // We store colors as hex strings:
        if let backgroundColor = userInfo["backgroundColor"] as? String {
            terminalBackgroundColor = UIColor(hexString: backgroundColor)
        }
        if let foregroundColor = userInfo["foregroundColor"] as? String {
            terminalForegroundColor =  UIColor(hexString: foregroundColor)
        }
        if let cursorColor = userInfo["cursorColor"] as? String {
            terminalCursorColor = UIColor(hexString: cursorColor)
        }
        if var terminalData = userInfo["terminal"] as? String {
            if (terminalData.contains(";Thanks for flying Vim")) {
                // Rest of a Vim session; skip everything until next prompt.
                let components = terminalData.components(separatedBy: ";Thanks for flying Vim")
                terminalData = String(components.last ?? "")
            }
            // Also skip to first prompt:
            if (terminalData.contains("$ ")) {
                if let index = terminalData.firstIndex(of: "$") {
                    terminalData = String(terminalData.suffix(from: index))
                }
            }
            print("printedContent restored = \(terminalData.count) End")
            let javascriptCommand = "window.printedContent = \"" + terminalData.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\r", with: "\\r").replacingOccurrences(of: "\n", with: "\\n\\r") + "\"; "
            webView!.evaluateJavaScript(javascriptCommand) { (result, error) in
                if error != nil {
                    // NSLog("Error in resetting terminal, line = \(javascriptCommand)")
                    // print(error)
                }
                // if (result != nil) { print(result) }
            }
        }
        // restart the current command if one was running before
        let currentCommandData = userInfo["currentCommand"]
        if let storedCommand = currentCommandData as? String {
            if (storedCommand.count > 0) {
                NSLog("Restarting session with \(storedCommand)")
                if (storedCommand.hasPrefix("ipython") || storedCommand.hasPrefix("man") || storedCommand.hasPrefix("jupyter")) {
                    return // Don't restart ipython, jupyter or man pages (because it crashes).
                }
                // Safety check: is the vim session file still there?
                // I could have been removed by the system, or by the user.
                // TODO: also check that files are still available / no
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
                NSLog("sceneWillEnterForeground, Restoring command: \(storedCommand)")
                let restoreCommand = "window.commandToExecute = '" + storedCommand.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: "\\n") + "';"
                NSLog("Calling command: \(restoreCommand)")
                self.webView?.evaluateJavaScript(restoreCommand) { (result, error) in
                    if error != nil {
                        // print(error)
                    }
                    if (result != nil) {
                        // print(result)
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
        if (terminalFontSize != nil) {
            scene.session.stateRestorationActivity?.userInfo!["fontSize"] = terminalFontSize
        }
        if (terminalFontName != nil) {
            scene.session.stateRestorationActivity?.userInfo!["fontName"] = terminalFontName
        }
        // Must store information in userinfo as String or Float, not UIColor.
        if (terminalBackgroundColor != nil) && (terminalBackgroundColor != .systemBackground) {
            scene.session.stateRestorationActivity?.userInfo!["backgroundColor"] = terminalBackgroundColor!.toHexString()
        }
        if (terminalForegroundColor != nil) && (terminalForegroundColor != .placeholderText) {
            scene.session.stateRestorationActivity?.userInfo!["foregroundColor"] = terminalForegroundColor!.toHexString()
        }
        if (terminalCursorColor != nil) && (terminalForegroundColor != .link) {
            scene.session.stateRestorationActivity?.userInfo!["cursorColor"] = terminalCursorColor!.toHexString()
        }
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
                // Don't store terminal content when vim is running.
                scene.session.stateRestorationActivity?.userInfo!["terminal"] = nil
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
                    if (stdin_file_input != nil) {
                        stdin_file_input?.write(data!)
                        return
                    }
                }
            }
        }
        // Get only the last 25000 characters of printedContent.
        // An iPad pro screen is 5000 characters, so this is 5 screens of content.
        // When window.printedContent is too large, this function does not return before the session is terminated.
        // Note: if this fails, check window.printedContent length at the start/end of a command, not after each print.
        webView!.evaluateJavaScript("window.printedContent.substring(window.printedContent.length - 25000)",
                                    completionHandler: { (printedContent: Any?, error: Error?) in
                                        if error != nil {
                                            NSLog("Error in capturing terminal content: \(error!.localizedDescription)")
                                            // print(error)
                                        }
                                        if (printedContent != nil) {
                                            scene.session.stateRestorationActivity?.userInfo!["terminal"] = printedContent
                                            print("printedContent saved.")
                                        }
        })
    }

    // Called when the stdout file handle is written to
    private var dataBuffer = Data()

    func activateVoiceOver(value: Bool) {
        guard (webView != nil) else { return }
        webView?.isAccessibilityElement = false
        let command = "window.voiceOver = \(value);"
        // NSLog(command)
        DispatchQueue.main.async {
            self.webView!.evaluateJavaScript(command) { (result, error) in
                if error != nil {
                    NSLog("Error in activateVoiceOver.")
                    print(error)
                }
                if (result != nil) {
                    // print(result)
                }
            }
        }
        let command2 = "if (window.term_ != undefined) { window.term_.setAccessibilityEnabled(window.voiceOver); }"
        // NSLog(command2)
        DispatchQueue.main.async {
            self.webView!.evaluateJavaScript(command2) { (result, error) in
                if error != nil {
                    NSLog("Error in activateVoiceOver.")
                    print(error)
                }
                if (result != nil) {
                    // print(result)
                }
            }
        }
    }
    
    private func outputToWebView(string: String) {
        guard (webView != nil) else { return }
        // Sanitize the output string to it can be sent to javascript:
        let parsedString = string.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\r", with: "\\r").replacingOccurrences(of: "\n", with: "\\n\\r")
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
    }
    
    private func onStdout(_ stdout: FileHandle) {
        if (!stdout_active) { return }
        let data = stdout.availableData
        guard (data.count > 0) else {
            return
        }
        if let string = String(data: data, encoding: String.Encoding.utf8) {
            // NSLog(string)
            outputToWebView(string: string)
            if (string.contains(endOfTransmission)) {
                stdout_active = false
            }
        } else if let string = String(data: data, encoding: String.Encoding.ascii) {
            NSLog("Couldn't convert data in stdout using UTF-8, resorting to ASCII: \(string)")
            outputToWebView(string: string)
            if (string.contains(endOfTransmission)) {
                stdout_active = false
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
        var message = ""
        var cancel = "Cancel"
        var confirm = "OK"

        if (arguments.count >= 1) {
            message = arguments[1]
        }
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        if (arguments.count >= 2) {
            cancel = arguments[2]
        }
        alertController.addAction(UIAlertAction(title: cancel, style: .cancel, handler: { (action) in
            completionHandler(false)
        }))
        
        if (arguments.count >= 3) {
            confirm = arguments[3]
            if (confirm.hasPrefix("btn-danger")) {
                confirm.removeFirst("btn-danger".count)
                alertController.addAction(UIAlertAction(title: confirm, style: .destructive, handler: { (action) in
                    completionHandler(true)
            }))
            } else {
                alertController.addAction(UIAlertAction(title: confirm, style: .default, handler: { (action) in
                    completionHandler(true)
                }))
            }
        }
                
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
        // communication with libc from webAssembly:
        
        let arguments = prompt.components(separatedBy: "\n")
        // NSLog("prompt: \(prompt)")
        let title = arguments[0]
        if (title == "libc") {
            // Make sure we are on the right iOS session. This resets the current working directory.
            ios_switchSession(self.persistentIdentifier?.toCString())
            ios_setContext(UnsafeMutableRawPointer(mutating: self.persistentIdentifier?.toCString()));
            if (arguments[1] == "open") {
                let rights = Int32(arguments[3]) ?? 577;
                if (!FileManager().fileExists(atPath: arguments[2]) && (rights > 0)) {
                    // The file doesn't exist *and* we will want to write into it. First, we create it:
                    let fileUrl = URL(fileURLWithPath: arguments[2])
                    do {
                        try "".write(to: fileUrl, atomically: true, encoding: .utf8)
                    }
                    catch {
                        // We will raise an error with open later.
                    }
                }
                let returnValue = open(arguments[2], rights)
                if (returnValue == -1) {
                    completionHandler("\(-errno)")
                    errno = 0
                } else {
                    completionHandler("\(returnValue)")
                }
                return
            } else if (arguments[1] == "close") {
                var returnValue:Int32 = -1
                if let fd = fileDescriptor(input: arguments[2]) {
                    if (fd == fileno(self.thread_stdin_copy)) || (fd == fileno(self.thread_stdout_copy)) || (fd == fileno(self.thread_stderr_copy)) {
                        // don't close stdin/stdout/stderr
                        returnValue = 0
                    } else {
                        returnValue = close(fd)
                    }
                    if (returnValue == -1) {
                        completionHandler("\(-errno)")
                        errno = 0
                    } else {
                        completionHandler("\(returnValue)")
                    }
                    return
                }
                completionHandler("\(-EBADF)") // invalid file descriptor
                return
            } else if (arguments[1] == "write") {
                var returnValue = Int(-EBADF); // Number of bytes written
                if let fd = fileDescriptor(input: arguments[2]) {
                    // arguments[3] == "84,104,105,115,32,116,101,120,116,32,103,111,101,115,32,116,111,32,115,116,100,111,117,116,10"
                    // arguments[4] == nb bytes
                    // arguments[5] == offset
                    returnValue = 0; // valid file descriptor, maybe nothing to write
                    let values = arguments[3].components(separatedBy:",")
                    var data = Data.init()
                    if let numValues = Int(arguments[4]) {
                        if (numValues > 0) {
                            let offset = UInt64(arguments[5]) ?? 0
                            for c in 0...numValues-1 {
                                if let value = UInt8(values[c]) {
                                    data.append(contentsOf: [value])
                                }
                            }
                            // let returnValue = write(fd, data, numValues)
                            let file = FileHandle(fileDescriptor: fd)
                            if (offset > 0) {
                                do {
                                  try file.seek(toOffset: offset)
                                }
                                catch {
                                    let errorCode = (error as NSError).code
                                    completionHandler("\(-errorCode)")
                                    return
                                }
                            }
                            file.write(data)
                            returnValue = numValues
                        }
                    }
                }
                completionHandler("\(returnValue)")
                return
            } else if (arguments[1] == "read") {
                var data = Data.init()
                if let fd = fileDescriptor(input: arguments[2]) {
                    // arguments[3] = length
                    // arguments[4] = offset
                    // let values = arguments[3].components(separatedBy:",")
                    if let numValues = Int(arguments[3]) {
                        let offset = UInt64(arguments[4]) ?? 0
                        let file = FileHandle(fileDescriptor: fd)
                        do {
                            try file.seek(toOffset: offset)
                        }
                        catch {
                            if (offset != 0) {
                                let errorCode = (error as NSError).code
                                completionHandler("\(-errorCode)")
                                return
                            }
                        }
                        data = file.readData(ofLength: numValues)
                    }
                    completionHandler("\(data.base64EncodedString())")
                } else {
                    completionHandler("\(-EBADF)") // Invalid file descriptor
                }
                return
            } else if (arguments[1] == "fstat") {
                if let fd = fileDescriptor(input: arguments[2]) {
                    let buf = stat.init()
                    var pbuf = UnsafeMutablePointer<stat>.allocate(capacity: 1)
                    pbuf.initialize(to: buf)
                    let returnValue = fstat(fd, pbuf)
                    if (returnValue == 0) {
                        completionHandler("\(pbuf.pointee)")
                    } else {
                        completionHandler("\(-errno)")
                        errno = 0
                    }
                    return
                }
                completionHandler("\(-EBADF)") // Invalid file descriptor
                return
            } else if (arguments[1] == "stat") {
                let buf = stat.init()
                var pbuf = UnsafeMutablePointer<stat>.allocate(capacity: 1)
                pbuf.initialize(to: buf)
                let returnValue = stat(arguments[2], pbuf)
                if (returnValue == 0) {
                    completionHandler("\(pbuf.pointee)")
                } else {
                    completionHandler("\(-errno)")
                    errno = 0
                }
                return
            } else if (arguments[1] == "readdir") {
                do {
                    // Much more compact code than using readdir.
                    let items = try FileManager().contentsOfDirectory(atPath: arguments[2])
                    var returnString = ""
                    for item in items {
                        returnString = returnString + item + "\n"
                    }
                    completionHandler(returnString)
                }
                catch {
                    let errorCode = (error as NSError).code
                    completionHandler("\(-errorCode)")
                }
                return
            } else if (arguments[1] == "mkdir") {
                do {
                    try FileManager().createDirectory(atPath: arguments[2], withIntermediateDirectories: true)
                    completionHandler("0")
                }
                catch {
                    let errorCode = (error as NSError).code
                    completionHandler("\(-errorCode)")
                }
                return
            } else if (arguments[1] == "rmdir") {
                do {
                    try FileManager().removeItem(atPath: arguments[2])
                    completionHandler("0")
                }
                catch {
                    let errorCode = (error as NSError).code
                    completionHandler("\(-errorCode)")
                }
                return
            } else if (arguments[1] == "rename") {
                do {
                    try FileManager().moveItem(atPath:arguments[2], toPath: arguments[3])
                    completionHandler("0")
                }
                catch {
                    let errorCode = (error as NSError).code
                    completionHandler("\(-errorCode)")
                }
                return
            }  else if (arguments[1] == "link") {
                do {
                    try FileManager().linkItem(atPath:arguments[2], toPath: arguments[3])
                    completionHandler("0")
                }
                catch {
                    let errorCode = (error as NSError).code
                    completionHandler("\(-errorCode)")
                }
                return
            } else if (arguments[1] == "symlink") {
                do {
                    try FileManager().createSymbolicLink(atPath:arguments[3], withDestinationPath: arguments[2])
                    completionHandler("0")
                }
                catch {
                    let errorCode = (error as NSError).code
                    completionHandler("\(-errorCode)")
                }
                return
            } else if (arguments[1] == "readlink") {
                do {
                    let destination = try FileManager().destinationOfSymbolicLink(atPath:arguments[2])
                    completionHandler(destination)
                }
                catch {
                    // to remove ambiguity, add '\n' at the beginning
                    // this might fail if a link points to
                    let errorCode = (error as NSError).code
                    completionHandler("\n\(-errorCode)")
                }
                return
            } else if (arguments[1] == "unlink") {
                let returnVal = unlink(arguments[2])
                if (returnVal != 0) {
                    completionHandler("\(-errno)")
                    errno = 0
                } else {
                    completionHandler("\(returnVal)")
                }
                return
            } else if (arguments[1] == "fsync") {
                if let fd = fileDescriptor(input: arguments[2]) {
                    let returnVal = fsync(fd)
                    if (returnVal != 0) {
                        completionHandler("\(-errno)")
                        errno = 0
                    } else {
                        completionHandler("\(returnVal)")
                    }
                    return
                }
                completionHandler("\(-EBADF)") // invalid file descriptor
                return
            } else if (arguments[1] == "ftruncate") {
                if let fd = fileDescriptor(input: arguments[2]) {
                    if let length = Int64(arguments[3]) {
                        let returnVal = ftruncate(fd, length)
                        if (returnVal != 0) {
                            completionHandler("\(-errno)")
                            errno = 0
                        } else {
                            completionHandler("\(returnVal)")
                        }
                        return
                    }
                    completionHandler("\(-EINVAL)") // invalid length
                    return
                }
                completionHandler("\(-EBADF)") // invalid file descriptor
                return
                //
                // Additions to WASI for easier interaction with the iOS underlying part: getenv, setenv, unsetenv
                // getcwd, chdir, fchdir, system.
                //
            } else if (arguments[1] == "getcwd") {
                let result = FileManager().currentDirectoryPath
                completionHandler(result)
                return
            } else if (arguments[1] == "chdir") {
                let result = changeDirectory(path: arguments[2]) // call cd_main and updates the ios current session
                completionHandler("\(result)") // true or false
                return
            } else if (arguments[1] == "fchdir") {
                if let fd = Int32(arguments[2]) {
                    let result = fchdir(fd)
                    if (result != 0) {
                        completionHandler("\(-errno)")
                        errno = 0
                    } else {
                        completionHandler("\(result)")
                    }
                } else {
                    completionHandler("-\(EBADF)") // bad file descriptor
                }
                return
            } else if (arguments[1] == "system") {
                thread_stdin = self.thread_stdin_copy
                thread_stdout = self.thread_stdout_copy
                thread_stderr = self.thread_stderr_copy
                let pid = ios_fork()
                let result = ios_system(arguments[2])
                ios_waitpid(pid)
                completionHandler("\(result)")
                return
            } else if (arguments[1] == "getenv") {
                let result = ios_getenv(arguments[2])
                if (result != nil) {
                    completionHandler(String(cString: result!))
                } else {
                    completionHandler("0")
                }
                return
            } else if (arguments[1] == "setenv") {
                let force = Int32(arguments[4])
                let result = setenv(arguments[2], arguments[3], force!)
                if (result != 0) {
                    completionHandler("\(-errno)")
                    errno = 0
                } else {
                    completionHandler("\(result)")
                }
                return
            } else if (arguments[1] == "unsetenv") {
                let result = unsetenv(arguments[2])
                if (result != 0) {
                    completionHandler("\(-errno)")
                    errno = 0
                } else {
                    completionHandler("\(result)")
                }
                return
            } else if (arguments[1] == "utimes") {
                let path = arguments[2]
                if let atime_millisec = Int32(arguments[3]) {
                    let atime_sec = Int(atime_millisec / 1000)
                    let atime_usec = Int32((atime_millisec - Int32(1000 * atime_sec)) * 1000)
                    let atime: timeval = timeval(tv_sec: atime_sec, tv_usec: atime_usec)
                    if let mtime_millisec = Int32(arguments[4]) {
                        let mtime_sec = Int(mtime_millisec / 1000)
                        let mtime_usec = Int32((mtime_millisec - Int32(1000 * mtime_sec)) * 1000)
                        let mtime: timeval = timeval(tv_sec: mtime_sec, tv_usec: mtime_usec)
                        var time = UnsafeMutablePointer<timeval>.allocate(capacity: 2)
                        time[0] = atime
                        time[1] = mtime
                        let returnVal = utimes(path, time)
                        if (returnVal != 0) {
                            completionHandler("\(-errno)")
                            errno = 0
                        } else {
                            completionHandler("\(returnVal)")
                        }
                        return
                    } else {
                        completionHandler("\(-EFAULT)") // time points out of process allocated space
                        return
                    }
                } else {
                    completionHandler("\(-EFAULT)") // time points out of process allocated space
                    return
                }
            } else if (arguments[1] == "futimes") {
                if let fd = fileDescriptor(input: arguments[2]) {
                    if let atime_sec = Int(arguments[3]) {
                        var atime_usec = Int32(arguments[4])
                        if (atime_usec == nil) {
                            atime_usec = 0
                        } else {
                            atime_usec = atime_usec! / 1000
                        }
                        let atime: timeval = timeval(tv_sec: atime_sec, tv_usec: atime_usec!)
                        if let mtime_sec = Int(arguments[5]) {
                            var mtime_usec = Int32(arguments[6])
                            if (mtime_usec == nil) {
                                mtime_usec = 0
                            } else {
                                mtime_usec = mtime_usec! / 1000
                            }
                            let mtime: timeval = timeval(tv_sec: mtime_sec, tv_usec: mtime_usec!)
                            var time = UnsafeMutablePointer<timeval>.allocate(capacity: 2)
                            time[0] = atime
                            time[1] = mtime
                            let returnVal = futimes(fd, time)
                            if (returnVal != 0) {
                                completionHandler("\(-errno)")
                                errno = 0
                            } else {
                                completionHandler("\(returnVal)")
                            }
                            return
                        } else {
                            completionHandler("\(-EFAULT)") // time points out of process allocated space
                            return
                        }
                    } else {
                        completionHandler("\(-EFAULT)") // time points out of process allocated space
                        return
                    }
                }
                completionHandler("\(-EBADF)") // invalid file descriptor
                return
            }
            // Not one of our commands:
            completionHandler("-1")
            return
        }
        // End communication with webAssembly using libc
        // Code copied from Carnets for better interaction with Jupyter
        var message = ""
        var cancel = "Dismiss"
        var confirm = "OK"
        if (arguments.count >= 1) {
            message = arguments[1]
        }
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        alertController.addTextField { (textField) in
            textField.text = defaultText
        }

        if (arguments.count >= 2) {
            cancel = arguments[2]
        }
        alertController.addAction(UIAlertAction(title: cancel, style: .default, handler: { (action) in
            completionHandler(nil)
        }))
        
        if (arguments.count >= 3) {
            confirm = arguments[3]
        }
        alertController.addAction(UIAlertAction(title: confirm, style: .default, handler: { (action) in
            if let text = alertController.textFields?.first?.text {
                completionHandler(text)
            } else {
                completionHandler(defaultText)
            }
        }))
        
        if let presenter = alertController.popoverPresentationController {
            presenter.sourceView = self.view
        }
        
        let rootVC = self.window?.rootViewController
        // rootVC?.resignFirstResponder()
        rootVC?.present(alertController, animated: true, completion: { () -> Void in
            // TODO: insert here some magical line that will restore focus to the window
            // makeFirstResponder and makeKeyboardActive don't work
        })
        // webView.allowDisplayingKeyboardWithoutUserAction()
    }

    // iOS 14: allow javascript evaluation
    func webView(_ webView: WKWebView,
          decidePolicyFor navigationAction: WKNavigationAction,
              preferences: WKWebpagePreferences,
              decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
        if #available(iOS 14.0, *) {
            preferences.allowsContentJavaScript = true // The default value is true, but let's make sure.
        }
        decisionHandler(.allow, preferences)
    }
    
}
