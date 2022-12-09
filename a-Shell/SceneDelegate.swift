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
import AVKit // for media playback
import AVFoundation // for media playback

var messageHandlerAdded = false
var inputFileURLBackup: URL?

let factoryFontSize = Float(13)
let factoryFontName = "Menlo"
let factoryCursorShape = "UNDERLINE"
var stdinString: String = ""

// Need: dictionary connecting userContentController with output streams (?)

class SceneDelegate: UIViewController, UIWindowSceneDelegate, WKNavigationDelegate, WKScriptMessageHandler, UIDocumentPickerDelegate, UIPopoverPresentationControllerDelegate, UIFontPickerViewControllerDelegate, UIDocumentInteractionControllerDelegate, UIGestureRecognizerDelegate {
    var window: UIWindow?
    var windowScene: UIWindowScene?
    var webView: Webview.WebViewType?
    var wasmWebView: WKWebView? // webView for executing wasm
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
    var shortcutCommandReceived: String? = nil
    var windowPrintedContent = ""
    var windowHistory = ""
    var pid: pid_t = 0
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
    var terminalCursorShape: String?
    // for audio / video playback:
    var avplayer: AVPlayer? = nil
    var avcontroller: AVPlayerViewController? = nil
    var avControllerPiPEnabled = false
    // for repetitive buttons
    var continuousButtonAction = false
    
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
            // if let error = error { print(error) }
            // if let result = result { print(result) }
        }
    }
    
    @objc private func controlAction(_ sender: UIBarButtonItem) {
        let configuration = UIImage.SymbolConfiguration(pointSize: fontSize, weight: .regular, scale: .large)
        controlOn = !controlOn;
        if #available(iOS 15.0, *) {
            if (!useSystemToolbar) {
                editorToolbar.items?[1].isSelected = controlOn
            } else {
                // This has no impact on the button appearance in some cases
                webView?.inputAssistantItem.leadingBarButtonGroups[0].barButtonItems[1].isSelected = controlOn
            }
        } else {
            sender.image = controlOn ? UIImage(systemName: "chevron.up.square.fill")!.withConfiguration(configuration) :
            UIImage(systemName: "chevron.up.square")!.withConfiguration(configuration)
        }
        webView?.evaluateJavaScript(controlOn ? "window.controlOn = true;" : "window.controlOn = false;") { (result, error) in
            // if let error = error { print(error) }
            // if let result = result { print(result) }
        }
    }
    
    @objc private func escapeAction(_ sender: UIBarButtonItem) {
        webView?.evaluateJavaScript("window.term_.io.onVTKeystroke(\"" + escape + "\");") { (result, error) in
            // if let error = error { print(error) }
            // if let result = result { print(result) }
        }
    }
    
    @objc private func pasteAction(_ sender: UIBarButtonItem) {
        // edit mode paste (works)
        if let pastedString = UIPasteboard.general.string {
            webView?.paste(pastedString)
        }
    }

    @objc private func copyAction(_ sender: UIBarButtonItem) {
        // edit mode copy (works)
        webView?.evaluateJavaScript("window.term_.copySelectionToClipboard();") { (result, error) in
            if let error = error { print(error) }
            if let result = result { print(result) }
        }
    }

    @objc private func cutAction(_ sender: UIBarButtonItem) {
        // edit mode cut (works)
        webView?.evaluateJavaScript("window.term_.onCut();") { (result, error) in
            if let error = error { print(error) }
            if let result = result { print(result) }
        }
    }

    
    @objc private func upAction(_ sender: UIBarButtonItem) {
        webView?.evaluateJavaScript("window.term_.io.onVTKeystroke((!window.term_.keyboard.applicationCursor) ? '\\x1b[A' : '\\x1bOA');") { (result, error) in
            // if let error = error { print(error) }
            // if let result = result { print(result) }
        }
    }
    
    @objc private func downAction(_ sender: UIBarButtonItem) {
        webView?.evaluateJavaScript("window.term_.io.onVTKeystroke((!window.term_.keyboard.applicationCursor) ? '\\x1b[B' : '\\x1bOB');") { (result, error) in
            // if let error = error { print(error) }
            // if let result = result { print(result) }
        }
    }
    
    @objc private func leftAction(_ sender: UIBarButtonItem) {
        webView?.evaluateJavaScript("window.term_.io.onVTKeystroke((!window.term_.keyboard.applicationCursor) ? '\\x1b[D' : '\\x1bOD');") { (result, error) in
            // if let error = error { print(error) }
            // if let result = result { print(result) }
        }
    }
    
    @objc private func rightAction(_ sender: UIBarButtonItem) {
        webView?.evaluateJavaScript("window.term_.io.onVTKeystroke((!window.term_.keyboard.applicationCursor) ? '\\x1b[C' : '\\x1bOC');") { (result, error) in
            // if let error = error { print(error) }
            // if let result = result { print(result) }
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
        let imageControl = UIImage(systemName: "chevron.up.square")!
        let controlButton = UIBarButtonItem(image: imageControl.withConfiguration(configuration), style: .plain, target: self, action: #selector(controlAction(_:)))
        if #available(iOS 15.0, *) {
            controlButton.changesSelectionAsPrimaryAction = true
            controlButton.menu = nil
        }
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
    
    var cutButton: UIBarButtonItem {
        let configuration = UIImage.SymbolConfiguration(pointSize: fontSize, weight: .regular)
        return UIBarButtonItem(image: UIImage(systemName: "scissors")!.withConfiguration(configuration), style: .plain, target: self, action: #selector(cutAction(_:)))
    }
    
    var copyButton: UIBarButtonItem {
        let configuration = UIImage.SymbolConfiguration(pointSize: fontSize, weight: .regular)
        return UIBarButtonItem(image: UIImage(systemName: "doc.on.doc")!.withConfiguration(configuration), style: .plain, target: self, action: #selector(copyAction(_:)))
    }
    
    var pasteButton: UIBarButtonItem {
        let configuration = UIImage.SymbolConfiguration(pointSize: fontSize, weight: .regular)
        return UIBarButtonItem(image: UIImage(systemName: "doc.on.clipboard")!.withConfiguration(configuration), style: .plain, target: self, action: #selector(pasteAction(_:)))
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
    
    @objc func hideKeyboard() {
        // if (onScreenKeyboardVisible != nil) && (!onScreenKeyboardVisible!) { return }
        DispatchQueue.main.async {
            guard self.webView != nil else { return }
            self.webView!.endEditing(true)
            self.webView!.keyboardDisplayRequiresUserAction = true
        }
    }
    
    @objc func hideToolbar() {
        DispatchQueue.main.async {
            showToolbar = false
            self.webView!.addInputAccessoryView(toolbar: self.emptyToolbar)
            if (useSystemToolbar) {
                self.webView!.inputAssistantItem.leadingBarButtonGroups = []
                self.webView!.inputAssistantItem.trailingBarButtonGroups = []
            }
        }
    }

    @objc func showEditorToolbar() {
        DispatchQueue.main.async {
            if (useSystemToolbar) {
                showToolbar = false
                self.webView!.addInputAccessoryView(toolbar: self.emptyToolbar)
                self.webView!.inputAssistantItem.leadingBarButtonGroups =
                [UIBarButtonItemGroup(barButtonItems: [self.tabButton, self.controlButton, self.escapeButton, self.pasteButton], representativeItem: nil)]
                self.webView!.inputAssistantItem.trailingBarButtonGroups =
                [UIBarButtonItemGroup(barButtonItems: [self.upButton, self.downButton, self.leftButton, self.rightButton], representativeItem: nil)]
            } else {
                showToolbar = true
                self.webView!.addInputAccessoryView(toolbar: self.editorToolbar)
            }
        }
    }
    
    
    func continuousButtonAction(button: String)  {
        let ms: UInt32 = 1000
        if (button == "up") {
            while (continuousButtonAction) {
                webView?.evaluateJavaScript("window.term_.io.onVTKeystroke((!window.term_.keyboard.applicationCursor) ? '\\x1b[A' : '\\x1bOA');") { (result, error) in
                    // if let error = error { print(error) }
                    // if let result = result { print(result) }
                }
                usleep(250 * ms)
            }
        } else if (button == "down") {
            while (continuousButtonAction) {
                webView?.evaluateJavaScript("window.term_.io.onVTKeystroke((!window.term_.keyboard.applicationCursor) ? '\\x1b[B' : '\\x1bOB');") { (result, error) in
                    // if let error = error { print(error) }
                    // if let result = result { print(result) }
                }
                usleep(250 * ms)
            }
        }  else if (button == "left") {
            while (continuousButtonAction) {
                webView?.evaluateJavaScript("window.term_.io.onVTKeystroke((!window.term_.keyboard.applicationCursor) ? '\\x1b[D' : '\\x1bOD');") { (result, error) in
                    // if let error = error { print(error) }
                    // if let result = result { print(result) }
                }
                usleep(100 * ms)
            }
        }  else if (button == "right") {
            while (continuousButtonAction) {
                webView?.evaluateJavaScript("window.term_.io.onVTKeystroke((!window.term_.keyboard.applicationCursor) ? '\\x1b[C' : '\\x1bOC');") { (result, error) in
                    // if let error = error { print(error) }
                    // if let result = result { print(result) }
                }
                usleep(100 * ms)
            }
        }
    }
    
    @objc func longPressAction(_ sender: UILongPressGestureRecognizer) {
        // If up-down-left-right buttons are currently being pressed, activate multi-action arrows (instead of hide keyboard)
        // get the location of the press event:
        if (sender.state == .ended) {
            continuousButtonAction = false
            return
        }
        let location = sender.location(in: sender.view)
        // NSLog("long press detected: \(location)")
        // NSLog("sender of long press: \(sender)")
        if (sender.state == .began) {
            let toolbarUpButton = editorToolbar.items![5]
            if let upButtonView = toolbarUpButton.value(forKey: "view") as? UIView {
                if (location.x >= upButtonView.frame.minX) && (location.x <= upButtonView.frame.maxX) {
                    continuousButtonAction = true
                    commandQueue.async {
                        self.continuousButtonAction(button: "up")
                    }
                    return
                }
            }
            let toolbarDownButton = editorToolbar.items![6]
            if let downButtonView = toolbarDownButton.value(forKey: "view") as? UIView {
                if (location.x >= downButtonView.frame.minX) && (location.x <= downButtonView.frame.maxX) {
                    continuousButtonAction = true
                    commandQueue.async {
                        self.continuousButtonAction(button: "down")
                    }
                    return
                }
            }
            let toolbarLeftButton = editorToolbar.items![7]
            if let leftButtonView = toolbarLeftButton.value(forKey: "view") as? UIView {
                if (location.x >= leftButtonView.frame.minX) && (location.x <= leftButtonView.frame.maxX) {
                    continuousButtonAction = true
                    commandQueue.async {
                        self.continuousButtonAction(button: "left")
                    }
                    return
                }
            }
            let toolbarRightButton = editorToolbar.items![8]
            if let rightButtonView = toolbarRightButton.value(forKey: "view") as? UIView {
                if (location.x >= rightButtonView.frame.minX) && (location.x <= rightButtonView.frame.maxX) {
                    continuousButtonAction = true
                    commandQueue.async {
                        self.continuousButtonAction(button: "right")
                    }
                    return
                }
            }
        }
        if (continuousButtonAction) {
            return
        }
        // No buttons left, must be a hidekeyboard event:
        hideKeyboard()
    }
    
    public lazy var emptyToolbar: UIToolbar = {
        var toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        toolbar.tintColor = .label
        toolbar.items = []
        return toolbar
    }()


    // cutButton and copyButton exist, but make less sense than paste.
    // the paste command is difficult to create with long press.
    // Possible additions: undo/redo buttons
    public lazy var editorToolbar: UIToolbar = {
        var toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: (self.webView?.bounds.width)!, height: toolbarHeight))
        toolbar.tintColor = .label
        toolbar.items = [tabButton, controlButton, escapeButton, pasteButton,
                         UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: self, action: nil),
                         upButton, downButton, leftButton, rightButton]
        // Long press gesture recognsizer:
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(longPressAction(_:)))
        longPressGesture.minimumPressDuration = 1.0 // 1 second press
        longPressGesture.allowableMovement = 15 // 15 points
        longPressGesture.delegate = self
        toolbar.addGestureRecognizer(longPressGesture)
        return toolbar
    }()
    
    func parsePrompt() -> String {
        // Documentation from: https://www.cyberciti.biz/tips/howto-linux-unix-bash-shell-setup-prompt.html
        // Not implemented: \nnn (octal char), \[ \] (non-printing characters)
        // - get PS1 from environment:
        guard let promptC = getenv("PS1") else {
            return "$ "
        }
        guard let prompt = String(utf8String: promptC) else {
            return "$ "
        }
        // - parse PS1 (bash syntax) using a regexp:
        do {
            let regex = try NSRegularExpression(pattern: #"\\[]adDehHjlnrstT@AuvVwW!#$\[]"#, options: [])
            let matches = regex.matches(in: prompt, range: NSRange(prompt.startIndex..<prompt.endIndex, in: prompt))
            var offset = 0
            var newPrompt = ""
            for match in matches {
                var range = match.range
                newPrompt += prompt[prompt.index(prompt.startIndex, offsetBy:offset)..<prompt.index(prompt.startIndex, offsetBy: range.lowerBound)]
                let subString = prompt[prompt.index(prompt.startIndex, offsetBy:range.lowerBound)..<prompt.index(prompt.startIndex, offsetBy: range.upperBound)]
                // NSLog("Found: \(subString)")
                switch (subString) {
                    //aAdDehHjlnrstTuvVwW@! # $ [ ]
                case "\\a": // ASCII bell character (07)
                    newPrompt += "\u{0007}"
                    break
                case "\\A": // current time in 24-hour HH:MM format
                    let format = DateFormatter()
                    format.dateFormat = "HH:mm"
                    newPrompt += format.string(from: Date())
                    break
                case "\\d": // the date in “Weekday Month Date” format (e.g., “Tue May 26”)
                    let format = DateFormatter()
                    format.dateFormat = "E MMM d"
                    newPrompt += format.string(from: Date())
                    break
                case "\\D": // \D{format} : the format is passed to strftime(3) and the result is inserted into the prompt string; an empty format results in a locale-specific time representation. The braces are required
                    var formatStringParse = prompt[prompt.index(prompt.startIndex, offsetBy:range.upperBound)..<prompt.endIndex]
                    if (formatStringParse.hasPrefix("{")) {
                        formatStringParse.removeFirst()
                        if let formatString = formatStringParse.split(separator: "}").first {
                            let maxSize: UInt = 256
                            var buffer: [CChar] = [CChar](repeating: 0, count: Int(maxSize))
                            var time: time_t = Int(NSDate().timeIntervalSince1970)
                            _ = strftime(&buffer, Int(maxSize), String(formatString).toCString(), localtime(&time))
                            newPrompt += String(cString: buffer)
                            // Advance to after "}":
                            range = NSRange(prompt.range(of: "}", options: [], range: (prompt.index(prompt.startIndex, offsetBy:range.upperBound)..<prompt.endIndex))!, in: prompt)
                        }
                    }
                    break
                case "\\e": // escape character
                    newPrompt += escape
                    break
                    // hHjlnrstTuvVwW@! # $
                case "\\h", "\\H": // the hostname up to the first ‘.’ or the hostname
                    // No easy access to hostname, we print the device name:
                    newPrompt += UIDevice.current.name
                    break
                case "\\j": // the number of jobs currently managed by the shell
                    newPrompt += "0" // no job management
                    break
                case "\\l": // the basename of the shell's terminal device name
                    newPrompt += UIDevice.current.localizedModel
                    break
                case "\\n", "\\r": // newline, carriage return
                    newPrompt += subString
                    break
                case "\\s": // the name of the shell, the basename of $0 (the portion following the final slash)
                    if let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String {
                        newPrompt += appName
                    } else {
                        newPrompt += "a-Shell"
                    }
                    break
                case "\\t": // the current time in 24-hour HH:MM:SS format
                    let format = DateFormatter()
                    format.dateFormat = "HH:mm:ss"
                    newPrompt += format.string(from: Date())
                    break
                case "\\T": // the current time in 12-hour HH:MM:SS format
                    let format = DateFormatter()
                    format.dateFormat = "h:mm:ss"
                    newPrompt += format.string(from: Date())
                    break
                case "\\u": // username
                    if let pw = getpwuid((getuid())) {
                        if let username = pw.pointee.pw_name {
                            newPrompt += String(utf8String: username) ?? "mobile"
                            break;
                        }
                    }
                    newPrompt += "mobile"
                    break;
                case "\\v": //  the version of bash (e.g., 2.00)
                    if let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                        newPrompt += currentVersion
                    }
                    break
                case "\\V": // the release of bash, version + patch level (e.g., 2.00.0)
                    if let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                        newPrompt += currentVersion
                        if let currentBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                            newPrompt += " " + currentBuild
                        }
                    }
                    break
                case "\\w": // the current working directory, with $HOME abbreviated with a tilde
                    let currentDirectory = FileManager().currentDirectoryPath
                    let path = String(cString: ios_getBookmarkedVersion(currentDirectory.utf8CString))
                    newPrompt += path
                    break
                case "\\W": // the basename of the current working directory, with $HOME abbreviated with a tilde
                    let currentDirectory = FileManager().currentDirectoryPath
                    let path = String(cString: ios_getBookmarkedVersion(currentDirectory.utf8CString))
                    let pathComponents = path.split(separator: "/")
                    if (pathComponents.count > 1) {
                        newPrompt += pathComponents[pathComponents.endIndex - 1]
                    } else {
                        newPrompt += path
                    }
                    break
                case "\\@": // the current time in 12-hour am/pm format
                    let format = DateFormatter()
                    format.dateFormat = "h:mm a"
                    newPrompt += format.string(from: Date())
                    break
                case "\\!", "\\#": //  the history number of this command or the command number of this command
                    newPrompt += String(history.count)
                    break
                case "\\$": // if the effective UID is 0, a #, otherwise a $
                    newPrompt += "$"
                    break
                case "\\[", "\\]": // supposed to encase zero-length characters. Not needed for a-Shell.
                    break
                case "\\0", "\\1", "\\2", "\\3", "\\4", "\\5", "\\6", "\\7", "\\8", "\\9": // \nnn: unicode character
                    newPrompt += "\\u\\{"
                    newPrompt += prompt[prompt.index(prompt.startIndex, offsetBy:range.lowerBound + 1)..<prompt.index(prompt.startIndex, offsetBy: range.upperBound + 2)]
                    newPrompt += "\\}"
                    let newRange = prompt.index(prompt.startIndex, offsetBy:range.lowerBound)..<prompt.index(prompt.startIndex, offsetBy: range.upperBound+2)
                    range = NSRange(newRange, in: prompt)
                    break
                default:
                    newPrompt += subString
                }
                offset = range.upperBound
                // NSLog("Edited prompt: \(newPrompt) offset: \(offset)")
            }
            newPrompt += prompt[prompt.index(prompt.startIndex, offsetBy:offset)..<prompt.index(prompt.endIndex, offsetBy: 0)]
            return newPrompt
        }
        catch {
            NSLog("Failed regexp creation")
        }
        return "$ "
    }
    
    func printPrompt() {
        // - set promptstring in JS
        // - have window.printPrompt() use promptString
        DispatchQueue.main.async {
            self.webView?.evaluateJavaScript("window.commandRunning = ''; window.promptMessage='\(self.parsePrompt())'; window.printPrompt(); window.updatePromptPosition();") { (result, error) in
                if let error = error {
                    NSLog("Error in executing window.commandRunning = ''; = \(error)")
                }
                if let result = result {
                    NSLog("Result of executing window.commandRunning = ''; = \(result)")
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
        let deviceModel = UIDevice.current.model
        if (deviceModel.hasPrefix("iPad")) {
            UIApplication.shared.requestSceneSessionDestruction(self.windowScene!.session, options: nil)
        }
    }
    
    func clearScreen() {
        DispatchQueue.main.async {
            // clear entire display: ^[[2J
            // position cursor on top line: ^[[1;1H 
            self.webView?.evaluateJavaScript("window.term_.io.print('" + self.escape + "[2J'); window.term_.io.print('" + self.escape + "[1;1H'); ") { (result, error) in
                // if let error = error { print(error) }
                // if let result = result { print(result) }
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
        var environmentAsJSDictionary = "{"
        if let localEnvironment = environmentAsArray() {
            for variable in localEnvironment {
                if let envVar = variable as? String {
                    // Let's not carry environment variables with quotes:
                    if (envVar.contains("\"")) {
                        continue
                    }
                    let components = envVar.components(separatedBy:"=")
                    if (components.count == 0) {
                        continue
                    }
                    let name = components[0]
                    var value = envVar
                    value.removeFirst(name.count + 1)
                    value = value.replacingOccurrences(of: "\\", with: "\\\\")
                    environmentAsJSDictionary += "\"" + name + "\"" + ":" + "\"" + value + "\",\n"
                }
            }
        }
        environmentAsJSDictionary += "}"
        let base64string = buffer.base64EncodedString()
        let javascript = "executeWebAssembly(\"\(base64string)\", " + argumentString + ", \"" + currentDirectory + "\", \(ios_isatty(STDIN_FILENO)), " + environmentAsJSDictionary + ")"
        if (javascriptRunning) {
            fputs("We can't execute webAssembly while we are already executing webAssembly.", thread_stderr)
            return -1
        }
        javascriptRunning = true
        var errorCode:Int32 = 0
        thread_stdin_copy = thread_stdin
        thread_stdout_copy = thread_stdout
        thread_stderr_copy = thread_stderr
        stdinString = "" // reinitialize stdin
        DispatchQueue.main.async {
            self.wasmWebView?.evaluateJavaScript(javascript) { (result, error) in
                if let error = error {
                    let userInfo = (error as NSError).userInfo
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
                if let result = result {
                    // executeWebAssembly sends back stdout and stderr as two Strings:
                    if let array = result as? NSMutableArray {
                        if let code = array[0] as? Int32 {
                            // return value from program
                            errorCode = code
                        }
                        if let errorMessage = array[1] as? String {
                            // webAssembly compile error:
                            fputs(errorMessage, self.thread_stderr_copy);
                        }
                    } else if let string = result as? String {
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
        if (thread_stdin_copy == nil) {
            // Strangely, the letters typed after ^D do not appear on screen. We force two carriage return to get the prompt visible:
            webView?.evaluateJavaScript("window.term_.io.onVTKeystroke(\"\\n\\n\"); window.term_.io.currentCommand = '';") { (result, error) in
                // if let error = error { print(error) }
                // if let result = result { print(result) }
            }
        }
        // Do not close thread_stdin because if it's a pipe, processes could still be writing into it
        // fclose(thread_stdin)
        
        thread_stdin_copy = nil
        thread_stdout_copy = nil
        thread_stderr_copy = nil
        return errorCode
    }
    
    func printJscUsage() {
        fputs("Usage: jsc [--in-window] file.js\nExecutes file.js.\n--in-window: runs inside the main window (can change terminal appearance or behaviour; use with caution).\n", thread_stdout)
    }
    
    func executeJavascript(arguments: [String]?) {
        guard (arguments != nil) else {
            printJscUsage()
            return
        }
        guard ((arguments!.count <= 3) && (arguments!.count > 1)) else {
            printJscUsage()
            return
        }
        var command = arguments![1]
        var jscWebView = wasmWebView
        if (arguments!.count == 3) {
            if (arguments![1] == "--in-window") {
                command = arguments![2]
                jscWebView = webView
            } else {
                printJscUsage()
                return
            }
        }
        // let fileName = FileManager().currentDirectoryPath + "/" + command
        let fileName = command.hasPrefix("/") ? command : currentDirectory + "/" + command
        thread_stdin_copy = thread_stdin
        thread_stdout_copy = thread_stdout
        thread_stderr_copy = thread_stderr
        if (javascriptRunning) {
            fputs("We can't execute JavaScript from a script already running JavaScript.", thread_stderr)
            return
        }
        javascriptRunning = true
        do {
            let javascript = try String(contentsOf: URL(fileURLWithPath: fileName), encoding: String.Encoding.utf8)
            DispatchQueue.main.async {
                jscWebView?.evaluateJavaScript(javascript) { (result, error) in
                    if let error = error {
                        // Extract information about *where* the error is, etc.
                        let userInfo = (error as NSError).userInfo
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
                    if let result = result {
                        if let string = result as? String {
                            fputs(string, self.thread_stdout_copy)
                            fputs("\n", self.thread_stdout_copy)
                        }  else if let number = result as? Int32 {
                            fputs("\(number)", self.thread_stdout_copy)
                            fputs("\n", self.thread_stdout_copy)
                        } else if let number = result as? Float {
                            fputs("\(number)", self.thread_stdout_copy)
                            fputs("\n", self.thread_stdout_copy)
                        } else {
                            fputs("\(result)", self.thread_stdout_copy)
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
        thread_stdin_copy = nil
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
        if (terminalCursorShape == nil) {
            fputs(factoryCursorShape.lowercased(), thread_stdout)
        } else {
            fputs(terminalCursorShape?.lowercased(), thread_stdout)
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
        let cursorShape = terminalCursorShape ?? factoryCursorShape
        // Force writing all config to term. Used when we changed many parameters.
        var command = "window.term_.setForegroundColor('" + foregroundColor.toHexString() + "'); window.term_.setBackgroundColor('" + backgroundColor.toHexString() + "'); window.term_.setCursorColor('" + cursorColor.toHexString() + "'); window.term_.setFontSize(\(fontSize)); window.term_.setFontFamily('\(fontName)'); window.term_.setCursorShape('\(cursorShape)');"
        DispatchQueue.main.async {
            self.webView?.evaluateJavaScript(command) { (result, error) in
                // if let error = error {
                //     print(error)
                // }
                // if let result = result {
                //     print(result)
                // }
            }
            command = "window.term_.prefs_.setSync('foreground-color', '" + foregroundColor.toHexString() + "'); window.term_.prefs_.setSync('background-color', '" + backgroundColor.toHexString() + "'); window.term_.prefs_.setSync('cursor-color', '" + cursorColor.toHexString() + "'); window.term_.prefs_.setSync('font-size', '\(fontSize)'); window.term_.prefs_.setSync('font-family', '\(fontName)'); window.term_.prefs_.setSync('cursor-shape', '\(cursorShape)');"
            self.webView?.evaluateJavaScript(command) { (result, error) in
                // if let error = error {
                //     print(error)
                // }
                // if let result = result {
                //     print(result)
                // }
            }
        }
    }
    
    func configWindow(fontSize: Float?, fontName: String?, backgroundColor: UIColor?, foregroundColor: UIColor?, cursorColor: UIColor?, cursorShape: String?) {
        if (fontSize != nil) {
            terminalFontSize = fontSize
            let fontSizeCommand = "window.term_.setFontSize(\(fontSize!));"
            DispatchQueue.main.async {
                self.webView?.evaluateJavaScript(fontSizeCommand) { (result, error) in
                    // if let error = error { print(error) }
                    // if let result = result { print(result) }
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
                        // if let error = error { print(error) }
                        // if let result = result { print(result) }
                    }
                }
            } else {
                // local fonts, defined by a file:
                // Currently does not work.
                let localFontURL = URL(fileURLWithPath: terminalFontName!)
                var localFontName = localFontURL.lastPathComponent
                localFontName.removeLast(".ttf".count)
                // NSLog("Local Font Name: \(localFontName)")
                DispatchQueue.main.async {
                    let fontNameCommand = "var newStyle = document.createElement('style'); newStyle.appendChild(document.createTextNode(\"@font-face { font-family: '\(localFontName)' ; src: url('\(localFontURL.path)') format('truetype'); }\")); document.head.appendChild(newStyle); window.term_.setFontFamily(\"\(localFontName)\");"
                    // NSLog(fontNameCommand)
                    self.webView?.evaluateJavaScript(fontNameCommand) { (result, error) in
                        // if let error = error { print(error) }
                        // if let result = result { print(result) }
                    }
                }
            }
        }
        if (backgroundColor != nil) {
            terminalBackgroundColor = backgroundColor
            let terminalColorCommand = "window.term_.setBackgroundColor(\"\(backgroundColor!.toHexString())\");"
            DispatchQueue.main.async {
                self.webView?.backgroundColor = backgroundColor
                self.webView?.evaluateJavaScript(terminalColorCommand) { (result, error) in
                    // if let error = error { print(error) }
                    // if let result = result { print(result) }
                }
            }
        }
        if (foregroundColor != nil) {
            terminalForegroundColor = foregroundColor
            let terminalColorCommand = "window.term_.setForegroundColor(\"\(foregroundColor!.toHexString())\");"
            DispatchQueue.main.async {
                self.webView?.tintColor = foregroundColor
                self.webView?.evaluateJavaScript(terminalColorCommand) { (result, error) in
                    // if let error = error { print(error) }
                    // if let result = result { print(result) }
                }
            }
        }
        if (cursorColor != nil) {
            terminalCursorColor = cursorColor
            let terminalColorCommand = "window.term_.setCursorColor(\"\(cursorColor!.toHexString())\");"
            DispatchQueue.main.async {
                self.webView?.evaluateJavaScript(terminalColorCommand) { (result, error) in
                    // if let error = error { print(error) }
                    // if let result = result { print(result) }
                }
            }
        }
        if (cursorShape != nil) {
            terminalCursorShape = cursorShape
            let terminalColorCommand = "window.term_.setCursorShape(\"\(cursorShape!)\");"
            DispatchQueue.main.async {
                self.webView?.evaluateJavaScript(terminalColorCommand) { (result, error) in
                    // if let error = error { print(error) }
                    // if let result = result { print(result) }
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
        // Wait until fontPicker is dismissed or a font has been selected:
        while (!fontPicker.isBeingDismissed && (selectedFont == "")) { }
        // NSLog("Dismissed. selectedFont= \(selectedFont)")
        DispatchQueue.main.sync {
            fontPicker.dismiss(animated:true)
        }
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
        // Set the initial directory (it doesn't work, so it's commented)
        // documentPicker.directoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
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
    
    func play_media(arguments: [String]?) -> Int32 {
        guard (arguments != nil) else { return -1 }
        guard (arguments!.count >= 2) else { return -1 } // There must be at least one file
        // copy arguments:
        let path = arguments![1]
        if (FileManager().fileExists(atPath: path)) {
            let url = URL(fileURLWithPath: path)
            // Create an AVPlayer, passing it the HTTP Live Streaming URL.
            avplayer = AVPlayer(url: url)
            
            // Create a new AVPlayerViewController and pass it a reference to the player.
            avcontroller = AVPlayerViewController()
            guard (avcontroller != nil) else {
                return -1
            }
            guard (avplayer != nil) else {
                return -1
            }
            avcontroller!.delegate = self
            avControllerPiPEnabled = false
            avplayer?.allowsExternalPlayback = true
            // Do we have a title?
            let asset = AVAsset(url: url)
            let metadata = asset.commonMetadata
            let titleID = AVMetadataIdentifier.commonIdentifierTitle
            let titleItems = AVMetadataItem.metadataItems(from: metadata,
                                                          filteredByIdentifier: titleID)
            if (titleItems.count == 0) {
                // No title present, let's use the file name:
                let titleMetadata = AVMutableMetadataItem()
                titleMetadata.identifier = AVMetadataIdentifier.commonIdentifierTitle
                titleMetadata.locale = NSLocale.current
                titleMetadata.value = arguments![1] as (NSCopying & NSObjectProtocol)?
                avplayer?.currentItem?.externalMetadata = [titleMetadata]
            }
            
            avcontroller!.player = avplayer
            
            // Modally present the player and call the player's play() method when complete.
            let rootVC = self.window?.rootViewController
            DispatchQueue.main.async {
                rootVC?.present(self.avcontroller!, animated: true) {
                    self.avplayer!.play()
                }
            }
            return 0
        } else {
            // File not found.
            if !path.hasPrefix("-") {
                fputs("play: file " + path + "not found\n", thread_stderr)
            }
            fputs("usage: play file\n", thread_stderr)
            return -1
        }
    }
    
    func preview(arguments: [String]?) -> Int32 {
        guard (arguments != nil) else { return -1 }
        guard (arguments!.count >= 2) else { return -1 } // There must be at least one command
        // copy arguments:
        let path = arguments![1]
        if (FileManager().fileExists(atPath: path)) {
        let url = URL(fileURLWithPath: path)
        let preview = UIDocumentInteractionController(url: url)
        preview.delegate = self
        DispatchQueue.main.async {
            preview.presentPreview(animated: true)
        }
        return 0
        } else {
            // File not found.
            if !path.hasPrefix("-") {
                fputs("view: file " + path + "not found\n", thread_stderr)
            }
            fputs("usage: view file\n", thread_stderr)
            return -1
        }
    }
    
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        let rootVC = self.window?.rootViewController
        if (rootVC == nil) {
            return self
        } else {
            return rootVC!
        }
    }
    
    // Even if Caps-Lock is activated, send lower case letters.
    @objc func insertKey(_ sender: UIKeyCommand) {
        guard (sender.input != nil) else { return }
        // This function only gets called if we are in a notebook, in edit_mode:
        // Only remap the keys if we are in a notebook, editing cell:
        webView?.evaluateJavaScript("window.term_.io.onVTKeystroke(\"" + sender.input! + "\");") { (result, error) in
            // if let error = error { print(error) }
            // if let result = result { print(result) }
        }
    }
    
    func executeCommand(command: String) {
        NSLog("executeCommand: \(command)")
        // There are 2 commands that are called directly, before going to ios_system(), because they need to.
        // We still allow them to be aliased.
        // We can't call exit through ios_system because it creates a new session
        // Also, we want to call it as soon as possible in case something went wrong
        let arguments = command.components(separatedBy: " ")
        let actualCommand = aliasedCommand(arguments[0])
        if (actualCommand == "exit") {
            closeWindow()
            // If we're here, closeWindow did not work. Clear window:
            // Calling "exit(0)" here results in a major crash (I tried).
            let infoCommand = "window.term_.wipeContents() ; window.printedContent = ''; window.term_.io.print('" + self.escape + "[2J'); window.term_.io.print('" + self.escape + "[1;1H'); window.commandArray = []; window.commandIndex = 0; window.maxCommandIndex = 0;"
            self.webView?.evaluateJavaScript(infoCommand) { (result, error) in
                // if let error = error {
                //     print(error)
                // }
                // if let result = result {
                //     print(result)
                // }
            }
            // Also clear history:
            history = []
            // Also reset directory:
            if (resetDirectoryAfterCommandTerminates != "") {
                // NSLog("Calling resetDirectoryAfterCommandTerminates in exit to \(resetDirectoryAfterCommandTerminates)")
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
        if (actualCommand == "newWindow") {
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
                let arguments = command.components(separatedBy: " ")
                let actualCommand = aliasedCommand(arguments[0])
                NSLog("Received command to execute: \(actualCommand)")
                if (actualCommand == "exit") {
                    self.closeWindow()
                    break // if "exit" didn't work, still don't execute the rest of the commands. 
                }
                if (actualCommand == "newWindow") {
                    self.executeCommand(command: command)
                    continue
                }
                self.currentCommand = command
                // If we received multiple commands (or if it's a shortcut), we need to inform the window if they are interactive:
                var commandForWindow = command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "'", with: "\\'").replacingOccurrences(of: "\n", with: "\\n")
                let windowCommand = "window.commandRunning = '\(commandForWindow)';window.interactiveCommandRunning = isInteractive('\(commandForWindow)');\n"
                DispatchQueue.main.async { // iOS 14 and 15: we need to communicate with the WkWebView in the main queue.
                    self.webView?.evaluateJavaScript(windowCommand) { (result, error) in
                        // if let error = error {
                        //     print(error)
                        // }
                        // if let result = result {
                        //     print(result)
                        // }
                    }
                }
                self.pid = ios_fork()
                DispatchQueue.main.async {
                    UIApplication.shared.isIdleTimerDisabled = true
                }
                ios_system(self.currentCommand)
                ios_waitpid(self.pid)
                ios_releaseThreadId(self.pid)
                DispatchQueue.main.async {
                    UIApplication.shared.isIdleTimerDisabled = false
                }
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
                let deviceModel = UIDevice.current.model
                if (deviceModel.hasPrefix("iPad")) {
                    let session = self.windowScene!.session
                    UIApplication.shared.requestSceneSessionDestruction(session, options: nil)
                }
            }
            // Did the command change the current directory?
            let newDirectory = FileManager().currentDirectoryPath
            if (newDirectory != self.currentDirectory) {
                self.previousDirectory = self.currentDirectory
                self.currentDirectory = newDirectory
            }
            // Did we set up a directory to restore at the end? (shortcuts do that)
            if (self.resetDirectoryAfterCommandTerminates != "") {
                // NSLog("Calling resetDirectoryAfterCommandTerminates to \(self.resetDirectoryAfterCommandTerminates)")
                if (!changeDirectory(path: self.resetDirectoryAfterCommandTerminates)) {
                    ios_switchSession(self.persistentIdentifier?.toCString())
                    ios_setContext(UnsafeMutableRawPointer(mutating: self.persistentIdentifier?.toCString()))
                    changeDirectory(path: self.resetDirectoryAfterCommandTerminates)
                }
                self.resetDirectoryAfterCommandTerminates = ""
            }
            self.currentCommand = ""
            self.pid = 0
            self.printPrompt();
        }
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let cmd:String = message.body as? String else {
            // NSLog("Could not convert Javascript message: \(message.body)")
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
            }
        } else if (cmd.hasPrefix("height:")) {
            var command = cmd
            command.removeFirst("height:".count)
            let newHeight = Int(command) ?? 80
            if (newHeight != height) {
                height = newHeight
                // NSLog("Calling ios_setWindowSize: \(width) x \(height)")
                ios_setWindowSize(Int32(width), Int32(height), self.persistentIdentifier?.toCString())
                setenv("LINES", "\(height)".toCString(), 1)
            }
        } else if (cmd.hasPrefix("controlOff")) {
            controlOn = false
            if #available(iOS 15.0, *) {
                if (!useSystemToolbar) {
                    editorToolbar.items?[1].isSelected = controlOn
                } else {
                    webView?.inputAssistantItem.leadingBarButtonGroups[0].barButtonItems[1].isSelected = controlOn
                }
            } else {
                let configuration = UIImage.SymbolConfiguration(pointSize: fontSize, weight: .regular, scale: .large)
                editorToolbar.items?[1].image = UIImage(systemName: "chevron.up.square")!.withConfiguration(configuration)
            }
        } else if (cmd.hasPrefix("input:")) {
            ios_switchSession(self.persistentIdentifier?.toCString())
            ios_setContext(UnsafeMutableRawPointer(mutating: self.persistentIdentifier?.toCString()));
            ios_setStreams(self.stdin_file, self.stdout_file, self.stdout_file)
            if (ios_activePager() != 0) { return }
            var command = cmd
            command.removeFirst("input:".count)
            // NSLog("Writing \(command) to stdin")
            // Because wasm is running asynchronously, we can have thread_stdin closed while wasm is still running
            if (javascriptRunning && (thread_stdin_copy != nil)) {
                stdinString += command
                return
            }
            guard let data = command.data(using: .utf8) else { return }
            if (command == endOfTransmission) {
                // There is a webAssembly command running, do not close stdin.
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
                    // NSLog("Could not close stdin input.")
                }
                stdin_file_input = nil
            } else if (command == interrupt) {
                // Calling ios_kill while executing webAssembly or JavaScript is a bad idea.
                // Do we have a way to interrupt JS execution in WkWebView?
                if (!javascriptRunning) {
                    ios_kill() // TODO: add printPrompt() here if no command running
                }
            } else {
                guard stdin_file_input != nil else { return }
                // TODO: don't send data if pipe already closed (^D followed by another key)
                // (store a variable that says the pipe has been closed)
                // NSLog("Writing (not interactive) \(command) to stdin")
                stdin_file_input?.write(data)
            }
        } else if (cmd.hasPrefix("inputInteractive:")) {
            ios_switchSession(self.persistentIdentifier?.toCString())
            ios_setContext(UnsafeMutableRawPointer(mutating: self.persistentIdentifier?.toCString()));
            ios_setStreams(self.stdin_file, self.stdout_file, self.stdout_file)
            if (ios_activePager() != 0) { return }
            // Interactive commands: just send the input to them. Allows Vim to map control-D to down half a page.
            var command = cmd
            command.removeFirst("inputInteractive:".count)
            guard let data = command.data(using: .utf8) else { return }
            guard stdin_file_input != nil else { return }
            // TODO: don't send data if pipe already closed (^D followed by another key)
            // (store a variable that says the pipe has been closed)
            // NSLog("Writing (interactive) \(command) to stdin")
            if (ios_activePager() == 0) {
                stdin_file_input?.write(data)
            }
        } else if (cmd.hasPrefix("inputTTY:")) {
            var command = cmd
            command.removeFirst("inputTTY:".count)
            // NSLog("Received (inputTTY) \(command)")
            guard let data = command.data(using: .utf8) else { return }
            guard tty_file_input != nil else { return }
            ios_switchSession(self.persistentIdentifier?.toCString())
            ios_setContext(UnsafeMutableRawPointer(mutating: self.persistentIdentifier?.toCString()))
            ios_setStreams(self.stdin_file, self.stdout_file, self.stdout_file)
            if (ios_activePager() != 0) {
                // Remove the string that we just sent from the command input
                // Sync issues: it could be executed before the string has been added to io.currentCommand
                webView?.evaluateJavaScript("window.term_.io.currentCommand = window.term_.io.currentCommand.substr(\(command.count));") { (result, error) in
                    // if let error = error { print(error) }
                    // if let result = result { print(result) }
                }
                tty_file_input?.write(data)
            }
        } else if (cmd.hasPrefix("listBookmarks:")) {
            let storedNamesDictionary = UserDefaults.standard.dictionary(forKey: "bookmarkNames") ?? [:]
            let sortedKeys = storedNamesDictionary.keys.sorted()
            var javascriptCommand = "fileList = [ \"~/\", "
            for key in sortedKeys {
                // print(filePath)
                // escape spaces, replace "\r" in filenames with "?"
                javascriptCommand += "\"~" + key.replacingOccurrences(of: " ", with: "\\ ") + "/\", "
            }
            // We need to re-escapce spaces for string comparison to work in JS:
            javascriptCommand += "]; lastDirectory = \"~bookmarkNames\"; updateFileMenu(); "
            // print(javascriptCommand)
            DispatchQueue.main.async {
                self.webView?.evaluateJavaScript(javascriptCommand) { (result, error) in
                    // if let error = error {
                    //     print(error)
                    // }
                    // if let result = result {
                    //     print(result)
                    // }
                }
            }
        } else if (cmd.hasPrefix("listDirectory:")) {
            var directory = cmd
            directory.removeFirst("listDirectory:".count)
            if (directory.count == 0) { return }
            do {
                ios_switchSession(self.persistentIdentifier?.toCString())
                ios_setContext(UnsafeMutableRawPointer(mutating: self.persistentIdentifier?.toCString()));
                // NSLog("about to list: \(directory)")
                var directoryForListing = directory
                let components = directoryForListing.components(separatedBy: "/")
                var name = components[0]
                if (name.hasPrefix("~")) {
                    // separate action between home directory ("~") and bookmarks ("~something"):
                    if (name.count == 1) {
                        directoryForListing.removeFirst("~".count)
                        let homeUrl = try! FileManager().url(for: .documentDirectory,
                                                             in: .userDomainMask,
                                                             appropriateFor: nil,
                                                             create: true).deletingLastPathComponent()
                        directoryForListing = homeUrl.path + "/" + directoryForListing
                    } else {
                        let storedNamesDictionary = UserDefaults.standard.dictionary(forKey: "bookmarkNames") ?? [:]
                        name.removeFirst("~".count)
                        if let bookmarkedDirectory = storedNamesDictionary[name] as? String {
                            directoryForListing.removeFirst(name.count + 1)
                            directoryForListing = bookmarkedDirectory + "/" + directoryForListing
                        }
                        NSLog("Listing a bookmark: \(directoryForListing): \(name)")
                    }
                } else if (name.hasPrefix("$")) {
                    name.removeFirst(1) // without the '$'
                    if let value = ios_getenv(name) {
                        directoryForListing.removeFirst(name.count + 1)
                        directoryForListing = String(cString: value) + "/" + directoryForListing
                    }
                }
                // NSLog("after parsing: \(directoryForListing)")
                var filePaths = try FileManager().contentsOfDirectory(atPath: directoryForListing.replacingOccurrences(of: "\\ ", with: " ")) // un-escape spaces
                filePaths.sort()
                var javascriptCommand = "fileList = ["
                for filePath in filePaths {
                    // print(filePath)
                    // escape spaces, replace "\r" in filenames with "?"
                    javascriptCommand += "\"" + filePath.replacingOccurrences(of: " ", with: "\\\\ ").replacingOccurrences(of: "\r", with: "?")
                    let fullPath = directoryForListing.replacingOccurrences(of: "\\ ", with: " ") + "/" + filePath
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
                        if let error = error { print(error) }
                        // if let result = result { print(result) }
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
        } else if (cmd.hasPrefix("reload:")) {
            // Reload the web page:
            self.webView?.reload()
        } else if (cmd.hasPrefix("resendConfiguration:")) {
            // For some reason the "window.foregroundColor = ..." in sceneDidBecomeActive did not stick.
            // We send it again (issue in iOS 15 beta 1)
            let backgroundColor = terminalBackgroundColor ?? UIColor.systemBackground.resolvedColor(with: traitCollection)
            let foregroundColor = terminalForegroundColor ?? UIColor.placeholderText.resolvedColor(with: traitCollection)
            let cursorColor = terminalCursorColor ?? UIColor.link.resolvedColor(with: traitCollection)
            // TODO: add font size and font name
            let fontSize = terminalFontSize ?? factoryFontSize
            let fontName = terminalFontName ?? factoryFontName
            let cursorShape = terminalCursorShape ?? factoryCursorShape
            var command = "window.foregroundColor = '" + foregroundColor.toHexString() + "'; window.backgroundColor = '" + backgroundColor.toHexString() + "'; window.cursorColor = '" + cursorColor.toHexString() + "'; window.cursorShape = '\(cursorShape)'; window.fontSize = '\(fontSize)' ; window.fontFamily = '\(fontName)';"
            // NSLog("resendConfiguration, command=\(command)")
            self.webView!.evaluateJavaScript(command) { (result, error) in
                if let error = error {
                    NSLog("Error in resendConfiguration, line = \(command)")
                    // print(error)
                }
                if result != nil {
                    // NSLog("Return from resendConfiguration, line = \(command)")
                    // print(result)
                }
            }
            command = "window.term_.setForegroundColor('" + foregroundColor.toHexString() + "'); window.term_.setBackgroundColor('" + backgroundColor.toHexString() + "'); window.term_.setCursorColor('" + cursorColor.toHexString() + "'); window.term_.setCursorShape('\(cursorShape)'); window.term_.setFontSize(\(fontSize)); window.term_.setFontFamily('\(fontName)');"
            self.webView!.evaluateJavaScript(command) { (result, error) in
                if let error = error {
                    NSLog("Error in resendConfiguration, line = \(command)")
                    // print(error)
                }
                if result != nil {
                    // NSLog("Return from resendConfiguration, line = \(command)")
                    // print(result)
                }
            }
            command = "window.term_.prefs_.setSync('foreground-color', '" + foregroundColor.toHexString() + "'); window.term_.prefs_.setSync('background-color', '" + backgroundColor.toHexString() + "'); window.term_.prefs_.setSync('cursor-color', '" + cursorColor.toHexString() + "'); window.term_.prefs_.setSync('font-size', '\(fontSize)'); window.term_.prefs_.setSync('font-family', '\(fontName)');  window.term_.scrollPort_.isScrolledEnd = true;"
            self.webView!.evaluateJavaScript(command) { (result, error) in
                if let error = error {
                    NSLog("Error in resendConfiguration, line = \(command)")
                    // print(error)
                }
                if result != nil {
                    // NSLog("Return from resendConfiguration, line = \(command)")
                    // print(result)
                }
            }
            // also initialize command list for autocomplete:
            guard var commandsArray = commandsAsArray() as! [String]? else { return }
            // Also scan PATH for executable files:
            let executablePath = String(cString: getenv("PATH"))
            // NSLog("\(executablePath)")
            for directory in executablePath.components(separatedBy: ":") {
                if (directory == "") {
                    continue
                }
                do {
                    // We don't check for exec status, because files inside $APPDIR have no x bit set.
                    for file in try FileManager().contentsOfDirectory(atPath: directory) {
                        let newCommand = URL(fileURLWithPath: file).lastPathComponent
                        // Do not add a command if it is already present:
                        if (!commandsArray.contains(newCommand)) {
                            commandsArray.append(newCommand)
                        }
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
                if let error = error {
                    NSLog("Error in creating command list, line = \(javascriptCommand)")
                    // print(error)
                }
                // if let result = result { print(result) }
            }
        } else if (cmd.hasPrefix("resendCommand:")) {
            if (shortcutCommandReceived != nil) {
                NSLog("resendCommand for Shortcut, command=\(shortcutCommandReceived!)")
                executeCommand(command: shortcutCommandReceived!)
                shortcutCommandReceived = nil
            } else {
                // Q: need to wait until configuration files are loaded?
                // window.printedContent = '\(windowPrintedContent.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\r", with: "\\r").replacingOccurrences(of: "\n", with: "\\n\\r"))';
                // print("PrintedContent to be restored: \(windowPrintedContent.count)")
                // print(windowPrintedContent.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\r", with: "\\r").replacingOccurrences(of: "\n", with: "\\n\\r"))
                let command = "window.promptMessage = '\(self.parsePrompt())'; \(windowHistory)  window.printedContent = \"\(windowPrintedContent.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\r", with: "\\r").replacingOccurrences(of: "\n", with: "\\n\\r"))\"; window.commandRunning = '\(currentCommand)'; window.interactiveCommandRunning = isInteractive(window.commandRunning); if (window.commandRunning == '') { if (window.printedContent != '') { window.term_.io.print(window.printedContent); } else { window.printPrompt(); } updatePromptPosition(); } else { window.printedContent= ''; }"
                NSLog("resendCommand, command=\(command)")
                self.webView!.evaluateJavaScript(command) { (result, error) in
                    if let error = error {
                        NSLog("Error in resendCommand, line = \(command)")
                        // print(error)
                    }
                    if let result = result {
                        NSLog("Return from resendCommand, line = \(command)")
                        // print(result)
                    }
                }
            }
        } else if (cmd.hasPrefix("setFontSize:")) {
            var size = cmd
            size.removeFirst("setFontSize:".count)
            if let sizeFloat = Float(size) {
                NSLog("Setting size to \(sizeFloat)")
                terminalFontSize = sizeFloat
            }
        }/* else if (cmd.hasPrefix("JS Error:")) {
            // When debugging JS, output warning/error messages to a file.
            let file = "jsError.txt"
            if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let logFile = dir.appendingPathComponent(file)
                guard let data = cmd.data(using: String.Encoding.utf8) else { return }
                if FileManager.default.fileExists(atPath: logFile.path) {
                    if let fileHandle = try? FileHandle(forWritingTo: logFile) {
                        fileHandle.seekToEndOfFile()
                        fileHandle.write(data)
                        fileHandle.closeFile()
                    }
                } else {
                    do {
                        try cmd.write(to: logFile, atomically: false, encoding: .utf8)
                    }
                    catch {
                        NSLog("Error writing logfile jsError")
                    }
                }
            }
        } */ else {
            // Usually debugging information
            NSLog("JavaScript message: \(message.body)")
            // print("JavaScript message: \(message.body)")
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
            // NSLog("scene/continue, userActivity.userInfo = \(userActivity.userInfo)")
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
                    commandSent = commandSent.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "'", with: "\\'").replacingOccurrences(of: "\n", with: "\\n")
                    let restoreCommand = "window.term_.io.println(\"Executing Shortcut: \(commandSent.replacingOccurrences(of: "\\n", with: "\\n\\r"))\");\nwindow.webkit.messageHandlers.aShell.postMessage('shell:' + '\(commandSent)');\n"
                    self.webView?.evaluateJavaScript(restoreCommand) { (result, error) in
                        if let error = error {
                            // print(error)
                        }
                        if let result = result {
                            // print(result)
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
        // NSLog("Scene, willConnectTo session: \(connectionOptions)")
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
            // toolbar for everyone because inputAssistantItem does not look good with a-Shell.
            if (!toolbarShouldBeShown) {
                showToolbar = false
                self.webView!.addInputAccessoryView(toolbar: self.emptyToolbar)
            } else {
                if (useSystemToolbar) {
                    showToolbar = false // ???
                    self.webView!.inputAssistantItem.leadingBarButtonGroups =
                    [UIBarButtonItemGroup(barButtonItems: [tabButton, controlButton, escapeButton, pasteButton], representativeItem: nil)]
                    self.webView!.inputAssistantItem.trailingBarButtonGroups =
                    [UIBarButtonItemGroup(barButtonItems: [upButton, downButton, leftButton, rightButton], representativeItem: nil)]
                } else {
                    showToolbar = true
                    self.webView!.addInputAccessoryView(toolbar: self.editorToolbar)
                }
            }
            // We create a separate WkWebView for webAssembly:
            let config = WKWebViewConfiguration()
            config.preferences.javaScriptCanOpenWindowsAutomatically = true
            config.preferences.setValue(true as Bool, forKey: "allowFileAccessFromFileURLs")
            wasmWebView = WKWebView(frame: .zero, configuration: config)
            let wasmFilePath = Bundle.main.path(forResource: "wasm", ofType: "html")
            wasmWebView?.isOpaque = false
            wasmWebView?.loadFileURL(URL(fileURLWithPath: wasmFilePath!), allowingReadAccessTo: URL(fileURLWithPath: wasmFilePath!))
            wasmWebView?.configuration.userContentController = WKUserContentController()
            wasmWebView?.configuration.userContentController.add(self, name: "aShell")
            wasmWebView?.navigationDelegate = self
            wasmWebView?.uiDelegate = self;
            wasmWebView?.isAccessibilityElement = false
            // End separate WkWebView
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
            if let shape = UserDefaults.standard.value(forKey: "cursorShape") as? String {
                terminalCursorShape = shape
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
                        let newCommand = URL(fileURLWithPath: file).lastPathComponent
                        // Do not add a command if it is already present:
                        if (!commandsArray.contains(newCommand)) {
                            commandsArray.append(newCommand)
                        }
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
                    // NSLog("Error in creating command list, line = \(javascriptCommand)")
                    // print(error)
                }
                // if let result = result { print(result) }
            }
            // If .profile or .bashrc exist, load them:
            for configFileName in [".profile", ".bashrc"] {
                var configFileUrl = try! FileManager().url(for: .documentDirectory,
                                                           in: .userDomainMask,
                                                           appropriateFor: nil,
                                                           create: true)
                configFileUrl = configFileUrl.appendingPathComponent(configFileName)
                // A big issue is that, at this point, the window does not exist yet. So stdin, stdout, stderr also do not exist.
                if (FileManager().fileExists(atPath: configFileUrl.path)) {
                    // Avoid interference with C SDK creation by interpreting .profile in installQueue:
                    installQueue.async {
                        do {
                            let contentOfFile = try String(contentsOf: configFileUrl, encoding: String.Encoding.utf8)
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
                                executeCommandAndWait(command: trimmedCommand)
                                NSLog("Done executing command from .profile: \(command)")
                                NSLog("Current directory: \(FileManager().currentDirectoryPath)")
                                // If the .profile modified PATH, we respect its value:
                                appDependentPath = String(utf8String: getenv("PATH")) ?? ""
                                NSLog("new default path: \(appDependentPath)")
                            }
                        }
                        catch {
                            NSLog("Could not load .profile: \(error.localizedDescription)")
                        }
                    }
                }
            }
            // Was this window created with a purpose?
            // Case 1: url to open is inside urlContexts
            // NSLog("connectionOptions.urlContexts: \(connectionOptions.urlContexts.first)")
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
                        if var userInfo = scene.session.stateRestorationActivity?.userInfo {
                            NSLog("Passing the directory to sceneWillEnterForeground: \(fileURL.path)")
                            if (currentDirectory == "") {
                                currentDirectory = FileManager().currentDirectoryPath
                            }
                            userInfo["prev_wd"] = currentDirectory
                            userInfo["cwd"] = fileURL.path
                        } else {
                            NSLog("Calling changeDirectory: \(fileURL.path)")  // seldom called
                            installQueue.async {
                                changeDirectory(path: fileURL.path) // call cd_main and checks secured bookmarked URLs
                                self.closeAfterCommandTerminates = false
                            }
                        }
                    } else {
                        // Go through installQueue so that the command is launched *after* the .profile is executed
                        self.closeAfterCommandTerminates = true
                        // It's a file
                        // TODO: customize the command (vim, microemacs, python, clang, TeX?)
                        installQueue.async {
                            self.executeCommand(command: "vim " + (fileURL.path.removingPercentEncoding!.replacingOccurrences(of: " ", with: "\\ ")))
                        }
                    }
                } else if (fileURL.scheme == "ashell") {
                    NSLog("We received an URL: \(fileURL)") // received "ashell:ls"
                    // The window is not yet fully opened, so executeCommand might fail.
                    // We use installQueue to be called once the window is ready.
                    var command = fileURL.absoluteString
                    command.removeFirst("ashell:".count)
                    command = command.removingPercentEncoding!
                    closeAfterCommandTerminates = false
                    installQueue.async {
                        // Set the working directory to somewhere safe:
                        // (but do not reset afterwards, since this is a new window)
                        if let groupUrl = FileManager().containerURL(forSecurityApplicationGroupIdentifier:"group.AsheKube.a-Shell") {
                            changeDirectory(path: groupUrl.path)
                        }
                        self.executeCommand(command: command)
                    }
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
                    self.closeAfterCommandTerminates = true
                    window.makeKeyAndVisible() // We need it a 2nd time for keyboard to resize itself.
                    installQueue.async {
                        if let fileURL: NSURL = userActivity.userInfo!["url"] as? NSURL {
                            // NSLog("willConnectTo: \(fileURL.path!.replacingOccurrences(of: "%20", with: " "))")
                            self.executeCommand(command: "vim " + (fileURL.path!.removingPercentEncoding!.replacingOccurrences(of: " ", with: "\\ ")))
                        } else {
                            // NSLog("Empty URL -- using backup")
                            self.executeCommand(command: "vim " + ((inputFileURLBackup?.path.removingPercentEncoding!.replacingOccurrences(of: " ", with: "\\ "))!))
                            inputFileURLBackup = nil
                        }
                    }
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
                    // NSLog("Scene, willConnectTo: userActivity.userInfo = \(userActivity.userInfo)")
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
                            // We can't go through executeCommand because the window is not fully created yet.
                            // Same reason we can't print the shortcut that is about to be executed.
                            // installQueue will be called after the .profile has been processed.
                            if let groupUrl = FileManager().containerURL(forSecurityApplicationGroupIdentifier:"group.AsheKube.a-Shell") {
                                changeDirectory(path: groupUrl.path)
                                NSLog("groupUrl: " + groupUrl.path)
                            }
                            // We wait until the window is fully initialized. This will be used when "resendCommand:" is triggered, at the end of window setting.
                            shortcutCommandReceived = commandSent
                        }
                    }
                }
            }

           NotificationCenter.default
                .publisher(for: UIWindow.didBecomeKeyNotification, object: window)
                .merge(with: NotificationCenter.default
                        .publisher(for: UIResponder.keyboardWillShowNotification))
                .handleEvents(receiveOutput: { notification in
                    // NSLog("didBecomeKey: \(notification.name.rawValue): \(session.persistentIdentifier).")
                })
                .sink { _ in self.webView?.focus() }
                .store(in: &cancellables)
            NotificationCenter.default
                .publisher(for: UIWindow.didResignKeyNotification, object: window)
                .merge(with: NotificationCenter.default
                        .publisher(for: UIResponder.keyboardWillHideNotification))
                .handleEvents(receiveOutput: { notification in
                    // NSLog("didResignKey: \(notification.name.rawValue): \(session.persistentIdentifier).")
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
                if (UIDevice.current.model.hasPrefix("iPad")) {
                    // iPad, so always open a new window to execute the command
                    let activity = NSUserActivity(activityType: "AsheKube.app.a-Shell.ExecuteCommand")
                    activity.userInfo!["url"] = fileURL
                    // create a window and execute the command:
                    UIApplication.shared.requestSceneSessionActivation(nil, userActivity: activity, options: nil)
                } else {
                    // iPhone: create the command, send it to the window once it's created.
                    var command = fileURL.absoluteString
                    command.removeFirst("ashell:".count)
                    command = command.removingPercentEncoding!
                    installQueue.async {
                        if let groupUrl = FileManager().containerURL(forSecurityApplicationGroupIdentifier:"group.AsheKube.a-Shell") {
                            changeDirectory(path: groupUrl.path)
                        }
                        self.executeCommand(command: command)
                    }
                }
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
                if (UIDevice.current.model.hasPrefix("iPad")) {
                    let activity = NSUserActivity(activityType: "AsheKube.app.a-Shell.OpenDirectory")
                    activity.userInfo!["url"] = fileURL
                    UIApplication.shared.requestSceneSessionActivation(nil, userActivity: activity, options: nil)
                } else {
                    // sceneWillEnterForeground will be called soon, will call cwd.
                    if var userInfo = scene.session.stateRestorationActivity?.userInfo {
                        NSLog("Passing the directory to sceneWillEnterForeground: \(fileURL.path)")
                        if (currentDirectory == "") {
                            currentDirectory = FileManager().currentDirectoryPath
                        }
                        userInfo["prev_wd"] = currentDirectory
                        userInfo["cwd"] = fileURL.path
                    } else {
                        NSLog("Calling changeDirectory: \(fileURL.path)")
                        installQueue.async {
                            changeDirectory(path: fileURL.path) // call cd_main and checks secured bookmarked URLs
                            self.closeAfterCommandTerminates = false
                        }
                    }
                }
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
                    if let data = command.data(using: .utf8) {
                        ios_switchSession(self.persistentIdentifier?.toCString())
                        ios_setContext(UnsafeMutableRawPointer(mutating: self.persistentIdentifier?.toCString()));
                        ios_setStreams(self.stdin_file, self.stdout_file, self.stdout_file)
                        if (stdin_file_input != nil) {
                            stdin_file_input?.write(data)
                            return
                        }
                    }
                }
                if (UIDevice.current.model.hasPrefix("iPad")) {
                    UIApplication.shared.requestSceneSessionActivation(nil, userActivity: activity, options: nil)
                } else {
                    // Not an iPad, so no requestSceneSessionActivation().
                    let openFileCommand = "window.commandRunning = 'vim'; window.interactiveCommandRunning = true; "
                    NSLog("About to execute \(openFileCommand), webview: \(self.webView)")
                    self.webView?.evaluateJavaScript(openFileCommand) { (result, error) in
                        // if let error = error { print(error) }
                        // if let result = result { print(result) }
                    }
                    installQueue.async {
                        self.executeCommand(command: "vim " + (fileURL.path.removingPercentEncoding!.replacingOccurrences(of: " ", with: "\\ ")))
                    }
                }
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
            } else if ((currentCommand == "sftp") || currentCommand.hasPrefix("sftp ")) {
                exitCommand = "\nquit"
            } else if ((currentCommand == "ed") || currentCommand.hasPrefix("ed ")) {
                exitCommand = "\n.\nwq" // Won't work if no filename provided. Then again, not much I can do.
            }
            if (exitCommand != "") {
                exitCommand += "\n"
                if let data = exitCommand.data(using: .utf8) {
                    ios_switchSession(self.persistentIdentifier?.toCString())
                    ios_setContext(UnsafeMutableRawPointer(mutating: self.persistentIdentifier?.toCString()));
                    ios_setStreams(self.stdin_file, self.stdout_file, self.stdout_file)
                    if (stdin_file_input != nil) {
                        stdin_file_input?.write(data)
                        return
                    }
                }
            } else {
                // NSLog("Un-recognized command: \(currentCommand)")
                // send sigquit to the command:
                if (self.pid != 0) {
                    ios_killpid(self.pid, SIGQUIT)
                }
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
        let cursorShape = terminalCursorShape ?? factoryCursorShape
        
        // Window.term_ does not always exist when sceneDidBecomeActive is called. We *also* set window.foregroundColor, and then use that when we create term.
        webView!.tintColor = foregroundColor
        webView!.backgroundColor = backgroundColor
        var command = "window.foregroundColor = '" + foregroundColor.toHexString() + "'; window.backgroundColor = '" + backgroundColor.toHexString() + "'; window.cursorColor = '" + cursorColor.toHexString() + "'; window.cursorShape = '\(cursorShape)'; window.fontSize = '\(fontSize)' ; window.fontFamily = '\(fontName)';"
        webView!.evaluateJavaScript(command) { (result, error) in
            if error != nil {
                // NSLog("Error in sceneDidBecomeActive, line = \(command)")
                // print(error)
            }
            if result != nil {
                // NSLog("Return from sceneDidBecomeActive, line = \(command)")
                // print(result)
            }
        }
        // Current status: window.term_ is undefined here in iOS 15b1.
        command = "(window.term_ != undefined)"
        webView!.evaluateJavaScript(command) { (result, error) in
            // if let error = error { print(error) }
            if let resultN = result as? Int {
                if (resultN == 1) {
                    // window.term_ exists, let's send commands:
                    command = "window.term_.setForegroundColor('" + foregroundColor.toHexString() + "'); window.term_.setBackgroundColor('" + backgroundColor.toHexString() + "'); window.term_.setCursorColor('" + cursorColor.toHexString() + "'); window.term_.setCursorShape('\(cursorShape)');window.term_.setFontSize(\(fontSize)); window.term_.setFontFamily('\(fontName)');"
                    self.webView!.evaluateJavaScript(command) { (result, error) in
                        if error != nil {
                            // NSLog("Error in sceneDidBecomeActive, line = \(command)")
                            // print(error)
                        }
                        if result != nil {
                            // NSLog("Return from sceneDidBecomeActive, line = \(command)")
                            // print(result)
                        }
                    }
                    command = "window.term_.prefs_.setSync('foreground-color', '" + foregroundColor.toHexString() + "'); window.term_.prefs_.setSync('background-color', '" + backgroundColor.toHexString() + "'); window.term_.prefs_.setSync('cursor-color', '" + cursorColor.toHexString() + "'); window.term_.prefs_.setSync('cursor-shape', '\(cursorShape)'); window.term_.prefs_.setSync('font-size', '\(fontSize)'); window.term_.prefs_.setSync('font-family', '\(fontName)');  window.term_.scrollPort_.isScrolledEnd = true;"
                    self.webView!.evaluateJavaScript(command) { (result, error) in
                        if error != nil {
                            // NSLog("Error in sceneDidBecomeActive, line = \(command)")
                            // print(error)
                        }
                        if result != nil {
                            // NSLog("Return from sceneDidBecomeActive, line = \(command)")
                            // print(result)
                        }
                    }
                }
            }
        }
        setEnvironmentFGBG(foregroundColor: foregroundColor, backgroundColor: backgroundColor)
        if (showKeyboardAtStartup) {
            webView!.keyboardDisplayRequiresUserAction = false
        }
        activateVoiceOver(value: UIAccessibility.isVoiceOverRunning)
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
        // Do not restore if a command is already running.
        if (userActivity?.activityType == "AsheKube.app.a-Shell.ExecuteCommand") { return }
        if (userActivity?.activityType == "AsheKube.app.a-Shell.EditDocument") { return }
        if (userActivity?.activityType == "AsheKube.app.a-Shell.OpenDirectory") { return }
        // Otherwise, go for it:
        NSLog("sceneWillEnterForeground: \(self.persistentIdentifier). userActivity: \(userActivity)")
        if (!toolbarShouldBeShown) {
            showToolbar = false
            self.webView!.addInputAccessoryView(toolbar: self.emptyToolbar)
        } else {
            if (useSystemToolbar) {
                showToolbar = false
                self.webView!.inputAssistantItem.leadingBarButtonGroups =
                [UIBarButtonItemGroup(barButtonItems: [tabButton, controlButton, escapeButton, pasteButton], representativeItem: nil)]
                self.webView!.inputAssistantItem.trailingBarButtonGroups =
                [UIBarButtonItemGroup(barButtonItems: [upButton, downButton, leftButton, rightButton], representativeItem: nil)]
            } else {
                showToolbar = true
                self.webView!.addInputAccessoryView(toolbar: self.editorToolbar)
            }
        }
        // If there is no userInfo and no stateRestorationActivity
        guard (scene.session.stateRestorationActivity != nil) else { return }
        guard let userInfo = scene.session.stateRestorationActivity!.userInfo else { return }
        // If a command is already running, we don't restore directories, etc: they probably are still valid
        if (currentCommand != "") { return }
        NSLog("Restoring history, previousDir, currentDir:")
        if let historyData = userInfo["history"] {
            history = historyData as! [String]
            // NSLog("set history to \(history)")
            windowHistory = "window.commandArray = ["
            for command in history {
                windowHistory += "\"" + command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\", "
            }
            windowHistory += "]; window.commandIndex = \(history.count); window.maxCommandIndex = \(history.count); "
            // webView!.evaluateJavaScript(javascriptCommand) { (result, error) in
            //     if error != nil {
            //         NSLog("Error in recreating history, line = \(javascriptCommand)")
            //         print(error)
            //     }
            //     if let result = result { print("Recreating history: \(result), line= \(javascriptCommand)") }
            // }
        }
        if let previousDirectoryData = userInfo["prev_wd"] {
            if let previousDirectory = previousDirectoryData as? String {
                NSLog("got previousDirectory as \(previousDirectory)")
                if (FileManager().fileExists(atPath: previousDirectory) && FileManager().isReadableFile(atPath: previousDirectory)) {
                    NSLog("set previousDirectory to \(previousDirectory)")
                    // Call cd_main instead of executeCommand("cd dir") to avoid closing a prompt and history.
                    ios_switchSession(self.persistentIdentifier?.toCString())
                    changeDirectory(path: previousDirectory) // call cd_main and checks secured bookmarked URLs
                }
            }
        }
        if let currentDirectoryData = userInfo["cwd"] {
            if var currentDirectory = currentDirectoryData as? String {
                NSLog("got currentDirectory as \(currentDirectory)")
                if (!FileManager().fileExists(atPath: currentDirectory) || !FileManager().isReadableFile(atPath: currentDirectory)) {
                    // The directory does not exist anymore (often home directory, changes after reinstall)
                    do {
                        currentDirectory = try FileManager().url(for: .documentDirectory,
                                                                 in: .userDomainMask,
                                                                 appropriateFor: nil,
                                                                 create: true).path
                        NSLog("reset currentDirectory to \(currentDirectory)")
                    }
                    catch {
                        NSLog("Could not get currentDirectory from FileManager()")
                    }
                }
                if (FileManager().fileExists(atPath: currentDirectory) && FileManager().isReadableFile(atPath: currentDirectory)) {
                    NSLog("set currentDirectory to \(currentDirectory)")
                    // Call cd_main instead of executeCommand("cd dir") to avoid closing a prompt and history.
                    ios_switchSession(self.persistentIdentifier?.toCString())
                    changeDirectory(path: currentDirectory) // call cd_main and checks secured bookmarked URLs
                }
            }
        }
        // We restore the environment variables to their previous values.
        // Useful for virtual Python environments
        // If the app was reinstalled, paths to files are not valid anymore, so we don't set them.
        // We never touch system environment variables like HOME and APPDIR.
        var path = String(utf8String: getenv( "PATH"))
        var pathChanged = false
        if let environmentVariables = userInfo["environ"] as? [String] {
            var virtualEnvironmentGone = false
            for variable in environmentVariables {
                let components = variable.split(separator:"=", maxSplits: 1)
                let name = String(components[0])
                let value = String(components[1])
                if name == "HOME" { continue }
                if name == "APPDIR" { continue }
                // Don't override PATH, MANPATH, PERL5LIB...
                // PATH itself will be dealt with separately
                if (value.hasPrefix("/") && (value.contains(":"))) { continue }
                // Don't override PERL_MB_OPT, PERL_MM_OPT, TERMINFO either:
                if name == "PERL_MB_OPT" { continue }
                if name == "PERL_MM_OPT" { continue }
                if name == "TERMINFO" { continue }
                if (name == "TERM") && (value == "dumb") { continue }
                // Env vars that are files:
                if (value.hasPrefix("/") && (!value.contains(":"))) {
                    // This variable might be a file or directory. Check it exists first:
                    if (!FileManager().fileExists(atPath: value)) {
                        // NSLog("Skipping \(name) = \(value) (not here)")
                        if (name == "VIRTUAL_ENV") {
                            // We had a virtual environment set, but pointing to a directory that no longer exists
                            // Since _OLD_VIRTUAL_PATH is usually before VIRTUAL_ENV in the list of variables,
                            // it has already been set by now. We set this boolean to erase it.
                            virtualEnvironmentGone = true
                        }
                        continue
                    }
                }
                // NSLog("setenv \(components[0]) \(components[1])")
                setenv(name, value, 1)
            }
            // The virtual environment is not in the right place anymore, get the PATH variable back to the correct value
            if (virtualEnvironmentGone) {
                unsetenv("_OLD_VIRTUAL_PATH")
            }
        }
        // Fix a specific bug introduced in 1.8.3:
        if let compileOptionsC = getenv("CCC_OVERRIDE_OPTIONS") {
            if let compileOptions = String(utf8String: compileOptionsC) {
                if (compileOptions.isEqual("#^--target")) {
                    setenv("CCC_OVERRIDE_OPTIONS", "#^--target=wasm32-wasi", 1)
                }
            }
        }
        // Only restore the parts of PATH that are not the main path (before and after),
        // and make sure that each directory exists.
        if let beforePath = userInfo["beforePath"] as? String {
            let components = beforePath.components(separatedBy: ":")
            var prefix:String = ""
            for dir in components {
                if (dir.count == 0) { continue } // empty string, can happen.
                if (prefix.contains(dir + ":")) { continue } // Don't add a directory more than once.
                if (FileManager().fileExists(atPath: dir)) {
                    prefix = prefix + dir + ":"
                }
            }
            if (prefix.count > 0) {
                if (path == nil) {
                    path = prefix
                } else {
                    path = prefix + path!
                }
                pathChanged = true
            }
        }
        if let afterPath = userInfo["afterPath"] as? String {
            let components = afterPath.components(separatedBy: ":")
            var suffix:String = ""
            for dir in components {
                // Don't add a string more than once:
                if (dir.count == 0) { continue } // empty string, can happen.
                if (suffix.isEqual(":" + dir)) { continue }
                if (suffix.contains(":" + dir + ":")) { continue }
                if (path != nil) {
                    if (path!.contains(dir + ":")) { continue } // Don't add a string that is already in path
                }
                if (FileManager().fileExists(atPath: dir)) {
                    suffix = suffix + ":" + dir
                }
            }
            if (suffix.count > 0) {
                if (path == nil) {
                    path = suffix
                } else {
                    if (!path!.hasSuffix(":") && !suffix.hasPrefix(":")) {
                        path = path! + ":" + suffix
                    } else {
                        if (path!.hasSuffix(":") && suffix.hasPrefix(":")) {
                            path!.removeLast()
                        }
                        path = path! + suffix
                    }
                }
                pathChanged = true
            }
        }
        if (pathChanged) {
            setenv("PATH", path, 1)
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
        if let cursorShape = userInfo["cursorShape"] as? String {
            terminalCursorShape = cursorShape
        }
        // Should we restore window content?
        if UserDefaults.standard.bool(forKey: "keep_content") {
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
                // print("printedContent restored = \(terminalData.count) End")
                webView!.evaluateJavaScript("window.setWindowContent",
                                            completionHandler: { (function: Any?, error: Error?) in
                    if (error != nil) || (function == nil) {
                        NSLog("function does not exist, set window.printedContent")
                        // resendCommend will print this on screen
                        self.windowPrintedContent = terminalData
                    } else {
                        // The function is defined, we are here *after* JS initialization:
                        NSLog("function does exist, calling window.setWindowContent")
                        let javascriptCommand = "window.promptMessage='\(self.parsePrompt())'; window.setWindowContent(\"" + terminalData.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\r", with: "\\r").replacingOccurrences(of: "\n", with: "\\n\\r") + "\");"
                        self.webView!.evaluateJavaScript(javascriptCommand) { (result, error) in
                            if error != nil {
                                NSLog("Error in resetting terminal w setWindowContent, line = \(javascriptCommand)")
                                // print(error)
                            }
                            // if let result = result { print(result) }
                        }
                    }
                })
            } else {
                // No terminal data stored, reset things:
                let javascriptCommand = "window.promptMessage='\(self.parsePrompt())'; window.printedContent = '';"
                webView!.evaluateJavaScript(javascriptCommand) { (result, error) in
                    if error != nil {
                        // NSLog("Error in setting terminal to empty, line = \(javascriptCommand)")
                        // print(error)
                    }
                    if result != nil {
                        // NSLog("Result in setting terminal to empty, line = \(javascriptCommand)")
                        // print(result)
                    }
                }
            }
        } else {
            // The user does not want the terminal to be restored:
            let javascriptCommand = "window.promptMessage='\(self.parsePrompt())'; window.printedContent = '';"
            webView!.evaluateJavaScript(javascriptCommand) { (result, error) in
                if error != nil {
                    // NSLog("Error in setting terminal to empty, line = \(javascriptCommand)")
                    // print(error)
                }
                if result != nil {
                    // NSLog("Result in setting terminal to empty, line = \(javascriptCommand)")
                    // print(result)
                }
            }
        }
        // restart the current command if one was running before
        let currentCommandData = userInfo["currentCommand"]
        if let storedCommand = currentCommandData as? String {
            if (storedCommand.count > 0) {
                // We only restart vim commands. Other commands are just creating issues, unless we could save their status.
                // Safety check: is the vim session file still there?
                // I could have been removed by the system, or by the user.
                // TODO: also check that files are still available / no
                if (storedCommand.hasPrefix("vim -S ")) {
                    // We counter it by restoring TERM before starting Vim:
                    if let storedTermC = getenv("TERM") {
                        if let storedTerm = String(utf8String: storedTermC) {
                            if storedTerm == "dumb" {
                                setenv("TERM", "xterm", 1)
                            }
                        }
                    }
                    NSLog("Restarting session with \(storedCommand)")
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
                    if (FileManager().fileExists(atPath: sessionFile)) {
                        if (UserDefaults.standard.bool(forKey: "restart_vim")) {
                            /* We only restart vim commands, and only if the user asks for it.
                             Everything else is creating problems.
                             Basically, we can only restart commands if we can save their status. */
                            // The preference is set to false by default, to avoid beginners trapped in Vim
                            NSLog("sceneWillEnterForeground, Restoring command: \(storedCommand)")
                            let commandSent = storedCommand.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "'", with: "\\'").replacingOccurrences(of: "\n", with: "\\n")
                            let restoreCommand = "window.webkit.messageHandlers.aShell.postMessage('shell:' + '\(commandSent)');\nwindow.commandRunning = '\(commandSent)';\n"
                            currentCommand = commandSent
                            NSLog("Calling command: \(restoreCommand)")
                            self.webView?.evaluateJavaScript(restoreCommand) { (result, error) in
                                // if let error = error { print(error) }
                                // if let result = result { print(result) }
                            }
                        }
                    } else {
                        NSLog("Could not find session file at \(sessionFile)")
                    }
                }
            }
        }
        if #available(iOS 16.0, *) {
            if (UIDevice.current.model.hasPrefix("iPad")) {
                // On iPadOS 16, windows going into the background and back to the foreground
                // sometimes change their font size. This tries to enforce it back:
                let fontSize = terminalFontSize ?? factoryFontSize
                let fontSizeCommand = "window.term_.setFontSize(\(fontSize));"
                DispatchQueue.main.async {
                    self.webView?.evaluateJavaScript(fontSizeCommand) { (result, error) in
                        if let error = error { print(error) }
                        if let result = result { print(result) }
                    }
                }
            }
        }
        // Re-enable video tracks when application enters foreground:
        // https://stackoverflow.com/questions/64055966/ios-14-play-audio-from-video-in-background/64753248#64753248
        // But only if picture-in-picture has not started
        if (!avControllerPiPEnabled) {
            if let tracks = avplayer?.currentItem?.tracks {
                for playerItemTrack in tracks
                {
                    if playerItemTrack.assetTrack!.hasMediaCharacteristic(AVMediaCharacteristic.visual)
                    {
                        // Re-enable the track.
                        playerItemTrack.isEnabled = true
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
        if (terminalCursorShape != nil) {
            scene.session.stateRestorationActivity?.userInfo!["cursorShape"] = terminalCursorShape!
        }
        scene.session.stateRestorationActivity?.userInfo!["currentCommand"] = currentCommand
        // save the environment variables:
        var env = [String]()
        var currentPath: String = ""
        var i = 0
        while (environ[i] != nil) {
            if let varValue = environ[i] {
                let varValue2 = String(cString: varValue)
                env.append(varValue2)
                if (varValue2.hasPrefix("PATH=")) {
                    currentPath = varValue2
                }
            }
            i += 1
        }
        scene.session.stateRestorationActivity?.userInfo!["environ"] = env
        //
        if (currentPath.count > "PATH=".count) {
            currentPath.removeFirst("PATH=".count)
            // NSLog("Path: \(currentPath)")
            let components = currentPath.components(separatedBy: appDependentPath)
            // NSLog("Components of Path: \(components)")
            if (components.count > 0) {
                scene.session.stateRestorationActivity?.userInfo!["beforePath"] = components[0]
            }
            if (components.count > 1) {
                scene.session.stateRestorationActivity?.userInfo!["afterPath"] = components[1]
            }
        }
        
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
                if let data = saveCommand.data(using: .utf8) {
                    ios_switchSession(self.persistentIdentifier?.toCString())
                    ios_setContext(UnsafeMutableRawPointer(mutating: self.persistentIdentifier?.toCString()));
                    ios_setStreams(self.stdin_file, self.stdout_file, self.stdout_file)
                    if (stdin_file_input != nil) {
                        stdin_file_input?.write(data)
                        return
                    }
                }
            }
        }
        // Get only the last 25000 characters of printedContent.
        // An iPad pro screen is 5000 characters, so this is 5 screens of content.
        // When window.printedContent is too large, this function does not return before the session is terminated.
        // Note: if this fails, check window.printedContent length at the start/end of a command, not after each print.
        // webView!.evaluateJavaScript("window.printedContent.substring(window.printedContent.length - 25000)",
        webView!.evaluateJavaScript("window.printedContent",
                                    completionHandler: { (printedContent: Any?, error: Error?) in
                                        if let error = error {
                                            NSLog("Error in capturing terminal content: \(error.localizedDescription)")
                                            // print(error)
                                        }
                                        if (printedContent != nil) {
                                            scene.session.stateRestorationActivity?.userInfo!["terminal"] = printedContent
                                            // print("printedContent saved: \(printedContent).")
                                        }
                                    })
        // Keep sound going when going in background, by disabling video tracks:
        // https://stackoverflow.com/questions/64055966/ios-14-play-audio-from-video-in-background/64753248#64753248
        // But only if Picture-in-Picture has not started
        if (!avControllerPiPEnabled) {
            if let tracks = avplayer?.currentItem?.tracks {
                for playerItemTrack in tracks
                {
                    if playerItemTrack.assetTrack!.hasMediaCharacteristic(AVMediaCharacteristic.visual)
                    {
                        // Disable the track.
                        playerItemTrack.isEnabled = false
                    }
                }
            }
        }
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
                if let error = error {
                    NSLog("Error in activateVoiceOver.")
                    // print(error)
                }
                // if let result = result { print(result) }
            }
        }
        let command2 = "if (window.term_ != undefined) { window.term_.setAccessibilityEnabled(window.voiceOver); }"
        // NSLog(command2)
        DispatchQueue.main.async {
            self.webView!.evaluateJavaScript(command2) { (result, error) in
                if let error = error {
                    NSLog("Error in activateVoiceOver.")
                    // print(error)
                }
                // if let result = result { print(result) }
            }
        }
    }
    
    private func outputToWebView(string: String) {
        guard (webView != nil) else { return }
        // Sanitize the output string to it can be sent to javascript:
        let parsedString = string.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\r", with: "\\r").replacingOccurrences(of: "\n", with: "\\n\\r")
        // iosNSLog("\(parsedString)")
        // This may cause several \r in a row
        let command = "window.term_.io.print(\"" + parsedString + "\");"
        DispatchQueue.main.async {
            self.webView!.evaluateJavaScript(command) { (result, error) in
                if let error = error {
                    NSLog("Error in print; offending line = \(parsedString), error = \(error)")
                    // print(error)
                }
                // if let result = result { print(result) }
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
            // NSLog("UTF8 string: \(string)")
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
    
extension SceneDelegate: AVPlayerViewControllerDelegate {
    func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController){
        NSLog("playerViewControllerWillStartPictureInPicture")
        avControllerPiPEnabled = true
    }
    
    func playerViewControllerWillStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
        NSLog("playerViewControllerWillStartPictureInPicture")
        avControllerPiPEnabled = false
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

        if (arguments.count > 1) {
            message = arguments[1]
        }
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        if (arguments.count > 2) {
            cancel = arguments[2]
        }
        alertController.addAction(UIAlertAction(title: cancel, style: .cancel, handler: { (action) in
            completionHandler(false)
        }))
        
        if (arguments.count > 3) {
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
            if (thread_stdin_copy != nil) {
                return fileno(thread_stdin_copy)
            } else {
                return nil
            }
        }
        if (fd == 1) {
            if (thread_stdout_copy != nil) {
                return fileno(thread_stdout_copy)
            } else {
                return nil
            }
        }
        if (fd == 2) {
            if (thread_stderr_copy != nil) {
                return fileno(thread_stderr_copy)
            } else {
                return nil
            }
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
                var returnValue:Int32 = 0
                if (rights & O_CREAT != 0) {
                    returnValue = open(arguments[2], rights, 0o644)
                } else {
                    returnValue = open(arguments[2], rights)
                }
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
                    if (((thread_stdin_copy != nil) && (fd == fileno(self.thread_stdin_copy))) ||
                        ((thread_stdout_copy != nil) && (fd == fileno(self.thread_stdout_copy))) ||
                        ((thread_stderr_copy != nil) && (fd == fileno(self.thread_stderr_copy)))) {
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
                    // Do we have something to write?
                    if (arguments.count >= 6) && (arguments[3].count > 0) {
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
                                do {
                                    try file.seek(toOffset: offset)
                                }
                                catch {
                                    let error = error as NSError
                                    //  Objects that are not capable of seeking always write from the current position (man page of read)
                                    if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
                                        NSLog("Underlying error in seek for write: \(underlyingError)")
                                    }
/*
                                    // printf write to stdout with offset == 0, which cause an error.
                                    if (fd != fileno(stdout_file)) {
                                        let error = error as NSError
                                        //  Objects that are not capable of seeking always read from the current position (man page of read)
                                        if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
                                            completionHandler("\(-underlyingError.code)")
                                        } else {
                                            completionHandler("\(-error.code)")
                                        }
                                        return
                                    }
 */
                                }
                                file.write(data)
                                returnValue = numValues
                            }
                        }
                    }
                }
                completionHandler("\(returnValue)")
                return
            } else if (arguments[1] == "read") {
                var data: Data?
                if let numValues = Int(arguments[3]) {
                    // arguments[3] = length
                    // arguments[4] = offset
                    // arguments[5] = tty input
                    // let values = arguments[3].components(separatedBy:",")
                    let offset = UInt64(arguments[4]) ?? 0
                    let isTTY = Int(arguments[5]) ?? 0
                    if (isTTY != 0) && (arguments[2] == "0") {
                        // Reading from stdin is delicate, we must avoid blocking the UI.
                        var inputString = stdinString;
                        if (inputString.count > numValues) {
                            inputString = String(stdinString.prefix(numValues))
                            stdinString.removeFirst(numValues)
                        } else {
                            stdinString = ""
                        }
                        // Dealing with control-D in input stream
                        if (inputString.hasPrefix(endOfTransmission)) {
                            completionHandler("\(-255)") // Mapped to EOF internally
                            return
                        } else if (inputString.contains(endOfTransmission)) {
                            // cut before EOF, rest of input string goes back to stdin
                            let components = inputString.components(separatedBy: endOfTransmission)
                            var sendBackToInput = inputString
                            sendBackToInput.removeFirst(components[0].count + 1)
                            stdinString = sendBackToInput + stdinString
                            inputString = components[0]
                        }
                        var utf8str = inputString.data(using: .utf8)
                        if (utf8str == nil) {
                            utf8str = inputString.data(using: .ascii)
                        }
                        if utf8str == nil {
                            completionHandler("")
                        } else {
                            completionHandler("\(utf8str!.base64EncodedString(options: Data.Base64EncodingOptions(rawValue: 0)))")
                        }
                        return
                    } else if let fd = fileDescriptor(input: arguments[2]) {
                        let file = FileHandle(fileDescriptor: fd)
                        do {
                            try file.seek(toOffset: offset)
                        }
                        catch {
                            let error = error as NSError
                            //  Objects that are not capable of seeking always read from the current position (man page of read)
                            if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
                                NSLog("Underlying error in seek: \(underlyingError)")
                            }
                        }
                        do {
                            // check if there are numValues available in file?
                            try data = file.read(upToCount: numValues)
                        }
                        catch {
                        }
                    } else {
                        completionHandler("\(-EBADF)") // Invalid file descriptor
                        return
                    }
                }
                if (data != nil) {
                    completionHandler("\(data!.base64EncodedString())")
                } else {
                    completionHandler("") // Did not read anything
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
                    NSLog("Mode: \(arguments[2]) = \(pbuf.pointee.st_mode)")
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
                    let error = (error as NSError)
                    if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
                        completionHandler("\(-underlyingError.code)")
                    } else {
                        completionHandler("\(-error.code)")
                    }
                }
                return
            } else if (arguments[1] == "mkdir") {
                do {
                    try FileManager().createDirectory(atPath: arguments[2], withIntermediateDirectories: true)
                    completionHandler("0")
                }
                catch {
                    let error = (error as NSError)
                    if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
                        completionHandler("\(-underlyingError.code)")
                    } else {
                        completionHandler("\(-error.code)")
                    }
                }
                return
            } else if (arguments[1] == "rmdir") {
                do {
                    let path = arguments[2]
                    let contentsOfDirectory = try FileManager().contentsOfDirectory(atPath: path)
                    if (contentsOfDirectory.isEmpty) {
                        try FileManager().removeItem(atPath: path)
                        completionHandler("0")
                    } else {
                        completionHandler("\(-ENOTEMPTY)")
                    }
                }
                catch {
                    let error = (error as NSError)
                    if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
                        completionHandler("\(-underlyingError.code)")
                    } else {
                        completionHandler("\(-error.code)")
                    }
                }
                return
            } else if (arguments[1] == "rename") {
                do {
                    if (FileManager().fileExists(atPath: arguments[3])) {
                        do {
                            try FileManager().removeItem(atPath: arguments[3])
                        }
                        catch {
                        }
                    }
                    try FileManager().moveItem(atPath:arguments[2], toPath: arguments[3])
                    completionHandler("0")
                }
                catch {
                    let error = (error as NSError)
                    if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
                        completionHandler("\(-underlyingError.code)")
                    } else {
                        completionHandler("\(-error.code)")
                    }
                }
                return
            }  else if (arguments[1] == "link") {
                do {
                    try FileManager().linkItem(atPath:arguments[2], toPath: arguments[3])
                    completionHandler("0")
                }
                catch {
                    let error = (error as NSError)
                    if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
                        completionHandler("\(-underlyingError.code)")
                    } else {
                        completionHandler("\(-error.code)")
                    }
                }
                return
            } else if (arguments[1] == "symlink") {
                do {
                    try FileManager().createSymbolicLink(atPath:arguments[3], withDestinationPath: arguments[2])
                    completionHandler("0")
                }
                catch {
                    let error = (error as NSError)
                    if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
                        completionHandler("\(-underlyingError.code)")
                    } else {
                        completionHandler("\(-error.code)")
                    }
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
                    let error = (error as NSError)
                    if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
                        completionHandler("\(-underlyingError.code)")
                    } else {
                        completionHandler("\(-error.code)")
                    }
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
                ios_releaseThreadId(pid)
                completionHandler("\(result)")
                return
            } else if (arguments[1] == "getenv") {
                if let result = ios_getenv(arguments[2]) {
                    completionHandler(String(cString: result))
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
            } else if (arguments[1] == "utimensat") {
                var fd: Int32 = Int32(arguments[2]) ?? AT_FDCWD
                // Several definitions of AT_FDCWD, but they're all negative
                if (fd < 0) {
                    fd = AT_FDCWD
                }
                var flag: Int32 = Int32(arguments[3]) ?? 0 // path flags
                if ((flag & 0x1) != 0) {
                    // Not the same definition of AT_SYMLINK_NOFOLLOW between wasi-libc and iOS
                    flag |= AT_SYMLINK_NOFOLLOW
                }
                let path = arguments[4]
                if let atime_sec = Int(arguments[5]) {
                    let atime_nsec = Int(arguments[6]) ?? 0
                    let atime: timespec = timespec(tv_sec: atime_sec, tv_nsec: atime_nsec)
                    if let mtime_sec = Int(arguments[7]) {
                        let mtime_nsec = Int(arguments[8]) ?? 0
                        let mtime: timespec = timespec(tv_sec: mtime_sec, tv_nsec: mtime_nsec)
                        // var time = UnsafeMutablePointer<timeval>.allocate(capacity: 2)
                        var time = UnsafeMutablePointer<Darwin.timespec>.allocate(capacity: 2)
                        time[0] = atime
                        time[1] = mtime
                        let returnVal = utimensat(fd, path, time, flag)
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
        if (arguments.count > 1) {
            message = arguments[1]
        }
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        alertController.addTextField { (textField) in
            textField.text = defaultText
        }

        if (arguments.count > 2) {
            cancel = arguments[2]
        }
        alertController.addAction(UIAlertAction(title: cancel, style: .default, handler: { (action) in
            completionHandler(nil)
        }))
        
        if (arguments.count > 3) {
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
