//
//  ContentView.swift
//  a-Shell
//
//  Created by Nicolas Holzschuch on 30/06/2019.
//  Copyright © 2019 AsheKube. All rights reserved.
//

import SwiftUI
import Combine
import WebKit

final class KeyboardResponder: BindableObject {
    let didChange = PassthroughSubject<CGFloat, Never>()
    
    private var _center: NotificationCenter
    private(set) var currentHeight: CGFloat = 0 {
        didSet {
            didChange.send(currentHeight)
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
    }
    
    func makeUIView(context: Context) -> WKWebView  {
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if (uiView.url != nil) { return } // Already loaded the page
        let htermFilePath = Bundle.main.path(forResource: "hterm", ofType: "html")
        uiView.load(URLRequest(url: URL(fileURLWithPath: htermFilePath!)))
    }
}

struct ContentView : View {
    @State var keyboard = KeyboardResponder()
    
    let webview = Webview()
    
    var body: some View {
        webview.padding(.bottom, keyboard.currentHeight)
        // resize depending on keyboard
    }
}


#if DEBUG
struct ContentView_Previews : PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
