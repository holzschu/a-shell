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
let escape = "\u{001B}"

extension WKWebView {

    
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
        let basicKeyCommands = [
            UIKeyCommand(input: UIKeyCommand.inputUpArrow, modifierFlags: [], action: #selector(upAction)),
            UIKeyCommand(input: UIKeyCommand.inputDownArrow, modifierFlags: [], action: #selector(downAction)),
            UIKeyCommand(input: UIKeyCommand.inputLeftArrow, modifierFlags: [], action: #selector(leftAction)),
            UIKeyCommand(input: UIKeyCommand.inputRightArrow, modifierFlags: [], action: #selector(rightAction)),
            UIKeyCommand(input: "k", modifierFlags:.command, action: #selector(clearScreen)), 
            UIKeyCommand(input: "c", modifierFlags:.alternate, action: #selector(insertC)), // This is weird. Need long term solution.
            UIKeyCommand(input: "c", modifierFlags:.control, action: #selector(insertC)), // This is weird. Need long term solution.
        ]
        return basicKeyCommands
    }

    @objc func insertC(_ sender: UIKeyCommand) {
        guard (sender.input != nil) else { return }
        var string = sender.input!
        // For reasons, the C key produces different chains. We override.
        // TODO: check this is still needed with the latest beta.
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
                print(error)
                print(result)
            }
        }
    }

    
    @objc func insertKey(_ sender: UIKeyCommand) {
        guard (sender.input != nil) else { return }
        // This function only gets called if we are in a notebook, in edit_mode:
        // Only remap the keys if we are in a notebook, editing cell:
        let commandString = "window.term_.io.onVTKeystroke(\'\(sender.input!)');"
        evaluateJavaScript(commandString) { (result, error) in
            if error != nil {
                print(error)
                print(result)
            }
        }
    }

    
}
