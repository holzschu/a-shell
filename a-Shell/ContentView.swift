//
//  ContentView.swift
//  a-Shell
//
//  Created by Nicolas Holzschuch on 30/06/2019.
//  Copyright © 2019 AsheKube. All rights reserved.
//

import SwiftUI
import SwiftTerm
import WebKit

// SwiftUI extension for fullscreen rendering
public enum ViewBehavior: Int {
    case original
    case ignoreSafeArea
    case fullScreen
}

extension View {
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

struct Termview : UIViewRepresentable {
    let view: TerminalView
    
    init() {
        view = TerminalView()
    }
    
    func makeUIView(context: Context) -> UIView {
        let edgeSwipe = UIScreenEdgePanGestureRecognizer(
            target: edgeSwipeTarget,
            action: #selector(EdgeSwipeTarget.handleRightEdgeSwipe(_:)))
        edgeSwipe.edges = .right
        view.addGestureRecognizer(edgeSwipe)

        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context)
    {
        
    }
}

class EdgeSwipeTarget: NSObject {
    @objc func handleRightEdgeSwipe(_ gesture: UIScreenEdgePanGestureRecognizer) {
        if gesture.state == .began {
            if let delegate = currentDelegate {
                delegate.activateBrowserAction()
            }
        }
    }
}

struct Webview : UIViewRepresentable {
    typealias WebViewType = WKWebView

    let webView: WKWebView
    var terminalIconName = "pc"

    init() {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        if #available(iOS 15.4, *) {
            config.preferences.isElementFullscreenEnabled = true
        }
        if #available(iOS 14.5, *) {
            config.preferences.isTextInteractionEnabled = true
        }
        config.preferences.setValue(true as Bool, forKey: "allowFileAccessFromFileURLs")
        config.setValue(true as Bool, forKey: "allowUniversalAccessFromFileURLs")
        // Does not change anything either way (??? !!!)
        config.preferences.setValue(true as Bool, forKey: "shouldAllowUserInstalledFonts")
        // let preferences = WKWebpagePreferences()
        // preferences.allowsContentJavaScript = true
        webView = .init(frame: .zero, configuration: config)
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        webView.allowsBackForwardNavigationGestures = true
        if #available(iOS 15.0, *) {
            webView.keyboardLayoutGuide.topAnchor.constraint(equalTo: webView.bottomAnchor).isActive = true
            // This is necessary to allow the various edge constraints to engage.
            webView.keyboardLayoutGuide.followsUndockedKeyboard = true
        }
        if #available(iOS 17, *) {
            terminalIconName = "apple.terminal"
        }
    }
    
    func makeUIView(context: Context) -> WebViewType {
        return webView
    }

    func updateUIView(_ uiView: WebViewType, context: Context) {
        NSLog("updateUIView: url= \(uiView.url)")
        if (uiView.url != nil) { return } // Already loaded the page
        uiView.isOpaque = false
    }
}


public var toolbarShouldBeShown = true
public var useSystemToolbar = UIDevice.current.model.hasPrefix("iPad")
public var isiPad = UIDevice.current.model.hasPrefix("iPad")
public var showToolbar = true
public var showKeyboardAtStartup = true
// .fullScreen is too much for floating KB + toolbar, ignoreSafeArea seems to work,
// automatic detection causes blank screen when switching back-forth
// Make this a user-defined setup, with "ignoreSafeArea" the default.
public var viewBehavior: ViewBehavior = .ignoreSafeArea
public var latestNotification: String = ""
public var extendBy: CGFloat = 0
public var showWebView = false
public var terminalViewHeight = 80
private let edgeSwipeTarget = EdgeSwipeTarget()

struct ContentView: View {
    @State private var keyboardHeight: CGFloat = 0
    @State private var lastKeyboardHeight: CGFloat = 0
    @State private var frameHeight: CGFloat = 0
    @State private var frameWidth: CGFloat = 0
    @State private var dynamicIsland: CGFloat = 0
    @State private var localShowWebView: Bool = true

    let terminalview = Termview()
    let webview = Webview()
    
    // Adapt window size to keyboard height, see:
    // https://stackoverflow.com/questions/56491881/move-textfield-up-when-thekeyboard-has-appeared-by-using-swiftui-ios
    // A publisher that combines all of the relevant keyboard changing notifications and maps them into a `CGFloat` representing the new height of the
    // keyboard rect.
    private let keyboardChangePublisher = NotificationCenter.Publisher(center: .default,
                                                                       name: UIResponder.keyboardWillShowNotification)
        .merge(with: NotificationCenter.Publisher(center: .default,
                                                  name: UIResponder.keyboardWillChangeFrameNotification))
        .merge(with: NotificationCenter.Publisher(center: .default, name: UIResponder.keyboardWillHideNotification))
    // Now map the merged notification stream into a height value.
        .map { (note) -> CGFloat in
            let height = (note.userInfo?[UIWindow.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero).size.height
            let width = (note.userInfo?[UIWindow.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero).size.width
            let x = (note.userInfo?[UIWindow.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero).origin.x
            let y = (note.userInfo?[UIWindow.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero).origin.y
            let userInfo = note.userInfo
            NSLog("SwiftUI Received \(note.name.rawValue) with height \(height) width \(width) origin: \(x) -- \(y)")
            if (note.name.rawValue == "UIKeyboardWillShowNotification") {
                latestNotification = "UIKeyboardWillShowNotification"
                showKeyboardAtStartup = true
            } else if (note.name.rawValue == "UIKeyboardWillHideNotification") {
                latestNotification = "UIKeyboardWillHideNotification"
            } else {
                latestNotification = ""
            }
            return height
        }
    
    // tests: 1) iPhone vertical, move to horizontal, check that window remains good
    //        2) reverse: iPhone horizontal, move to vertical
    //        3) remove bluetooth connection, check that window is resized after onScreen keyboard appears
    //        4) use hideKeyboard, check that window now extends all the way to the bottom
    //        5) click on screen, check that the bottom of the window is at the top of the toolbar
    // Known issues:
    //        - on iPhone SE, vertical -> horizontal -> vertical = terminal view is shifted 10 points up, behind the status bar.
    //           Could maybe be fixed with safeAreaPadding() but that is iOS 17 only.
    var body: some View {
        GeometryReader {geometry in
            Group {
                if (showWebView && localShowWebView) {
                    // NavigationView is deprecated, but the replacement only works for iOS 16 and above.
                    // I'm trying to keep a-Shell active for iOS 14 and above.
                    NavigationView {
                        webview
                            .toolbar {
                                ToolbarItem(placement: .navigationBarLeading) {
                                    Button(action: {
                                        if (webview.webView.canGoBack) {
                                            webview.webView.goBack()
                                            let url = webview.webView.url
                                            if url?.host == "localhost" && url?.path == "/wasm.html" {
                                                showKeyboardAtStartup = true
                                                localShowWebView = false
                                                terminalview.view.becomeFirstResponder()
                                            }
                                        }
                                    }, label: {
                                        Image(systemName: "arrow.backward")
                                    })
                                }
                                ToolbarItem(placement: .navigationBarLeading) {
                                    Button(action: {
                                        // reload wams.html at this position in history:
                                        if (appVersion != "a-Shell-mini") {
                                            webview.webView.load(URLRequest(url: URL(string: "https://localhost:8443/wasm.html")!))
                                        } else {
                                            NSLog("Loding wasm.html from 8334 (sceneWillEnterForeground)")
                                            webview.webView.load(URLRequest(url: URL(string: "https://localhost:8334/wasm.html")!))
                                        }
                                        localShowWebView = false
                                        showWebView = false
                                        showKeyboardAtStartup = true
                                        _ = terminalview.view.becomeFirstResponder()
                                    }, label: {
                                        Image(systemName: webview.terminalIconName) // apple.terminal or pc depending on the version
                                    })
                                }
                                ToolbarItem(placement: .principal) {
                                    // TODO: it would be great if this could show the title of the web page,
                                    // but I don't know how to do that.
                                    Text("a-Shell navigator")
                                }
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button(action: {
                                        webview.webView.reload()
                                    }, label: {
                                        Image(systemName: "arrow.clockwise.circle")
                                    })
                                }
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button(action: {
                                        if (webview.webView.canGoForward) {
                                            let nextUrl = webview.webView.backForwardList.forwardItem?.url
                                            if nextUrl?.host != "localhost" || nextUrl?.path != "/wasm.html" {
                                                webview.webView.goForward()
                                            }
                                        }
                                    }, label: {
                                        Image(systemName: "arrow.forward")
                                    })
                                }
                            }.navigationBarTitleDisplayMode(.inline)
                    }.navigationViewStyle(.stack) // so the navigation view is full screen on an iPad
                } else {
                    terminalview
                }
            }
            // terminalview
            .onReceive(keyboardChangePublisher) {
                if (showWebView) {
                    let url = webview.webView.url
                    NSLog("showWebView: \(url)")
                    if url?.host == "localhost" && url?.path == "/wasm.html" {
                        localShowWebView = false
                    } else {
                        localShowWebView = true
                    }
                }
                keyboardHeight = $0
                if !showKeyboardAtStartup || ((latestNotification == "UIKeyboardWillHideNotification") && !useSystemToolbar) {
                    NSLog("setting keyboardHeight to 0 from \(keyboardHeight)")
                    keyboardHeight = 0
                }
                frameHeight = geometry.size.height
                frameWidth = geometry.size.width
                if (!isiPad) {
                    // iPhones (only)
                    if (frameWidth > UIScreen.main.bounds.width) {
                        frameWidth = UIScreen.main.bounds.width
                    }
                    let globalFrame = geometry.frame(in: .global)
                    if (globalFrame.minY > 45) {
                        // There is a dynamic island at the top, we need to move the terminal window up a bit.
                        // iPhones with DI: minY = 59 on iPhone 15, 62 on iPhone 17
                        // iPhones without DI: minY = 20 on iPhone 8 and iPhone SE
                        dynamicIsland = 13
                    }
                    NSLog("Scene: \(UIScreen.main.bounds) terminal frame: \(terminalview.view.frame) geometry size: \(geometry.size) keyboardHeight: \(keyboardHeight) minY= \(globalFrame.minY)")
                    // geometry.size.height is wildly all over the place on iPhones.
                    // Sometimes it's a better estimate than keyboardHeight + toolbarHeight, but
                    // it doesn't change when we show and remove the emoji keyboard.
                    // Not for future self: do **not** use geometry.size.height for anything. I tried, it fails.
                    frameHeight = UIScreen.main.bounds.height - keyboardHeight
                    if (UIScreen.main.bounds.height > UIScreen.main.bounds.width) {
                        // keyboard height takes into account the toolbar height in landscape mode, not in portrait
                        // It's probably a bug that will be fixed at some poin
                        if (UIScreen.main.bounds.height < 700) {
                            // The toolbar height is a bit too much on iPhone SE and iPhone 8 (h = 667)
                            // This could be merged with the dynamic island test (?)
                            // Apparently we need the -20 even when there's no toolbar on iPhone SE
                            // It doesn't make sense
                            frameHeight -= 20
                        } else if showToolbar  {
                            NSLog("toolbar height: \(terminalview.view.inputAccessoryView!.bounds.height)")
                            let toolbarHeight = terminalview.view.inputAccessoryView!.bounds.height
                            frameHeight -= toolbarHeight
                            if #unavailable(iOS 26) {
                                // related to line 208 in SceneDelegate: we made the toolbar smaller, but
                                // we need to reduce the frame size a tiny bit as well
                                // Value of 3 has been determined through expensive testing
                                frameHeight -= 3
                            }
                        }
                    }
                }  else {
                    // iPads:
                    // geometry.size.height is not reliable (and neither is maxY, since maxY = minY + height)
                    // geometry.size.height can change without us going through this keyboardChange call.
                    // frameHeight stores the difference between window size and geometry.size.height
                    let globalFrame = geometry.frame(in: .global)
                    if (keyboardHeight < 40) {
                        // iPad 16, slideOver window. minY == 20, keyboardHeight == 35
                        frameHeight = 0.0 // geometry.size.height - (UIScreenp.main.bounds.height - 73 - globalFrame.minY)
                    } else if (keyboardHeight < 60) {
                        // iPad 16, full window. minY == 20, keyboardHeight == 55
                        frameHeight = 0.0 // geometry.size.height - (UIScreen.main.bounds.height - 73)
                    } else if (keyboardHeight < 90) {
                        // iOS 26 with external keyboard (I see 66, 69, 71, 76...)
                        // minY == 32
                        frameHeight = 16 // ?
                    } else {
                        frameHeight = 0
                    }
                    NSLog("keyboardHeight: \(keyboardHeight) geometry height: \(geometry.size.height) min: \(globalFrame.minY)  computed: \(geometry.size.height - frameHeight) Screen: \(UIScreen.main.bounds.height) ")
                }
                NSLog("results: frameHeight: \(geometry.size.height - frameHeight) actual: \(frameHeight)")
            }
            // iPhones
            .if(!isiPad) {
                $0.frame(height: frameHeight).position(x: frameWidth / 2, y: frameHeight / 2 - dynamicIsland)
            }
            // if nothing is defined, the size is geometry.size.height
            .if((viewBehavior == .ignoreSafeArea || viewBehavior == .original) && isiPad) {
                $0.frame(maxHeight: geometry.size.height - frameHeight)
            }
            .if(((viewBehavior == .ignoreSafeArea || viewBehavior == .fullScreen)) && isiPad) {
                $0.ignoresSafeArea(.container, edges: .bottom)
            }
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
