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
let factoryFontLigature = "contextual" // normal has a bug, so contextual by default
var stdinString: String = ""
var lastKey: Character?
var lastKeyTime: Date = Date(timeIntervalSinceNow: 0)
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

var commandsStack: [javascriptCommand?] = []
var resultStack: [Int32?] = []

class SceneDelegate: UIViewController, UIWindowSceneDelegate, WKNavigationDelegate, WKScriptMessageHandler, UIDocumentPickerDelegate, UIPopoverPresentationControllerDelegate, UIFontPickerViewControllerDelegate, UIDocumentInteractionControllerDelegate, UIGestureRecognizerDelegate {
    var window: UIWindow?
    var screen: UIScreen?
    var windowScene: UIWindowScene?
    var webView: Webview.WebViewType?
    var wasmWebView: WKWebView? // webView for executing wasm
    var contentView: ContentView?
    var history: [String] = []
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
    // copies of thread_std*, used when inside a sub-thread, for example executing webAssembly
    var thread_stdin_copy: UnsafeMutablePointer<FILE>? = nil
    var thread_stdout_copy: UnsafeMutablePointer<FILE>? = nil
    var thread_stderr_copy: UnsafeMutablePointer<FILE>? = nil
    // var keyboardTimer: Timer!
    private let commandQueue = DispatchQueue(label: "executeCommand", qos: .utility) // low priority, for executing commands
    private var javascriptRunning = false // We can't execute JS while we are already executing JS.
    private var executeWebAssemblyCommandsRunning = false // We can't execute JS while we are already executing JS.
    // Buttons and toolbars:
    var controlOn = false;
    // control codes:
    let interrupt = "\u{0003}"  // control-C, used to kill the process
    let endOfTransmission = "\u{0004}"  // control-D, used to signal end of transmission
    let escape = "\u{001B}"
    let carriageReturn = "\u{000D}" // carriage return
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
    var terminalFontLigature: String?
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
    
    private func title(_ button: UIBarButtonItem) -> String? {
        var title: String? = nil
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
            if (title.hasSuffix("\\n")) {
                title.removeLast("\\n".count)
                sendCarriageReturn = true
            }
            DispatchQueue.main.async {
                self.webView?.evaluateJavaScript("window.term_.io.onVTKeystroke(\"" + title + "\");") { (result, error) in
                    // if let error = error { print(error) }
                    // if let result = result { print(result) }
                }
                if (sendCarriageReturn) {
                    self.webView?.evaluateJavaScript("window.term_.io.onVTKeystroke(\"" + "\\r" + "\");") { (result, error) in
                        // if let error = error { print(error) }
                        // if let result = result { print(result) }
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
            ios_system(command)
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
            close(stdout_pipe.fileHandleForWriting.fileDescriptor)
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
    
    @objc private func systemAction(_ sender: UIBarButtonItem) {
        if let title = title(sender) {
            if (title == "paste") {
                if let pastedString = UIPasteboard.general.string {
                    // NSLog("Sending text to paste: \(pastedString)")
                    webView?.paste(pastedString)
                }
                return
            }
            var commandString: String? = nil
            switch (title) {
            case "up":
                commandString = "window.term_.io.onVTKeystroke((!window.term_.keyboard.applicationCursor) ? '\\x1b[A' : '\\x1bOA');"
                break
            case "down":
                commandString = "window.term_.io.onVTKeystroke((!window.term_.keyboard.applicationCursor) ? '\\x1b[B' : '\\x1bOB');"
                break
            case "left":
                commandString = "window.term_.io.onVTKeystroke((!window.term_.keyboard.applicationCursor) ? '\\x1b[D' : '\\x1bOD');"
                break
            case "right":
                commandString = "window.term_.io.onVTKeystroke((!window.term_.keyboard.applicationCursor) ? '\\x1b[C' : '\\x1bOC');"
                break
            case "copy":
                commandString = "window.term_.copySelectionToClipboard();"
                break
            case "cut":
                commandString = "window.term_.onCut();"
                break
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
                break
            default:
                break
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
@objc func generateToolbarButtons() {
        // check issue with screen size and pico.
        // Scan the configuration file to generate the button groups:
        var configFile = Bundle.main.resourceURL?.appendingPathComponent("defaultToolbar.txt")
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
                                NSLog("Storing: \(commandRegex) for tag: \(activeTag)")
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
                        button!.possibleTitles = ["", String(buttonParts[2]).replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "'", with: "\\'")]
                    } else {
                        button!.possibleTitles = ["", String(buttonParts[2])]
                    }
                    button!.tag = activeTag
                    if #available(iOS 16.0, *) {
                        if (activeTag != 0) && (activeTag != noneTag) {
                            button!.isHidden = true
                        }
                    }
                    activeButtonGroup.append(button!)
                }
                rightButtonGroup.append(contentsOf: activeButtonGroup)
                rightButtonGroups.append(UIBarButtonItemGroup(barButtonItems: activeButtonGroup, representativeItem: nil))
            }
        }
    }
    
    @objc func showEditorToolbar() {
        generateToolbarButtons()
        // NSLog("leftButtonGroup: \(leftButtonGroup)")
        // NSLog("rightButtonGroup: \(rightButtonGroup)")
        DispatchQueue.main.async {
            if (useSystemToolbar) {
                showToolbar = false
                self.webView?.addInputAccessoryView(toolbar: self.emptyToolbar)
                self.webView?.inputAssistantItem.leadingBarButtonGroups = self.leftButtonGroups
                self.webView?.inputAssistantItem.trailingBarButtonGroups = self.rightButtonGroups
            } else {
                showToolbar = true
                self.webView?.inputAssistantItem.leadingBarButtonGroups = []
                self.webView?.inputAssistantItem.trailingBarButtonGroups = []
                self.webView?.addInputAccessoryView(toolbar: self.editorToolbar)
            }
        }
    }
    
    func continuousButtonAction(_ button: UIBarButtonItem)  {
        let ms: UInt32 = 1000
        if (title(button) == "up") || (title(button) == "down") {
            while (continuousButtonAction) {
                systemAction(button)
                usleep(250 * ms)
            }
        } else if (title(button) == "left") || (title(button) == "right") {
            while (continuousButtonAction) {
                systemAction(button)
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
        if (sender.state == .began) {
            // NSLog("long press detected: \(location)")
            // NSLog("sender of long press: \(sender)")
            for button in editorToolbar.items! {
                if let buttonView = button.value(forKey: "view") as? UIView {
                    if (location.x >= buttonView.frame.minX) && (location.x <= buttonView.frame.maxX) {
                        // NSLog("Long press on button: \(button)")
                        continuousButtonAction = true
                        commandQueue.async {
                            // this function contains a sleep() call.
                            // We need to prevent the entire program from sleeping,
                            // so we run it in a queue.
                            self.continuousButtonAction(button)
                        }
                        return
                    }
                }
            }
        }
        if (continuousButtonAction) {
            return
        }
        // Not on any button, must be a hidekeyboard event:
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
        toolbar.items = leftButtonGroup
        toolbar.items?.append(UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: self, action: nil))
        toolbar.items?.append(contentsOf: rightButtonGroup)
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
                /* if let error = error {
                    NSLog("Error in executing window.commandRunning = ''; = \(error)")
                }
                if let result = result {
                    NSLog("Result of executing window.commandRunning = ''; = \(result)")
                } */
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
        let commandNumber = Int(webAssemblyCommandOrder() - 1)
        NSLog("WebAssembly command position: \(commandNumber)")
        while (commandsStack.count <= commandNumber) {
            commandsStack.append(nil)
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
        NSLog("Entered webAssemblyCommand: \(argumentString) at position: \(commandNumber) = \(commandsStack.count) ")
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
        let javascript = "executeWebAssembly(\"\(base64string)\", " + argumentString + ", \"" + currentDirectory + "\", \(ios_isatty(STDIN_FILENO)), " + environmentAsJSDictionary + ")"
        
        var webAssemblyCommand = javascriptCommand()
        webAssemblyCommand.jsCommand = javascript
        webAssemblyCommand.thread_stdin_copy = thread_stdin
        webAssemblyCommand.thread_stdout_copy = thread_stdout
        webAssemblyCommand.thread_stderr_copy = thread_stderr
        webAssemblyCommand.webAssemblyGroup = DispatchGroup()
        webAssemblyCommand.originalCommand = argumentString
        NSLog("Created webAssemblyCommand: \(argumentString) at position: \(commandNumber) stdout:\(thread_stdout) == \(fileno(thread_stdout))")
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
        
        if (fileno(webAssemblyCommand.thread_stdout_copy) != fileno(stdout_file)) {
            fclose(webAssemblyCommand.thread_stdout_copy)
        }
        
        return (resultStack[commandNumber]!)
    }
    
    func executeWebAssemblyCommands() {
        // since we're multi-threaded, we could be executing this while executeWebAssembly() is still running. So we wait.
        //
        NSLog("Starting executeWebAssemblyCommands, commands: \(commandsStack.count) results: \(resultStack)")
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
            var errorCode:Int32 = 0
            javascriptRunning = true
            let javascriptGroup = DispatchGroup()
            javascriptGroup.enter()
            DispatchQueue.main.async {
                self.thread_stdin_copy = command!.thread_stdin_copy
                self.thread_stdout_copy = command!.thread_stdout_copy
                self.thread_stderr_copy = command!.thread_stderr_copy
                stdinString = "" // reinitialize stdin
                NSLog("Executing \(command!.originalCommand) in executeWebAssComm, position= \(commandsStack.count)")
                self.wasmWebView?.evaluateJavaScript(command!.jsCommand) { (result, error) in
                    // NSLog("webassembly command returned: \(result)")
                    if let error = error {
                        if (self.thread_stderr_copy != nil) {
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
                        }
                        print(error)
                        errorCode = -1
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
                                if (self.thread_stderr_copy != nil) {
                                    fputs(errorMessage, self.thread_stderr_copy);
                                }
                            }
                        } else if let string = result as? String {
                            if (self.thread_stdout_copy != nil) {
                                fputs(string, self.thread_stdout_copy);
                            }
                        }
                    }
                    self.javascriptRunning = false
                    javascriptGroup.leave()
                }
            }
            // force synchronization:
            javascriptGroup.wait()
            resultStack[position] = errorCode

            if (thread_stdin_copy == nil) {
                // Strangely, the letters typed after ^D do not appear on screen. We force two carriage return to get the prompt visible:
                webView?.evaluateJavaScript("window.term_.io.onVTKeystroke(\"\\n\\n\"); window.term_.io.currentCommand = '';") { (result, error) in
                    // if let error = error { print(error) }
                    // if let result = result { print(result) }
                }
            }
            // Do not close thread_stdin because if it's a pipe, processes could still be writing into it
            // fclose(thread_stdin)
            
            command!.webAssemblyGroup?.leave()
        }
        NSLog("Ended executeWebAssemblyCommands, commands: \(commandsStack.count) results: \(resultStack)")
        
        executeWebAssemblyCommandsRunning = false
    }
        
    func printJscUsage() {
        fputs("Usage: jsc [--in-window] [--silent] file.js\nExecutes JavaScript file.js.\n--in-window: runs inside the main window (can change terminal appearance or behaviour; use with caution).\n--silent: do not print the result of the JavaScript execution.\n", thread_stdout)
    }
    
    func executeJavascript(arguments: [String]?) {
        guard (arguments != nil) else {
            printJscUsage()
            return
        }
        guard ((arguments!.count <= 4) && (arguments!.count > 1)) else {
            printJscUsage()
            return
        }
        var command = arguments![1]
        var silent = false
        var jscWebView = wasmWebView
        for argument in arguments! {
            if (argument == "--in-window") {
                jscWebView = webView
            }
            if (argument == "--silent") {
                silent = true
            }
            if (!argument.hasPrefix("--")) {
                command = argument
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
        if (terminalFontLigature == nil) {
            fputs(" ligatures: " + factoryFontLigature, thread_stdout)
        } else {
            fputs(" ligatures: " + terminalFontLigature!, thread_stdout)
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
        let fontLigature = terminalFontLigature ?? factoryFontLigature
        // Force writing all config to term. Used when we changed many parameters.
        var command = "window.term_.setForegroundColor('" + foregroundColor.toHexString() + "'); window.term_.setBackgroundColor('" + backgroundColor.toHexString() + "'); window.term_.setCursorColor('" + cursorColor.toHexString() + "'); window.fontSize = \(fontSize); window.term_.setFontSize(\(fontSize)); window.term_.setFontFamily('\(fontName)'); window.term_.setCursorShape('\(cursorShape)'); window.term_.scrollPort_.screen_.style.fontVariantLigatures = '\(fontLigature)';"
        DispatchQueue.main.async {
            self.webView?.evaluateJavaScript(command) { (result, error) in
                if let error = error {
                    print(error)
                }
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
    
    func configWindow(fontSize: Float?, fontName: String?, backgroundColor: UIColor?, foregroundColor: UIColor?, cursorColor: UIColor?, cursorShape: String?, fontLigature: String?) {
        if (fontSize != nil) {
            terminalFontSize = fontSize
            let fontSizeCommand = "window.fontSize = \(fontSize!); window.term_.setFontSize(\(fontSize!));"
            DispatchQueue.main.async {
                self.webView?.evaluateJavaScript(fontSizeCommand) { (result, error) in
                    if let error = error { print(error) }
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
                        if let error = error { print(error) }
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
                        if let error = error { print(error) }
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
                    if let error = error { print(error) }
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
                    if let error = error { print(error) }
                    // if let result = result { print(result) }
                }
            }
        }
        if (cursorShape != nil) {
            terminalCursorShape = cursorShape
            let terminalColorCommand = "window.term_.setCursorShape(\"\(cursorShape!)\");"
            DispatchQueue.main.async {
                self.webView?.evaluateJavaScript(terminalColorCommand) { (result, error) in
                    if let error = error { print(error) }
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
        if (fontLigature != nil) {
            terminalFontLigature = fontLigature
            let terminalFontLigatureCommand = "window.term_.scrollPort_.screen_.style.fontVariantLigatures = '\(fontLigature!)';"
            DispatchQueue.main.async {
                self.webView?.evaluateJavaScript(terminalFontLigatureCommand) { (result, error) in
                    if let error = error { print(error) }
                    // if let result = result { print(result) }
                }
            }
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
        // "normal" commands can go through ios_system
        // We use a queue to allow the system to continue running (important for commands that interact with the system, such as "config -n" and "view".
        // Test: moved the commandQueue *upwards* to help with pipe generation and StageManager (?)
        // If that's the issue with StageManager, then should I move commandQueue *inside* these commands?
        commandQueue.async {
            // set up streams for feedback:
            // Create new pipes for our own stdout/stderr
            // Get file for stdin that can be read from
            // Create new pipes for our own stdout/stderr
            var stdin_pipe = Pipe()
            self.stdin_file = fdopen(stdin_pipe.fileHandleForReading.fileDescriptor, "r")
            var counter = 0
            while (self.stdin_file == nil) && (counter < 5) {
                self.outputToWebView(string: "Could not create an input stream, retrying (\(counter+1))\n")
                stdin_pipe = Pipe()
                self.stdin_file = fdopen(stdin_pipe.fileHandleForReading.fileDescriptor, "r")
                if (counter > 2) {
                    let ms: UInt32 = 1000
                    usleep(150 * ms)
                }
                counter += 1
            }
            if (self.stdin_file == nil) {
                self.outputToWebView(string: "Unable to create an input stream. I give up.\n")
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
            while (self.stdout_file == nil) && (counter > 5) {
                self.outputToWebView(string: "Could not create an output stream, retrying (\(counter+1))\n")
                stdout_pipe = Pipe()
                self.stdout_file = fdopen(stdout_pipe.fileHandleForWriting.fileDescriptor, "w")
                if (counter > 2) {
                    let ms: UInt32 = 1000
                    usleep(150 * ms)
                }
                counter += 1
            }
            if (self.stdout_file == nil) {
                self.outputToWebView(string: "Unable to create an output stream. I give up.\n")
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
                    if #available(iOS 16.0, *) {
                        // Show buttons depending on commands:
                        // Hide all buttons with tag == noneTag, show all buttons that match.
                        if (useSystemToolbar) {
                            self.webView?.inputAssistantItem.leadingBarButtonGroups.forEach { leftButtonGroup in
                                if let representativeItem = leftButtonGroup.representativeItem {
                                    representativeItem.isHidden = self.hideButton(tag: representativeItem.tag)
                                }
                                leftButtonGroup.barButtonItems.forEach { button in
                                    button.isHidden = self.hideButton(tag: button.tag)
                                }
                            }
                            self.webView?.inputAssistantItem.trailingBarButtonGroups.forEach { rightButtonGroup in
                                if let representativeItem = rightButtonGroup.representativeItem {
                                    representativeItem.isHidden = self.hideButton(tag: representativeItem.tag)
                                }
                                rightButtonGroup.barButtonItems.forEach { button in
                                    button.isHidden = self.hideButton(tag: button.tag)
                                }
                            }
                        } else {
                            self.editorToolbar.items?.forEach { button in
                                button.isHidden = self.hideButton(tag: button.tag)
                            }
                        }
                    }
                }
                resultStack.removeAll()
                self.pid = ios_fork()
                DispatchQueue.main.async {
                    UIApplication.shared.isIdleTimerDisabled = true
                }
                ios_system(self.currentCommand)
                NSLog("Returned from ios_system")
                ios_waitpid(self.pid)
                NSLog("Returned from ios_waitpid")
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
            // re-hide buttons after leaving command:
            DispatchQueue.main.async {
                if #available(iOS 16.0, *) {
                    if (useSystemToolbar) {
                        // Show buttons after command is done:
                        self.webView?.inputAssistantItem.leadingBarButtonGroups.forEach { leftButtonGroup in
                            if let representativeItem = leftButtonGroup.representativeItem {
                                if (representativeItem.tag != 0) {
                                    representativeItem.isHidden = !(representativeItem.tag == self.noneTag)
                                }
                            }
                            leftButtonGroup.barButtonItems.forEach { button in
                                if (button.tag != 0) {
                                    button.isHidden = !(button.tag == self.noneTag)
                                }
                            }
                        }
                        self.webView?.inputAssistantItem.trailingBarButtonGroups.forEach { rightButtonGroup in
                            if let representativeItem = rightButtonGroup.representativeItem {
                                if (representativeItem.tag != 0) {
                                    representativeItem.isHidden = !(representativeItem.tag == self.noneTag)
                                }
                            }
                            rightButtonGroup.barButtonItems.forEach { button in
                                if (button.tag != 0) {
                                    button.isHidden = !(button.tag == self.noneTag)
                                }
                            }
                        }
                    } else {
                        self.editorToolbar.items?.forEach { button in
                            if (button.tag != 0) {
                                button.isHidden = !(button.tag == self.noneTag)
                            }
                        }
                    }
                }
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
        // NSLog("Received JS message: \(cmd)")
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
                    for button in editorToolbar.items! {
                        if title(button) == "control" {
                            button.isSelected = controlOn
                            break
                        }
                    }
                } else {
                    var foundControl = false
                    if let leftButtonGroups = webView?.inputAssistantItem.leadingBarButtonGroups {
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
                        if let rightButtonGroups = webView?.inputAssistantItem.trailingBarButtonGroups {
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
        } else if (cmd.hasPrefix("input:")) {
            ios_switchSession(self.persistentIdentifier?.toCString())
            ios_setContext(UnsafeMutableRawPointer(mutating: self.persistentIdentifier?.toCString()));
            ios_setStreams(self.stdin_file, self.stdout_file, self.stdout_file)
            if (ios_activePager() != 0) { return }
            var command = cmd
            command.removeFirst("input:".count)
            // NSLog("Writing \(command) to stdin")
            // Because wasm is running asynchronously, we can have thread_stdin closed while wasm is still running
            // I would like to have a way to kill webassembly commands
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
            if #available(iOS 15.0, *) {
                // Take over from the system for letters, to enforce auto-repeat for letters:
                if let character = command.last {
                    if ((character >= "a") && (character <= "z")) || ((character >= "A") && (character <= "Z")) {
                        lastKey = character
                        lastKeyTime = .now
                    } else {
                        lastKey = nil
                    }
                }
            }
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
        } else if (cmd.hasPrefix("listBookmarks:") || cmd.hasPrefix("listBookmarksDir:")) {
            let storedNamesDictionary = UserDefaults.standard.dictionary(forKey: "bookmarkNames") ?? [:]
            var onlyDirectories = false
            if cmd.hasPrefix("listBookmarksDir:") {
                onlyDirectories = true
            }
            var sortedKeys = storedNamesDictionary.keys.sorted() // alphabetical order
            if (onlyDirectories) {
                // sort directories in order of use:
                sortedKeys = sortedKeys.sorted(by: { current, next in rankDirectory(dir:"~" + current, base: nil) > rankDirectory(dir:"~" + next, base: nil)})
            }
            var javascriptCommand = "fileList = [ "
            for key in sortedKeys {
                // Skip bookmarks that aren't directories
                if (onlyDirectories) {
                    if let path = storedNamesDictionary[key] as? String {
                        if (!URL(fileURLWithPath: path).isDirectory) {
                            continue
                        }
                    }
                }
                // print(key)
                // escape spaces, replace "\r" in filenames with "?"
                javascriptCommand += "\"~" + key.replacingOccurrences(of: " ", with: "\\ ") + "/\", "
            }
            // We need to re-escapce spaces for string comparison to work in JS:
            javascriptCommand += "]; lastDirectory = \"~bookmarkNames\"; lastOnlyDirectories= \(onlyDirectories); updateFileMenu(); "
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
        } else if (cmd.hasPrefix("listDirectory:") || cmd.hasPrefix("listDirectoryDir:")) {
            var directory = cmd
            var onlyDirectories = false
            if cmd.hasPrefix("listDirectoryDir:") {
                directory.removeFirst("listDirectoryDir:".count)
                onlyDirectories = true
            } else {
                directory.removeFirst("listDirectory:".count)
            }
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
                        if (directoryForListing.hasPrefix("/")) {
                            directoryForListing.removeFirst()
                        }
                        if (homeUrl.path.hasSuffix("/")) {
                            directoryForListing = homeUrl.path + directoryForListing
                        } else {
                            directoryForListing = homeUrl.path + "/" + directoryForListing
                        }
                    } else {
                        let storedNamesDictionary = UserDefaults.standard.dictionary(forKey: "bookmarkNames") ?? [:]
                        name.removeFirst("~".count)
                        if let bookmarkedDirectory = storedNamesDictionary[name] as? String {
                            directoryForListing.removeFirst(name.count + 1)
                            directoryForListing = bookmarkedDirectory + "/" + directoryForListing
                        }
                        // NSLog("Listing a bookmark: \(directoryForListing): \(name)")
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
                filePaths.sort() // alphabetical order
                if (onlyDirectories) {
                    // sort directories in order of use:
                    var directoryForSorting = directoryForListing
                    if (directoryForSorting.hasPrefix(".")) {
                        if (directoryForSorting == ".") {
                            directoryForSorting = FileManager().currentDirectoryPath
                        } else if (directoryForSorting.hasPrefix("./")) {
                            directoryForSorting = directoryForSorting.replacingOccurrences(of: "./", with: FileManager().currentDirectoryPath + "/")
                        } else {
                            directoryForSorting = FileManager().currentDirectoryPath + "/" + directoryForSorting
                        }
                    }
                    var localDirCompact = String(cString: ios_getBookmarkedVersion(directoryForSorting))
                    filePaths = filePaths.sorted(by: { current, next in rankDirectory(dir:current, base: localDirCompact) > rankDirectory(dir:next, base: localDirCompact)})
                    // NSLog("after sorting: \(filePaths)")
                }
                var javascriptCommand = "fileList = ["
                for filePath in filePaths {
                    let fullPath = directoryForListing.replacingOccurrences(of: "\\ ", with: " ") + "/" + filePath
                    // NSLog("path = \(fullPath) , isDirectory: \(URL(fileURLWithPath: fullPath).isDirectory)")
                    let isDirectory = URL(fileURLWithPath: fullPath).isDirectory
                    if onlyDirectories && !isDirectory {
                        continue
                    }
                    // escape spaces, replace "\r" in filenames with "?"
                    javascriptCommand += "\"" + filePath.replacingOccurrences(of: " ", with: "\\\\ ").replacingOccurrences(of: "\r", with: "?")
                    if isDirectory {
                        javascriptCommand += "/"
                    }
                    else {
                        javascriptCommand += " "
                    }
                    javascriptCommand += "\", "
                }
                // We need to re-escapce spaces for string comparison to work in JS:
                javascriptCommand += "]; lastDirectory = \"" + directory.replacingOccurrences(of: " ", with: "\\ ") + "\"; lastOnlyDirectories= \(onlyDirectories); updateFileMenu(); "
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
        } else if (cmd.hasPrefix("listDirectoriesForZ:")) {
            var directory = cmd
            directory.removeFirst("listDirectoriesForZ:".count)
            if (directory.count == 0) { return }
            var keys: [String]
            do {
                ios_switchSession(self.persistentIdentifier?.toCString())
                ios_setContext(UnsafeMutableRawPointer(mutating: self.persistentIdentifier?.toCString()));
                let matchingRegexp = directory.replacingOccurrences(of: ".", with: "\\.").replacingOccurrences(of: "/", with: ".*/.*")
                let regex = try NSRegularExpression(pattern: matchingRegexp, options: [])
                // select keys from dictionary that match argument. Using partial match.
                let result = directoriesUsed.filter( { regex.matches(in: $0.key, range: NSRange($0.key.startIndex..<$0.key.endIndex, in: $0.key)).count > 0 } )
                if (result.count == 0) {
                    // No matches in history. Search local directory, same regexp.
                    let filePaths = try FileManager().contentsOfDirectory(atPath: FileManager().currentDirectoryPath)
                    var result = filePaths.filter( { regex.matches(in: $0, range: NSRange($0.startIndex..<$0.endIndex, in: $0)).count > 0 } )
                    if (result.count > 1) {
                        let localDirCompact = String(cString: ios_getBookmarkedVersion(FileManager().currentDirectoryPath)) + "/"
                        result = result.sorted(by: { current, next in rankDirectory(dir: current, base: localDirCompact) > rankDirectory(dir: next, base: localDirCompact)})
                    }
                }
                keys = result.keys.sorted()
                keys = keys.sorted(by: { current, next in rankDirectory(dir: current, base: nil) > rankDirectory(dir: next, base: nil)})

                var javascriptCommand = "fileList = ["
                for key in keys {
                    // escape spaces, replace "\r" in filenames with "?"
                    javascriptCommand += "\"" + key.replacingOccurrences(of: " ", with: "\\\\ ").replacingOccurrences(of: "\r", with: "?")
                    javascriptCommand += " "
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
            } catch {
                NSLog("Error getting Z files from directory: \(directory): \(error.localizedDescription)")
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
            let fontSize = terminalFontSize ?? factoryFontSize
            let fontName = terminalFontName ?? factoryFontName
            let cursorShape = terminalCursorShape ?? factoryCursorShape
            let fontLigature = terminalFontLigature ?? factoryFontLigature
            // Force writing all config to term. Used when we changed many parameters.
            let command1 = "window.foregroundColor = '" + foregroundColor.toHexString() + "'; window.backgroundColor = '" + backgroundColor.toHexString() + "'; window.cursorColor = '" + cursorColor.toHexString() + "'; window.cursorShape = '\(cursorShape)'; window.fontSize = '\(fontSize)' ; window.fontFamily = '\(fontName)';"
            NSLog("resendConfiguration, command=\(command1)")
            self.webView!.evaluateJavaScript(command1) { (result, error) in
                /* if let error = error {
                    NSLog("Error in resendConfiguration, line = \(command1) error = \(error)")
                    // print(error)
                }
                if result != nil {
                    NSLog("Return from resendConfiguration, line = \(command1) result = \(result)")
                    // print(result)
                } */
            }
            let command2 = "window.term_.setForegroundColor('" + foregroundColor.toHexString() + "'); window.term_.setBackgroundColor('" + backgroundColor.toHexString() + "'); window.term_.setCursorColor('" + cursorColor.toHexString() + "'); window.term_.setCursorShape('\(cursorShape)'); window.fontSize = \(fontSize); window.term_.setFontSize(\(fontSize)); window.term_.setFontFamily('\(fontName)'); window.term_.scrollPort_.screen_.style.fontVariantLigatures = '\(fontLigature)';"
            self.webView!.evaluateJavaScript(command2) { (result, error) in
                /* if let error = error {
                    NSLog("Error in resendConfiguration, line = \(command2) error= \(error)")
                    // print(error)
                }
                if result != nil {
                    NSLog("Return from resendConfiguration, line = \(command2) result = \(result)")
                    // print(result)
                } */
            }
            let command3 = "window.term_.prefs_.setSync('foreground-color', '" + foregroundColor.toHexString() + "'); window.term_.prefs_.setSync('background-color', '" + backgroundColor.toHexString() + "'); window.term_.prefs_.setSync('cursor-color', '" + cursorColor.toHexString() + "'); window.term_.prefs_.setSync('font-size', '\(fontSize)'); window.term_.prefs_.setSync('font-family', '\(fontName)');  window.term_.scrollPort_.isScrolledEnd = true;"
            self.webView!.evaluateJavaScript(command3) { (result, error) in
                /* if let error = error {
                    NSLog("Error in resendConfiguration, line = \(command3) error = \(error)")
                    // print(error)
                }
                if result != nil {
                    NSLog("Return from resendConfiguration, line = \(command3) result = \(result)")
                    // print(result)
                } */
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
                    NSLog("Error in creating command list, line = \(javascriptCommand) error = \(error)")
                    // print(error)
                }
                // if let result = result { print(result) }
            }
        } else if (cmd.hasPrefix("resendCommand:")) {
            if (shortcutCommandReceived != nil) {
                // NSLog("resendCommand for Shortcut, command=\(shortcutCommandReceived!)")
                executeCommand(command: shortcutCommandReceived!)
                shortcutCommandReceived = nil
            } else {
                // Q: need to wait until configuration files are loaded?
                // window.printedContent = '\(windowPrintedContent.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\r", with: "\\r").replacingOccurrences(of: "\n", with: "\\n\\r"))';
                // print("PrintedContent to be restored: \(windowPrintedContent.count)")
                // print(windowPrintedContent.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\r", with: "\\r").replacingOccurrences(of: "\n", with: "\\n\\r"))
                let command = "window.promptMessage = '\(self.parsePrompt())'; \(windowHistory)  window.printedContent = \"\(windowPrintedContent.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\r", with: "\\r").replacingOccurrences(of: "\n", with: "\\n\\r"))\"; window.commandRunning = '\(currentCommand)'; window.interactiveCommandRunning = isInteractive(window.commandRunning); if (window.commandRunning == '') { if (window.printedContent != '') { window.term_.io.print(window.printedContent); } else { window.printPrompt(); } updatePromptPosition(); } else { window.printedContent= ''; }"
                // NSLog("resendCommand, command=\(command)")
                self.webView!.evaluateJavaScript(command) { (result, error) in
                    if let error = error {
                        // NSLog("Error in resendCommand, line = \(command)")
                        // print(error)
                    }
                    if let result = result {
                        // print(result)
                    }
                }
            }
        } else if (cmd.hasPrefix("setFontSize:")) {
            var size = cmd
            size.removeFirst("setFontSize:".count)
            if let sizeFloat = Float(size) {
                // NSLog("Setting size to \(sizeFloat)")
                terminalFontSize = sizeFloat
            }
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
                    let prefix = fileURL.scheme ?? ""
                    commandSent.removeFirst(prefix.count + 1)
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
            // }
            // if #available(iOS 16.0, *) {
            //     if session.role == .windowExternalDisplayNonInteractive {
            //         window.rootViewController = UIHostingController(rootView: contentView)
            //         window.autoresizesSubviews = true
            //         self.window = window
            //         window.makeKeyAndVisible()
            //     }
            // }
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
            if #available(iOS 16.0, *) {
                webView?.isFindInteractionEnabled = true
            }
            if (!toolbarShouldBeShown) {
                showToolbar = false
                self.webView?.addInputAccessoryView(toolbar: self.emptyToolbar)
            } else {
                generateToolbarButtons()
                if (useSystemToolbar) {
                    showToolbar = false
                    self.webView?.inputAssistantItem.leadingBarButtonGroups = self.leftButtonGroups
                    self.webView?.inputAssistantItem.trailingBarButtonGroups = self.rightButtonGroups
                } else {
                    showToolbar = true
                    self.webView?.addInputAccessoryView(toolbar: self.editorToolbar)
                }
            }
            // We create a separate WkWebView for webAssembly:
            let config = WKWebViewConfiguration()
            config.preferences.javaScriptCanOpenWindowsAutomatically = true
            config.preferences.setValue(true as Bool, forKey: "allowFileAccessFromFileURLs")
            config.setValue(true as Bool, forKey: "allowUniversalAccessFromFileURLs")
            wasmWebView = WKWebView(frame: .zero, configuration: config)
            if #available(iOS 16.4, *) {
                wasmWebView?.isInspectable = true
            }
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
            if let ligature = UserDefaults.standard.value(forKey: "fontLigature") as? String {
                terminalCursorShape = ligature
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
            webView?.evaluateJavaScript(javascriptCommand) { (result, error) in
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
                } else if ((fileURL.scheme ?? "").hasPrefix("ashell")) {
                    NSLog("We received an URL: \(fileURL.absoluteString.removingPercentEncoding)") // received "ashell://ls"
                    // The window is not yet fully opened, so executeCommand might fail.
                    // We use installQueue to be called once the window is ready.
                    var command = fileURL.absoluteString
                    command.removeFirst((fileURL.scheme ?? "").count + 3)
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
                            commandSent.removeFirst((fileURL.scheme ?? "").count + 3)
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
            
            // Make sure we are informed when the keyboard status changes.
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
            if ((fileURL.scheme ?? "").hasPrefix("ashell")) {
                NSLog("We received an URL: \(fileURL.absoluteString.removingPercentEncoding)") // received "ashell://ls"
                if (UIDevice.current.model.hasPrefix("iPad")) {
                    // iPad, so always open a new window to execute the command
                    let activity = NSUserActivity(activityType: "AsheKube.app.a-Shell.ExecuteCommand")
                    activity.userInfo!["url"] = fileURL
                    // create a window and execute the command:
                    UIApplication.shared.requestSceneSessionActivation(nil, userActivity: activity, options: nil)
                } else {
                    // iPhone: create the command, send it to the window once it's created.
                    var command = fileURL.absoluteString
                    command.removeFirst((fileURL.scheme ?? "").count + 3)
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
        let fontLigature = terminalFontLigature ?? factoryFontLigature
        // Force writing all config to term. Used when we changed many parameters.
        // Window.term_ does not always exist when sceneDidBecomeActive is called. We *also* set window.foregroundColor, and then use that when we create term.
        webView!.tintColor = foregroundColor
        webView!.backgroundColor = backgroundColor
        let command1 = "window.foregroundColor = '" + foregroundColor.toHexString() + "'; window.backgroundColor = '" + backgroundColor.toHexString() + "'; window.cursorColor = '" + cursorColor.toHexString() + "'; window.cursorShape = '\(cursorShape)'; window.fontSize = '\(fontSize)' ; window.fontFamily = '\(fontName)';"
        webView!.evaluateJavaScript(command1) { (result, error) in
            /* if error != nil {
                NSLog("Error in sceneDidBecomeActive, line = \(command1)")
                print(error)
            }
            if result != nil {
                NSLog("Return from sceneDidBecomeActive, line = \(command1)")
                print(result)
            } */
        }
        // Current status: window.term_ is undefined here in iOS 15b1.
        let command2 = "(window.term_ != undefined)"
        webView!.evaluateJavaScript(command2) { (result, error) in
            /* if let error = error {
                NSLog("Error in sceneDidBecomeActive, line = \(command2)")
                print(error)
            }
            if result != nil {
                NSLog("Return from sceneDidBecomeActive, line = \(command2), result= \(result)")
            } */
            if let resultN = result as? Int {
                if (resultN == 1) {
                    // window.term_ exists, let's send commands:
                    let command3 = "window.term_.setForegroundColor('" + foregroundColor.toHexString() + "'); window.term_.setBackgroundColor('" + backgroundColor.toHexString() + "'); window.term_.setCursorColor('" + cursorColor.toHexString() + "'); window.term_.setCursorShape('\(cursorShape)');window.fontSize = \(fontSize);window.term_.setFontSize(\(fontSize)); window.term_.setFontFamily('\(fontName)'); window.term_.scrollPort_.screen_.style.fontVariantLigatures = '\(fontLigature)';"
                    self.webView!.evaluateJavaScript(command3) { (result, error) in
                        /* if error != nil {
                            NSLog("Error in sceneDidBecomeActive, line = \(command3)")
                            print(error)
                        }
                        if result != nil {
                            NSLog("Return from sceneDidBecomeActive, line = \(command3)")
                            print(result)
                        } */
                    }
                    let command4 = "window.term_.prefs_.setSync('foreground-color', '" + foregroundColor.toHexString() + "'); window.term_.prefs_.setSync('background-color', '" + backgroundColor.toHexString() + "'); window.term_.prefs_.setSync('cursor-color', '" + cursorColor.toHexString() + "'); window.term_.prefs_.setSync('cursor-shape', '\(cursorShape)'); window.term_.prefs_.setSync('font-size', '\(fontSize)'); window.term_.prefs_.setSync('font-family', '\(fontName)');  window.term_.scrollPort_.isScrolledEnd = true;"
                    self.webView!.evaluateJavaScript(command4) { (result, error) in
                        /* if error != nil {
                            NSLog("Error in sceneDidBecomeActive, line = \(command4)")
                            print(error)
                        }
                        if result != nil {
                            NSLog("Return from sceneDidBecomeActive, line = \(command4)")
                            print(result)
                        } */
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
            generateToolbarButtons()
            if (useSystemToolbar) {
                showToolbar = false
                self.webView?.inputAssistantItem.leadingBarButtonGroups = self.leftButtonGroups
                self.webView?.inputAssistantItem.trailingBarButtonGroups = self.rightButtonGroups
            } else {
                showToolbar = true
                self.webView!.addInputAccessoryView(toolbar: self.editorToolbar)
            }
        }
        // If there is no userInfo and no stateRestorationActivity:
        // On the first run, one of these are null, so we return.
        guard (scene.session.stateRestorationActivity != nil) else { return }
        guard let userInfo = scene.session.stateRestorationActivity!.userInfo else { return }
        // If a command is already running, we don't restore directories, etc: they probably are still valid
        if (currentCommand != "") { return }
        NSLog("Restoring history, previousDir, currentDir:")
        if let historyData = userInfo["history"] {
            history = historyData as! [String]
        } else {
            history = UserDefaults.standard.array(forKey: "history") as? [String] ?? []
        }
        directoriesUsed = UserDefaults.standard.dictionary(forKey: "directoriesUsed") as? [String:Int] ?? [:]
        // NSLog("set history to \(history)")
        // NSLog("set directoriesUsed to \(directoriesUsed)")
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
        if let fontLigature = userInfo["fontLigature"] as? String {
            terminalFontLigature = fontLigature
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
                        // NSLog("function does not exist, set window.printedContent")
                        // resendCommend will print this on screen
                        self.windowPrintedContent = terminalData
                    } else {
                        // The function is defined, we are here *after* JS initialization:
                        // NSLog("function does exist, calling window.setWindowContent")
                        let javascriptCommand = "window.promptMessage='\(self.parsePrompt())'; window.setWindowContent(\"" + terminalData.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\r", with: "\\r").replacingOccurrences(of: "\n", with: "\\n\\r") + "\");"
                        self.webView!.evaluateJavaScript(javascriptCommand) { (result, error) in
                            /* if error != nil {
                                NSLog("Error in resetting terminal w setWindowContent, line = \(javascriptCommand)")
                                // print(error)
                            }
                            // if let result = result { print(result) }
                             */
                        }
                    }
                })
            } else {
                // No terminal data stored, reset things:
                let javascriptCommand = "window.promptMessage='\(self.parsePrompt())'; window.printedContent = '';"
                webView!.evaluateJavaScript(javascriptCommand) { (result, error) in
                    /* if error != nil {
                        NSLog("Error in setting terminal to empty, line = \(javascriptCommand)")
                        print(error)
                    }
                    if result != nil {
                        NSLog("Result in setting terminal to empty, line = \(javascriptCommand)")
                        print(result)
                    } */
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
                } else if (storedCommand.hasPrefix("dash ")) || (storedCommand == "dash") {
                    if (UserDefaults.standard.bool(forKey: "restart_vim")) {
                        /* We only restart vim and dash commands, and only if the user asks for it.
                         Everything else is creating problems.
                         Basically, we can only restart commands if we can save their status. */
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
                }
            }
        }
        if #available(iOS 16.0, *) {
            // TODO: probably remove this line since it didn't work, and size enforcement is now at a deeper level.
            if (UIDevice.current.model.hasPrefix("iPad")) {
                // On iPadOS 16, windows going into the background and back to the foreground
                // sometimes change their font size. This tries to enforce it back:
                let fontSize = terminalFontSize ?? factoryFontSize
                let fontSizeCommand = "window.fontSize = \(fontSize);window.term_.setFontSize(\(fontSize));"
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
            self.webView?.evaluateJavaScript(command) { (result, error) in
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
            self.webView?.evaluateJavaScript(command2) { (result, error) in
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
    
    private func onStdoutButton(_ stdout: FileHandle) {
        if (!stdout_button_active) { return }
        let data = stdout.availableData
        guard (data.count > 0) else {
            return
        }
        guard (webView != nil) else { return }
        if var string = String(data: data, encoding: String.Encoding.utf8) {
            // Remove all trailing \n\r (but keep those inside the string)
            if (string.contains(endOfTransmission)) {
                stdout_button_active = false
                string = string.replacingOccurrences(of: endOfTransmission, with: "")
            }
            while (string.hasSuffix("\n") || string.hasSuffix("\r")) {
                string.removeLast("\n".count)
            }
            // Sanitize the output string to it can be sent to javascript:
            let parsedString = string.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\r", with: "\\r").replacingOccurrences(of: "\n", with: "\\n\\r")
            DispatchQueue.main.async {
                self.webView?.evaluateJavaScript("window.term_.io.onVTKeystroke(\"" + parsedString + "\");") { (result, error) in
                    if let error = error {
                        NSLog("Error in onStdoutButton; offending line = \(parsedString), error = \(error)")
                        // print(error)
                    }
                    // if let result = result { print(result) }
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
                let f = fileno(thread_stdin_copy)
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
    
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {
        // communication with libc from webAssembly:
        let arguments = prompt.components(separatedBy: "\n")
        // NSLog("prompt: \(prompt)")
        // NSLog("thread_stdout_copy: \(thread_stdout_copy)")
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
                var result = ios_system(arguments[2])
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
        // End communication with webAssembly using libc
        // Start of JavaScriptCore extensions for interaction with filesystem
        } else if (title == "jsc") {
            // JSC extensions: readFile, writeFile...
            // Copied from the extensions in iOS_system, making them available to WkWebView JS interpreter.
            // Make sure we are on the right iOS session. This resets the current working directory.
            ios_switchSession(self.persistentIdentifier?.toCString())
            ios_setContext(UnsafeMutableRawPointer(mutating: self.persistentIdentifier?.toCString()));
            if (arguments[1] == "readFile") {
                do {
                    completionHandler(try String(contentsOf: URL(fileURLWithPath: arguments[2]), encoding: String.Encoding.utf8))
                }
                catch {
                    completionHandler(error.localizedDescription)
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
                    try arguments[3].write(toFile: arguments[2], atomically: true, encoding: String.Encoding.utf8)
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
                thread_stdin = self.thread_stdin_copy
                thread_stdout = self.thread_stdout_copy
                thread_stderr = self.thread_stderr_copy
                let pid = ios_fork()
                var result = ios_system(arguments[2])
                ios_waitpid(pid)
                ios_releaseThreadId(pid)
                if (result == 0) {
                    // If there's already been an error (e.g. "command not found") no need to ask for more.
                    result = ios_getCommandStatus()
                }
                completionHandler("\(result)")
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
