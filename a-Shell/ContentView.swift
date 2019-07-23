//
//  ContentView.swift
//  a-Shell
//
//  Created by Nicolas Holzschuch on 30/06/2019.
//  Copyright © 2019 AsheKube. All rights reserved.
//

import SwiftUI
import WebKit
import Combine

final class KeyboardResponder: BindableObject {
    var willChange = PassthroughSubject<CGFloat, Never>()
    
    typealias PublisherType = PassthroughSubject<CGFloat, Never>
    
    private var _center: NotificationCenter
    private(set) var currentHeight: CGFloat = 0 {
        didSet {
            willChange.send(currentHeight)
        }
    }

    init(center: NotificationCenter = .default) {
        _center = center
        _center.addObserver(self, selector: #selector(keyBoardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        _center.addObserver(self, selector: #selector(keyBoardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    deinit {
        _center.removeObserver(self)
    }
    
    @objc func keyBoardWillShow(notification: Notification) {
        print("keyboard will show")
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            currentHeight = keyboardSize.height
            if (!UIDevice.current.model.hasPrefix("iPad")) {
                // currentHeight -= toolbarHeight
            }
            // NSLog("keyboard size = \(keyboardSize)")
        }
    }
    
    @objc func keyBoardWillHide(notification: Notification) {
        print("keyboard will hide")
        currentHeight = 0
    }
}


struct Webview : UIViewRepresentable {
    
    let webView: WKWebView
    
    init() {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptEnabled = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.preferences.setValue(true as Bool, forKey: "allowFileAccessFromFileURLs")
        config.preferences.setValue(true as Bool, forKey: "shouldAllowUserInstalledFonts")
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
    @State var keyboard = KeyboardResponder()
    
    let webview = Webview()
    
    var body: some View {
        webview.padding(.bottom, keyboard.currentHeight)
        // resize depending on keyboard
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
