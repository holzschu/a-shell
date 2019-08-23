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
        config.preferences.setValue(true as Bool, forKey: "shouldAllowUserInstalledFonts")
        config.selectionGranularity = .character; // Could be .dynamic
        webView = WKWebView(frame: .zero, configuration: config)
        webView.keyboardDisplayRequiresUserAction = false
    }
    
    func makeUIView(context: Context) -> WKWebView  {
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if (uiView.url != nil) { return } // Already loaded the page
        let htermFilePath = Bundle.main.path(forResource: "hterm", ofType: "html")
        let traitCollection = uiView.traitCollection
        uiView.tintColor = UIColor.placeholderText.resolvedColor(with: traitCollection)
        uiView.backgroundColor = UIColor.systemBackground.resolvedColor(with: traitCollection)
        var command = "window.foregroundColor = '" + UIColor.placeholderText.resolvedColor(with: traitCollection).toHexString() + "'; window.backgroundColor = '" + UIColor.systemBackground.resolvedColor(with: traitCollection).toHexString() + "'; "
        uiView.evaluateJavaScript(command) { (result, error) in
            if error != nil {
                NSLog("Error in updateUIView, line = \(command)")
                print(error)
            }
            if (result != nil) {
                print(result)
            }
        }
        uiView.loadFileURL(URL(fileURLWithPath: htermFilePath!), allowingReadAccessTo: URL(fileURLWithPath: htermFilePath!))
    }
}




struct ContentView: View {
    @State private var keyboardHeight: CGFloat = 0

    private let showPublisher = NotificationCenter.Publisher.init(
        center: .default,
        name: UIResponder.keyboardWillShowNotification
    ).map { (notification) -> CGFloat in
        if let rect = notification.userInfo?["UIKeyboardFrameEndUserInfoKey"] as? CGRect {
            return rect.size.height
        } else {
            return 0
        }
    }

    private let hidePublisher = NotificationCenter.Publisher.init(
        center: .default,
        name: UIResponder.keyboardWillHideNotification
    ).map {_ -> CGFloat in 0}
    
    let webview = Webview()
    
    var body: some View {
        // resize depending on keyboard
        webview.padding(.bottom, keyboardHeight).onReceive(showPublisher.merge(with: hidePublisher)) { (height) in
            self.keyboardHeight = height
        }
    }
}

/* #if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
*/
