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

    @objc private func closeWindow(_ sender: UIBarButtonItem) {
        let opaquePointer = OpaquePointer(ios_getContext())
        guard let stringPointer = UnsafeMutablePointer<CChar>(opaquePointer) else { return }
        let currentSessionIdentifier = String(cString: stringPointer)
        for scene in UIApplication.shared.connectedScenes {
            if (scene.session.persistentIdentifier == currentSessionIdentifier) {
                let delegate: SceneDelegate = scene.delegate as! SceneDelegate
                delegate.closeWindow()
                return
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
        let opaquePointer = OpaquePointer(ios_getContext())
        guard let stringPointer = UnsafeMutablePointer<CChar>(opaquePointer) else { return }
        let currentSessionIdentifier = String(cString: stringPointer)
        for scene in UIApplication.shared.connectedScenes {
            if (scene.session.persistentIdentifier == currentSessionIdentifier) {
                let delegate: SceneDelegate = scene.delegate as! SceneDelegate
                let fontSize = delegate.terminalFontSize ?? factoryFontSize
                delegate.configWindow(fontSize: fontSize + 1, fontName: nil, backgroundColor: nil, foregroundColor: nil, cursorColor: nil, cursorShape: nil)
                return
            }
        }
    }

    @objc private func decreaseTextSize(_ sender: UIBarButtonItem) {
        NSLog("Decrease event received")
        let opaquePointer = OpaquePointer(ios_getContext())
        guard let stringPointer = UnsafeMutablePointer<CChar>(opaquePointer) else { return }
        let currentSessionIdentifier = String(cString: stringPointer)
        for scene in UIApplication.shared.connectedScenes {
            if (scene.session.persistentIdentifier == currentSessionIdentifier) {
                let delegate: SceneDelegate = scene.delegate as! SceneDelegate
                let fontSize = delegate.terminalFontSize ?? factoryFontSize
                delegate.configWindow(fontSize: fontSize - 1, fontName: nil, backgroundColor: nil, foregroundColor: nil, cursorColor: nil, cursorShape: nil)
                return
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
            UIKeyCommand(input: "w", modifierFlags:.command, action: #selector(closeWindow), discoverabilityTitle: "Close window"),
            UIKeyCommand(input: "x", modifierFlags:.command, action: #selector(cutText), discoverabilityTitle: "Cut"),
            UIKeyCommand(input: "+", modifierFlags:.command, action: #selector(increaseTextSize), discoverabilityTitle: "Bigger text"),
            UIKeyCommand(input: "-", modifierFlags:.command, action: #selector(decreaseTextSize), discoverabilityTitle: "Smaller text"),
            // Still required with external keyboards as of May 26, 2020: control-C maps to control-C
            UIKeyCommand(input: "c", modifierFlags:.control, action: #selector(insertC))
            ]
        if #available(iOS 15.0, *) {
            let dKey = UIKeyCommand(input: "d", modifierFlags:.control, action: #selector(insertD))
            dKey.wantsPriorityOverSystemBehavior = true
            basicKeyCommands.append(dKey)
        } else {
            basicKeyCommands.append(UIKeyCommand(input: "d", modifierFlags:.control, action: #selector(insertD)))
        }
        /* Caps Lock remapped to escape: */
        if (UserDefaults.standard.bool(forKey: "escape_preference")) {
            // If we remapped caps-lock to escape, we need to disable caps-lock, at least with certain keyboards.
            // This loop remaps all lowercase characters without a modifier to themselves, thus disabling caps-lock
            // It doesn't work for characters produced with alt-key, though.
            for key in 0x061...0x2AF { // all lowercase unicode letters
                let K = Unicode.Scalar(key)!
                if CharacterSet.lowercaseLetters.contains(Unicode.Scalar(key)!) {
                    // no discoverabilityTitle
                    basicKeyCommands.append(UIKeyCommand(input: "\(K)", modifierFlags: [],  action: #selector(insertKey)))
                }
            }
            // This one remaps capslock to escape, no discoverabilityTitle
            basicKeyCommands.append(UIKeyCommand(input: "", modifierFlags:.alphaShift,  action: #selector(escapeAction)))
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
        let commandString = "window.term_.io.onVTKeystroke(\'\(sender.input!)');"
        evaluateJavaScript(commandString) { (result, error) in
            // if let error = error { print(error) }
            // if let result = result { print(result) }
        }
    }

    
}
