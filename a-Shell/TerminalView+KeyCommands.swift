//
//  TerminalView+KeyCommands.swift
//  a-Shell
//
//  Created by Nicolas Holzschuch on 27/02/2026.
//  Copyright © 2026 AsheKube. All rights reserved.
//

import Foundation
import UIKit
import SwiftTerm

// Currently, external keyboard shortcuts are not working, see https://github.com/migueldeicaza/SwiftTerm/issues/483
// We keep the code in place for now, since it compiles and doesn't break anything.

extension TerminalView {
    
    @objc private func newWindow(_ sender: UIBarButtonItem) {
        if (UIDevice.current.model.hasPrefix("iPad")) {
            UIApplication.shared.requestSceneSessionActivation(nil, userActivity: nil, options: nil)
        }
    }

    @objc private func clearScreen(_ sender: UIBarButtonItem) {
        for scene in UIApplication.shared.connectedScenes {
            if let delegate = scene.delegate as? SceneDelegate {
                if delegate.terminalView == self {
                    delegate.clearScreen()
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


    open override var keyCommands: [UIKeyCommand]? {
        // In case we need keyboard personalization for specific languages
        // var language = textInputMode?.primaryLanguage ?? "en-US"
        // command-W is now a system-based command, like command-backquote
        let basicKeyCommands = [
            // "discoverabilityTitle:)' was deprecated in iOS 13.0" but it's quite convenient
            // These shortcuts work through direct implementation in SwiftTerm
            UIKeyCommand(input: "k", modifierFlags:.command, action: #selector(clearScreen), discoverabilityTitle: "Clear screen"),
            UIKeyCommand(input: "n", modifierFlags:.command, action: #selector(newWindow), discoverabilityTitle: "New window"),
            // These don't, but they still show up in the summary, so we comment them:
            // UIKeyCommand(input: "+", modifierFlags:.command, action: #selector(increaseTextSize), discoverabilityTitle: "Bigger text"),
            // UIKeyCommand(input: "-", modifierFlags:.command, action: #selector(decreaseTextSize), discoverabilityTitle: "Smaller text"),
            // back/forward one page keys for internal browser:
        ]
        return basicKeyCommands
    }
}
