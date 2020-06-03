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
            if error != nil {
                print(error)
            }
            if (result != nil) {
                print(result)
            }
        }
    }
    
    @objc private func upAction(_ sender: UIBarButtonItem) {
        evaluateJavaScript("window.term_.io.onVTKeystroke(\"" + escape + "[A\");") { (result, error) in
            if error != nil {
                print(error)
            }
            if (result != nil) {
                print(result)
            }
        }
    }
    
    @objc private func downAction(_ sender: UIBarButtonItem) {
        evaluateJavaScript("window.term_.io.onVTKeystroke(\"" + escape + "[B\");") { (result, error) in
            if error != nil {
                print(error)
            }
            if (result != nil) {
                print(result)
            }
            
        }
    }

    @objc private func leftAction(_ sender: UIBarButtonItem) {
        evaluateJavaScript("window.term_.io.onVTKeystroke(\"" + escape + "[D\");") { (result, error) in
            if error != nil {
                print(error)
            }
            if (result != nil) {
                print(result)
            }
            
        }
    }

    @objc private func rightAction(_ sender: UIBarButtonItem) {
        evaluateJavaScript("window.term_.io.onVTKeystroke(\"" + escape + "[C\");") { (result, error) in
            if error != nil {
                print(error)
            }
            if (result != nil) {
                print(result)
            }
            
        }
    }
    
    @objc private func newWindow(_ sender: UIBarButtonItem) {
        UIApplication.shared.requestSceneSessionActivation(nil, userActivity: nil, options: nil)
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
        let javascriptCommand = "window.term_.io.print('" + escape + "[2J'); window.term_.io.print('" + escape + "[1;1H'); " +
        " window.printPrompt(); window.term_.io.print(window.term_.io.currentCommand); var endOfCommand = window.term_.io.currentCommand.slice(window.currentCommandCursorPosition, window.term_.io.currentCommand.length); var wcwidth = lib.wc.strWidth(endOfCommand); for (var i = 0; i < wcwidth; i++) { io.print('\\b'); }"
        evaluateJavaScript(javascriptCommand) { (result, error) in
            if error != nil {
                print(error)
            }
            if (result != nil) {
                print(result)
            }
        }
    }


    override open var keyCommands: [UIKeyCommand]? {
        var language = textInputMode?.primaryLanguage ?? "en-US"
        var basicKeyCommands = [
            UIKeyCommand(input: UIKeyCommand.inputUpArrow, modifierFlags: [], action: #selector(upAction)),
            UIKeyCommand(input: UIKeyCommand.inputDownArrow, modifierFlags: [], action: #selector(downAction)),
            UIKeyCommand(input: UIKeyCommand.inputLeftArrow, modifierFlags: [], action: #selector(leftAction)),
            UIKeyCommand(input: UIKeyCommand.inputRightArrow, modifierFlags: [], action: #selector(rightAction)),
            // "discoverabilityTitle:)' was deprecated in iOS 13.0" but it's quite convenient
            UIKeyCommand(input: "k", modifierFlags:.command, action: #selector(clearScreen), discoverabilityTitle: "Clear screen"),
            UIKeyCommand(input: "n", modifierFlags:.command, action: #selector(newWindow), discoverabilityTitle: "New window"),
            UIKeyCommand(input: "w", modifierFlags:.command, action: #selector(closeWindow), discoverabilityTitle: "Close window"),
            // Still required with external keyboards as of May 26, 2020: control-C maps to control-C
            UIKeyCommand(input: "c", modifierFlags:.control, action: #selector(insertC)),
        ]
        if (language.hasPrefix("en")) {
            // iOS English keyboard does not have "ç" and "Ç" mapped to alt-c
            basicKeyCommands.append(UIKeyCommand(input: "c", modifierFlags:.alternate, action: #selector(insertC)))
            basicKeyCommands.append(UIKeyCommand(input: "c", modifierFlags:[.alternate, .shift], action: #selector(insertC)))
        }
        if (language.hasPrefix("cs")) {
            // Likewise, Czech keyboard is missing some shortcuts. This is the entire top row, alt-[0-9] and shift-alt-[0-9].
            // basicKeyCommands.append(UIKeyCommand(input: "+", modifierFlags:.alternate, action: #selector(insertCzechKB)))
            basicKeyCommands.append(UIKeyCommand(input: "ě", modifierFlags:.alternate, action: #selector(insertCzechKB)))
            basicKeyCommands.append(UIKeyCommand(input: "š", modifierFlags:.alternate, action: #selector(insertCzechKB)))
            basicKeyCommands.append(UIKeyCommand(input: "č", modifierFlags:.alternate, action: #selector(insertCzechKB)))
            basicKeyCommands.append(UIKeyCommand(input: "ř", modifierFlags:.alternate, action: #selector(insertCzechKB)))
            basicKeyCommands.append(UIKeyCommand(input: "ž", modifierFlags:.alternate, action: #selector(insertCzechKB)))
            basicKeyCommands.append(UIKeyCommand(input: "ý", modifierFlags:.alternate, action: #selector(insertCzechKB)))
            basicKeyCommands.append(UIKeyCommand(input: "á", modifierFlags:.alternate, action: #selector(insertCzechKB)))
            basicKeyCommands.append(UIKeyCommand(input: "í", modifierFlags:.alternate, action: #selector(insertCzechKB)))
            basicKeyCommands.append(UIKeyCommand(input: "é", modifierFlags:.alternate, action: #selector(insertCzechKB)))
            basicKeyCommands.append(UIKeyCommand(input: "+", modifierFlags:[.alternate, .shift], action: #selector(insertCzechKB)))
            basicKeyCommands.append(UIKeyCommand(input: "ě", modifierFlags:[.alternate, .shift], action: #selector(insertCzechKB)))
            basicKeyCommands.append(UIKeyCommand(input: "š", modifierFlags:[.alternate, .shift], action: #selector(insertCzechKB)))
            basicKeyCommands.append(UIKeyCommand(input: "č", modifierFlags:[.alternate, .shift], action: #selector(insertCzechKB)))
            basicKeyCommands.append(UIKeyCommand(input: "ř", modifierFlags:[.alternate, .shift], action: #selector(insertCzechKB)))
            basicKeyCommands.append(UIKeyCommand(input: "ž", modifierFlags:[.alternate, .shift], action: #selector(insertCzechKB)))
            basicKeyCommands.append(UIKeyCommand(input: "ý", modifierFlags:[.alternate, .shift], action: #selector(insertCzechKB)))
            basicKeyCommands.append(UIKeyCommand(input: "á", modifierFlags:[.alternate, .shift], action: #selector(insertCzechKB)))
            basicKeyCommands.append(UIKeyCommand(input: "í", modifierFlags:[.alternate, .shift], action: #selector(insertCzechKB)))
            basicKeyCommands.append(UIKeyCommand(input: "é", modifierFlags:[.alternate, .shift], action: #selector(insertCzechKB)))
        }
        if (language.hasPrefix("nb")) {
            // Norwegian keyboard support. Left-alt key is not working.
            basicKeyCommands.append(UIKeyCommand(input: "ě", modifierFlags:.alternate, action: #selector(insertCzechKB)))
            let keyboardCharacters = "<1234567890+´qwetyuiopå¨asdfghjkløæzxcvbnm,.-"
            for character in keyboardCharacters {
                basicKeyCommands.append(UIKeyCommand(input: "\(character)", modifierFlags:.alternate, action: #selector(insertNorwegianKB)))
                basicKeyCommands.append(UIKeyCommand(input: "\(character)", modifierFlags:[.alternate, .shift], action: #selector(insertNorwegianKB)))
            }
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

    @objc func insertCzechKB(_ sender: UIKeyCommand) {
        guard (sender.input != nil) else { return }
        var string = sender.input!
        if (sender.modifierFlags.contains(.alternate) && sender.modifierFlags.contains(.shift)) {
            // NSLog("alt-shift-number: \(string)")
            // alt-shift-number
            switch (string) {
            case "+":
                string = "¬"
                break
            case "ě":
                string = "•"
                break
            case "š":
                string = "≠"
                break
            case "č":
                string = "£"
                break
            case "ř":
                string = "◊"
                break
            case "ž":
                string = "†"
                break
            case "ý":
                string = "¶"
                break
            case "á":
                string = "÷"
                break
            case "í":
                string = "«"
                break
            case "é":
                string = "»"
                break
            default:
                break
            }
        } else if (sender.modifierFlags.contains(.alternate)) {
            // NSLog("alt-number: \(string)")
            // alt-number
            switch (string) {
            case "ě":
                string = "@"
                break
            case "š":
                string = "#"
                break
            case "č":
                string = "$"
                break
            case "ř":
                string = "~"
                break
            case "ž":
                string = "^"
                break
            case "ý":
                string = "&"
                break
            case "á":
                string = "*"
                break
            case "í":
                string = "{"
                break
            case "é":
                string = "}"
                break
            default:
                break
            }
        }
        // NSLog("sending: \(string)")
        let commandString = "window.term_.io.onVTKeystroke(\'\(string)');"
        evaluateJavaScript(commandString) { (result, error) in
            if error != nil {
                // print(error)
                // print(result)
            }
        }
    }

    @objc func insertNorwegianKB(_ sender: UIKeyCommand) {
        let keyboardCharacters = Array("<1234567890+´qwetyuiopå¨asdfghjkløæzxcvbnm,.-")
        let altKeyboard = Array("≤©™£€∞§|[]≈±`•Ωé†µüıœπ˙~ß∂ƒ¸˛√ªﬁöä÷≈ç‹›‘’‚…–")
        let shiftAltKeyboard = Array("≥¡®¥¢‰¶\\{}≠¿ °˝É‡˜ÜˆŒ∏˚^◊∑∆∫¯˘¬ºﬂÖÄ⁄ Ç«»“”„·—")
        guard (sender.input != nil) else { return }
        var string = sender.input!
        let character = Array(string)[0]
        if (keyboardCharacters.contains(character)) {
            if let index = keyboardCharacters.firstIndex(of: character) {
                // NSLog("index = \(index)")
                if (sender.modifierFlags.contains(.alternate) && sender.modifierFlags.contains(.shift)) {
                    // NSLog("alt-shift-key: \(string)")
                    string = String(shiftAltKeyboard[index])
                } else if (sender.modifierFlags.contains(.alternate)) {
                    // NSLog("alt-key: \(string)")
                    string = String(altKeyboard[index])
                }
            }
        }
        if (string != " ") {
            if (string == "\\") { string = "\\\\" }
            // NSLog("sending: \(string)")
            let commandString = "window.term_.io.onVTKeystroke(\'\(string)');"
            evaluateJavaScript(commandString) { (result, error) in
                if error != nil {
                    // print(error)
                    // print(result)
                }
            }
        }
    }

    
    @objc func insertC(_ sender: UIKeyCommand) {
        guard (sender.input != nil) else { return }
        var string = sender.input!
        // For reasons, the C key produces different chains. We override.
        // TODO: check this is still needed with each new iOS. Still true as of 13.5.
        if (sender.modifierFlags.contains(.alternate)) {
            string = "ç"
            if (sender.modifierFlags.contains(.shift)) {
                string = "Ç"
            }
        } else if (sender.modifierFlags.contains(.control)) {
            string = "\u{003}"
        }
        let commandString = "window.term_.io.onVTKeystroke(\'\(string)');"
        evaluateJavaScript(commandString) { (result, error) in
            if error != nil {
               // print(error)
               // print(result)
            }
        }
    }

    
    @objc func insertKey(_ sender: UIKeyCommand) {
        guard (sender.input != nil) else { return }
        let commandString = "window.term_.io.onVTKeystroke(\'\(sender.input!)');"
        evaluateJavaScript(commandString) { (result, error) in
            if error != nil {
                print(error)
                print(result)
            }
        }
    }

    
}
