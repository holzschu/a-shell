//
//  ContentView.swift
//  a-Shell
//
//  Created by Nicolas Holzschuch on 30/06/2019.
//  Copyright © 2019 AsheKube. All rights reserved.
//

import SwiftUI
import WebKit

struct Webview : UIViewRepresentable {

    let webView: WKWebView

    init() {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptEnabled = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.preferences.setValue(true as Bool, forKey: "allowFileAccessFromFileURLs")
        // Does not change anything either way (??? !!!)
        // config.preferences.setValue(true as Bool, forKey: "shouldAllowUserInstalledFonts")
        config.selectionGranularity = .character; // Could be .dynamic
        // let preferences = WKWebpagePreferences()
        // preferences.allowsContentJavaScript = true
        webView = WKWebView(frame: .zero, configuration: config)
    }
    
    func makeUIView(context: Context) -> WKWebView  {
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if (uiView.url != nil) { return } // Already loaded the page
        let htermFilePath = Bundle.main.path(forResource: "hterm", ofType: "html")
        uiView.isOpaque = false
        uiView.loadFileURL(URL(fileURLWithPath: htermFilePath!), allowingReadAccessTo: URL(fileURLWithPath: htermFilePath!))
    }
}


struct ContentView: View {
    @State private var keyboardHeight: CGFloat = 0

    // Adapt window size to keyboard height, see:
    // https://stackoverflow.com/questions/56491881/move-textfield-up-when-thekeyboard-has-appeared-by-using-swiftui-ios
    // A publisher that combines all of the relevant keyboard changing notifications and maps them into a `CGFloat` representing the new height of the
    // keyboard rect.
     private let keyboardChangePublisher = NotificationCenter.Publisher(center: .default,
                                                                       name: UIResponder.keyboardWillShowNotification)
        .merge(with: NotificationCenter.Publisher(center: .default,
                                                  name: UIResponder.keyboardWillChangeFrameNotification))
        .merge(with: NotificationCenter.Publisher(center: .default,
                                                  name: UIResponder.keyboardWillHideNotification)
            // But we don't want to pass the keyboard rect from keyboardWillHide, so strip the userInfo out before
            // passing the notification on.
            .map { Notification(name: $0.name, object: $0.object, userInfo: nil) })
        // Now map the merged notification stream into a height value.
        .map { (note) -> CGFloat in
            let height = (note.userInfo?[UIWindow.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero).size.height
            let userInfo = note.userInfo
            // NSLog("Received \(note.name.rawValue) with height \(height)")
            // This is really annoying. Based on values from simulator.
            // Need to redo everything?
            if (height == 336) { return 306 } // Bug in iPhone 11 & 11 Pro Max, keyboard overestimated
            if (height == 89) { return 35 } // Bug in iPhone 11 with external keyboard, keyboard overestimated
            if (height == 326) { return 306 } // Bug in iPhone 11 Pro, keyboard is overestimated.
            if (height == 400) { return 380 } // Bug in iPad Pro 12.9 inch 3rd Gen
            if (height == 398) { return 380 } // Bug in iPad Pro 12.9 inch 3rd Gen
            if (height == 493) { return 476 } // Bug in iPad Pro 12.9 inch 3rd Gen
            if (height == 50) { return 40 } // Bug in iPad Pro 12.9 inch 3rd Gen with external keyboard
            // We have no way to make the difference between "no keyboard on screen" and "external kb connected"
            // (some BT keyboards do not register as such)
            if (height == 0) { return 40 } // At least the size of the toolbar -- if no keyboard present
            return height
    }
    
    let webview = Webview()
    
    var body: some View {
        if #available(iOS 14.0, *) {
            // on iOS 14, it seems that the webview adapts to the size of the keyboard.
            // Well, at least on the simulator.
            webview.padding(.top, 0)
        } else {
            // resize depending on keyboard. Specify size (.frame) instead of padding.
            webview.onReceive(keyboardChangePublisher) { self.keyboardHeight = $0 }
                .padding(.top, 0) // Important, to set the size of the view
                .padding(.bottom, keyboardHeight)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView()
        }
    }
}
