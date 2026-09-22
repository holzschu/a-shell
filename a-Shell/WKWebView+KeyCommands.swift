//
//  WkWebView+KeyCommands.swift
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
    
    @objc private func newWindow(_ sender: UIBarButtonItem) {
        if (UIDevice.current.model.hasPrefix("iPad")) {
            UIApplication.shared.requestSceneSessionActivation(nil, userActivity: nil, options: nil)
        }
    }

    @objc private func closeWindow(_ sender: UIBarButtonItem) {
        for scene in UIApplication.shared.connectedScenes {
            if let delegate = scene.delegate as? SceneDelegate {
                if delegate.terminalView == self {
                    delegate.closeWindow()
                    return
                }
            }
        }
    }

    @objc private func increaseTextSize(_ sender: UIBarButtonItem) {
        NSLog("Increase event received")
        for scene in UIApplication.shared.connectedScenes {
            if let delegate = scene.delegate as? SceneDelegate {
                if delegate.terminalView == self {
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
                if delegate.terminalView == self {
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
            // UIKeyCommand(input: UIKeyCommand.inputUpArrow, modifierFlags: [], action: #selector(upAction)),
            // UIKeyCommand(input: UIKeyCommand.inputDownArrow, modifierFlags: [], action: #selector(downAction)),
            // UIKeyCommand(input: UIKeyCommand.inputLeftArrow, modifierFlags: [], action: #selector(leftAction)),
            // UIKeyCommand(input: UIKeyCommand.inputRightArrow, modifierFlags: [], action: #selector(rightAction)),
            // "discoverabilityTitle:)' was deprecated in iOS 13.0" but it's quite convenient
            UIKeyCommand(input: "n", modifierFlags:.command, action: #selector(newWindow), discoverabilityTitle: "New window"),
            UIKeyCommand(input: "w", modifierFlags:.command, action: #selector(closeWindow), discoverabilityTitle: "Close window"),
            UIKeyCommand(input: "+", modifierFlags:.command, action: #selector(increaseTextSize), discoverabilityTitle: "Bigger text"),
            UIKeyCommand(input: "-", modifierFlags:.command, action: #selector(decreaseTextSize), discoverabilityTitle: "Smaller text"),
            // back/forward one page keys for internal browser:
            UIKeyCommand(input: "[", modifierFlags: [.command, .shift], action: #selector(gobackkeyAction), discoverabilityTitle: "Previous page"),
            UIKeyCommand(input: "]", modifierFlags: [.command, .shift], action: #selector(goforwardkeyAction), discoverabilityTitle: "Next page")
        ]
        let aKey = UIKeyCommand(input: "a", modifierFlags:.command, action: #selector(selectAll_), discoverabilityTitle: "Select all")
        if #available(iOS 15.0, *) {
            aKey.wantsPriorityOverSystemBehavior = true
        }
        basicKeyCommands.append(aKey)
        return basicKeyCommands
    }

    @objc func selectAll_(_ sender: UIKeyCommand) {
        let commandString = "editor.selectAll();"
        evaluateJavaScript(commandString) { (result, error) in
            if let error = error { 
                print("Error in executing \(commandString): \(error)")
            }
            if let result = result { print(result) }
        }
    }
    
}
