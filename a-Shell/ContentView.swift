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
    // Compiles but doesn't show.
    var JavaScriptAlertMessage: String
    var JavaScriptAlertTitle: String
    @State var showingJavaScriptConfirmAlert: Bool = false
    let contentController = ContentController(nil)

    init() {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptEnabled = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.preferences.setValue(true as Bool, forKey: "allowFileAccessFromFileURLs")
        config.preferences.setValue(true as Bool, forKey: "shouldAllowUserInstalledFonts")
        config.selectionGranularity = .character; // Could be .dynamic
        let wkcontentController = WKUserContentController()
        wkcontentController.add(contentController, name: "aShell")
        config.userContentController = wkcontentController
        webView = WKWebView(frame: .zero, configuration: config)
        JavaScriptAlertMessage = ""
        JavaScriptAlertTitle = ""
        // self._showingJavaScriptConfirmAlert = false
    }
    
    class ContentController: NSObject, WKScriptMessageHandler {
    var parent: WKWebView?
    init(_ parent: WKWebView?) {
        self.parent = parent
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage)  {
        if message.name == "test"{
            print(message.body)
            parent?.evaluateJavaScript("document.getElementsByClassName('mat-toolbar-single-row')[0].style.backgroundColor = 'red'", completionHandler: nil)

        }
    }
    
    
    class Coordinator: NSObject, WKUIDelegate {

        var parent: Webview

        init(_ parent: Webview) {
            self.parent = parent
        }

        // Delegate methods go here
        
        // Javascript alert dialog boxes:
        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping () -> Void) {
            
            let arguments = message.components(separatedBy: "\n")
            NSLog("arguments = \(arguments)")
            if (arguments.count == 0) { return }
            let title = arguments[0]
            var messageMinusTitle = message
            messageMinusTitle.removeFirst(title.count)
            
            parent.JavaScriptAlertMessage = messageMinusTitle
            parent.JavaScriptAlertTitle = title
            parent.showingJavaScriptConfirmAlert = true
            // Does not crash, but does not show the alert either. Progress.
            // while (parent.showingJavaScriptConfirmAlert) { } // wait until the alert is dismissed
            completionHandler()
        }
        
        
        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping (Bool) -> Void) {
            
            let arguments = message.components(separatedBy: "\n")
            /*
            let alertController = UIAlertController(title: arguments[0], message: arguments[1], preferredStyle: .alert)
            
            alertController.addAction(UIAlertAction(title: arguments[2], style: .cancel, handler: { (action) in
                completionHandler(false)
            }))
            
            if (arguments[3].hasPrefix("btn-danger")) {
                var newLabel = arguments[3]
                newLabel.removeFirst("btn-danger".count)
                alertController.addAction(UIAlertAction(title: newLabel, style: .destructive, handler: { (action) in
                    completionHandler(true)
                }))
            } else {
                alertController.addAction(UIAlertAction(title: arguments[3], style: .default, handler: { (action) in
                    completionHandler(true)
                }))
            }
            
            if let presenter = alertController.popoverPresentationController {
                presenter.sourceView = self.view
            }
            
            self.present(alertController, animated: true, completion: nil) */
        }
        
        
        func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping (String?) -> Void) {
            
            let arguments = prompt.components(separatedBy: "\n")
            /*
            let alertController = UIAlertController(title: arguments[0], message: arguments[1], preferredStyle: .alert)
            
            alertController.addTextField { (textField) in
                textField.text = defaultText
            }

            alertController.addAction(UIAlertAction(title: arguments[2], style: .default, handler: { (action) in
                completionHandler(nil)
            }))
            
            alertController.addAction(UIAlertAction(title: arguments[3], style: .default, handler: { (action) in
                if let text = alertController.textFields?.first?.text {
                    completionHandler(text)
                } else {
                    completionHandler(defaultText)
                }
            }))
            
            if let presenter = alertController.popoverPresentationController {
                presenter.sourceView = self.view
            }
            
            self.present(alertController, animated: true, completion: nil)
             */
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    
    
    func makeUIView(context: Context) -> WKWebView  {
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if (uiView.url != nil) { return } // Already loaded the page
        let htermFilePath = Bundle.main.path(forResource: "hterm", ofType: "html")
        let traitCollection = uiView.traitCollection
        uiView.isOpaque = false
        uiView.tintColor = UIColor.placeholderText.resolvedColor(with: traitCollection)
        uiView.backgroundColor = UIColor.systemBackground.resolvedColor(with: traitCollection)
        uiView.uiDelegate = context.coordinator
        // uiView.accessibilityIgnoresInvertColors
        let command = "window.foregroundColor = '" + UIColor.placeholderText.resolvedColor(with: traitCollection).toHexString() + "'; window.backgroundColor = '" + UIColor.systemBackground.resolvedColor(with: traitCollection).toHexString() + "'; window.cursorColor = '" + UIColor.link.resolvedColor(with: traitCollection).toHexString() + "';"
        uiView.evaluateJavaScript(command) { (result, error) in
            if error != nil {
                // NSLog("Error in updateUIView, line = \(command)")
                // print(error)
            }
            if (result != nil) {
                // sprint(result)
            }
        }
        uiView.loadFileURL(URL(fileURLWithPath: htermFilePath!), allowingReadAccessTo: URL(fileURLWithPath: htermFilePath!))
    }
}


struct ContentView: View {
    @State private var keyboardHeight: CGFloat = 0
    @State var showAlert = false

    // @State(initialValue: false) var showingJavaScriptConfirmAlert: Bool

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
        // resize depending on keyboard. Specify size (.frame) instead of padding.
        webview.onReceive(keyboardChangePublisher) { self.keyboardHeight = $0 }
            .padding(.top, 0) // Important, to set the size of the view
            .padding(.bottom, keyboardHeight)
            .alert(isPresented: webview.$showingJavaScriptConfirmAlert) {
                Alert(title: Text(webview.JavaScriptAlertTitle),
                      message: Text(webview.JavaScriptAlertMessage))
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
