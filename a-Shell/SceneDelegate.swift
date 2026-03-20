//
//  SceneDelegate.swift
//  a-Shell
//
//  Created by Nicolas Holzschuch on 30/06/2019.
//  Copyright © 2019 AsheKube. All rights reserved.
//

import UIKit
import CoreText
import SwiftUI
import WebKit // for WebAssembly
import SwiftTerm // for the terminal window
import ios_system
import MobileCoreServices
import Combine
import AVKit // for media playback
import AVFoundation // for media playback
import TipKit // for helpful tips

var inputFileURLBackup: URL?

let factoryFontSize = Float(13)
let factoryFontName = "Menlo"
let factoryCursorShape = "UNDERLINE"
let factoryFontLigature = "contextual" // normal has a bug, so contextual by default
var directoriesUsed: [String:Int] = [:]

// Experimental: execute JS & webAssembly commands in reverse order, so they can be piped.
struct javascriptCommand {
    var thread_stdin_copy: UnsafeMutablePointer<FILE>? = nil
    var thread_stdout_copy: UnsafeMutablePointer<FILE>? = nil
    var thread_stderr_copy: UnsafeMutablePointer<FILE>? = nil
    var jsCommand: String = ""
    var webAssemblyGroup: DispatchGroup? = nil
    var originalCommand: String = ""
}

// Tips:
@available(iOS 17, *)
let myToolbarTip = toolbarTip()
var internalBrowserStarted = false

class SceneDelegate: UIViewController, UIWindowSceneDelegate, WKNavigationDelegate, WKScriptMessageHandler, UIDocumentPickerDelegate, UIPopoverPresentationControllerDelegate, UIFontPickerViewControllerDelegate, UIDocumentInteractionControllerDelegate, UIGestureRecognizerDelegate, TerminalViewDelegate {
    var window: UIWindow?
    var screen: UIScreen?
    var windowScene: UIWindowScene?
    var terminalView: TerminalView?
    var webView: WKWebView? // webView for browsing and executing webAssembly
    // variables for WebAssembly execution
    // TODO: remove all references to stdinString
    var stdinString: String = ""
    var commandsStack: [javascriptCommand?] = []
    var resultStack: [Int32?] = []
    var javascriptRunning = false // We can't execute JS while we are already executing JS.
    var executeWebAssemblyCommandsRunning = false // We can't execute JS while we are already executing JS.
    // copies of thread_std*, used when executing webAssembly
    var thread_stdin_copy: UnsafeMutablePointer<FILE>? = nil
    var thread_stdout_copy: UnsafeMutablePointer<FILE>? = nil
    var thread_stderr_copy: UnsafeMutablePointer<FILE>? = nil
    // for when a webAssembly command returns:
    var currentDispatchGroup: DispatchGroup? = nil
    var errorCode:Int32 = 0
    var errorMessage: String = ""
    
    var contentView: ContentView?
    // history of commands used:
    var history: [String] = []
    var historyPosition = 0
    // history of commands started inside the command
    var commandHistory: [String] = []
    var commandHistoryPosition = 0
    var commandsArray: [String] = []
    // if we run the same command twice, keep the history:
    var lastCommand = ""
    var width = 80
    var height = 80
    var stdout_active = false
    var stdout_button_active = false
    var persistentIdentifier: String? = nil
    var stdin_file: UnsafeMutablePointer<FILE>? = nil
    var stdin_file_input: FileHandle? = nil
    var stdout_file: UnsafeMutablePointer<FILE>? = nil
    var tty_file: UnsafeMutablePointer<FILE>? = nil
    var tty_file_input: FileHandle? = nil
    var timer = Timer()               // timer for scheduled execution of commands
    var webAssemblyTimer = Timer()    // timer for pinging the webassembly interpreter
    var activateButtonsTimer = Timer()// timer for activating the long-press gesture for buttons
    var continuousButtonTimer = Timer() // timer for the long-press gesture itself.
    var scheduledCommand = ""         // the command that is scheduled to run
    var scheduleInterval: Float = 0.0       // the interval for execution
    var lastExecution: Date = .distantPast  // the last time the command was executed
    var nextExecution: Date = .distantFuture  // the next time the command is scheduled to be executed
    private let commandQueue = DispatchQueue(label: "executeCommand", qos: .utility) // low priority, for executing commands
    // Buttons and toolbars:
    var controlOn = false;
    // control codes:
    let interrupt = "\u{0003}"  // control-C, used to kill the process
    let endOfTransmission = "\u{0004}"  // control-D, used to signal end of transmission
    let tabulation = "\u{0009}"  // control-D, used to signal end of transmission
    let escape = "\u{001B}"
    let deleteBackward = "\u{007F}"
    let carriageReturn = "\u{000D}" // carriage return
    // Are we editing a file?
    var closeAfterCommandTerminates = false
    var resetDirectoryAfterCommandTerminates = ""
    var currentCommand = ""
    var interactiveCommandRunning = true
    //
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
    var terminalFontLigature: String?
    var basicCharWidth = 0.0
    // for audio / video playback:
    var avplayer: AVPlayer? = nil
    var avcontroller: AVPlayerViewController? = nil
    var avControllerPiPEnabled = false
    // for repetitive buttons
    var continuousButtonAction = false
    // If we introduce submenus, the abilities of editorToolbar and inputAssistantItem change.
    var leftButtonGroup: [UIBarButtonItem] = []
    var leftButtonGroups: [UIBarButtonItemGroup] = []
    var rightButtonGroup: [UIBarButtonItem] = []
    var rightButtonGroups: [UIBarButtonItemGroup] = []
    let maxSubmenuLevels = 15
    var buttonRegex: [Int:String] = [:]
    var noneTag = -1
    var fontPicker = UIFontPickerViewController()
    var navigationType: WKNavigationType = .other
    var lastUsedPrompt = "$"
    var extraBytes: Data? = nil
    // tap on multi-arrow buttons
    var tapPosition: CGPoint = .zero
    // initial font size for zoom action
    var zoomGestureInitialSize: Float = factoryFontSize
    // initial position for pan action
    var scrollGestureOrigin: CGPoint = .zero
    var sceneIsInForeground = false
    // command entering and autocomplete (have to be scene-specific, can't be stored in an extension):
    var autocompleteRunning = false
    var autocompleteSuggestions: [String] = []
    var autocompletePosition = 0
    var autocompleteOptions = false
    // variables for user interaction with SwiftTerm:
    var commandBeforeCursor = ""
    var commandAfterCursor = ""
    // gesturereco
    
    // Create a document picker for directories.
    private let documentPicker =
    UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
    
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
        // font size for the labels on buttons.
        // iPads with external keyboard: not used
        // iPads with onscreen keyboard: used
        // iPhones: used
        // toolbar height is always 45
        if (UIDevice.current.model.hasPrefix("iPad")) {
            return 19
        } else {
            return 21
        }
        // This can now be made a configurable option
    }
    
    var toolbarHeight: CGFloat {
        let deviceModel = UIDevice.current.model
        if (deviceModel.hasPrefix("iPad")) {
            return 40
        } else {
            // 45 OK, 40 makes the buttons too small.
            return 45
        }
    }
    
    var isVimRunning: Bool {
        return (currentCommand.hasPrefix("vim ")) || (currentCommand == "vim") || (currentCommand.hasPrefix("jump "))
    }
    
    private func title(_ button: UIBarButtonItem) -> String? {
        if let possibleTitles = button.possibleTitles {
            for attemptedTitle in possibleTitles {
                if (attemptedTitle.count > 0) {
                    return attemptedTitle
                }
            }
        }
        return button.title
    }
    
    @objc private func insertString(_ sender: UIBarButtonItem) {
        if var title = title(sender) {
            var sendCarriageReturn = false
            if (title.hasSuffix("\n")) {
                title.removeLast("\n".count)
                sendCarriageReturn = true
            }
            // If it's termView at the front, just print the string
            if (terminalView != nil) && terminalView!.isFirstResponder {
                DispatchQueue.main.async {
                    if (title == self.deleteBackward) {
                        self.terminalView?.deleteBackward()
                    } else {
                        NSLog("insertString: \(title)")
                        self.terminalView?.send(txt: title)
                        if (sendCarriageReturn) {
                            self.terminalView?.send(txt: "\r\n")
                        }
                    }
                }
            } else if (webView?.url != nil) {
                if (title == "\u{001B}") { // escape
                    webView?.evaluateJavaScript("var event = new KeyboardEvent('keydown', {which:27, keyCode:27, key:'Esc', code:'Esc', bubbles:true});document.activeElement.dispatchEvent(event);") { (result, error) in
                        // if let error = error { print(error) }
                        // if let result = result { print(result) }
                    }
                } else if (title == "\u{007F}") { // delete
                    webView?.evaluateJavaScript("var event = new KeyboardEvent('keydown', {which:8, keyCode:8, key:'Delete', code:'Delete', bubbles:true});document.activeElement.dispatchEvent(event);") { (result, error) in
                        // if let error = error { print(error) }
                        // if let result = result { print(result) }
                    }
                } else {
                    // editor.insert() work with ACE-editor, but not with others
                    // Still not working: control
                    // This works with CodeMirror and ACE:
                    // document.execCommand("insertText", false, "This is a test");
                    DispatchQueue.main.async {
                        self.webView?.evaluateJavaScript("document.execCommand(\"insertText\", false, \"" + title.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\n", with: "\\n").replacingOccurrences(of: "\r", with: "\\r") + "\");") { (result, error) in
                            // if let error = error { print(error) }
                            // if let result = result { print(result) }
                        }
                        if (sendCarriageReturn) {
                            self.webView?.evaluateJavaScript("document.execCommand(\"insertText\", false, \"" + "\\r" + "\");") { (result, error) in
                                // if let error = error { print(error) }
                                // if let result = result { print(result) }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // This is a bit sad, but when a menu uses a representativeItem, sender is set to that representativeItem,
    // so we have no way to know which button was pressed. Hence the multiple commands (3 * maxSubmenuLevels)
    @objc private func insertString_0(_ sender: UIBarButtonItem) {
        if (useSystemToolbar) {
            if let buttonGroup = sender.buttonGroup {
                return insertString(buttonGroup.barButtonItems[0])
            }
        }
        insertString(sender)
    }
    
    @objc private func insertString_1(_ sender: UIBarButtonItem) {
        if (useSystemToolbar) {
            if let buttonGroup = sender.buttonGroup {
                return insertString(buttonGroup.barButtonItems[1])
            }
        }
        insertString(sender)
    }
    
    @objc private func insertString_2(_ sender: UIBarButtonItem) {
        if (useSystemToolbar) {
            if let buttonGroup = sender.buttonGroup {
                return insertString(buttonGroup.barButtonItems[2])
            }
        }
        insertString(sender)
    }
    
    @objc private func insertString_3(_ sender: UIBarButtonItem) {
        if (useSystemToolbar) {
            if let buttonGroup = sender.buttonGroup {
                return insertString(buttonGroup.barButtonItems[3])
            }
        }
        insertString(sender)
    }
    
    @objc private func insertString_4(_ sender: UIBarButtonItem) {
        if (useSystemToolbar) {
            if let buttonGroup = sender.buttonGroup {
                return insertString(buttonGroup.barButtonItems[4])
            }
        }
        insertString(sender)
    }
    
    @objc private func insertString_5(_ sender: UIBarButtonItem) {
        if (useSystemToolbar) {
            if let buttonGroup = sender.buttonGroup {
                return insertString(buttonGroup.barButtonItems[5])
            }
        }
        insertString(sender)
    }
    
    @objc private func insertString_6(_ sender: UIBarButtonItem) {
        if (useSystemToolbar) {
            if let buttonGroup = sender.buttonGroup {
                return insertString(buttonGroup.barButtonItems[6])
            }
        }
        insertString(sender)
    }
    
    @objc private func insertString_7(_ sender: UIBarButtonItem) {
        if (useSystemToolbar) {
            if let buttonGroup = sender.buttonGroup {
                return insertString(buttonGroup.barButtonItems[7])
            }
        }
        insertString(sender)
    }
    
    @objc private func insertString_8(_ sender: UIBarButtonItem) {
        if (useSystemToolbar) {
            if let buttonGroup = sender.buttonGroup {
                return insertString(buttonGroup.barButtonItems[8])
            }
        }
        insertString(sender)
    }
    
    @objc private func insertString_9(_ sender: UIBarButtonItem) {
        if (useSystemToolbar) {
            if let buttonGroup = sender.buttonGroup {
                return insertString(buttonGroup.barButtonItems[9])
            }
        }
        insertString(sender)
    }
    
    @objc private func insertString_10(_ sender: UIBarButtonItem) {
        if (useSystemToolbar) {
            if let buttonGroup = sender.buttonGroup {
                return insertString(buttonGroup.barButtonItems[10])
            }
        }
        insertString(sender)
    }
    
    @objc private func insertString_11(_ sender: UIBarButtonItem) {
        if (useSystemToolbar) {
            if let buttonGroup = sender.buttonGroup {
                return insertString(buttonGroup.barButtonItems[11])
            }
        }
        insertString(sender)
    }
    
    @objc private func insertString_12(_ sender: UIBarButtonItem) {
        if (useSystemToolbar) {
            if let buttonGroup = sender.buttonGroup {
                return insertString(buttonGroup.barButtonItems[12])
            }
        }
        insertString(sender)
    }
    
    @objc private func insertString_13(_ sender: UIBarButtonItem) {
        if (useSystemToolbar) {
            if let buttonGroup = sender.buttonGroup {
                return insertString(buttonGroup.barButtonItems[13])
            }
        }
        insertString(sender)
    }
    
    @objc private func insertString_14(_ sender: UIBarButtonItem) {
        if (useSystemToolbar) {
            if let buttonGroup = sender.buttonGroup {
                return insertString(buttonGroup.barButtonItems[14])
            }
        }
        insertString(sender)
    }
    
    @objc private func insertCommand(_ sender: UIBarButtonItem) {
        // runs the command, and inserts on screen the result of running it. So a button can produce the current date, for example.
        if let command = title(sender) {
            // NSLog("Running button command: \(command)")
            // Get file for stdout/stderr that can be written to
            let stdin_pipe = Pipe()
            let stdin_file = fdopen(stdin_pipe.fileHandleForReading.fileDescriptor, "r")
            var stdout_pipe = Pipe()
            var stdout_file = fdopen(stdout_pipe.fileHandleForWriting.fileDescriptor, "w")
            while (stdout_file == nil) {
                stdout_pipe = Pipe()
                stdout_file = fdopen(stdout_pipe.fileHandleForWriting.fileDescriptor, "w")
            }
            // Call the following functions when data is written to stdout/stderr.
            stdout_pipe.fileHandleForReading.readabilityHandler = self.onStdoutButton
            stdout_button_active = true
            // NSLog("Streams for button: \(stdin_file)  \(stdout_file)")
            ios_setStreams(stdin_file, stdout_file, stdout_file)
            let pid = ios_fork()
            resultStack.removeAll()
            ios_system(command.decomposedStringWithCanonicalMapping)
            ios_waitpid(pid)
            ios_releaseThreadId(pid)
            // Send info to the stdout handler that the command has finished:
            let writeOpen = fcntl(stdout_pipe.fileHandleForWriting.fileDescriptor, F_GETFD)
            if (writeOpen >= 0) {
                // NSLog("write channel still open, flushing")
                fflush(stdout_file)
                // Pipe is still open, send information to close it, once all output has been processed.
                stdout_pipe.fileHandleForWriting.write(self.endOfTransmission.data(using: .utf8)!)
                while (stdout_button_active) {
                    fflush(stdout_file)
                }
            }
            do {
                try stdout_pipe.fileHandleForWriting.close()
            }
            catch {
                NSLog("Error in closing stdout_pipe in insertCommand: \(error)")
            }
        }
    }
    
    @objc private func insertCommand_0(_ sender: UIBarButtonItem) {
        if (useSystemToolbar) {
            if let buttonGroup = sender.buttonGroup {
                return insertCommand(buttonGroup.barButtonItems[0])
            }
        }
        insertCommand(sender)
    }
    
    @objc private func insertCommand_1(_ sender: UIBarButtonItem) {
        if (useSystemToolbar) {
            if let buttonGroup = sender.buttonGroup {
                return insertCommand(buttonGroup.barButtonItems[1])
            }
        }
        insertCommand(sender)
    }
    
    @objc private func insertCommand_2(_ sender: UIBarButtonItem) {
        if (useSystemToolbar) {
            if let buttonGroup = sender.buttonGroup {
                return insertCommand(buttonGroup.barButtonItems[2])
            }
        }
        insertCommand(sender)
    }
    
    @objc private func insertCommand_3(_ sender: UIBarButtonItem) {
        if (useSystemToolbar) {
            if let buttonGroup = sender.buttonGroup {
                return insertCommand(buttonGroup.barButtonItems[3])
            }
        }
        insertCommand(sender)
    }
    
    @objc private func insertCommand_4(_ sender: UIBarButtonItem) {
        if (useSystemToolbar) {
            if let buttonGroup = sender.buttonGroup {
                return insertCommand(buttonGroup.barButtonItems[4])
            }
        }
        insertCommand(sender)
    }
    
    @objc private func insertCommand_5(_ sender: UIBarButtonItem) {
        if (useSystemToolbar) {
            if let buttonGroup = sender.buttonGroup {
                return insertCommand(buttonGroup.barButtonItems[5])
            }
        }
        insertCommand(sender)
    }
    
    @objc private func insertCommand_6(_ sender: UIBarButtonItem) {
        if (useSystemToolbar) {
            if let buttonGroup = sender.buttonGroup {
                return insertCommand(buttonGroup.barButtonItems[6])
            }
        }
        insertCommand(sender)
    }
    
    @objc private func insertCommand_7(_ sender: UIBarButtonItem) {
        if (useSystemToolbar) {
            if let buttonGroup = sender.buttonGroup {
                return insertCommand(buttonGroup.barButtonItems[7])
            }
        }
        insertCommand(sender)
    }
    
    @objc private func insertCommand_8(_ sender: UIBarButtonItem) {
        if (useSystemToolbar) {
            if let buttonGroup = sender.buttonGroup {
                return insertCommand(buttonGroup.barButtonItems[8])
            }
        }
        insertCommand(sender)
    }
    
    @objc private func insertCommand_9(_ sender: UIBarButtonItem) {
        if (useSystemToolbar) {
            if let buttonGroup = sender.buttonGroup {
                return insertCommand(buttonGroup.barButtonItems[9])
            }
        }
        insertCommand(sender)
    }
    
    @objc private func insertCommand_10(_ sender: UIBarButtonItem) {
        if (useSystemToolbar) {
            if let buttonGroup = sender.buttonGroup {
                return insertCommand(buttonGroup.barButtonItems[10])
            }
        }
        insertCommand(sender)
    }
    
    @objc private func insertCommand_11(_ sender: UIBarButtonItem) {
        if (useSystemToolbar) {
            if let buttonGroup = sender.buttonGroup {
                return insertCommand(buttonGroup.barButtonItems[11])
            }
        }
        insertCommand(sender)
    }
    
    @objc private func insertCommand_12(_ sender: UIBarButtonItem) {
        if (useSystemToolbar) {
            if let buttonGroup = sender.buttonGroup {
                return insertCommand(buttonGroup.barButtonItems[12])
            }
        }
        insertCommand(sender)
    }
    
    @objc private func insertCommand_13(_ sender: UIBarButtonItem) {
        if (useSystemToolbar) {
            if let buttonGroup = sender.buttonGroup {
                return insertCommand(buttonGroup.barButtonItems[13])
            }
        }
        insertCommand(sender)
    }
    
    @objc private func insertCommand_14(_ sender: UIBarButtonItem) {
        if (useSystemToolbar) {
            if let buttonGroup = sender.buttonGroup {
                return insertCommand(buttonGroup.barButtonItems[14])
            }
        }
        insertCommand(sender)
    }
    
    func sendArrow(direction: String) {
        DispatchQueue.main.async { [self] in
            switch (direction) {
            case "up":
                if terminalView!.getTerminal().applicationCursor {
                    terminalView!.send(txt: escape + "OA")
                } else {
                    terminalView!.send(txt: escape + "[A")
                }
            case "down":
                if terminalView!.getTerminal().applicationCursor {
                    terminalView!.send(txt: escape + "OB")
                } else {
                    terminalView!.send(txt: escape + "[B")
                }
            case "left":
                if terminalView!.getTerminal().applicationCursor {
                    terminalView!.send(txt: escape + "OD")
                } else {
                    terminalView!.send(txt: escape + "[D")
                }
            case "right":
                if terminalView!.getTerminal().applicationCursor {
                    terminalView!.send(txt: escape + "OC")
                } else {
                    terminalView!.send(txt: escape + "[C")
                }
            default:
                return
            }
        }
    }
    
    @objc private func systemAction(_ sender: UIBarButtonItem) {
        if let title = title(sender) {
            if (terminalView != nil) && terminalView!.isFirstResponder {
                switch (title) {
                case "paste":
                    terminalView?.paste(sender)
                case "up":
                    sendArrow(direction: title)
                case "down":
                    sendArrow(direction: title)
                case "left":
                    sendArrow(direction: title)
                case "right":
                    sendArrow(direction: title)
                case "up.down":
                    if (tapPosition.y > 0) {
                        sendArrow(direction: "down")
                    } else {
                        sendArrow(direction: "up")
                    }
                case "left.right":
                    if (tapPosition.x > 0) {
                        sendArrow(direction: "right")
                    } else {
                        sendArrow(direction: "left")
                    }
                case "up.down.left.right":
                    NSLog("up.down.left.right: \(tapPosition.x) -- \(tapPosition.y)")
                    if abs(tapPosition.x) > abs(tapPosition.y) {
                        if (tapPosition.x > 0) {
                            sendArrow(direction: "right")
                        } else {
                            sendArrow(direction: "left")
                        }
                    } else {
                        if (tapPosition.y > 0) {
                            sendArrow(direction: "down")
                        } else {
                            sendArrow(direction: "up")
                        }
                    }
                case "copy":
                    terminalView?.copy()
                case "cut":
                    terminalView?.cut(sender)
                case "control":
                    controlOn = !controlOn;
                    if #available(iOS 15.0, *) {
                        // This has no impact on the button appearance with systemToolbar and no keyboard visible.
                        sender.isSelected = controlOn
                    } else {
                        // buttonName.fill? if it exists?
                        let configuration = UIImage.SymbolConfiguration(pointSize: fontSize, weight: .regular, scale: .large)
                        sender.image = controlOn ? UIImage(systemName: "chevron.up.square.fill")!.withConfiguration(configuration) :
                        UIImage(systemName: "chevron.up.square")!.withConfiguration(configuration)
                    }
                case "selectAll":
                    terminalView?.selectAll()
                case "showBrowser":
                    activateBrowserAction()
                default:
                    break
                }
                return
            }
            
            // If we're displaying a web page, the toolbar buttons still need to work:
            var commandString: String? = nil
            if (webView?.url != nil) {
                // Standard HTML window, send keyboard event:
                switch (title) {
                case "up":
                    commandString = "var event = new KeyboardEvent('keydown', {which:38, keyCode:38, key:'Up', code:'Up', bubbles:true});document.activeElement.dispatchEvent(event);"
                case "down":
                    commandString = "var event = new KeyboardEvent('keydown', {which:40, keyCode:40, key:'Down', code:'Down', bubbles:true});document.activeElement.dispatchEvent(event);"
                case "left":
                    commandString = "var event = new KeyboardEvent('keydown', {which:37, keyCode:37, key:'Left', code:'Left', bubbles:true});document.activeElement.dispatchEvent(event);"
                case "right":
                    commandString = "var event = new KeyboardEvent('keydown', {which:39, keyCode:39, key:'Right', code:'Right', bubbles:true});document.activeElement.dispatchEvent(event);"
                case "up.down":
                    if (tapPosition.y > 0) {
                        commandString = "var event = new KeyboardEvent('keydown', {which:40, keyCode:40, key:'Down', code:'Down', bubbles:true});document.activeElement.dispatchEvent(event);"
                    } else {
                        commandString = "var event = new KeyboardEvent('keydown', {which:38, keyCode:38, key:'Up', code:'Up', bubbles:true});document.activeElement.dispatchEvent(event);"
                    }
                case "left.right":
                    if (tapPosition.x > 0) {
                        commandString = "var event = new KeyboardEvent('keydown', {which:39, keyCode:39, key:'Right', code:'Right', bubbles:true});document.activeElement.dispatchEvent(event);"
                    } else {
                        commandString = "var event = new KeyboardEvent('keydown', {which:37, keyCode:37, key:'Left', code:'Left', bubbles:true});document.activeElement.dispatchEvent(event);"
                    }
                case "up.down.left.right":
                    NSLog("up.down.left.right: \(tapPosition.x) -- \(tapPosition.y)")
                    if abs(tapPosition.x) > abs(tapPosition.y) {
                        if (tapPosition.x > 0) {
                            commandString = "var event = new KeyboardEvent('keydown', {which:39, keyCode:39, key:'Right', code:'Right', bubbles:true});document.activeElement.dispatchEvent(event);"
                        } else {
                            commandString = "var event = new KeyboardEvent('keydown', {which:37, keyCode:37, key:'Left', code:'Left', bubbles:true});document.activeElement.dispatchEvent(event);"
                        }
                    } else {
                        if (tapPosition.y > 0) {
                            commandString = "var event = new KeyboardEvent('keydown', {which:40, keyCode:40, key:'Down', code:'Down', bubbles:true});document.activeElement.dispatchEvent(event);"
                        } else {
                            commandString = "var event = new KeyboardEvent('keydown', {which:38, keyCode:38, key:'Up', code:'Up', bubbles:true});document.activeElement.dispatchEvent(event);"
                        }
                    }
                    // These are more specific to ACE-editor:
                case "paste":
                    if let pastedString = UIPasteboard.general.string {
                        // NSLog("Sending text to paste: \(pastedString)")
                        webView?.paste(pastedString)
                    }
                case "copy":
                    commandString = "editor.commands.exec('copy');"
                case "cut":
                    commandString = "editor.commands.exec('copy');editor.onCut();"
                    break
                case "selectAll":
                    commandString = "editor.selectAll();"
                case "control":
                    controlOn = !controlOn;
                    if #available(iOS 15.0, *) {
                        // This has no impact on the button appearance with systemToolbar and no keyboard visible.
                        sender.isSelected = controlOn
                    } else {
                        // buttonName.fill? if it exists?
                        let configuration = UIImage.SymbolConfiguration(pointSize: fontSize, weight: .regular, scale: .large)
                        sender.image = controlOn ? UIImage(systemName: "chevron.up.square.fill")!.withConfiguration(configuration) :
                        UIImage(systemName: "chevron.up.square")!.withConfiguration(configuration)
                    }
                    commandString = controlOn ? "window.controlOn = true;" : "window.controlOn = false;"
                default:
                    break
                }
                
            }
            if (commandString != nil) {
                webView?.evaluateJavaScript(commandString!) { (result, error) in
                    // if let error = error { print(error) }
                    // if let result = result { print(result) }
                }
            }
        }
    }
    
    @objc private func systemAction_0(_ sender: UIBarButtonItem) {
        if (useSystemToolbar) {
            if let buttonGroup = sender.buttonGroup {
                return systemAction(buttonGroup.barButtonItems[0])
            }
        }
        systemAction(sender)
    }
    
    @objc private func systemAction_1(_ sender: UIBarButtonItem) {
        if (useSystemToolbar) {
            if let buttonGroup = sender.buttonGroup {
                return systemAction(buttonGroup.barButtonItems[1])
            }
        }
        systemAction(sender)
    }
    @objc private func systemAction_2(_ sender: UIBarButtonItem) {
        if (useSystemToolbar) {
            if let buttonGroup = sender.buttonGroup {
                return systemAction(buttonGroup.barButtonItems[2])
            }
        }
        systemAction(sender)
    }
    
    @objc private func systemAction_3(_ sender: UIBarButtonItem) {
        if (useSystemToolbar) {
            if let buttonGroup = sender.buttonGroup {
                return systemAction(buttonGroup.barButtonItems[3])
            }
        }
        systemAction(sender)
    }
    
    @objc private func systemAction_4(_ sender: UIBarButtonItem) {
        if (useSystemToolbar) {
            if let buttonGroup = sender.buttonGroup {
                return systemAction(buttonGroup.barButtonItems[4])
            }
        }
        systemAction(sender)
    }
    
    @objc private func systemAction_5(_ sender: UIBarButtonItem) {
        if (useSystemToolbar) {
            if let buttonGroup = sender.buttonGroup {
                return systemAction(buttonGroup.barButtonItems[5])
            }
        }
        systemAction(sender)
    }
    
    @objc private func systemAction_6(_ sender: UIBarButtonItem) {
        if (useSystemToolbar) {
            if let buttonGroup = sender.buttonGroup {
                return systemAction(buttonGroup.barButtonItems[6])
            }
        }
        systemAction(sender)
    }
    
    @objc private func systemAction_7(_ sender: UIBarButtonItem) {
        if (useSystemToolbar) {
            if let buttonGroup = sender.buttonGroup {
                return systemAction(buttonGroup.barButtonItems[7])
            }
        }
        systemAction(sender)
    }
    
    @objc private func systemAction_8(_ sender: UIBarButtonItem) {
        if (useSystemToolbar) {
            if let buttonGroup = sender.buttonGroup {
                return systemAction(buttonGroup.barButtonItems[8])
            }
        }
        systemAction(sender)
    }
    
    @objc private func systemAction_9(_ sender: UIBarButtonItem) {
        if (useSystemToolbar) {
            if let buttonGroup = sender.buttonGroup {
                return systemAction(buttonGroup.barButtonItems[9])
            }
        }
        systemAction(sender)
    }
    
    @objc private func systemAction_10(_ sender: UIBarButtonItem) {
        if (useSystemToolbar) {
            if let buttonGroup = sender.buttonGroup {
                return systemAction(buttonGroup.barButtonItems[10])
            }
        }
        systemAction(sender)
    }
    
    @objc private func systemAction_11(_ sender: UIBarButtonItem) {
        if (useSystemToolbar) {
            if let buttonGroup = sender.buttonGroup {
                return systemAction(buttonGroup.barButtonItems[11])
            }
        }
        systemAction(sender)
    }
    
    @objc private func systemAction_12(_ sender: UIBarButtonItem) {
        if (useSystemToolbar) {
            if let buttonGroup = sender.buttonGroup {
                return systemAction(buttonGroup.barButtonItems[12])
            }
        }
        systemAction(sender)
    }
    
    @objc private func systemAction_13(_ sender: UIBarButtonItem) {
        if (useSystemToolbar) {
            if let buttonGroup = sender.buttonGroup {
                return systemAction(buttonGroup.barButtonItems[13])
            }
        }
        systemAction(sender)
    }
    
    @objc private func systemAction_14(_ sender: UIBarButtonItem) {
        if (useSystemToolbar) {
            if let buttonGroup = sender.buttonGroup {
                return systemAction(buttonGroup.barButtonItems[14])
            }
        }
        systemAction(sender)
    }
    
    
    
    @objc func hideKeyboard() {
        DispatchQueue.main.async {
            guard self.terminalView != nil else { return }
            if self.terminalView!.isFirstResponder {
                showKeyboardAtStartup = false
                _ = self.terminalView!.resignFirstResponder()
            }
        }
    }
    
    @objc func hideToolbar() {
        DispatchQueue.main.async {
            showToolbar = false
            self.terminalView!.inputAccessoryView = self.emptyToolbar
            self.webView!.addInputAccessoryView(toolbar: self.emptyToolbar)
            if (useSystemToolbar) {
                self.terminalView!.inputAssistantItem.leadingBarButtonGroups = []
                self.terminalView!.inputAssistantItem.trailingBarButtonGroups = []
                self.webView!.inputAssistantItem.leadingBarButtonGroups = []
                self.webView!.inputAssistantItem.trailingBarButtonGroups = []
            }
        }
    }
    @objc func generateToolbarButtons() {
        // check issue with screen size and pico.
        // Scan the configuration file to generate the button groups:
        var configFile = Bundle.main.resourceURL?.appendingPathComponent("defaultToolbar.txt")
        if (UIDevice.current.model.hasPrefix("iPad")) {
            configFile = Bundle.main.resourceURL?.appendingPathComponent("defaultToolbar_iPad.txt")
        }
        var showBrowserButtonFound = false // new feature, introduced with v2.0.0. Add it for older implamentations.
        if let documentsUrl = try? FileManager().url(for: .documentDirectory,
                                                     in: .userDomainMask,
                                                     appropriateFor: nil,
                                                     create: true) {
            let localConfigFile = documentsUrl.appendingPathComponent(".toolbarDefinition")
            if FileManager().fileExists(atPath: localConfigFile.path) {
                configFile = localConfigFile
            }
        }
        if let configFileUrl = configFile {
            if let contentOfFile = try? String(contentsOf: configFileUrl, encoding: String.Encoding.utf8) {
                leftButtonGroup = []
                rightButtonGroup = []
                leftButtonGroups = []
                rightButtonGroups = []
                buttonRegex = [:]
                var maximumTag = 0
                var insideSubmenu = false
                var submenuLevel = 0
                var pastSeparator = false
                var activeTag = 0
                noneTag = -1
                let buttonsDefinition = contentOfFile.split(separator: "\n")
                var activeButtonGroup: [UIBarButtonItem] = []
                let configuration = UIImage.SymbolConfiguration(pointSize: fontSize, weight: .regular)
                for buttonLine in buttonsDefinition {
                    let trimmedButtonLine = buttonLine.trimmingCharacters(in: .whitespacesAndNewlines)
                    if (trimmedButtonLine.hasPrefix("#")) { continue } // skip comments
                    if (trimmedButtonLine.count == 0) { continue } // skip blank lines
                    // NSLog("Parsing line: \(trimmedButtonLine)")
                    if (trimmedButtonLine == "separator") { // first time: switch to next button group. After: ignored.
                        leftButtonGroup.append(contentsOf: activeButtonGroup)
                        leftButtonGroups.append(UIBarButtonItemGroup(barButtonItems: activeButtonGroup, representativeItem: nil))
                        activeButtonGroup = []
                        pastSeparator = true
                        continue
                    }
                    let regularLine = trimmedButtonLine.contains("insertString") || trimmedButtonLine.contains("systemAction") || trimmedButtonLine.contains("insertCommand")
                    if (!insideSubmenu) && ((trimmedButtonLine == "[")
                                            || ((trimmedButtonLine.hasPrefix("[=\"")) && !regularLine)
                                            || ((trimmedButtonLine.hasPrefix("[='")) && !regularLine)) {
                        // new group:
                        if (activeButtonGroup.count > 0) {
                            // start of a new group. Dump what we have so far:
                            if (pastSeparator) {
                                rightButtonGroup.append(contentsOf: activeButtonGroup)
                                rightButtonGroups.append(UIBarButtonItemGroup(barButtonItems: activeButtonGroup, representativeItem: nil))
                            } else {
                                leftButtonGroup.append(contentsOf: activeButtonGroup)
                                leftButtonGroups.append(UIBarButtonItemGroup(barButtonItems: activeButtonGroup, representativeItem: nil))
                            }
                            activeButtonGroup = []
                        }
                        insideSubmenu = true
                        submenuLevel = 0
                        if trimmedButtonLine.hasPrefix("[=") {
                            var commandRegex = trimmedButtonLine
                            commandRegex.removeFirst("[=".count)
                            if (commandRegex.first == commandRegex.last) {
                                commandRegex.removeFirst()
                                commandRegex.removeLast()
                            }
                            var foundRegexBefore = false
                            for (key, value) in buttonRegex {
                                if value == commandRegex {
                                    activeTag = key
                                    foundRegexBefore = true
                                    break
                                }
                            }
                            if (!foundRegexBefore) {
                                activeTag = maximumTag + 1
                                maximumTag = activeTag
                                // NSLog("Storing: \(commandRegex) for tag: \(activeTag)")
                                if (commandRegex == "none") {
                                    noneTag = activeTag
                                }
                                buttonRegex[activeTag] = commandRegex
                            }
                        }
                        continue
                    }
                    if insideSubmenu && trimmedButtonLine.hasPrefix("]") {
                        // end of submenu
                        var iconName = trimmedButtonLine
                        insideSubmenu = false
                        submenuLevel = 0
                        iconName.removeFirst("]".count)
                        iconName = iconName.trimmingCharacters(in: .whitespacesAndNewlines)
                        var button:UIBarButtonItem? = nil
                        if (iconName != "nil") {
                            if let systemImage = UIImage(systemName: String(iconName)) {
                                button = UIBarButtonItem(image: systemImage.withConfiguration(configuration), style: .plain, target: nil, action: nil)
                            } else {
                                button = UIBarButtonItem(title: iconName, style: .plain, target: nil, action: nil)
                            }
                        }
                        if (button != nil) {
                            button!.tag = activeTag
                            if #available(iOS 16.0, *) {
                                if (activeTag != 0) && (activeTag != noneTag) {
                                    button!.isHidden = true
                                }
                            }
                        }
                        activeTag = 0
                        if (pastSeparator) {
                            rightButtonGroup.append(contentsOf: activeButtonGroup)
                            rightButtonGroups.append(UIBarButtonItemGroup(barButtonItems: activeButtonGroup, representativeItem: button))
                        } else {
                            leftButtonGroup.append(contentsOf: activeButtonGroup)
                            leftButtonGroups.append(UIBarButtonItemGroup(barButtonItems: activeButtonGroup, representativeItem: button))
                        }
                        activeButtonGroup = []
                        continue
                    }
                    // We have a line with a button definition. We need to split it into 3 parts (icon, command, title)
                    let buttonPartsLine = trimmedButtonLine.components(separatedBy: .whitespaces)
                    // There are usually white parts, so we skip them and keep only the non-whites:
                    var buttonParts: [String] = []
                    var buttonCount = 0
                    for str in buttonPartsLine {
                        // command is a single string, the others can have spaces
                        if (str.count > 0) {
                            if ((str == "insertString") || (str == "systemAction") || (str == "insertCommand")) {
                                if (buttonParts.count == 0) {
                                    buttonParts.append("questionmark.app.dashed")
                                }
                                buttonParts.append(str)
                                buttonCount = 2
                            } else if (buttonCount == 0) {
                                if (buttonParts.count > 0) {
                                    buttonParts[0].append(" ")
                                    buttonParts[0].append(str)
                                } else {
                                    buttonParts.append(str)
                                }
                            } else {
                                if (buttonParts.count <= 2) {
                                    buttonParts.append(str)
                                } else {
                                    buttonParts[2].append(" ")
                                    buttonParts[2].append(str)
                                }
                            }
                        }
                    }
                    if (buttonParts.count < 2) {
                        continue
                    }
                    // How to use hierarchical UIImages. Contrast not good enough in Dec. 2022, so disabled.
                    /* var configuration: UIImage.SymbolConfiguration
                     if #available(iOS 15.0, *) {
                     configuration = UIImage.SymbolConfiguration(hierarchicalColor: .placeholderText)
                     } else {
                     configuration = UIImage.SymbolConfiguration(pointSize: fontSize, weight: .regular)
                     } */
                    // If there's no string to insert, string to insert == title
                    if (buttonParts.count == 2) {
                        buttonParts.append(buttonParts[0])
                    }
                    var action: Selector? = nil
                    if ((buttonParts[1] == "insertString") || (buttonParts[1] == "systemAction") || (buttonParts[1] == "insertCommand")) {
                        action = Selector(buttonParts[1] + ":")
                    }
                    if (action == nil) { continue }
                    if insideSubmenu && (submenuLevel < maxSubmenuLevels) {
                        action = Selector(buttonParts[1] + "_\(submenuLevel):")
                        submenuLevel += 1
                    }
                    var button: UIBarButtonItem? = nil
                    if let systemImage = UIImage(systemName: String(buttonParts[0])) {
                        button = UIBarButtonItem(image: systemImage.withConfiguration(configuration), style: .plain, target: self, action: action)
                        button!.target = self
                    } else {
                        button = UIBarButtonItem(title: buttonParts[0], style: .plain, target: self, action: action)
                        button!.target = self
                    }
                    if (button == nil) { continue }
                    // Sanitize the button title before storing it:
                    if (buttonParts[1] == "insertString") {
                        button!.possibleTitles = ["", buttonParts[2].convertUnicode]
                        // .replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "'", with: "\\'")
                    } else {
                        button!.possibleTitles = ["", String(buttonParts[2])]
                    }
                    button!.tag = activeTag
                    if #available(iOS 16.0, *) {
                        if (activeTag != 0) && (activeTag != noneTag) {
                            button!.isHidden = true
                        }
                        // button to switch back to the internal web browser. Hidden until the browser is activated.
                        if (title(button!) == "showBrowser") {
                            showBrowserButtonFound = true
                            button!.isHidden = !internalBrowserStarted
                        }
                    }
                    activeButtonGroup.append(button!)
                }
                rightButtonGroup.append(contentsOf: activeButtonGroup)
                rightButtonGroups.append(UIBarButtonItemGroup(barButtonItems: activeButtonGroup, representativeItem: nil))
                if (!showBrowserButtonFound) {
                    // old configuration file (before v2.0). Add the showBrowser button manually:
                    if let systemImage = UIImage(systemName: "network") {
                        let showBrowserButton = UIBarButtonItem(image: systemImage.withConfiguration(configuration), style: .plain, target: self, action: #selector(self.systemAction(_:)))
                        showBrowserButton.target = self
                        showBrowserButton.possibleTitles = ["", "showBrowser"]
                        if #available(iOS 16.0, *) {
                            showBrowserButton.isHidden = !internalBrowserStarted
                        }
                        leftButtonGroup.append(showBrowserButton)
                    }
                }
            }
        }
    }
    
    @objc func showEditorToolbar() {
        generateToolbarButtons()
        // NSLog("leftButtonGroup: \(leftButtonGroup)")
        // NSLog("rightButtonGroup: \(rightButtonGroup)")
        DispatchQueue.main.async {
            if (useSystemToolbar) {
                self.terminalView?.inputAccessoryView = self.emptyToolbar
                self.webView?.addInputAccessoryView(toolbar: self.emptyToolbar)
                self.terminalView?.inputAssistantItem.leadingBarButtonGroups = self.leftButtonGroups
                self.terminalView?.inputAssistantItem.trailingBarButtonGroups = self.rightButtonGroups
                self.webView?.inputAssistantItem.leadingBarButtonGroups = self.leftButtonGroups
                self.webView?.inputAssistantItem.trailingBarButtonGroups = self.rightButtonGroups
            } else {
                self.terminalView?.inputAssistantItem.leadingBarButtonGroups = []
                self.terminalView?.inputAssistantItem.trailingBarButtonGroups = []
                self.webView?.inputAssistantItem.leadingBarButtonGroups = []
                self.webView?.inputAssistantItem.trailingBarButtonGroups = []
                self.terminalView?.inputAccessoryView = self.editorToolbar
                self.webView?.addInputAccessoryView(toolbar: self.editorToolbar)
            }
        }
    }
    
    func continuousButtonAction(_ button: UIBarButtonItem)  {
        if (title(button) == "up") || (title(button) == "down") || (title(button) == "up.down")
            || (title(button) == "up.down.left.right" && abs(tapPosition.x) <= abs(tapPosition.y)){
            continuousButtonTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true, block: {_ in
                self.systemAction(button)
            })
        } else if (title(button) == "left") || (title(button) == "right") || title(button) == "left.right"
                    || (title(button) == "up.down.left.right" && abs(tapPosition.x) > abs(tapPosition.y)) {
            continuousButtonTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: {_ in
                self.systemAction(button)
            })
        }
    }
    
    @objc func tapAction(_ sender: UITapGestureRecognizer) {
        NSLog("tap action, sender.state: \(sender.state): \(tapPosition.x) -- \(tapPosition.y) bounds: \(sender.view!.frame.width) -- \(sender.view!.frame.height)")
        tapPosition = sender.location(in: sender.view)
        if (sender.view != nil) {
            tapPosition.x /= sender.view!.frame.width
            tapPosition.y /= sender.view!.frame.height
            tapPosition.x -= 0.5
            tapPosition.y -= 0.5
        }
        if (sender.state == .ended) {
            if !useSystemToolbar {
                for button in editorToolbar.items! {
                    if let buttonView = button.value(forKey: "view") as? UIView {
                        if (buttonView == sender.view) {
                            systemAction(button)
                            return
                        }
                    }
                }
            } else {
                if let leftButtonGroups = terminalView?.inputAssistantItem.leadingBarButtonGroups {
                    for leftButtonGroup in leftButtonGroups {
                        for button in leftButtonGroup.barButtonItems {
                            if let buttonView = button.value(forKey: "view") as? UIView {
                                if (buttonView == sender.view) {
                                    systemAction(button)
                                    return
                                }
                            }
                        }
                    }
                }
            }
            if let rightButtonGroups = self.terminalView?.inputAssistantItem.trailingBarButtonGroups {
                for rightButtonGroup in rightButtonGroups {
                    for button in rightButtonGroup.barButtonItems {
                        if let buttonView = button.value(forKey: "view") as? UIView {
                            if (buttonView == sender.view) {
                                systemAction(button)
                                return
                            }
                        }
                    }
                }
            }
        }
    }
    
    @objc func longPressAction(_ sender: UILongPressGestureRecognizer) {
        // If up-down-left-right buttons are currently being pressed, activate multi-action arrows (instead of hide keyboard)
        
        if (sender.state == .ended) {
            continuousButtonTimer.invalidate()
            return
        }
        NSLog("long press action, sender.state: \(sender.state): \(tapPosition.x) -- \(tapPosition.y) bounds: \(sender.view!.frame.width) -- \(sender.view!.frame.height)")
        if (sender.state == .began) || (sender.state == .changed) {
            tapPosition = sender.location(in: sender.view)
            if (sender.view != nil) {
                tapPosition.x /= sender.view!.frame.width
                tapPosition.y /= sender.view!.frame.height
                tapPosition.x -= 0.5
                tapPosition.y -= 0.5
            }
        }
        if (sender.state == .began) {
            // NSLog("sender of long press: \(sender)") // it's a button, now
            if !useSystemToolbar {
                for button in editorToolbar.items! {
                    // long-press == repeat action only for arrows. For anything else, it's remove keyboard.
                    if let buttonView = button.value(forKey: "view") as? UIView {
                        if (buttonView == sender.view) {
                            continuousButtonAction(button)
                            return
                        }
                    }
                }
            } else {
                if let leftButtonGroups = terminalView?.inputAssistantItem.leadingBarButtonGroups {
                    for leftButtonGroup in leftButtonGroups {
                        for button in leftButtonGroup.barButtonItems {
                            if let buttonView = button.value(forKey: "view") as? UIView {
                                if (buttonView == sender.view) {
                                    continuousButtonAction(button)
                                    return
                                }
                            }
                        }
                    }
                }
                if let rightButtonGroups = self.terminalView?.inputAssistantItem.trailingBarButtonGroups {
                    for rightButtonGroup in rightButtonGroups {
                        for button in rightButtonGroup.barButtonItems {
                            if let buttonView = button.value(forKey: "view") as? UIView {
                                if (buttonView == sender.view) {
                                    continuousButtonAction(button)
                                    return
                                }
                            }
                        }
                    }
                }
            }
        }
        if (continuousButtonTimer.isValid) {
            return
        }
        // Not on any arrow button, must be a hidekeyboard event:
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
        var toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: screenWidth - 20, height: toolbarHeight))
        toolbar.tintColor = .label
        if (leftButtonGroup.count == 0) {
            toolbar.items = rightButtonGroup
        } else {
            toolbar.items = leftButtonGroup
            var useLiquidGlass = false
            if #available(iOS 26, *) {
                if let preference = Bundle.main.infoDictionary?["UIDesignRequiresCompatibility"] as? Bool {
                    NSLog("stored UIDesignRequiresCompatibility: \(preference)")
                    useLiquidGlass = !preference
                }
            }
            if useLiquidGlass {
                // liquid glass makes the buttons larger, we can't have a middle space on small screens
                // NSLog("leftButtonGroup: \(leftButtonGroup)")
                // NSLog("rightButtonGroup: \(rightButtonGroup)")
                if (screenWidth > 550) || (leftButtonGroup.count + rightButtonGroup.count < 7) {
                    toolbar.items?.append(UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: self, action: nil))
                }
            } else {
                toolbar.items?.append(UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: self, action: nil))
            }
            if (rightButtonGroup.count > 0) {
                toolbar.items?.append(contentsOf: rightButtonGroup)
            }
        }
        // Long press gesture recognizer for when the toolbar itself is pressed.
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(longPressAction(_:)))
        longPressGesture.minimumPressDuration = 1.0 // 1 second press
        longPressGesture.allowableMovement = 15 // 30 points
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
                case "\\A": // current time in 24-hour HH:MM format
                    let format = DateFormatter()
                    format.dateFormat = "HH:mm"
                    newPrompt += format.string(from: Date())
                case "\\d": // the date in “Weekday Month Date” format (e.g., “Tue May 26”)
                    let format = DateFormatter()
                    format.dateFormat = "E MMM d"
                    newPrompt += format.string(from: Date())
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
                case "\\e": // escape character
                    newPrompt += escape
                    // hHjlnrstTuvVwW@! # $
                case "\\h", "\\H": // the hostname up to the first ‘.’ or the hostname
                    // No easy access to hostname, we print the device name:
                    newPrompt += UIDevice.current.name
                case "\\j": // the number of jobs currently managed by the shell
                    newPrompt += "0" // no job management
                case "\\l": // the basename of the shell's terminal device name
                    newPrompt += UIDevice.current.localizedModel
                case "\\n", "\\r": // newline, carriage return
                    newPrompt += subString
                case "\\s": // the name of the shell, the basename of $0 (the portion following the final slash)
                    if let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String {
                        newPrompt += appName
                    } else {
                        newPrompt += "a-Shell"
                    }
                case "\\t": // the current time in 24-hour HH:MM:SS format
                    let format = DateFormatter()
                    format.dateFormat = "HH:mm:ss"
                    newPrompt += format.string(from: Date())
                case "\\T": // the current time in 12-hour HH:MM:SS format
                    let format = DateFormatter()
                    format.dateFormat = "h:mm:ss"
                    newPrompt += format.string(from: Date())
                case "\\u": // username
                    if let username = ios_getenv("USERNAME") {
                        newPrompt += String(utf8String: username) ?? "mobile"
                        break;
                    }
                    if let username = ios_getenv("USER") {
                        newPrompt += String(utf8String: username) ?? "mobile"
                        break;
                    }
                    if let username = ios_getenv("LOGNAME") {
                        newPrompt += String(utf8String: username) ?? "mobile"
                        break;
                    }
                    if let pw = getpwuid((getuid())) {
                        if let username = pw.pointee.pw_name {
                            newPrompt += String(utf8String: username) ?? "mobile"
                            break;
                        }
                    }
                    newPrompt += "mobile"
                case "\\v": //  the version of bash (e.g., 2.00)
                    if let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                        newPrompt += currentVersion
                    }
                case "\\V": // the release of bash, version + patch level (e.g., 2.00.0)
                    if let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                        newPrompt += currentVersion
                        if let currentBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                            newPrompt += " " + currentBuild
                        }
                    }
                case "\\w": // the current working directory, with $HOME abbreviated with a tilde
                    let currentDirectory = FileManager().currentDirectoryPath
                    let path = String(cString: ios_getBookmarkedVersion(currentDirectory.utf8CString))
                    newPrompt += path
                case "\\W": // the basename of the current working directory, with $HOME abbreviated with a tilde
                    let currentDirectory = FileManager().currentDirectoryPath
                    let path = String(cString: ios_getBookmarkedVersion(currentDirectory.utf8CString))
                    let pathComponents = path.split(separator: "/")
                    if (pathComponents.count > 1) {
                        newPrompt += pathComponents[pathComponents.endIndex - 1]
                    } else {
                        newPrompt += path
                    }
                case "\\@": // the current time in 12-hour am/pm format
                    let format = DateFormatter()
                    format.dateFormat = "h:mm a"
                    newPrompt += format.string(from: Date())
                case "\\!", "\\#": //  the history number of this command or the command number of this command
                    newPrompt += String(history.count)
                case "\\$": // if the effective UID is 0, a #, otherwise a $
                    newPrompt += "$"
                case "\\[", "\\]": // supposed to encase zero-length characters. Not needed for a-Shell.
                    break
                case "\\0", "\\1", "\\2", "\\3", "\\4", "\\5", "\\6", "\\7", "\\8", "\\9": // \nnn: unicode character
                    newPrompt += "\\u\\{"
                    newPrompt += prompt[prompt.index(prompt.startIndex, offsetBy:range.lowerBound + 1)..<prompt.index(prompt.startIndex, offsetBy: range.upperBound + 2)]
                    newPrompt += "\\}"
                    let newRange = prompt.index(prompt.startIndex, offsetBy:range.lowerBound)..<prompt.index(prompt.startIndex, offsetBy: range.upperBound+2)
                    range = NSRange(newRange, in: prompt)
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
        guard terminalView != nil else { return }
        if (self.currentCommand == "") {
            lastUsedPrompt = parsePrompt()
            DispatchQueue.main.async {
                self.terminalView!.ensureCaretIsVisible()
                self.terminalView!.feed(text: self.lastUsedPrompt)
                self.terminalView!.setPromptEnd()
            }
        } else {
            if let data = "\n".data(using: .utf8) {
                stdin_file_input?.write(data)
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
    
    @objc func closeWindow() {
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
            // This call doesn't do anything on iPhones
            UIApplication.shared.requestSceneSessionDestruction(self.windowScene!.session, options: nil)
        }
    }
    
    func clearScreen() {
        // clear entire display: ^[[2J
        // position cursor on top line: ^[[1;1H
        terminalView?.feed(text: self.escape + "[2J")
        terminalView?.feed(text: self.escape + "[1;1H")
        self.windowPrintedContent = "";
    }
    
    func executeWebAssembly(arguments: [String]?) -> Int32 {
        guard (arguments != nil) else { return -1 }
        guard (arguments!.count >= 2) else { return -1 } // There must be at least one command
        let commandNumber = Int(webAssemblyCommandOrder() - 1)
        NSLog("WebAssembly command position: \(commandNumber)")
        while (commandsStack.count <= commandNumber) {
            commandsStack.append(nil)
        }
        while (resultStack.count <= commandNumber) {
            resultStack.append(nil)
        }
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
        NSLog("Entered webAssemblyCommand: \(argumentString) at position: \(commandNumber) = \(commandsStack.count) results: \(resultStack.count)")
        // async functions don't work in WKWebView (so, no fetch, no WebAssembly.instantiateStreaming)
        // Instead, we load the file in swift and send the base64 version to JS
        let currentDirectory = FileManager().currentDirectoryPath
        let fileName = command.hasPrefix("/") ? command : currentDirectory + "/" + command
        guard let buffer = NSData(contentsOf: URL(fileURLWithPath: fileName)) else {
            fputs("wasm: file \(command) not found\n", thread_stderr)
            finishedPreparingWebAssemblyCommand();
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
                    if (components.count <= 1) {
                        continue
                    }
                    let name = components[0]
                    var value = envVar
                    if (value.count > name.count + 1) {
                        value.removeFirst(name.count + 1)
                    } else {
                        continue
                    }
                    value = value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\n", with: "\\n")
                    // NSLog("envVar: \(envVar) name: \(name) value: \(value)")
                    environmentAsJSDictionary += "\"" + name + "\"" + ":" + "\"" + value + "\",\n"
                }
            }
        }
        environmentAsJSDictionary += "}"
        let base64string = buffer.base64EncodedString()
        let javascript = "executeWebAssembly(\"\(base64string)\", " + argumentString + ", \"" + currentDirectory + "\", \(ios_isatty(STDIN_FILENO)), " + environmentAsJSDictionary + ");"
        
        var webAssemblyCommand = javascriptCommand()
        webAssemblyCommand.jsCommand = javascript
        webAssemblyCommand.thread_stdin_copy = thread_stdin
        webAssemblyCommand.thread_stdout_copy = thread_stdout
        webAssemblyCommand.thread_stderr_copy = thread_stderr
        webAssemblyCommand.webAssemblyGroup = DispatchGroup()
        webAssemblyCommand.originalCommand = argumentString
        NSLog("Created webAssemblyCommand: \(argumentString) at position: \(commandNumber) stdout:\(fileno(thread_stdout))")
        if (commandsStack[commandNumber] == nil) {
            commandsStack[commandNumber] = webAssemblyCommand
            resultStack[commandNumber] = nil
        } else {
            NSLog("webAssemblyCommand collision detected!")
            commandsStack.append(webAssemblyCommand)
            resultStack.append(nil)
        }
        // This is the key issue for pipes in dash: make sure the resultStack and commandStack are in sync
        // Also need to test (again) that this works in a-Shell shell.
        finishedPreparingWebAssemblyCommand();
        // Don't start the command, don't return from the command.
        webAssemblyCommand.webAssemblyGroup?.enter()
        webAssemblyCommand.webAssemblyGroup?.wait()
        
        if (stdout_file != nil && fileno(webAssemblyCommand.thread_stdout_copy) != fileno(stdout_file)) {
            fclose(webAssemblyCommand.thread_stdout_copy)
        }
        
        // if resultStack[commandNumber] does not exist, something went wrong.
        // Don't crash, but raise the issue.
        return (resultStack[commandNumber] ?? -1)
    }
    
    func endWebAssemblyCommand(error: Int32, message: String) {
        if executeWebAssemblyCommandsRunning && webAssemblyTimer.isValid {
            errorCode = error
            errorMessage = message
            currentDispatchGroup?.leave()
            webAssemblyTimer.invalidate()
        }
    }
    
    func executeWebAssemblyCommands() {
        // since we're multi-threaded, we could be executing this while executeWebAssembly() is still running. So we wait.
        var wasmEndedWithError = false;
        NSLog("Starting executeWebAssemblyCommands, commands: \(commandsStack.count) results: \(resultStack.count) = \(resultStack) executeWebAssemblyCommandsRunning= \(executeWebAssemblyCommandsRunning)")
        if (commandsStack.isEmpty) {
            NSLog("executeWebAssemblyCommands: empty stack")
            return
        }
        if (executeWebAssemblyCommandsRunning) {
            // Only run one of these at a time
            return
        }
        executeWebAssemblyCommandsRunning = true
        while let command = commandsStack.popLast() {
            if (command == nil) {
                continue
            }
            let position = commandsStack.count
            javascriptRunning = true
            let javascriptGroup = DispatchGroup()
            javascriptGroup.enter()
            currentDispatchGroup = javascriptGroup;
            DispatchQueue.main.async {
                // Check the webassembly interpreter regularly (required in iOS 18 and above, a good idea nevertheless)
                // See https://discord.com/channels/935519150305050644/935519150305050647/1431680783122174205
                self.webAssemblyTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { _ in
                    self.webView?.evaluateJavaScript("commandIsRunning;") { (result, error) in
                        if let error = error {
                            print(error)
                            wasmEndedWithError = true
                            self.endWebAssemblyCommand(error: -1, message: "The WebAssembly interpreter has crashed (often because two windows start at the same time). You'll need to close windows and restart the app.")
                        }
                        if let result = result as? Bool {
                            if (!result) {
                                self.endWebAssemblyCommand(error: 0, message: "")
                            }
                        }
                    }
                }
                self.thread_stdin_copy = command!.thread_stdin_copy
                self.thread_stdout_copy = command!.thread_stdout_copy
                self.thread_stderr_copy = command!.thread_stderr_copy
                self.stdinString = "" // reinitialize stdin
                NSLog("Executing \(command!.originalCommand) in executeWebAssComm, position= \(self.commandsStack.count)")
                self.webView?.evaluateJavaScript(command!.jsCommand)
                // javascriptGroup.leave() // This is now triggered by a prompt() call
            }
            // force synchronization:
            javascriptGroup.wait()
            resultStack[position] = errorCode
            if (errorMessage.count > 0) {
                wasmEndedWithError = true
                // webAssembly compile error:
                if (thread_stderr_copy != nil) {
                    NSLog("Wasm error: \(errorMessage)")
                    fputs(errorMessage + "\n", thread_stderr_copy);
                }
            }
            javascriptRunning = false
            
            if (thread_stdin_copy == nil) {
                // Strangely, the letters typed after ^D do not appear on screen. We force two carriage return to get the prompt visible:
                terminalView?.feed(text: "\n\n")
            }
            // Do not close thread_stdin because if it's a pipe, processes could still be writing into it
            // fclose(thread_stdin)
            // Wait until the command is done, signal is sent by prompt()
            command!.webAssemblyGroup?.leave()
        }
        NSLog("Ended executeWebAssemblyCommands, commands: \(commandsStack.count) results: \(resultStack.count) = \(resultStack)")
        
        executeWebAssemblyCommandsRunning = false
        // Restart the webAssembly engine after an error:
        if (wasmEndedWithError) {
            DispatchQueue.main.async {
                NSLog("reloaded webView after an error")
                // Note: reload is not enough, I need to clear the JS state.
                self.webView?.reloadFromOrigin()
            }
        }
    }
    
    func printJscUsage() {
        fputs("Usage: jsc file.js [--in-window] [--silent] [arguments]\n       jsc --reset\nExecutes JavaScript file.js.\n--in-window: runs inside the main window (can change terminal appearance or behaviour; use with caution).\n--silent: do not print the result of the JavaScript execution.\nOther arguments are passed to the command through process.argv.\njsc --reset: forces a restart of the JavaScript engine.\n", thread_stdout)
    }
    
    func executeJavascript(arguments: [String]?) {
        guard (arguments != nil) else {
            printJscUsage()
            return
        }
        guard (arguments!.count > 1) else {
            printJscUsage()
            return
        }
        let command = arguments![1]
        if (command == "--reset") {
            DispatchQueue.main.async {
                NSLog("reloading webView (on purpose)")
                self.webView?.reloadFromOrigin()
            }
            return
        }
        if ((command == "--help") || (command == "-h")) {
            printJscUsage()
            return
        }
        var silent = false
        var jscWebView = webView
        var process_args = "var process = process ?? {}; process.argv = [";
        for argument in arguments! {
            if (argument == "--in-window") {
                fputs("--in-window is not supported anymore.", thread_stderr)
            } else if ((argument == "--silent") && !silent) {
                silent = true
            } else {
                process_args += "'" + argument + "', ";
            }
        }
        process_args += "];"
        // Also add the environment to the process variable:
        process_args += "process.env = {";
        if let localEnvironment = environmentAsArray() {
            for variable in localEnvironment {
                if let envVar = variable as? String {
                    // Let's not carry environment variables with quotes:
                    if (envVar.contains("\"")) {
                        continue
                    }
                    let components = envVar.components(separatedBy:"=")
                    if (components.count <= 1) {
                        continue
                    }
                    let name = components[0]
                    var value = envVar
                    if (value.count > name.count + 1) {
                        value.removeFirst(name.count + 1)
                    } else {
                        continue
                    }
                    value = value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\n", with: "\\n")
                    // NSLog("envVar: \(envVar) name: \(name) value: \(value)")
                    process_args += "\"" + name + "\"" + ":" + "\"" + value + "\",\n"
                }
            }
        }
        process_args += "};"
        let currentDirectory = FileManager().currentDirectoryPath
        // let fileName = FileManager().currentDirectoryPath + "/" + command
        NSLog("filename: \(command)")
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
            var fileContent = try String(contentsOf: URL(fileURLWithPath: fileName), encoding: String.Encoding.utf8)
            if (fileContent.hasPrefix("#!")) {
                // shebang for javascript, must remove before execution
                if (fileContent.contains("\n")) {
                    if let index = fileContent.firstIndex(of: "\n") {
                        fileContent = String(fileContent.suffix(from: index))
                    }
                }
            }
            // process.args only available in webView
            var javascript = fileContent
            if (jscWebView == webView) {
                javascript = process_args + fileContent
            }
            if #available(iOS 15.0, *), false {
                // Execution of asynchronous JS code, while still waiting for the result
                Task { @MainActor in
                    do {
                        let result = try await jscWebView?.callAsyncJavaScript(javascript, arguments: [:], in: nil, contentWorld: .page)
                        if (!silent) {
                            if let result = result {
                                if let string = result as? String {
                                    fputs(string, thread_stdout_copy)
                                    fputs("\n", thread_stdout_copy)
                                }  else if let number = result as? Int32 {
                                    fputs("\(number)", thread_stdout_copy)
                                    fputs("\n", thread_stdout_copy)
                                } else if let number = result as? Float {
                                    fputs("\(number)", thread_stdout_copy)
                                    fputs("\n", thread_stdout_copy)
                                } else {
                                    fputs("\(result)", thread_stdout_copy)
                                    fputs("\n", thread_stdout_copy)
                                }
                                fflush(thread_stdout_copy)
                                fflush(thread_stderr_copy)
                            }
                        }
                        javascriptRunning = false
                    }
                    catch {
                        // Extract information about *where* the error is, etc.
                        NSLog("Error in JSC: \(error)")
                        let userInfo = (error as NSError).userInfo
                        fputs("jsc: Error ", thread_stderr_copy)
                        // WKJavaScriptExceptionSourceURL is wasm.html, of course.
                        fputs("in file " + command + " ", thread_stderr_copy)
                        if let line = userInfo["WKJavaScriptExceptionLineNumber"] as? Int32 {
                            fputs("at line \(line)", thread_stderr_copy)
                        }
                        if let column = userInfo["WKJavaScriptExceptionColumnNumber"] as? Int32 {
                            fputs(", column \(column): ", thread_stderr_copy)
                        } else {
                            fputs(": ", thread_stderr_copy)
                        }
                        if let message = userInfo["WKJavaScriptExceptionMessage"] as? String {
                            fputs(message + "\n", thread_stderr_copy)
                        } else if let message = userInfo["NSLocalizedDescription"] as? String {
                            fputs(message + "\n", thread_stderr_copy)
                        }
                        fflush(thread_stderr_copy)
                        javascriptRunning = false
                    }
                }
            } else {
                // before iOS 15: execute JS code synchronously. Will give an error an async JS code.
                DispatchQueue.main.async {
                    jscWebView?.evaluateJavaScript(javascript) { (result, error) in
                        if let error = error {
                            // Extract information about *where* the error is, etc.
                            NSLog("Error in JSC: \(error)")
                            let userInfo = (error as NSError).userInfo
                            fputs("jsc: Error ", self.thread_stderr_copy)
                            // WKJavaScriptExceptionSourceURL is wasm.html, of course.
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
                            } else if let message = userInfo["NSLocalizedDescription"] as? String {
                                fputs(message + "\n", self.thread_stderr_copy)
                            }
                            fflush(self.thread_stderr_copy)
                        }
                        if (!silent) {
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
                        }
                        self.javascriptRunning = false
                    }
                }
            }
        }
        catch {
            fputs("Error executing JavaScript file: " + command + ": \(error) \n", thread_stderr)
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
        if (terminalFontLigature == nil) {
            fputs(" ligatures: " + factoryFontLigature, thread_stdout)
        } else {
            fputs(" ligatures: " + terminalFontLigature!, thread_stdout)
        }
        fputs("\n", thread_stdout)
    }
    
    func writeConfigWindow() {
        // Force rewrite of all color parameters. Used for reset.
        let traitCollection = terminalView!.traitCollection
        // Set scene parameters (unless they were set before)
        let backgroundColor = terminalBackgroundColor ?? UIColor.systemBackground.resolvedColor(with: traitCollection)
        let foregroundColor = terminalForegroundColor ?? UIColor.placeholderText.resolvedColor(with: traitCollection)
        let cursorColor = terminalCursorColor ?? UIColor.link.resolvedColor(with: traitCollection)
        // TODO: add font size and font name
        let fontSize = terminalFontSize ?? factoryFontSize
        let fontName = terminalFontName ?? factoryFontName
        let cursorShape = terminalCursorShape ?? factoryCursorShape
        let fontLigature = terminalFontLigature ?? factoryFontLigature
        // Force writing all config to term. Used when we changed many parameters.
        terminalView?.backgroundColor = backgroundColor
        terminalView?.getTerminal().backgroundColor = (backgroundColor.toSwiftTermColor())
        terminalView?.tintColor = foregroundColor
        terminalView?.getTerminal().foregroundColor = (foregroundColor.toSwiftTermColor())
        terminalView?.caretColor = cursorColor
        terminalView?.getTerminal().cursorColor = (cursorColor.toSwiftTermColor())
        terminalView?.selectedTextBackgroundColor = cursorColor.makeTransparent()
        if let terminalFont = UIFont(name: fontName, size: CGFloat(fontSize)) {
            terminalView?.font = terminalFont
            basicCharWidth = NSAttributedString(string: "m", attributes: [.font: terminalFont]).size().width
        }
        switch (cursorShape.lowercased()) {
        case "block":
            self.terminalView?.getTerminal().setCursorStyle(.blinkBlock)
        case "beam":
            self.terminalView?.getTerminal().setCursorStyle(.blinkBar)
        case "underline":
            self.terminalView?.getTerminal().setCursorStyle(.blinkUnderline)
        default:
            self.terminalView?.getTerminal().setCursorStyle(.blinkUnderline)
        }
    }
    
    func configWindow(fontSize: Float?, fontName: String?, backgroundColor: UIColor?, foregroundColor: UIColor?, cursorColor: UIColor?, cursorShape: String?, fontLigature: String?) {
        DispatchQueue.main.async { // SwiftTerm changes to the UI must happen on the main thread
            if (fontSize != nil) {
                self.terminalFontSize = fontSize
            }
            if (fontName != nil) {
                self.terminalFontName = fontName
            }
            if let terminalFont = UIFont(name: self.terminalFontName ?? factoryFontName, size: CGFloat(self.terminalFontSize ?? factoryFontSize)) {
                self.terminalView?.font = terminalFont
                self.basicCharWidth = NSAttributedString(string: "m", attributes: [.font: self.terminalView?.font]).size().width
            }
            if (backgroundColor != nil) {
                self.terminalBackgroundColor = backgroundColor
                self.terminalView?.backgroundColor = self.terminalBackgroundColor
                self.terminalView?.getTerminal().backgroundColor = (backgroundColor!.toSwiftTermColor())
            }
            if (foregroundColor != nil) {
                self.terminalForegroundColor = foregroundColor
                self.terminalView?.tintColor = self.terminalForegroundColor
                self.terminalView?.getTerminal().foregroundColor = (self.terminalForegroundColor?.toSwiftTermColor())!
            }
            if (cursorColor != nil) {
                self.terminalCursorColor = cursorColor
                self.terminalView?.caretColor = self.terminalCursorColor!
                self.terminalView?.getTerminal().cursorColor = self.terminalCursorColor!.toSwiftTermColor()
                self.terminalView?.selectedTextBackgroundColor = self.terminalCursorColor!.makeTransparent()
            }
            if (cursorShape != nil) {
                self.terminalCursorShape = cursorShape
                switch (cursorShape!.lowercased()) {
                case "block":
                    self.terminalView?.getTerminal().setCursorStyle(.blinkBlock)
                case "beam":
                    self.terminalView?.getTerminal().setCursorStyle(.blinkBar)
                case "underline":
                    self.terminalView?.getTerminal().setCursorStyle(.blinkUnderline)
                default:
                    self.terminalView?.getTerminal().setCursorStyle(.blinkUnderline)
                }
            }
            // Update COLORFGBG depending on new color:
            if (foregroundColor != nil ) || (backgroundColor != nil) {
                let fg = foregroundColor ?? self.terminalForegroundColor ?? UIColor.placeholderText.resolvedColor(with: self.traitCollection)
                let bg = backgroundColor ?? self.terminalBackgroundColor ?? UIColor.systemBackground.resolvedColor(with: self.traitCollection)
                self.setEnvironmentFGBG(foregroundColor: fg, backgroundColor: bg)
            }
            // TODO: ligatures are activated by default. I'm not sure how to deactivate them with SwiftTerm
            if (fontLigature != nil) {
                self.terminalFontLigature = fontLigature
            }
        }
    }
    
    func keepDirectoryAfterShortcut() {
        resetDirectoryAfterCommandTerminates = ""
    }
    
    // Creates the iOS 13 Font picker, returns the name of the font selected.
    func pickFont() -> String? {
        DispatchQueue.main.sync {
            let fontPickerConfig = UIFontPickerViewController.Configuration()
            fontPickerConfig.includeFaces = true
            fontPickerConfig.filteredTraits = .traitMonoSpace
            // Create the font picker
            fontPicker = UIFontPickerViewController(configuration: fontPickerConfig)
            fontPicker.delegate = self
            // Present the font picker
            self.selectedFont = ""
            // Main issue: the user can dismiss the fontPicker by sliding upwards.
            // So we need to check if it was, indeed dismissed:
            let rootVC = self.window?.rootViewController
            rootVC?.present(fontPicker, animated: false, completion: nil)
        }
        // Wait until fontPicker is dismissed or a font has been selected:
        while (!self.fontPicker.isBeingDismissed) && (self.selectedFont == "") { }
        DispatchQueue.main.async {
            self.fontPicker.dismiss(animated: false)
        }
        if (selectedFont != "cancel") && (selectedFont != "") {
            return selectedFont
        }
        return nil
    }
    
    func fontPickerViewControllerDidCancel(_ viewController: UIFontPickerViewController) {
        // User cancelled the font picker delegate
        // NSLog("Cancelled font")
        selectedFont = "cancel"
    }
    
    
    func fontPickerViewControllerDidPickFont(_ viewController: UIFontPickerViewController) {
        // We got a font!
        if let descriptor = viewController.selectedFontDescriptor {
            if let name = descriptor.fontAttributes[.family] as? String {
                // NSLog("Selected font: \(name)")
                // "Regular" variants of the font:
                selectedFont = name
                return
            } else if let name = descriptor.fontAttributes[.name] as? String {
                // This is for Light, Medium, ExtraLight variants of the font:
                // NSLog("Selected font: \(name)")
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
        if #unavailable(iOS 26) {
            // This causes the document picker to freeze on iOS 26
            documentPicker.allowsMultipleSelection = true
        }
        documentPicker.delegate = self
        
        let rootVC = self.window?.rootViewController
        // Set the initial directory (doesn't always work).
        documentPicker.directoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        // Present the document picker.
        selectedDirectory = ""
        DispatchQueue.main.async {
            rootVC?.present(self.documentPicker, animated: false, completion: nil)
        }
        while (selectedDirectory == "") { } // wait until a directory is selected, for Shortcuts.
    }
    
    func pickFile() {
        if #unavailable(iOS 26) {
            documentPicker.allowsMultipleSelection = false
        }
        documentPicker.delegate = self
        
        let rootVC = self.window?.rootViewController
        // Set the initial directory (it doesn't always work)
        documentPicker.directoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        // Present the document picker.
        selectedDirectory = ""
        DispatchQueue.main.async {
            rootVC?.present(self.documentPicker, animated: false, completion: nil)
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
        if (newDirectory.isDirectory) {
            changeDirectory(path: newDirectory.path) // call cd_main and checks secured bookmarked URLs
            if (newDirectory.path != currentDirectory) {
                previousDirectory = currentDirectory
                currentDirectory = newDirectory.path
            }
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
            if #available(iOS 14.2, *) {
                // Doesn't do anything, should start PiP when going to background:
                // Works differently on iPhones and iPads?
                avcontroller!.canStartPictureInPictureAutomaticallyFromInline = true
            }
            avcontroller!.allowsPictureInPicturePlayback = true
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
                preview.presentPreview(animated: false)
            }
            return 0
        } else {
            // File not found.
            if !path.hasPrefix("-") {
                fputs("view: file " + path + " not found\n", thread_stderr)
            }
            fputs("usage: view file\n", thread_stderr)
            return -1
        }
    }
    
    func stopRepeating() {
        DispatchQueue.main.async {
            self.timer.invalidate()
            self.lastExecution = .distantPast
            self.nextExecution = .distantFuture
            self.scheduledCommand = ""
            self.scheduleInterval = 0
        }
    }
    
    func showRepeatingCommand() {
        if (!self.timer.isValid) {
            fputs("No currently scheduled command\n", thread_stdout)
            return
        }
        fputs("Scheduled command: \(scheduledCommand)\nRepeat every: \(scheduleInterval) seconds\n", thread_stdout)
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .medium
        if #available(iOS 15, *) {
            if (lastExecution != .distantPast) {
                fputs("Last executed at: \(dateFormatter.string(from: lastExecution)).\n", thread_stdout)
            } else {
                fputs("Not executed yet.\n", thread_stdout)
            }
            if (nextExecution != .distantFuture) {
                while (self.nextExecution <= .now) {
                    self.nextExecution += TimeInterval(scheduleInterval)
                }
                let delay = nextExecution.timeIntervalSinceNow
                let formattedDelay = String(format: "%.2f", delay)
                fputs("Next execution at: \(dateFormatter.string(from: nextExecution)), in \(formattedDelay) seconds\n", thread_stdout)
            }
        }
    }
    
    func repeatCommand(interval: Float, command: String) {
        // These are all local input-output streams that also send to the window.
        // If multiple commands are running, things are going to be messy.
        DispatchQueue.main.async {
            if (self.timer.isValid) {
                self.timer.invalidate()
            }
            self.scheduledCommand = command
            self.scheduleInterval = interval
            self.lastExecution = .distantPast
            if #available(iOS 15, *) {
                self.nextExecution = .now + TimeInterval(interval)
            }
            self.timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(interval), repeats: true) { _ in
                if (!self.stdout_active) {
                    let stdout_pipe = Pipe()
                    stdout_pipe.fileHandleForReading.readabilityHandler = self.onStdout
                    let stdout_file = fdopen(stdout_pipe.fileHandleForWriting.fileDescriptor, "w")
                    if (stdout_file != nil) {
                        // we need to have a stdin, even if we won't use it.
                        let stdin_pipe = Pipe()
                        let stdin_file = fdopen(stdin_pipe.fileHandleForReading.fileDescriptor, "r")
                        ios_switchSession(self.persistentIdentifier?.toCString())
                        ios_setContext(UnsafeMutableRawPointer(mutating: self.persistentIdentifier?.toCString()))
                        ios_setStreams(stdin_file, stdout_file, stdout_file)
                        // don't run the scheduled command if another command is already running
                        // (either one from the user or another run of the scheduled command)
                        // This is to avoid messy screens, and to avoid system overload if the
                        // scheduled command takes longer to complete than the interval.
                        self.stdout_active = true
                        if #available(iOS 15, *) {
                            self.lastExecution = .now
                            self.nextExecution += TimeInterval(interval)
                        }
                        let pid = ios_fork()
                        _ = ios_system(command.decomposedStringWithCanonicalMapping)
                        ios_waitpid(pid)
                        fflush(thread_stdout)
                        let closeTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) {_ in
                            fflush(thread_stdout)
                            do {
                                try stdout_pipe.fileHandleForWriting.close()
                                try stdout_pipe.fileHandleForReading.close()
                                // These need to be reset to nil, otherwise it won't work:
                                thread_stdin = nil
                                thread_stdout = nil
                                thread_stderr = nil
                                self.stdout_active = false
                            }
                            catch {
                                NSLog("Error in closing stdout_pipe in repeatCommand: \(error)")
                            }
                        }
                    } else {
                        NSLog("Unable to open stdout_pipe in repeatCommand")
                    }
                }
            }
            self.timer.fire()
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
    
    @objc func activateBrowserAction() {
        showWebView = true
        guard webView != nil else { return }
        if let url = webView!.url {
            NSLog("showWebView: \(url)")
            if url.scheme == "file" && url.path == Bundle.main.bundlePath + "/wasm.html" {
                if webView!.canGoBack {
                    webView?.goBack()
                } else {
                    return
                }
            }
        }
        if let url = webView!.url {
            if url.scheme == "file" && url.path != Bundle.main.bundlePath + "/wasm.html"{
                // http URLs reload automatically, but file URLs must be reloaded explicitly:
                webView?.goBack()
                let directoryURL = url.deletingLastPathComponent()
                webView?.loadFileURL(url, allowingReadAccessTo: directoryURL)
            }
            hideKeyboard() // hides the keyboard *and* causes SwiftUI to refresh
        }
    }
    
    func openURLInWindow(url: URL) {
        // load URL on current window.
        if (url.scheme == "file") {
            // Create a directory URL:
            let directoryURL = url.deletingLastPathComponent()
            webView?.loadFileURL(url, allowingReadAccessTo: directoryURL)
        } else {
            webView?.load(URLRequest(url: url))
        }
        NSLog("setting showWebView to true")
        showWebView = true
        hideKeyboard() // hides the keyboard *and* causes SwiftUI to refresh
        internalBrowserStarted = true
        // make "showBrowser" button now visible in the toolbar
        if #available(iOS 16.0, *) {
            if (!useSystemToolbar) {
                for button in editorToolbar.items! {
                    if title(button) == "showBrowser" {
                        button.isHidden = false
                        // Works with internalbrowser, but not with jupyter-notebook. WHY?
                        NSLog("Making showBrowser button visible")
                        break
                    }
                }
            } else {
                var foundBrowser = false
                if let leftButtonGroups = terminalView?.inputAssistantItem.leadingBarButtonGroups {
                    for leftButtonGroup in leftButtonGroups {
                        for button in leftButtonGroup.barButtonItems {
                            if title(button) == "showBrowser" {
                                button.isHidden = false
                                foundBrowser = true
                                break
                            }
                        }
                    }
                }
                if (!foundBrowser) {
                    if let rightButtonGroups = terminalView?.inputAssistantItem.trailingBarButtonGroups {
                        for rightButtonGroup in rightButtonGroups {
                            for button in rightButtonGroup.barButtonItems {
                                if title(button) == "showBrowser" {
                                    foundBrowser = true
                                    button.isHidden = false
                                    break
                                }
                            }
                        }
                    }
                }
                if (foundBrowser) {
                    NSLog("We made showBrowser button visible")
                }
            }
        }
    }
    
    private func hideButton(tag: Int) -> Bool {
        if (tag == 0) { return false }
        if (tag == noneTag) { return true }
        if let regexString = self.buttonRegex[tag] {
            do {
                let regex = try NSRegularExpression(pattern: regexString, options: [])
                let matches = regex.matches(in: currentCommand, range: NSRange(currentCommand.startIndex..<currentCommand.endIndex, in: currentCommand))
                if (matches.count > 0) {
                    // one match: make this button visible.
                    return false
                }
            }
            catch {
            }
        }
        return true
    }
    
    func executeCommand(command: String) {
        NSLog("executeCommand: \(command) sceneIdentifier: \(persistentIdentifier)")
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
            commandQueue.async {
                self.terminalView?.wipeContents()
                // self.clearScreen()
            }
            // self.terminalView?.feed(text: self.escape + "[2J" + self.escape + "[1;1H")
            // Also clear history:
            history = []
            historyPosition = 0
            // and directories used:
            directoriesUsed = [:]
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
            commandQueue.async {
                self.printPrompt()
            }
            return
        } // exit()
        if (!command.contains("\n")) {
            // save command in history.
            // We don't store multi-line commands in history, as they create issues.
            if (history.last != command) && (command != "") {
                // only store command if different from last command
                history.append(command)
            }
            while (history.count > 100) {
                // only keep the last 100 commands
                history.removeFirst()
            }
            historyPosition = history.count
        }
        // Can't create/close windows through ios_system, because it creates/closes a new session.
        if (actualCommand == "newWindow") {
            let activity = NSUserActivity(activityType: "AsheKube.app.a-Shell.OpenDirectory")
            activity.userInfo!["url"] = URL(fileURLWithPath: FileManager().currentDirectoryPath)
            UIApplication.shared.requestSceneSessionActivation(nil, userActivity: activity, options: nil)
            printPrompt() // Needed to show that the window is ready for a new command
            return
        }
        // "normal" commands can go through ios_system
        // We use a queue to allow the system to continue running (important for commands that interact with the system, such as "config -n" and "view".
        commandQueue.async {
            // set up streams for feedback:
            // Create new pipes for our own stdout/stderr
            // Get file for stdin that can be read from
            // Create new pipes for our own stdout/stderr
            var stdin_pipe = Pipe()
            self.stdin_file = fdopen(stdin_pipe.fileHandleForReading.fileDescriptor, "r")
            var counter = 0
            while (self.stdin_file == nil) && (counter < 5) {
                self.terminalView?.feed(text: "Could not create an input stream, retrying (\(counter+1))\n")
                stdin_pipe = Pipe()
                self.stdin_file = fdopen(stdin_pipe.fileHandleForReading.fileDescriptor, "r")
                if (counter > 2) {
                    let ms: UInt32 = 1000
                    usleep(150 * ms)
                }
                counter += 1
            }
            if (self.stdin_file == nil) {
                self.terminalView?.feed(text: "Unable to create an input stream. I give up.\n")
                return
            }
            self.stdin_file_input = stdin_pipe.fileHandleForWriting
            let tty_pipe = Pipe()
            self.tty_file = fdopen(tty_pipe.fileHandleForReading.fileDescriptor, "r")
            self.tty_file_input = tty_pipe.fileHandleForWriting
            // Get file for stdout/stderr that can be written to
            var stdout_pipe = Pipe()
            counter = 0
            self.stdout_file = fdopen(stdout_pipe.fileHandleForWriting.fileDescriptor, "w")
            while (self.stdout_file == nil) && (counter < 5) {
                self.terminalView?.feed(text: "Could not create an output stream, retrying (\(counter+1))\n")
                stdout_pipe = Pipe()
                self.stdout_file = fdopen(stdout_pipe.fileHandleForWriting.fileDescriptor, "w")
                if (counter > 2) {
                    let ms: UInt32 = 1000
                    usleep(150 * ms)
                }
                counter += 1
            }
            if (self.stdout_file == nil) {
                self.terminalView?.feed(text: "Unable to create an output stream. I give up.\n")
                return
            }
            // Call the following functions when data is written to stdout/stderr.
            stdout_pipe.fileHandleForReading.readabilityHandler = self.onStdout
            self.stdout_active = true
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
                if let actualCommand = aliasedCommand(arguments[0]) {
                    NSLog("Received command to execute: \(actualCommand)")
                    if (actualCommand == "exit") {
                        self.closeWindow()
                        break // if "exit" didn't work, still don't execute the rest of the commands.
                    }
                    if (actualCommand == "newWindow") {
                        self.executeCommand(command: actualCommand)
                        continue
                    }
                }
                self.currentCommand = command
                if (showToolbar) {
                    DispatchQueue.main.async {
                        if #available(iOS 16.0, *) {
                            // Show buttons depending on commands:
                            // Hide all buttons with tag == noneTag, show all buttons that match.
                            if (useSystemToolbar) {
                                self.terminalView?.inputAssistantItem.leadingBarButtonGroups.forEach { leftButtonGroup in
                                    if let representativeItem = leftButtonGroup.representativeItem {
                                        representativeItem.isHidden = self.hideButton(tag: representativeItem.tag)
                                    }
                                    leftButtonGroup.barButtonItems.forEach { button in
                                        if (self.title(button) != "showBrowser") {
                                            button.isHidden = self.hideButton(tag: button.tag)
                                        }
                                    }
                                }
                                self.terminalView?.inputAssistantItem.trailingBarButtonGroups.forEach { rightButtonGroup in
                                    if let representativeItem = rightButtonGroup.representativeItem {
                                        representativeItem.isHidden = self.hideButton(tag: representativeItem.tag)
                                    }
                                    rightButtonGroup.barButtonItems.forEach { button in
                                        if (self.title(button) != "showBrowser") {
                                            button.isHidden = self.hideButton(tag: button.tag)
                                        }
                                    }
                                }
                            } else {
                                self.editorToolbar.items?.forEach { button in
                                    if (self.title(button) != "showBrowser") {
                                        button.isHidden = self.hideButton(tag: button.tag)
                                    }
                                }
                            }
                        }
                    }
                }
                self.resultStack.removeAll()
                self.pid = ios_fork()
                DispatchQueue.main.async {
                    UIApplication.shared.isIdleTimerDisabled = true
                }
                self.interactiveCommandRunning = false // if it's interactive, ios_system will set it to true
                // decompose file names (and commands) using a decomposed (NFD) UTF8 form,
                // the keyboard uses NFC with non-English systems.
                // See: https://github.com/holzschu/a-shell/issues/995
                // And: https://developer.apple.com/forums/thread/817449
                ios_system(self.currentCommand.decomposedStringWithCanonicalMapping)
                NSLog("Returned from ios_system")
                // for long running commands, ios_waitpid eats up to 68% CPU.
                // but for short-running commands, we need it to be reactive.
                // I tried with a timer, but it didn't work (not reactive enough, fails with dash)
                ios_waitpid(self.pid)
                NSLog("Returned from ios_waitpid")
                ios_releaseThreadId(self.pid)
                DispatchQueue.main.async {
                    UIApplication.shared.isIdleTimerDisabled = false
                }
                NSLog("Done executing command: \(command)")
                NSLog("Current directory: \(FileManager().currentDirectoryPath)")
            }
            do {
                fclose(self.stdin_file)
                try stdin_pipe.fileHandleForReading.close()
                try stdin_pipe.fileHandleForWriting.close()
            }
            catch {
                NSLog("Exception in closing stdin_pipe: \(error)")
            }
            self.stdin_file_input = nil
            do {
                fclose(self.tty_file)
                try tty_pipe.fileHandleForReading.close()
                try tty_pipe.fileHandleForWriting.close()
            }
            catch {
                NSLog("Exception in closing tty_pipe: \(error)")
            }
            self.tty_file_input = nil
            // Send info to the stdout handler that the command has finished:
            let writeOpen = fcntl(stdout_pipe.fileHandleForWriting.fileDescriptor, F_GETFD)
            if (writeOpen >= 0) {
                // Pipe is still open, send information to close it, once all output has been processed.
                stdout_pipe.fileHandleForWriting.write(self.endOfTransmission.data(using: .utf8)!)
                fflush(thread_stdout)
                while (self.stdout_active) {
                    fflush(thread_stdout)
                }
            }
            do {
                fclose(self.stdout_file)
                try stdout_pipe.fileHandleForWriting.close()
                try stdout_pipe.fileHandleForReading.close()
            }
            catch {
                NSLog("Exception in closing stdout_pipe: \(error)")
            }
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
            // re-hide buttons after leaving command:
            if (showToolbar) {
                DispatchQueue.main.async {
                    if #available(iOS 16.0, *) {
                        if (useSystemToolbar) {
                            // Show buttons after command is done:
                            self.terminalView?.inputAssistantItem.leadingBarButtonGroups.forEach { leftButtonGroup in
                                if let representativeItem = leftButtonGroup.representativeItem {
                                    if (representativeItem.tag != 0) {
                                        representativeItem.isHidden = !(representativeItem.tag == self.noneTag)
                                    }
                                }
                                leftButtonGroup.barButtonItems.forEach { button in
                                    if (button.tag != 0) {
                                        if (self.title(button) != "showBrowser") {
                                            button.isHidden = !(button.tag == self.noneTag)
                                        }
                                    }
                                }
                            }
                            self.terminalView?.inputAssistantItem.trailingBarButtonGroups.forEach { rightButtonGroup in
                                if let representativeItem = rightButtonGroup.representativeItem {
                                    if (representativeItem.tag != 0) {
                                        representativeItem.isHidden = !(representativeItem.tag == self.noneTag)
                                    }
                                }
                                rightButtonGroup.barButtonItems.forEach { button in
                                    if (button.tag != 0) {
                                        if (self.title(button) != "showBrowser") {
                                            button.isHidden = !(button.tag == self.noneTag)
                                        }
                                    }
                                }
                            }
                            if #available(iOS 26, *) {
                                // fix for an iOS bug: the buttons can be pushed sideways
                                self.terminalView?.inputAssistantItem.trailingBarButtonGroups[0].barButtonItems.append(UIBarButtonItem(title: "Hi", style: .plain, target: self, action: nil))
                                self.terminalView?.inputAssistantItem.trailingBarButtonGroups[0].barButtonItems.removeLast()
                            }
                        } else {
                            self.editorToolbar.items?.forEach { button in
                                if (button.tag != 0) {
                                    if (self.title(button) != "showBrowser") {
                                        button.isHidden = !(button.tag == self.noneTag)
                                    }
                                }
                            }
                            if #available(iOS 26, *) {
                                // fix for an iOS 26 bug: the buttons won't reappear unless I force a redraw of the toolbar.
                                self.editorToolbar.items?.append(UIBarButtonItem(title: "Hi", style: .plain, target: self, action: nil))
                                self.editorToolbar.items?.removeLast()
                                // re-activate long-press gesture for buttons (iOS 26 only?):
                                NSLog("activating the long press button timer, repets=false: \(self.activateLongPressForButtons())")
                            }
                        }
                    }
                }
            }
            self.currentCommand = ""
            self.pid = 0
            self.printPrompt() // Needs to be in main queue
        }
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let cmd:String = message.body as? String else {
            // NSLog("Could not convert Javascript message: \(message.body)")
            return
        }
        // A handful should be kept for when webView is at the front (and even then?)
        // NSLog("Received JS message: \(cmd)")
        // TODO: check if these commands are used by the editors.
        if (cmd.hasPrefix("controlOff")) {
            controlOn = false
            if #available(iOS 15.0, *) {
                if (!useSystemToolbar) {
                    for button in editorToolbar.items! {
                        if title(button) == "control" {
                            button.isSelected = controlOn
                            break
                        }
                    }
                } else {
                    var foundControl = false
                    if let leftButtonGroups = terminalView?.inputAssistantItem.leadingBarButtonGroups {
                        for leftButtonGroup in leftButtonGroups {
                            for button in leftButtonGroup.barButtonItems {
                                if title(button) == "control" {
                                    foundControl = true
                                    button.isSelected = controlOn
                                    break
                                }
                            }
                        }
                    }
                    if (!foundControl) {
                        if let rightButtonGroups = terminalView?.inputAssistantItem.trailingBarButtonGroups {
                            for rightButtonGroup in rightButtonGroups {
                                for button in rightButtonGroup.barButtonItems {
                                    if title(button) == "control" {
                                        button.isSelected = controlOn
                                        break
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                let configuration = UIImage.SymbolConfiguration(pointSize: fontSize, weight: .regular, scale: .large)
                for button in editorToolbar.items! {
                    if title(button) == "control" {
                        button.image = UIImage(systemName: "chevron.up.square")!.withConfiguration(configuration)
                        break
                    }
                }
            }
        } else if (cmd.hasPrefix("copy:")) {
            // copy text to clipboard. Required since simpler methods don't work with what we want to do with cut in JS.
            var string = cmd
            string.removeFirst("copy:".count)
            UIPasteboard.general.string = string
        } else if (cmd.hasPrefix("print:")) {
            // print result of JS file:
            var string = cmd
            string.removeFirst("print:".count)
            if (thread_stdout_copy != nil) {
                fputs(string, thread_stdout_copy)
            }
        } else if (cmd.hasPrefix("print_error:")) {
            // print result of JS file:
            var string = cmd
            string.removeFirst("print_error:".count)
            if (thread_stderr_copy != nil) {
                fputs(string, thread_stderr_copy)
            }
        } else if (cmd.hasPrefix("reload:")) {
            // Reload the web page:
            webView?.reloadFromOrigin()
        } else if (cmd.hasPrefix("setHomeDir:")) {
            NSLog("Kitura: setHomeDir received")
            let documentsUrl = try! FileManager().url(for: .documentDirectory,
                                                      in: .userDomainMask,
                                                      appropriateFor: nil,
                                                      create: true)
            let homeurl = documentsUrl.deletingLastPathComponent();
            webView?.evaluateJavaScript("window.homedir = '\(homeurl)';")
            
        } /* else if (cmd.hasPrefix("JS Error:")) {
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
               // NSLog("JavaScript message: \(message.body)")
               // print("JavaScript message: \(message.body)")
           }
    }
    
    func storeBookmark(fileURL: URL) {
        // Store the bookmark for this object:
        do {
            let fileBookmark = try fileURL.bookmarkData(options: [],
                                                        includingResourceValuesForKeys: nil,
                                                        relativeTo: nil)
            let storedBookmarksDictionary =  UserDefaults.standard.dictionary(forKey: "fileBookmarks") ?? [:]
            // let groupBookmarksDictionary = UserDefaults(suiteName: "group.AsheKube.a-Shell")?.dictionary(forKey: "fileBookmarks")
            // if (groupBookmarksDictionary != nil) {
            //     storedBookmarksDictionary.merge(groupBookmarksDictionary!, uniquingKeysWith: { (current, _) in current })
            // }
            var mutableBookmarkDictionary : [String:Any] = storedBookmarksDictionary
            mutableBookmarkDictionary.updateValue(fileBookmark, forKey: fileURL.path)
            UserDefaults.standard.set(mutableBookmarkDictionary, forKey: "fileBookmarks")
            UserDefaults(suiteName: "group.AsheKube.a-Shell")?.set(mutableBookmarkDictionary, forKey: "fileBookmarks")
        }
        catch {
            NSLog("Could not bookmark this file: \(fileURL)")
        }
    }
    
    func storeName(fileURL: URL, name: String) {
        var storedNamesDictionary = UserDefaults.standard.dictionary(forKey: "bookmarkNames") ?? [:]
        // let groupNamesDictionary = UserDefaults(suiteName: "group.AsheKube.a-Shell")?.dictionary(forKey: "bookmarkNames")
        // if (groupNamesDictionary != nil) {
        //     storedNamesDictionary.merge(groupNamesDictionary!, uniquingKeysWith: { (current, _) in current })
        // }
        // Does "name" alrady exist? If so create a unique name:
        var newName = name
        var counter = 0
        var existingURLPath = storedNamesDictionary[newName]
        while (existingURLPath != nil) {
            let existingPath = existingURLPath as! String
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
        UserDefaults(suiteName: "group.AsheKube.a-Shell")?.set(mutableNamesDictionary, forKey: "bookmarkNames")
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
                    let prefix = fileURL.scheme ?? ""
                    commandSent.removeFirst(prefix.count + 1)
                    if (commandSent.hasPrefix("//")) {
                        commandSent.removeFirst("//".count)
                    }
                    commandSent = commandSent.removingPercentEncoding!
                    // Set working directory to a safer place (also used by URL calls and extension shortcuts):
                    closeAfterCommandTerminates = false
                    if let closeAtEnd = userActivity.userInfo!["closeAtEnd"] as? String {
                        if (closeAtEnd == "true") {
                            closeAfterCommandTerminates = true
                        }
                    }
                    // Display the shortcut on screen:
                    DispatchQueue.main.async {
                        self.terminalView?.feed(text: "Executing Shortcut: \(commandSent.replacingOccurrences(of: "\n", with: "\n\r"))")
                    }
                    NSLog("Command to execute: " + commandSent)
                    executeCommand(command: commandSent)
                }
            }
        }
    }
    
    func scene(_ scene: UIScene, didUpdate userActivity: NSUserActivity) {
        NSLog("Scene, didUpdate: userActivity.activityType = \(userActivity.activityType)")
    }
    
    func restoreFontVariables(scene: UIScene) {
        // If there is no userInfo and no stateRestorationActivity:
        // On the first run, one of these are null, so we return.
        guard (scene.session.stateRestorationActivity != nil) else { return }
        guard let userInfo = scene.session.stateRestorationActivity!.userInfo else { return }
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
        if let fontLigature = userInfo["fontLigature"] as? String {
            terminalFontLigature = fontLigature
        }
    }
    
    func restoreHistoryAndDirectories(scene: UIScene) {
        if let userInfo = scene.session.stateRestorationActivity?.userInfo {
            NSLog("Restoring history, previousDir, currentDir:")
            if let historyData = userInfo["history"] {
                history = historyData as! [String]
            } else {
                history = UserDefaults.standard.array(forKey: "history") as? [String] ?? []
            }
            historyPosition = history.count
            directoriesUsed = UserDefaults.standard.dictionary(forKey: "directoriesUsed") as? [String:Int] ?? [:]
            // NSLog("set history to \(history)")
            // NSLog("set directoriesUsed to \(directoriesUsed)")
            if let previousDirectoryData = userInfo["prev_wd"] {
                if let previousDirectory = previousDirectoryData as? String {
                    NSLog("got previousDirectory as \(previousDirectory)")
                    if (FileManager().fileExists(atPath: previousDirectory) && FileManager().isReadableFile(atPath: previousDirectory)) {
                        NSLog("set previousDirectory to \(previousDirectory)")
                        // Call cd_main instead of executeCommand("cd dir") to avoid closing a prompt and history.
                        ios_switchSession(self.persistentIdentifier?.toCString())
                        ios_setContext(UnsafeMutableRawPointer(mutating: self.persistentIdentifier?.toCString()))
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
                        ios_setContext(UnsafeMutableRawPointer(mutating: self.persistentIdentifier?.toCString()))
                        changeDirectory(path: currentDirectory) // call cd_main and checks secured bookmarked URLs
                    }
                }
            }
        }
    }
    
    func restoreEnvironment(scene: UIScene) {
        // We restore the environment variables to their previous values.
        // Useful for virtual Python environments
        // If the app was reinstalled, paths to files are not valid anymore, so we don't set them.
        // We never touch system environment variables like HOME and APPDIR.
        if let userInfo = scene.session.stateRestorationActivity?.userInfo {
            var path = String(utf8String: getenv( "PATH"))
            var pathChanged = false
            if let environmentVariables = userInfo["environ"] as? [String] {
                var virtualEnvironmentGone = false
                for variable in environmentVariables {
                    let components = variable.split(separator:"=", maxSplits: 1)
                    if components.count <= 0 { continue }
                    let name = String(components[0])
                    var value = ""
                    if (components.count >= 2) {
                        value = String(components[1])
                    }
                    if name == "HOME" { continue }
                    if name == "APPDIR" { continue }
                    // Don't override PATH, MANPATH, PERL5LIB, TZ...
                    // PATH itself will be dealt with separately
                    if (value.hasPrefix("/") && (value.contains(":"))) { continue }
                    // Don't override PERL_MB_OPT, PERL_MM_OPT, TERMINFO either:
                    if name == "PERL_MB_OPT" { continue }
                    if name == "PERL_MM_OPT" { continue }
                    if name == "TZ" { continue }
                    if name == "TERMINFO" { continue }
                    // Don't override APPVERSION and others:
                    if name == "APPNAME" { continue }
                    if name == "APPVERSION" { continue }
                    if name == "APPBUILDNUMBER" { continue }
                    // Do not restore SSH_AUTH_SOCK, since ssh-agent is not running anymore.
                    if name == "SSH_AUTH_SOCK" {
                        // Do not remove the old socket, as ssh-agent could still be running.
                        // unlink(value); // close the old socket
                        continue
                    }
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
                    // These are user-defined environment variables, we keep them:
                    setenv(name, value, 1)
                }
                // The virtual environment is not in the right place anymore, get the PATH variable back to the correct value
                if (virtualEnvironmentGone) {
                    unsetenv("_OLD_VIRTUAL_PATH")
                    unsetenv("_OLD_VIRTUAL_PS1")
                }
            }
            // Change in the default value for this variable:
            if let compileOptionsC = getenv("CCC_OVERRIDE_OPTIONS") {
                if let compileOptions = String(utf8String: compileOptionsC) {
                    if (compileOptions.isEqual("#^--target") || compileOptions.isEqual("#^--target=wasm32-wasi")) {
                        setenv("CCC_OVERRIDE_OPTIONS", "#^--target=wasm32-wasip1 ^-fwasm-exceptions +-lunwind", 1)
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
        }
    }
    
    func restartPreviousCommand(scene: UIScene) {
        if let userInfo = scene.session.stateRestorationActivity?.userInfo {
            // restart the current command if one was running before
            let currentCommandData = userInfo["currentCommand"]
            if let storedCommand = currentCommandData as? String {
                if (storedCommand.count > 0) {
                    // We only restart vim commands (and dash). Other commands are just creating issues, unless we could save their status.
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
                                NSLog("sceneDidBecomeActive, Restoring command: \(storedCommand)")
                                self.currentCommand = storedCommand
                                commandQueue.async {
                                    self.executeCommand(command: storedCommand)
                                }
                            }
                        } else {
                            NSLog("Could not find session file at \(sessionFile)")
                        }
                    } else if (storedCommand.hasPrefix("dash ")) || (storedCommand == "dash") {
                        if (UserDefaults.standard.bool(forKey: "restart_vim")) {
                            /* We only restart vim and dash commands, and only if the user asks for it.
                             Everything else is creating problems.
                             Basically, we can only restart commands if we can save their status. */
                            NSLog("sceneDidBecomeActive, Restoring command: \(storedCommand)")
                            self.currentCommand = storedCommand
                            commandQueue.async {
                                self.executeCommand(command: storedCommand)
                            }
                        }
                    }
                }
            }
        }
    }
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnecting:SceneSession` instead).
        // Use a UIHostingController as window root view controller
        // NSLog("Scene, willConnectTo session: \(connectionOptions)")
        NSLog("Scene, willConnectTo session.role: \(session.role)")
        if let windowScene = scene as? UIWindowScene {
            self.windowScene = windowScene
            let window = UIWindow(windowScene: windowScene)
            contentView = ContentView()
            // if session.role == .windowApplication {
            window.rootViewController = UIHostingController(rootView: contentView)
            window.autoresizesSubviews = true
            self.window = window
            window.makeKeyAndVisible()
            // if #available(iOS 16.0, *) {
            //     if session.role == .windowExternalDisplayNonInteractive {
            //         window.rootViewController = UIHostingController(rootView: contentView)
            //         window.autoresizesSubviews = true
            //         self.window = window
            //         window.makeKeyAndVisible()
            //     }
            // }
            self.persistentIdentifier = session.persistentIdentifier
            NSLog("Setting identifier to \(session.persistentIdentifier)")
            ios_switchSession(self.persistentIdentifier?.toCString())
            ios_setContext(UnsafeMutableRawPointer(mutating: self.persistentIdentifier?.toCString()));
            terminalView = contentView?.terminalview.view
            terminalView?.terminalDelegate = self
            terminalView?.isAccessibilityElement = true
            terminalView?.optionAsMetaKey = false
            // Is the app opened from a Shortcut?
            var startedFromShortcut = false
            for userActivity in connectionOptions.userActivities {
                if (userActivity.activityType == "AsheKube.app.a-Shell.ExecuteCommand") {
                    startedFromShortcut = true
                    break
                }
            }
            // printPrompt here doesn't work yet.
            if (!toolbarShouldBeShown) {
                showToolbar = false
                self.terminalView!.inputAccessoryView = self.emptyToolbar
                self.webView?.addInputAccessoryView(toolbar: self.emptyToolbar)
            } else {
                generateToolbarButtons()
                if (useSystemToolbar) {
                    self.terminalView!.inputAccessoryView = self.emptyToolbar
                    self.terminalView?.inputAssistantItem.leadingBarButtonGroups = self.leftButtonGroups
                    self.terminalView?.inputAssistantItem.trailingBarButtonGroups = self.rightButtonGroups
                    self.webView?.inputAssistantItem.leadingBarButtonGroups = self.leftButtonGroups
                    self.webView?.inputAssistantItem.trailingBarButtonGroups = self.rightButtonGroups
                } else {
                    self.terminalView!.inputAccessoryView = self.editorToolbar
                    self.webView?.addInputAccessoryView(toolbar: self.editorToolbar)
                }
                if #available(iOS 17, *) {
                    // Do not show the toolbar tip if the app has been started from a Shortcut:
                    if (!startedFromShortcut) {
                        // Do *not* show the toolbar tip if the user has already edited the toolbar
                        // (you can't show an old user a new tip)
                        if let documentsUrl = try? FileManager().url(for: .documentDirectory,
                                                                     in: .userDomainMask,
                                                                     appropriateFor: nil,
                                                                     create: true) {
                            let localConfigFile = documentsUrl.appendingPathComponent(".toolbarDefinition")
                            if !FileManager().fileExists(atPath: localConfigFile.path) {
                                NSLog("myToolbarTip status: \(myToolbarTip.status)")
                                Task { @MainActor in
                                    for await shouldDisplay in myToolbarTip.shouldDisplayUpdates {
                                        NSLog("myToolbarTip: \(shouldDisplay) status: \(myToolbarTip.status)")
                                        if shouldDisplay {
                                            if (self.terminalView != nil) {
                                                if (!useSystemToolbar) {
                                                    let controller = TipUIPopoverViewController(myToolbarTip, sourceItem: self.terminalView!.inputAccessoryView!)
                                                    controller.popoverPresentationController?.canOverlapSourceViewRect = true
                                                    let rootVC = self.window?.rootViewController
                                                    rootVC?.present(controller, animated: false)
                                                } else {
                                                    if let centerButton = terminalView?.inputAssistantItem.leadingBarButtonGroups.first?.barButtonItems.last {
                                                        NSLog("centerButton: \(centerButton)")
                                                        if let buttonView = centerButton.value(forKey: "view") as? UIView {
                                                            let controller = TipUIPopoverViewController(myToolbarTip, sourceItem: buttonView)
                                                            controller.popoverPresentationController?.canOverlapSourceViewRect = true
                                                            let rootVC = self.window?.rootViewController
                                                            rootVC?.present(controller, animated: false)
                                                            
                                                        }
                                                    }
                                                }
                                            }
                                        }  else {
                                            let rootVC = self.window?.rootViewController
                                            if let controller = rootVC?.presentedViewController {
                                                if controller is TipUIPopoverViewController {
                                                    controller.dismiss(animated: false)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            // The WkWebView used for browsing:
            webView = contentView?.webview.webView
            // add a contentController that is specific to each webview
            webView?.configuration.userContentController = WKUserContentController()
            webView?.configuration.userContentController.add(self, name: "aShell")
            webView?.navigationDelegate = self
            webView?.uiDelegate = self;
            webView?.isAccessibilityElement = true
            if #available(iOS 16.0, *) {
                webView?.isFindInteractionEnabled = true
            }
            
            if (appVersion != "a-Shell-mini") {
                webView?.load(URLRequest(url: URL(string: "https://localhost:8443/\(session.persistentIdentifier).html")!))
            } else {
                NSLog("Loding UUID.html from 8334 (sceneWillEnterForeground)")
                webView?.load(URLRequest(url: URL(string: "https://localhost:8334/wasm.html")!))
                // webView?.load(URLRequest(url: URL(string: "https://localhost:8334/\(session.persistentIdentifier).html")!))
            }
            // End WkWebView settings
            // Restore colors and settings from global preference (if set):
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
            if let ligature = UserDefaults.standard.value(forKey: "fontLigature") as? String {
                terminalFontLigature = ligature
            }
            // restore specific values for this scene:
            restoreFontVariables(scene: scene)
            // If .profile or .bashrc exist, load them:
            for configFileName in [".profile", ".bashrc"] {
                var configFileUrl = try! FileManager().url(for: .documentDirectory,
                                                           in: .userDomainMask,
                                                           appropriateFor: nil,
                                                           create: true)
                configFileUrl = configFileUrl.appendingPathComponent(configFileName)
                if (FileManager().fileExists(atPath: configFileUrl.path)) {
                    commandQueue.async {
                        do {
                            let contentOfFile = try String(contentsOf: configFileUrl, encoding: String.Encoding.utf8)
                            let commands = contentOfFile.split(separator: "\n")
                            ios_switchSession(self.persistentIdentifier?.toCString())
                            ios_setContext(UnsafeMutableRawPointer(mutating: self.persistentIdentifier?.toCString()));
                            thread_stdin  = nil
                            thread_stdout = nil
                            thread_stderr = nil
                            let stdin_pipe = Pipe()
                            self.stdin_file = fdopen(stdin_pipe.fileHandleForReading.fileDescriptor, "r")
                            let stdout_pipe = Pipe()
                            self.stdout_file = fdopen(stdout_pipe.fileHandleForWriting.fileDescriptor, "w")
                            // Call the following functions when data is written to stdout/stderr.
                            if (self.stdout_file != nil) {
                                stdout_pipe.fileHandleForReading.readabilityHandler = self.onStdout
                            }
                            self.stdout_active = true
                            // Make sure we're on the right session:
                            // Set COLUMNS to term width:
                            setenv("COLUMNS", "\(self.width)".toCString(), 1);
                            setenv("LINES", "\(self.height)".toCString(), 1);
                            ios_setWindowSize(Int32(self.width), Int32(self.height), self.persistentIdentifier?.toCString())
                            // Make sure we're running the right session
                            ios_setStreams(self.stdin_file, self.stdout_file, self.stdout_file)
                            for command in commands {
                                let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
                                if (trimmedCommand.count == 0) { continue } // skip white lines
                                if (trimmedCommand.hasPrefix("#")) { continue } // skip comments
                                // reset the LC_CTYPE (some commands (luatex) can change it):
                                setenv(" CTYPE", "UTF-8", 1);
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
                            NSLog("Could not load initialization file \(configFileName): \(error.localizedDescription)")
                        }
                    }
                }
            }
            // restore window content, using commandQueue so it happens after the .profile has been loaded:
            // also move the environment variables code here (separate function?)
            if UserDefaults.standard.bool(forKey: "keep_content") {
                // commandQueue so that it is executed after the .profile loading,
                // DispatchQueue.main because SwiftTerm can crash if it receives data outside the main queue.
                // Note: if the .profile prints something, we can see that something printed twice (once by the
                // .profile, once as part of the saved terminal content).
                commandQueue.async {
                    // print("terminalData:\n\(terminalData)\n--------")
                    DispatchQueue.main.async {
                        if let terminalData = scene.session.stateRestorationActivity?.userInfo?["terminal"] as? String {
                            self.terminalView?.getTerminal().feed(text: terminalData.replacingOccurrences(of: "\n", with: "\r\n"))
                            self.terminalView!.setPromptEnd()
                            self.windowPrintedContent = terminalData
                        }
                        self.restoreHistoryAndDirectories(scene: scene)
                        self.restoreEnvironment(scene: scene)
                    }
                }
            }
            // initialize command list for autocomplete (*after* loading the .profile):
            commandsArray = commandsAsArray() as! [String]
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
            // Was this window created with a purpose?
            // Case 1: url to open is inside urlContexts
            NSLog("connectionOptions.urlContexts: \(connectionOptions.urlContexts.first)")
            if let urlContext = connectionOptions.urlContexts.first {
                // let sendingAppID = urlContext.options.sourceApplication
                let fileURL = urlContext.url
                NSLog("url from urlContexts = \(fileURL)")
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
                            commandQueue.async {
                                changeDirectory(path: fileURL.path) // call cd_main and checks secured bookmarked URLs
                                self.closeAfterCommandTerminates = false
                            }
                        }
                    } else {
                        // Go through commandQueue so that the command is launched *after* the .profile is executed
                        self.closeAfterCommandTerminates = true
                        // It's a file
                        // TODO: customize the command (vim, microemacs, python, clang, TeX?)
                        commandQueue.async {
                            self.executeCommand(command: "vim " + (fileURL.path.removingPercentEncoding!.replacingOccurrences(of: " ", with: "\\ ")))
                        }
                    }
                } else if ((fileURL.scheme ?? "").hasPrefix("ashell")) {
                    // NSLog("We received an URL in willConnectTo: \(fileURL.absoluteString.removingPercentEncoding)") // received "ashell://ls"
                    var command = fileURL.absoluteString
                    command.removeFirst((fileURL.scheme ?? "").count + 1)
                    if (command.hasPrefix("//")) { // either ashell://command or ashell:command
                        command.removeFirst("//".count)
                    }
                    command = command.removingPercentEncoding!
                    closeAfterCommandTerminates = false
                    // We can't go through executeCommand because the window is not fully created yet.
                    // Same reason we can't print the shortcut that is about to be executed.
                    // Set the working directory to somewhere safe:
                    // (but do not reset afterwards, since this is a new window)
                    if let groupUrl = FileManager().containerURL(forSecurityApplicationGroupIdentifier:"group.AsheKube.a-Shell") {
                        changeDirectory(path: groupUrl.path)
                    }
                    commandQueue.async {
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
                // These two lines cause a crash in iOS 18:
                // NSLog("URL: \(userActivity.userInfo?["url"])")
                // NSLog("UserInfo: \(userActivity.userInfo)")
                if (userActivity.activityType == "AsheKube.app.a-Shell.EditDocument") {
                    self.closeAfterCommandTerminates = true
                    window.makeKeyAndVisible() // We need it a 2nd time for keyboard to resize itself.
                    commandQueue.async {
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
                    // This line causes a crash in iOS 18:
                    // NSLog("Scene, willConnectTo: userActivity.userInfo = \(userActivity.userInfo)")
                    if let groupUrl = FileManager().containerURL(forSecurityApplicationGroupIdentifier:"group.AsheKube.a-Shell") {
                        changeDirectory(path: groupUrl.path)
                    }
                    if let fileURL: NSURL = userActivity.userInfo!["url"] as? NSURL {
                        // single command:
                        if var commandSent = fileURL.absoluteString {
                            commandSent.removeFirst((fileURL.scheme ?? "").count + 1)
                            if (commandSent.hasPrefix("//")) {
                                commandSent.removeFirst("//".count)
                            }
                            commandSent = commandSent.removingPercentEncoding!
                            closeAfterCommandTerminates = false
                            if let closeAtEnd = userActivity.userInfo!["closeAtEnd"] as? String {
                                if (closeAtEnd == "true") {
                                    closeAfterCommandTerminates = true
                                }
                            }
                            DispatchQueue.main.async {
                                // print the shortcut:
                                self.terminalView?.feed(text: "Executing Shortcut: \(commandSent.replacingOccurrences(of: "\n", with: "\n\r"))")
                            }
                            commandQueue.async {
                                if let groupUrl = FileManager().containerURL(forSecurityApplicationGroupIdentifier:"group.AsheKube.a-Shell") {
                                    changeDirectory(path: groupUrl.path)
                                    NSLog("groupUrl: " + groupUrl.path)
                                }
                                self.executeCommand(command: commandSent)
                            }
                        }
                    }
                }
            }
            // iPads: re-activate long-press on arrow buttons when the toolbar appears:
            sceneIsInForeground = true
            if (useSystemToolbar && showToolbar) {
                NotificationCenter.default.addObserver(
                    forName: UIResponder.keyboardWillChangeFrameNotification,
                    object: nil,
                    queue: nil
                ) { (notification) in
                    NSLog("keyboardWillChangeFrame: \(notification.name.rawValue): \(session.persistentIdentifier).")
                    NSLog("activating the long press button timer, repets=false: \(self.activateLongPressForButtons())")
                }
            }
            if UserDefaults.standard.bool(forKey: "keep_content") {
                // if the window was not created with an intent, and we want to restore content,
                // we relaunch the previous command (only dash and vim)
                restartPreviousCommand(scene: scene)
            }
            NSLog("printing prompt, command: \(currentCommand)")
            if (currentCommand == "") {
                commandQueue.async {
                    self.printPrompt()
                }
            }
        }
    }
    
    
    func scene(_ scene: UIScene, openURLContexts: Set<UIOpenURLContext>) {
        NSLog("Calling openURLContexts with \(openURLContexts)")
        for urlContext in openURLContexts {
            // Is it one of our URLs?
            let fileURL = urlContext.url
            if ((fileURL.scheme ?? "").hasPrefix("ashell")) {
                NSLog("We received an URL in openURLContexts: \(fileURL.absoluteString.removingPercentEncoding)") // received "ashell://ls"
                if (UIDevice.current.model.hasPrefix("iPad")) {
                    // iPad, so always open a new window to execute the command
                    let activity = NSUserActivity(activityType: "AsheKube.app.a-Shell.ExecuteCommand")
                    activity.userInfo!["url"] = fileURL
                    // create a window and execute the command:
                    UIApplication.shared.requestSceneSessionActivation(nil, userActivity: activity, options: nil)
                } else {
                    // iPhone: create the command, send it to the window once it's created.
                    var command = fileURL.absoluteString
                    command.removeFirst((fileURL.scheme ?? "").count + 1)
                    if (command.hasPrefix("//")) {
                        command.removeFirst("//".count)
                    }
                    command = command.removingPercentEncoding!
                    commandQueue.async {
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
                        commandQueue.async {
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
                    commandQueue.async {
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
            } else if ((currentCommand == "isympy") || currentCommand.hasPrefix("isympy ")) {
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
            } else if ((currentCommand == "pico") || currentCommand.hasPrefix("pico ")) {
                exitCommand = "\u{0017}\u{0018}" // ^W ^X
            }
            if (exitCommand != "") {
                exitCommand += "\n"
                if let data = exitCommand.data(using: .utf8) {
                    ios_switchSession(self.persistentIdentifier?.toCString())
                    ios_setContext(UnsafeMutableRawPointer(mutating: self.persistentIdentifier?.toCString()))
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
    
    func overrideUserInterfaceStyle(style: UIUserInterfaceStyle) {
        DispatchQueue.main.async {
            self.window?.overrideUserInterfaceStyle = style
            self.overrideUserInterfaceStyle = style
        }
    }
    
    func setEnvironmentFGBG(foregroundColor: UIColor, backgroundColor: UIColor)  {
        // Are we in light mode or dark mode?
        // This could be improved now that we can be in a whole set of situations
        // If the user is running one window in light mode and one in dark mode,
        // it will be the same environment for both.
        // unless I make COLORFGBG a scene-dependent environment variable, like COLUMN and LINES.
        if (foregroundColor.getBrightness() > backgroundColor.getBrightness()) {
            // Dark mode
            setenv("COLORFGBG", "15;0", 1)
            if (UserDefaults.standard.string(forKey: "toolbar_color") == "screen") {
                overrideUserInterfaceStyle(style: .dark)
            }
        } else {
            // Light mode
            setenv("COLORFGBG", "0;15", 1)
            if (UserDefaults.standard.string(forKey: "toolbar_color") == "screen") {
                overrideUserInterfaceStyle(style: .light)
            }
        }
    }
    
    func activateLongPressForButtons() -> Bool {
        // Give it slight delay so the button views are actually present
        // Note: for some reasons, this doesn't work on iPad with external keyboards the first time the window is activated
        // (the gestures *are* added to the buttons, but the actions are not called when the user taps/long press)
        // It works fine after the first redisplay of the window.
        var returnValue = false
        if (!useSystemToolbar) {
            for button in editorToolbar.items! {
                if (title(button) == "up") || (title(button) == "down") || (title(button) == "left") || (title(button) == "right")
                    || title(button) == "up.down" || title(button) == "left.right" || title(button) == "up.down.left.right" {
                    if let buttonView = button.value(forKey: "view") as? UIView {
                        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.tapAction(_:)))
                        tapGesture.delegate = self
                        buttonView.addGestureRecognizer(tapGesture)
                        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(self.longPressAction(_:)))
                        longPressGesture.minimumPressDuration = 0.2 // 1 second press
                        longPressGesture.allowableMovement = 30 // 15 points
                        longPressGesture.delegate = self
                        buttonView.addGestureRecognizer(longPressGesture)
                        returnValue = true
                    }
                }
            }
        } else {
            if let leftButtonGroups = terminalView?.inputAssistantItem.leadingBarButtonGroups {
                for leftButtonGroup in leftButtonGroups {
                    for button in leftButtonGroup.barButtonItems {
                        if (title(button) == "up") || (title(button) == "down") || (title(button) == "left") || (title(button) == "right")
                            || title(button) == "up.down" || title(button) == "left.right" || title(button) == "up.down.left.right" {
                            if let buttonView = button.value(forKey: "view") as? UIView {
                                let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.tapAction(_:)))
                                tapGesture.delegate = self
                                buttonView.addGestureRecognizer(tapGesture)
                                let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(self.longPressAction(_:)))
                                longPressGesture.minimumPressDuration = 0.2 // 1 second press
                                longPressGesture.allowableMovement = 30 // 15 points
                                longPressGesture.delegate = self
                                buttonView.addGestureRecognizer(longPressGesture)
                                returnValue = true
                            }
                        }
                    }
                }
            }
            if let rightButtonGroups = terminalView?.inputAssistantItem.trailingBarButtonGroups {
                for rightButtonGroup in rightButtonGroups {
                    for button in rightButtonGroup.barButtonItems {
                        if (title(button) == "up") || (title(button) == "down") || (title(button) == "left") || (title(button) == "right")
                            || title(button) == "up.down" || title(button) == "left.right" || title(button) == "up.down.left.right" {
                            if let buttonView = button.value(forKey: "view") as? UIView {
                                // NSLog("activating long press for \(title(button)). view= \(buttonView)")
                                let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.tapAction(_:)))
                                tapGesture.delegate = self
                                buttonView.addGestureRecognizer(tapGesture)
                                let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(self.longPressAction(_:)))
                                longPressGesture.minimumPressDuration = 0.2 // 1 second press
                                longPressGesture.allowableMovement = 30 // 15 points
                                longPressGesture.delegate = self
                                buttonView.addGestureRecognizer(longPressGesture)
                                returnValue = true
                            }
                        }
                    }
                }
            }
        }
        return returnValue // did we activate the longpress action?
    }
    
    func activateLongPressForButtonsWithTimer() {
        // Give it slight delay so the button views are actually present
        // Note: for some reasons, this doesn't work on iPad with external keyboards the first time the window is activated
        // (the gestures *are* added to the buttons, but the actions are not called when the user taps/long press)
        // It works fine after the first redisplay of the window.
        if (sceneIsInForeground) {
            if (!activateLongPressForButtons()) {
                NSLog("Setting the buttons timer since it didn't work. ")
                // if it didn't work, make a timer to restart it regularly until it does
                // repeats: true because sometimes 0.5 s is not enough.
                activateButtonsTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [self]_ in
                    NSLog("Launching the buttons timer. ")
                    if activateLongPressForButtons() {
                        self.activateButtonsTimer.invalidate()
                    }
                }
            }
        }
    }
    
    @available(iOS 26, *)
    func preferredWindowingControlStyle(for windowScene: UIWindowScene) -> UIWindowScene.WindowingControlStyle {
        return .minimal
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
        NSLog("sceneDidBecomeActive: \(self.persistentIdentifier).")
        let traitCollection = terminalView!.traitCollection
        // Set scene parameters (unless they were set before)
        let backgroundColor = terminalBackgroundColor ?? UIColor.systemBackground.resolvedColor(with: traitCollection)
        let foregroundColor = terminalForegroundColor ?? UIColor.placeholderText.resolvedColor(with: traitCollection)
        let cursorColor = terminalCursorColor ?? UIColor.link.resolvedColor(with: traitCollection)
        // TODO: add font size and font name
        let fontSize = terminalFontSize ?? factoryFontSize
        let fontName = terminalFontName ?? factoryFontName
        let cursorShape = terminalCursorShape ?? factoryCursorShape
        let fontLigature = terminalFontLigature ?? factoryFontLigature
        // Force writing all config to term. Used when we changed many parameters.
        terminalView?.tintColor = foregroundColor
        terminalView?.caretColor = cursorColor
        terminalView?.backgroundColor = backgroundColor
        terminalView?.selectedTextBackgroundColor = cursorColor.makeTransparent()
        terminalView?.getTerminal().foregroundColor = foregroundColor.toSwiftTermColor()
        terminalView?.getTerminal().backgroundColor = backgroundColor.toSwiftTermColor()
        terminalView?.getTerminal().cursorColor = cursorColor.toSwiftTermColor()
        switch (cursorShape.lowercased()) {
        case "block":
            terminalView?.getTerminal().setCursorStyle(.blinkBlock)
        case "beam":
            terminalView?.getTerminal().setCursorStyle(.blinkBar)
        case "underline":
            terminalView?.getTerminal().setCursorStyle(.blinkUnderline)
        default:
            terminalView?.getTerminal().setCursorStyle(.blinkUnderline)
        }
        // TODO: Ligatures are enabled by default on iOS, they're a property of NSAttributeString, not the font.
        if let terminalFont = UIFont(name: fontName, size: CGFloat(fontSize)) {
            terminalView?.font = terminalFont
            basicCharWidth = NSAttributedString(string: "m", attributes: [.font: terminalView?.font]).size().width
        }
        setEnvironmentFGBG(foregroundColor: foregroundColor, backgroundColor: backgroundColor)
        if (showKeyboardAtStartup) {
            if let termView = self.terminalView {
                if !termView.isFirstResponder {
                    _ = termView.becomeFirstResponder()
                }
            }
        }
        // Delay the long-press-gesture a little so that the buttons have a view:
        NSLog("activating the long press button timer, repets=true")
        activateLongPressForButtonsWithTimer()
        // zoom gesture interferes with scroll gesture. Disabled for now.
        // let zoomGesture = UIPinchGestureRecognizer(target: self, action: #selector(zoomGestureHandler))
        // terminalView?.addGestureRecognizer(zoomGesture)
        let scrollGesture = UIPanGestureRecognizer(target: self, action: #selector(scrollGestureHandler))
        scrollGesture.minimumNumberOfTouches = 2
        terminalView?.addGestureRecognizer(scrollGesture)
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
        // Reload the webAssembly interpreter (this will also check if the local server is still running):
        sceneIsInForeground = true
        if (showWebView) {
            webView?.reloadFromOrigin()
        }
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
            self.terminalView!.inputAccessoryView = self.emptyToolbar
            self.webView!.addInputAccessoryView(toolbar: self.emptyToolbar)
        } else {
            generateToolbarButtons()
            if (useSystemToolbar) {
                self.terminalView!.inputAccessoryView = self.emptyToolbar
                self.terminalView?.inputAssistantItem.leadingBarButtonGroups = self.leftButtonGroups
                self.terminalView?.inputAssistantItem.trailingBarButtonGroups = self.rightButtonGroups
                self.webView?.inputAssistantItem.leadingBarButtonGroups = self.leftButtonGroups
                self.webView?.inputAssistantItem.trailingBarButtonGroups = self.rightButtonGroups
            } else {
                self.terminalView!.inputAccessoryView = self.editorToolbar
                self.webView?.addInputAccessoryView(toolbar: self.editorToolbar)
            }
            if #available(iOS 17, *) {
                NSLog("myToolbarTip status: \(myToolbarTip.status)")
                if (myToolbarTip.shouldDisplay) {
                    if (self.terminalView != nil) {
                        // TODO: re-check placement of tips
                        let controller = TipUIPopoverViewController(myToolbarTip, sourceItem: self.terminalView!)
                        controller.popoverPresentationController?.canOverlapSourceViewRect = true
                        let rootVC = self.window?.rootViewController
                        rootVC?.present(controller, animated: false)
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
        sceneIsInForeground = false
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
        // Store history and directories used in the UserDefaults (so new windows don't start with a blank state)
        UserDefaults.standard.set(history, forKey: "history")
        UserDefaults.standard.set(directoriesUsed, forKey: "directoriesUsed")
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
        if (terminalFontLigature != nil) {
            scene.session.stateRestorationActivity?.userInfo!["fontLigature"] = terminalFontLigature!
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
            } else if ((currentCommand == "dash") || currentCommand.hasPrefix("dash ")) {
                scene.session.stateRestorationActivity?.userInfo!["currentCommand"] = currentCommand // restore command is modified
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
        // Get only the last 50000 characters of printedContent.
        // An iPad pro screen is 5000 characters, so this is 10 screens of content.
        if (windowPrintedContent != nil) {
            scene.session.stateRestorationActivity?.userInfo!["terminal"] = windowPrintedContent
            // print("saved terminalData:\n\(windowPrintedContent)\n--------")
        }
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
        guard (terminalView != nil) else { return }
        terminalView?.isAccessibilityElement = value
    }
    
    func outputToTerminalView(string: String) {
        guard (terminalView != nil) else { return }
        // Only store what happens in the main buffer, not the alternate buffer
        if !self.terminalView!.getTerminal().isCurrentBufferAlternate {
            var shortString = string
            for controlCharacters in [escape + "[?47h", escape + "[?1047h", escape + "[?1049h"] {
                // if the string contains the switch to alternate buffer, only store characters up to that.
                if let alternateScreenRange = shortString.range(of: controlCharacters) {
                    shortString.removeSubrange(alternateScreenRange.lowerBound..<shortString.endIndex)
                    break // ? (unlikely that a string contains two of them, but do I want to risk it?)
                }
            }
            windowPrintedContent += shortString
            let characterCount = windowPrintedContent.count
            if (characterCount > 50000) {
                windowPrintedContent.removeFirst(characterCount - 50000)
            }
            // print("terminalData:\n\(windowPrintedContent)\n----------")
        }
        DispatchQueue.main.async {
            self.terminalView?.feed(text: string.replacingOccurrences(of:"\n", with: "\n\r")) // prints the string
        }
    }
    
    private func onStdoutButton(_ stdout: FileHandle) {
        if (!stdout_button_active) { return }
        let data = stdout.availableData
        guard (data.count > 0) else {
            return
        }
        if var string = String(data: data, encoding: String.Encoding.utf8) {
            // Remove all trailing \n\r (but keep those inside the string)
            if (string.contains(endOfTransmission)) {
                stdout_button_active = false
                string = string.replacingOccurrences(of: endOfTransmission, with: "")
            }
            while (string.hasSuffix("\n") || string.hasSuffix("\r")) {
                string.removeLast("\n".count)
            }
            if (terminalView != nil) && terminalView!.isFirstResponder {
                DispatchQueue.main.async {
                    self.terminalView?.send(txt: string)
                }
            } else if (webView?.url != nil) {
                // WebView:
                // Sanitize the output string to it can be sent to javascript:
                let parsedString = string.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\r", with: "\\r").replacingOccurrences(of: "\n", with: "\\n\\r")
                DispatchQueue.main.async {
                    // This works with CodeMirror and ACE:
                    // document.execCommand("insertText", false, "This is a test");
                    self.webView?.evaluateJavaScript("document.execCommand(\"insertText\", false, \"" + parsedString + "\");") { (result, error) in
                        if let error = error {
                            NSLog("Error in onStdoutButton; offending line = \(parsedString), error = \(error)")
                            // print(error)
                        }
                        // if let result = result { print(result) }
                    }
                }
            }
        }
    }
    
    private func onStdout(_ stdout: FileHandle) {
        if (!stdout_active) { return }
        var data = stdout.availableData
        if (extraBytes != nil) {
            data = extraBytes! + data
            extraBytes = nil
        }
        guard (data.count > 0) else {
            return
        }
        if let string = String(data: data, encoding: .utf8) {
            // NSLog("UTF8 string: \(string)")
            outputToTerminalView(string: string)
            if (string.contains(endOfTransmission)) {
                // NSLog("Received ^D, stopping writing")
                stdout_active = false
            }
        } else {
            // Unable to convert to UTF8. Usually because the data block cuts in the middle of an UTF8 character.
            // We cut at the closest character, and store the end of the data block to append at the beginning
            // of the next block.
            // This might cause "combined" emojis to be split
            let max = data.count
            var conversionFound = false
            for i in 0...max-1 {
                if let string = String(data: data.prefix(max - i), encoding: .utf8) {
                    conversionFound = true
                    outputToTerminalView(string: string)
                    if (string.contains(endOfTransmission)) {
                        stdout_active = false
                    } else {
                        extraBytes = data.suffix(i)
                    }
                    break
                }
            }
            // With some commands (pdflatex), UTF8 decoding of the output didn't work.
            // In the tests, .isoLatin1 worked, .ascii didn't.
            // This selection of encodings covers all non-Unicode. Tested on iOS 16 and iOS 18.
            if (!conversionFound) {
                for encoding in [String.Encoding.isoLatin1, .isoLatin2, .iso2022JP, .japaneseEUC, .macOSRoman, .shiftJIS, .windowsCP1250, .nonLossyASCII, .ascii] {
                    if let string = String(data: data, encoding: encoding) {
                        conversionFound = true
                        outputToTerminalView(string: string)
                        if (string.contains(endOfTransmission)) {
                            stdout_active = false
                        }
                        break
                    }
                }
            }
            // Last resort solution: go through the data, byte by byte.
            // We lose multi-byte UTF8 decoding, but we won't have it anyway.
            if (!conversionFound) {
                // NSLog("Couldn't convert data in stdout using any encoding, resorting to raw decoding.");
                var outputString = ""
                data.forEach { character in
                    let characterEncoded = String(Character(UnicodeScalar(character)))
                    outputString += characterEncoded
                    if (characterEncoded == endOfTransmission) {
                        stdout_active = false
                    }
                }
                outputToTerminalView(string: outputString)
            }
        }
    }

}
    
extension SceneDelegate: AVPlayerViewControllerDelegate {
    func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController){
        NSLog("playerViewControllerWillStartPictureInPicture")
        avControllerPiPEnabled = true
    }
    
    func playerViewControllerWillStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
        NSLog("playerViewControllerWillStopPictureInPicture")
        avControllerPiPEnabled = false
    }
    
    func playerViewControllerRestoreUserInterfaceForPictureInPictureStop(_ playerViewController: AVPlayerViewController) async {
        NSLog("playerViewControllerRestoreUserInterfaceForPictureInPictureStop")
    }
    
    func playerViewController(_ playerViewController: AVPlayerViewController,
                              restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        present(playerViewController, animated: false) {
            completionHandler(true)
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
        rootVC?.present(alertController, animated: false, completion: nil)
    }
    
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        commandQueue.async {
            let cred = URLCredential(trust: challenge.protectionSpace.serverTrust!)
            completionHandler(.useCredential, cred)
        }
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
        rootVC?.present(alertController, animated: false, completion: nil)
    }
    
    func fileDescriptor(input: String) -> Int32? {
        guard let fd = Int32(input) else {
            return nil
        }
        NSLog("fileDescriptor: input \(input) fd= \(fd)")
        if (fd == 0) {
            if (thread_stdin_copy != nil) {
                let f = fileno(thread_stdin_copy)
                NSLog("fileDescriptor: f= \(f)")
                if (f >= 0) {
                    return f
                } else {
                    return nil
                }
            } else {
                return nil
            }
        }
        if (fd == 1) {
            if (thread_stdout_copy != nil) {
                let f = fileno(thread_stdout_copy)
                NSLog("fileDescriptor: f= \(f) thread_stdout_copy= \(thread_stdout_copy)")
                if (f >= 0) {
                    return f
                } else {
                    return nil
                }
            } else {
                return nil
            }
        }
        if (fd == 2) {
            if (thread_stderr_copy != nil) {
                let f = fileno(thread_stderr_copy)
                if (f >= 0) {
                    return f
                } else {
                    return nil
                }
            } else {
                return nil
            }
        }
        return fd
    }
    
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        // communication with libc from webAssembly:
        let arguments = prompt.components(separatedBy: "\n")
        // NSLog("prompt: \(prompt)")
        // NSLog("thread_stdin_copy: \(thread_stdin_copy)")
        // NSLog("thread_stdout_copy: \(thread_stdout_copy)")
        let title = arguments[0]
        if (title == "libc") {
            // Make sure we are on the right iOS session. This resets the current working directory.
            if (arguments[1] != "read") && (arguments[1] != "write") {
                NSLog("prompt: \(prompt.replacingOccurrences(of: "\n", with: " "))")
            }
            ios_switchSession(self.persistentIdentifier?.toCString())
            ios_setContext(UnsafeMutableRawPointer(mutating: self.persistentIdentifier?.toCString()));
            if (arguments[1] == "open") {
                // NSLog("opening file: \(arguments[2])")
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
                    if (((thread_stdin_copy != nil) && (fd == fileno(thread_stdin_copy))) ||
                        ((thread_stdout_copy != nil) && (fd == fileno(thread_stdout_copy))) ||
                        ((thread_stderr_copy != nil) && (fd == fileno(thread_stderr_copy)))) {
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
                                // NSLog("writing \(String(decoding: data, as: UTF8.self)) to fd \(fd)")
                                // let returnValue = write(fd, data, numValues)
                                let file = FileHandle(fileDescriptor: fd)
                                do {
                                    try file.seek(toOffset: offset)
                                }
                                catch {
                                    let error = error as NSError
                                    //  Objects that are not capable of seeking always write from the current position (man page of read)
                                    /*
                                    if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
                                        NSLog("Underlying error in seek for write: \(underlyingError)")
                                    }
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
                                // NSLog("wrote \(String(decoding: data, as: UTF8.self)) to fd \(fd)")
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
                    // arguments[5] = tty input
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
                        NSLog("sending back (Wasm): \(inputString)")
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
                            /*
                            if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
                                NSLog("Underlying error in seek: \(underlyingError)")
                            } */
                        }
                        do {
                            // check if there are numValues available in file?
                            // check if file is still open?
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
                    // NSLog("libc/read, sending string with \(data!.base64EncodedString().count) bytes")
                    completionHandler("\(data!.base64EncodedString())")
                } else {
                    // NSLog("libc_read: Sending nil string")
                    completionHandler("") // Did not read anything
                }
                return
            } else if (arguments[1] == "fstat") {
                if let fd = fileDescriptor(input: arguments[2]) {
                    let buf = stat.init()
                    let pbuf = UnsafeMutablePointer<stat>.allocate(capacity: 1)
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
                let pbuf = UnsafeMutablePointer<stat>.allocate(capacity: 1)
                pbuf.initialize(to: buf)
                // NSLog("stat: " + arguments[2])
                let returnValue = stat(arguments[2].utf8CString, pbuf)
                if (returnValue == 0) {
                    // NSLog("Mode: \(arguments[2]) = \(pbuf.pointee.st_mode) stat= \(pbuf.pointee)")
                    completionHandler("\(pbuf.pointee)")
                } else {
                    // NSLog("Error: \(arguments[2]) = " + String(cString: strerror(errno)))
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
                    // NSLog("readdir worked on \(arguments[2]), returned: \(returnString.count) bytes")
                    completionHandler(returnString.data(using: .utf8)?.base64EncodedString())
                }
                catch {
                    let error = (error as NSError)
                    //  NSLog("readdir failed, returned: \(error)")
                    if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
                        // NSLog("underlying error: \(underlyingError)")
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
                        completionHandler("\n\(-underlyingError.code)")
                    } else {
                        completionHandler("\n\(-error.code)")
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
                // NSLog("launching command: \(arguments[2])")
                // NSLog("Launch: \(self.thread_stdin_copy)  \(self.thread_stdout_copy) \(self.thread_stderr_copy)")
                thread_stdin = thread_stdin_copy
                thread_stdout = thread_stdout_copy
                thread_stderr = thread_stderr_copy
                if let editor_env = ios_getenv("EDITOR") {
                    let editor = String(cString: editor_env)
                    if (arguments[2].hasPrefix(editor + " ")) {
                        // a Wasm command (nnn) is trying to start the editor on a file.
                        // We need to be smart
                        // TODO: do this for all interactive commands.
                        completionHandler("0") // this returns to WebAssembly, then we leave the command:
                        let commandBeforeEdit = self.currentCommand
                        // executeCommandAndWait does not work, executeCommand works (but it prints one extra prompt)
                        // DispatchQueue works, it also works if we use a Timer, or both.
                        DispatchQueue.main.async {
                            self.executeCommand(command: arguments[2])
                            self.executeCommand(command: commandBeforeEdit)
                        }
                        webView.evaluateJavaScript("inputString += 'q';") { (result, error) in
                            if let error = error { print(error) }
                        }
                        stdinString += "q" // It takes around 0.2 seconds for the command to end
                        return
                    }
                }
                let pid = ios_fork()
                var result = ios_system(arguments[2].decomposedStringWithCanonicalMapping)
                ios_waitpid(pid)
                ios_releaseThreadId(pid)
                if (result == 0) {
                    // If there's already been an error (e.g. "command not found") no need to ask for more.
                    result = ios_getCommandStatus()
                }
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
                        // NSLog("utimensat, atime: \(atime) mtime: \(mtime)")
                        let returnVal = utimensat(fd, path, time, flag)
                        if (returnVal != 0) {
                            // NSLog("Error: " + String(cString: strerror(errno)))
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
                            // NSLog("futimes, atime: \(atime) mtime: \(mtime)")
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
            } else if (arguments[1] == "commandTerminated") {
                let returnCode = arguments[2]
                self.endWebAssemblyCommand(error: Int32(returnCode) ?? 0, message: arguments[3])
                completionHandler("done")
                return
            }
            // Not one of our commands:
            completionHandler("-1")
            return
        // End communication with webAssembly using libc
        // Start of JavaScriptCore extensions for interaction with filesystem
        } else if (title == "jsc") {
            // JSC extensions: readFile, writeFile...
            // Copied from the extensions in iOS_system, making them available to WkWebView JS interpreter.
            // Make sure we are on the right iOS session. This resets the current working directory.
            // TODO: that's one call to ios_switchSession. Reset?
            ios_switchSession(self.persistentIdentifier?.toCString())
            ios_setContext(UnsafeMutableRawPointer(mutating: self.persistentIdentifier?.toCString()));
            if (arguments[1] == "readFile") {
                do {
                    completionHandler(try String(contentsOf: URL(fileURLWithPath: arguments[2]), encoding: .utf8))
                }
                catch {
                    // failed UTF8 encoding:
                    do {
                        completionHandler(try String(contentsOf: URL(fileURLWithPath: arguments[2]), encoding: .ascii))
                    }
                    catch {
                        completionHandler(error.localizedDescription)
                    }
                }
                return
            } else if (arguments[1] == "readFileBase64") {
                do {
                    completionHandler(try NSData(contentsOf: URL(fileURLWithPath: arguments[2])).base64EncodedString())
                }
                catch {
                    completionHandler(error.localizedDescription)
                }
                return
            } else if (arguments[1] == "writeFile") {
                do {
                    var content = prompt
                    content.removeFirst(arguments[0].count + 1 + arguments[1].count + 1 + arguments[2].count + 1)
                    try content.write(toFile: arguments[2], atomically: true, encoding: String.Encoding.utf8)
                    completionHandler("0")
                }
                catch {
                    completionHandler("-1\n" + error.localizedDescription)
                }
                return
            } else if (arguments[1] == "writeFileBase64") {
                do {
                    if let data = Data(base64Encoded: arguments[3], options: .ignoreUnknownCharacters) {
                        try data.write(to: URL(fileURLWithPath: arguments[2]))
                        completionHandler("0")
                    }
                }
                catch {
                    completionHandler("-1\n" + error.localizedDescription)
                }
                return
            } else if (arguments[1] == "listFiles") {
                do {
                    let items = try FileManager().contentsOfDirectory(atPath: arguments[2])
                    var returnString = ""
                    for item in items {
                        returnString = returnString + item + "\n"
                    }
                    completionHandler(returnString)
                }
                catch {
                    completionHandler("\n" + error.localizedDescription)
                }
                return
            } else if (arguments[1] == "isFile") {
                var isDirectory: ObjCBool = false
                let isFile = FileManager().fileExists(atPath: arguments[2], isDirectory: &isDirectory)
                if (isFile && !isDirectory.boolValue) {
                    completionHandler("1")
                } else {
                    completionHandler("0")
                }
                return
            } else if (arguments[1] == "isDirectory") {
                var isDirectory: ObjCBool = false
                let isFile = FileManager().fileExists(atPath: arguments[2], isDirectory: &isDirectory)
                if (isFile && isDirectory.boolValue) {
                    completionHandler("1")
                } else {
                    completionHandler("0")
                }
                return
            } else if (arguments[1] == "makeFolder") {
                do {
                    try FileManager().createDirectory(atPath: arguments[2], withIntermediateDirectories: true)
                    completionHandler("0")
                }
                catch {
                    completionHandler("-1\n" + error.localizedDescription)
                }
                return
            } else if (arguments[1] == "delete") {
                do {
                    try FileManager().removeItem(atPath: arguments[2])
                    completionHandler("0")
                }
                catch {
                    completionHandler("-1\n" + error.localizedDescription)
                }
                return
            } else if (arguments[1] == "move") {
                do {
                    try FileManager().moveItem(atPath: arguments[2], toPath: arguments[3])
                    completionHandler("0")
                }
                catch {
                    completionHandler("-1\n" + error.localizedDescription)
                }
                return
            } else if (arguments[1] == "copy") {
                do {
                    try FileManager().copyItem(atPath: arguments[2], toPath: arguments[3])
                    completionHandler("0")
                }
                catch {
                    completionHandler("-1\n" + error.localizedDescription)
                }
                return
            } else if (arguments[1] == "fileSize") {
                do {
                    //return [FileAttributeKey : Any]
                    let attr = try FileManager.default.attributesOfItem(atPath: arguments[2])
                    completionHandler("\(attr[FileAttributeKey.size] as? UInt64 ?? 0)")
                } catch {
                    completionHandler("-1\n" + error.localizedDescription)
                }
                return
            } else if (arguments[1] == "system") {
                // NSLog("Launch: \(self.thread_stdin_copy)  \(self.thread_stdin_copy) \(self.thread_stdin_copy)")
                thread_stdin = thread_stdin_copy
                thread_stdout = thread_stdout_copy
                thread_stderr = thread_stderr_copy
                let pid = ios_fork()
                var result = ios_system(arguments[2].decomposedStringWithCanonicalMapping)
                ios_waitpid(pid)
                ios_releaseThreadId(pid)
                if (result == 0) {
                    // If there's already been an error (e.g. "command not found") no need to ask for more.
                    result = ios_getCommandStatus()
                }
                completionHandler("\(result)")  
                return
            } else if (arguments[1] == "pickDirectory") {
                completionHandler("\(FileManager().currentDirectoryPath)")
                return
            }
        }
        // End of JavaScriptCore extensions
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
        rootVC?.present(alertController, animated: false, completion: { () -> Void in
            // TODO: insert here some magical line that will restore focus to the window
            // makeFirstResponder and makeKeyboardActive don't work
        })
        // webView.allowDisplayingKeyboardWithoutUserAction()
    }


    // Debugging navigation:
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        // NSLog("navigationAction: \(navigationAction.request)")
        if navigationAction.targetFrame == nil {
            webView.stopLoading()
            webView.load(navigationAction.request)
        }
        return nil
    }
    
    func webView(_ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        // NSLog("decidePolicyFor WKNavigationResponse: \(navigationResponse)")
        // NSLog("decidePolicyFor, url requested: \((navigationResponse.response as? HTTPURLResponse)?.url)")
        // NSLog("decidePolicyFor, webView.url?.path: \(webView.url?.path)")
        guard let statusCode
                = (navigationResponse.response as? HTTPURLResponse)?.statusCode else {
            // NSLog("decidePolicyFor: no http status code to act on")
            // if there's no http status code to act on, exit and allow navigation
            decisionHandler(.allow)
            return
        }
        if statusCode >= 400 {
            // NSLog("decidePolicyFor: status code: \(statusCode)")
            if let requestedUrl = (navigationResponse.response as? HTTPURLResponse)?.url {
                if (!requestedUrl.isFileURL
                    && (requestedUrl.host == "127.0.0.1" || requestedUrl.host == "localhost")
                    && requestedUrl.path == "/wasm.html") {
                    NSLog("failed to load wasm.html, restarting the server")
                    // if statusCode != 200..299 restart the server.
                    decisionHandler(.cancel)
                    startLocalWebServer()
                    // and reload the wasmWebView:
                    webView.reloadFromOrigin()
                    return
                }
            }
            decisionHandler(.cancel)
            return
        }
        // NSLog("decidePolicyFor: status code: \(statusCode)")
        decisionHandler(.allow)
    }

    
    // iOS 14: allow javascript evaluation
    func webView(_ webView: WKWebView,
          decidePolicyFor navigationAction: WKNavigationAction,
              preferences: WKWebpagePreferences,
              decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
        // NSLog("decidePolicyFor WKNavigationAction, navigationType= \(navigationAction.navigationType)")
        navigationType = navigationAction.navigationType
        if #available(iOS 14.0, *) {
            preferences.allowsContentJavaScript = true // The default value is true, but let's make sure.
        }
        // NSLog("decidePolicyFor webView.url?.path: \(webView.url?.path)")
        decisionHandler(.allow, preferences)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        NSLog("finished loading, title= \(webView.title ?? "unknown"), host= \(webView.url?.host) path=\(webView.url?.path ?? "unknown"), navigation= \(navigation)")
        if (webView.url?.host == "localhost") && (webView.url?.path == "/wasm.html") {
            // host=="localhost" && path == "/wasm.html" --> make the terminal active
            // NSLog("Back to the terminal. showWebView: \(showWebView)")
        }
        if (webView.title != nil) && (webView.title != "") {
            title = webView.title
        } else {
            title = webView.url?.lastPathComponent
        }
    }
}
