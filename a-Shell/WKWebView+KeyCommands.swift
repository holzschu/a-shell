//
//  ViewController+KeyCommands.swift
//  a-Shell
//
//  Created by Nicolas Holzschuch on 26/08/2019.
//  Copyright © 2019 AsheKube. All rights reserved.
//

import Foundation
import UIKit
import WebKit
import ios_system
let escape = "\u{001B}"

extension WKWebView {
    
    @objc private func escapeAction(_ sender: UIBarButtonItem) {
        evaluateJavaScript("window.term_.io.onVTKeystroke(\"" + escape + "\");") { (result, error) in
            // if let error = error { print(error) }
            // if let result = result { print(result) }
        }
    }
    
    @objc private func newWindow(_ sender: UIBarButtonItem) {
        if (UIDevice.current.model.hasPrefix("iPad")) {
            UIApplication.shared.requestSceneSessionActivation(nil, userActivity: nil, options: nil)
        }
    }

    @objc private func nextWindow(_ sender: UIBarButtonItem) {
        // This doesn't work for the time being.
        // It's probably connected to the issue with Stage Manager.
        // Could not find documentation on how to activate the next scene with the keyboard.
        if (UIDevice.current.model.hasPrefix("iPad")) {
            var activateNextWindow = false
            let options = UIScene.ActivationRequestOptions()
            for scene in UIApplication.shared.connectedScenes {
                if let delegate = scene.delegate as? SceneDelegate {
                    if (activateNextWindow) {
                        DispatchQueue.main.async {
                            NSLog("Activating WebView, Scene ID: \(scene.session.persistentIdentifier)")
                            UIApplication.shared.requestSceneSessionActivation(scene.session, userActivity: nil, options: options)
                            // activates the scene, but gives focus back to previous window.
                        }
                        return
                    }
                    if delegate.webView == self {
                        NSLog("Active WebView, Scene ID: \(scene.session.persistentIdentifier)")
                        activateNextWindow = true
                        options.requestingScene = scene
                    } else {
                        NSLog("Not-active WebView, Scene ID: \(scene.session.persistentIdentifier)")
                    }
                }
            }
            // If we arrived here, the last window was active: activate the first one:
            if let scene = UIApplication.shared.connectedScenes.first {
                if let delegate = scene.delegate as? SceneDelegate {
                    DispatchQueue.main.async {
                        // self.keyboardDisplayRequiresUserAction = true
                        NSLog("Activating first WebView, Scene ID: \(scene.session.persistentIdentifier)")
                        UIApplication.shared.requestSceneSessionActivation(scene.session, userActivity: nil, options: nil)
                    }
                }
            }
        }
    }

    @objc private func closeWindow(_ sender: UIBarButtonItem) {
        for scene in UIApplication.shared.connectedScenes {
            if let delegate = scene.delegate as? SceneDelegate {
                if delegate.webView == self {
                    delegate.closeWindow()
                    return
                }
            }
        }
    }

    @objc private func clearScreen(_ sender: UIBarButtonItem) {
        // clear entire display: ^[[2J
        // position cursor on top line: ^[[1;1H
        // print current command again.
        let javascriptCommand = #"""
        window.term_.io.print('\#(escape)[2J\#(escape)[1;1H');
        window.printPrompt();
        window.term_.io.print(window.term_.io.currentCommand);
        var endOfCommand = window.term_.io.currentCommand.slice(window.currentCommandCursorPosition, window.term_.io.currentCommand.length);
        var wcwidth = lib.wc.strWidth(endOfCommand);
        for (var i = 0; i < wcwidth; i++) {
            window.term_.io.print('\b');
        }
        """#
        evaluateJavaScript(javascriptCommand) { (result, error) in
            // if let error = error { print(error) }
            // if let result = result { print(result) }
        }
    }

    @objc private func increaseTextSize(_ sender: UIBarButtonItem) {
        NSLog("Increase event received")
        for scene in UIApplication.shared.connectedScenes {
            if let delegate = scene.delegate as? SceneDelegate {
                if delegate.webView == self {
                    let fontSize = delegate.terminalFontSize ?? factoryFontSize
                    delegate.configWindow(fontSize: fontSize + 1, fontName: nil, backgroundColor: nil, foregroundColor: nil, cursorColor: nil, cursorShape: nil, fontLigature: nil)
                    return
                }
            }
        }
    }

    @objc private func decreaseTextSize(_ sender: UIBarButtonItem) {
        NSLog("Decrease event received")
        for scene in UIApplication.shared.connectedScenes {
            if let delegate = scene.delegate as? SceneDelegate {
                if delegate.webView == self {
                    let fontSize = delegate.terminalFontSize ?? factoryFontSize
                    delegate.configWindow(fontSize: fontSize - 1, fontName: nil, backgroundColor: nil, foregroundColor: nil, cursorColor: nil, cursorShape: nil, fontLigature: nil)
                    return
                }
            }
        }
    }

    @objc private func gobackkeyAction() {
        if canGoBack {
            let position = -1
            if let backPageItem = backForwardList.item(at: position) {
                go(to: backPageItem)
            }
        }
    }
    
    @objc private func goforwardkeyAction() {
        if canGoForward {
            let position = 1
            if let forwardPageItem = backForwardList.item(at: position) {
                go(to: forwardPageItem)
            }
        }
    }


    override open var keyCommands: [UIKeyCommand]? {
        // In case we need keyboard personalization for specific languages
        // var language = textInputMode?.primaryLanguage ?? "en-US"
        var basicKeyCommands = [
            // 16/6/2021: hterm_all deals with the keyboard arrow keys.
            // UIKeyCommand(input: UIKeyCommand.inputUpArrow, modifierFlags: [], action: #selector(upAction)),
            // UIKeyCommand(input: UIKeyCommand.inputDownArrow, modifierFlags: [], action: #selector(downAction)),
            // UIKeyCommand(input: UIKeyCommand.inputLeftArrow, modifierFlags: [], action: #selector(leftAction)),
            // UIKeyCommand(input: UIKeyCommand.inputRightArrow, modifierFlags: [], action: #selector(rightAction)),
            // "discoverabilityTitle:)' was deprecated in iOS 13.0" but it's quite convenient
            UIKeyCommand(input: "k", modifierFlags:.command, action: #selector(clearScreen), discoverabilityTitle: "Clear screen"),
            UIKeyCommand(input: "n", modifierFlags:.command, action: #selector(newWindow), discoverabilityTitle: "New window"),
            // UIKeyCommand(input: "t", modifierFlags:.command, action: #selector(nextWindow), discoverabilityTitle: "Next window"),
            UIKeyCommand(input: "w", modifierFlags:.command, action: #selector(closeWindow), discoverabilityTitle: "Close window"),
            UIKeyCommand(input: "x", modifierFlags:.command, action: #selector(cutText), discoverabilityTitle: "Cut"),
            UIKeyCommand(input: "+", modifierFlags:.command, action: #selector(increaseTextSize), discoverabilityTitle: "Bigger text"),
            UIKeyCommand(input: "-", modifierFlags:.command, action: #selector(decreaseTextSize), discoverabilityTitle: "Smaller text"),
            // Still required with external keyboards as of May 26, 2020: control-C maps to control-C
            UIKeyCommand(input: "c", modifierFlags:.control, action: #selector(insertC)),
            // back/forward one page keys for internal browser:
            UIKeyCommand(input: "[", modifierFlags: [.command, .shift], action: #selector(gobackkeyAction), discoverabilityTitle: "Previous page"),
            UIKeyCommand(input: "]", modifierFlags: [.command, .shift], action: #selector(goforwardkeyAction), discoverabilityTitle: "Next page")
        ]
        let dKey = UIKeyCommand(input: "d", modifierFlags:.control, action: #selector(insertD))
        if #available(iOS 15.0, *) {
            dKey.wantsPriorityOverSystemBehavior = true
        }
        basicKeyCommands.append(dKey)
        let aKey = UIKeyCommand(input: "a", modifierFlags:.command, action: #selector(selectAll_), discoverabilityTitle: "Select all")
        if #available(iOS 15.0, *) {
            aKey.wantsPriorityOverSystemBehavior = true
        }
        basicKeyCommands.append(aKey)
        /* Caps Lock remapped to escape: */
        if (UserDefaults.standard.bool(forKey: "escape_preference")) {
            // If we remapped caps-lock to escape, we need to disable caps-lock, at least with certain keyboards.
            // This loop remaps all lowercase characters without a modifier to themselves, thus disabling caps-lock
            // It doesn't work for characters produced with alt-key, though.
            for key in 0x061...0x2AF { // all lowercase unicode letters
                let K = Unicode.Scalar(key)!
                if CharacterSet.lowercaseLetters.contains(Unicode.Scalar(key)!) {
                    // no discoverabilityTitle
                    let key = UIKeyCommand(input: "\(K)", modifierFlags: [],  action: #selector(insertKey))
                    if #available(iOS 15.0, *) {
                        key.wantsPriorityOverSystemBehavior = true
                    }
                    basicKeyCommands.append(key)
                }
            }
            // This one remaps capslock to escape, no discoverabilityTitle
            let capsLockKey = UIKeyCommand(input: "", modifierFlags:.alphaShift,  action: #selector(escapeAction))
            if #available(iOS 15.0, *) {
                capsLockKey.wantsPriorityOverSystemBehavior = true
            }
            basicKeyCommands.append(capsLockKey)
        } else if #available(iOS 15.0, *) {
            if let keyboardLanguage = self.textInputMode?.primaryLanguage {
                // Is the keyboard language one of the multi-input languages? Chinese, Japanese, Korean and Hindi-Transliteration
                if (!keyboardLanguage.hasPrefix("hi") && !keyboardLanguage.hasPrefix("zh") && !keyboardLanguage.hasPrefix("ja")) {
                    // auto-repeat for external keyboard keys. Activate wantsPriorityOverSystemBehavior for the last key pressed.
                    if (lastKey != nil) && (-lastKeyTime.timeIntervalSinceNow < 1) {
                        // NSLog("auto-repeat for \(lastKey!)")
                        if ((lastKey! >= "a") && (lastKey! <= "z")) {
                            let key = UIKeyCommand(input: "\(lastKey!)", modifierFlags: [],  action: #selector(insertKey))
                            key.wantsPriorityOverSystemBehavior = true
                            basicKeyCommands.append(key)
                        } else if ((lastKey! >= "A") && (lastKey! <= "Z")) {
                            let K = lastKey!.lowercased()
                            let keyS = UIKeyCommand(input: "\(K)", modifierFlags: .shift,  action: #selector(insertKey))
                            keyS.wantsPriorityOverSystemBehavior = true
                            basicKeyCommands.append(keyS)
                        }
                    }
                }
                if keyboardLanguage.hasPrefix("en") {
                    // For the english keyboard, we can set auto-repeat for numbers too:
                    for key in 0x030...0x039 { // all 10 numbers
                        let K = Unicode.Scalar(key)!
                        let key = UIKeyCommand(input: "\(K)", modifierFlags: [],  action: #selector(insertKey))
                        key.wantsPriorityOverSystemBehavior = true
                        basicKeyCommands.append(key)
                    }
                }
            }
        }
        return basicKeyCommands
    }

    @objc func cutText(_ sender: UIKeyCommand) {
        let commandString = "window.term_.onCut('null');"
        evaluateJavaScript(commandString) { (result, error) in
            // if let error = error { print(error) }
            // if let result = result { print(result) }
        }
    }

    @objc func selectAll_(_ sender: UIKeyCommand) {
        let commandString = "window.term_.scrollPort_.selectAll();"
        evaluateJavaScript(commandString) { (result, error) in
            if let error = error { 
                print("Error in executing \(commandString): \(error)")
            }
            if let result = result { print(result) }
        }
    }

    @objc func insertC(_ sender: UIKeyCommand) {
        // Make sure we send control-C from external KB:
        guard (sender.input != nil) else { return }
        var string = sender.input!
        if (sender.modifierFlags.contains(.control)) {
            string = "\u{003}"
        }
        let commandString = "window.term_.io.onVTKeystroke(\'\(string)');"
        evaluateJavaScript(commandString) { (result, error) in
            // if let error = error { print(error) }
            // if let result = result { print(result) }
        }
    }
    @objc func insertD(_ sender: UIKeyCommand) {
        // Make sure we send control-D from external KB:
        guard (sender.input != nil) else { return }
        var string = sender.input!
        if (sender.modifierFlags.contains(.control)) {
            string = "\u{004}"
        }
        let commandString = "window.term_.io.onVTKeystroke(\'\(string)');"
        evaluateJavaScript(commandString) { (result, error) in
            // if let error = error { print(error) }
            // if let result = result { print(result) }
        }
    }

    
    @objc func insertKey(_ sender: UIKeyCommand) {
        guard (sender.input != nil) else { return }
        // Not modifierFlags, attributes, state
        if #available(iOS 15.0, *) {
            lastKey = sender.input!.last
            lastKeyTime = .now
        }
        var input = sender.input
        if sender.modifierFlags.contains(.shift) {
            input = input?.uppercased()
        }
        let commandString = "window.term_.io.onVTKeystroke(\'\(input!)');"
        evaluateJavaScript(commandString) { (result, error) in
            // if let error = error { print(error) }
            // if let result = result { print(result) }
        }
    }

    
}
