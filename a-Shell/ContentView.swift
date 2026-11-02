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

final class ConfirmingTerminalView: TerminalView {
    override func paste(_ sender: Any?) {
        guard let scene = terminalDelegate as? SceneDelegate, let text = UIPasteboard.general.string else { super.paste(sender); return }
        if getTerminal().bracketedPasteMode || !text.contains(where: { $0.isNewline }) { super.paste(sender); return }
        scene.confirmPaste(text, intoTerminal: true) { [weak self] in self?.pasteConfirmed(sender) }
    }

    private func pasteConfirmed(_ sender: Any?) {
        super.paste(sender)
    }
}

struct Termview : UIViewRepresentable {
    let view: TerminalView
    
    init() {
        view = ConfirmingTerminalView()
    }
    
    func makeUIView(context: Context) -> UIView {
        let edgeSwipe = UIScreenEdgePanGestureRecognizer(
            target: edgeSwipeTarget,
            action: #selector(EdgeSwipeTarget.handleRightEdgeSwipe(_:)))
        edgeSwipe.edges = .right
        view.addGestureRecognizer(edgeSwipe)

        return TerminalContainerView(terminal: view)
    }
    
    func updateUIView(_ uiView: UIView, context: Context)
    {
        
    }
}


private final class TerminalKeyboardViewport: UIView {
    weak var terminal: TerminalView?

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let terminal, bounds.width > 0, bounds.height > 0, terminal.bounds.size != bounds.size else { return }
        terminal.layer.removeAllAnimations()
        UIView.performWithoutAnimation {
            terminal.transform = .identity
            terminal.frame = bounds
            terminal.layoutIfNeeded()
        }
    }
}

final class TerminalContainerView: UIView {
    private weak var terminal: TerminalView?
    private var keyboardBottomConstraint: NSLayoutConstraint?
    private var notificationBottomConstraint: NSLayoutConstraint?
    private var keyboardViewport: TerminalKeyboardViewport?
    private var keyboardSnapshot: UIView?
    private var keyboardFrame = CGRect.zero
    private var keyboardNotificationWidth: CGFloat?
    private var keyboardObservers: [NSObjectProtocol] = []

    init(terminal: TerminalView) {
        self.terminal = terminal
        super.init(frame: .zero)
        if #available(iOS 26, *), UIDevice.current.userInterfaceIdiom == .phone {
            let viewport = TerminalKeyboardViewport()
            viewport.translatesAutoresizingMaskIntoConstraints = false
            viewport.clipsToBounds = true
            addSubview(viewport)
            NSLayoutConstraint.activate([
                viewport.topAnchor.constraint(equalTo: topAnchor),
                viewport.leadingAnchor.constraint(equalTo: leadingAnchor),
                viewport.trailingAnchor.constraint(equalTo: trailingAnchor)
            ])
            viewport.addSubview(terminal)
            viewport.terminal = terminal
            terminal.contentMode = .topLeft
            keyboardViewport = viewport
            let bottom = viewport.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor)
            bottom.isActive = true
            notificationBottomConstraint = bottom
            keyboardObservers.append(NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillChangeFrameNotification, object: nil, queue: .main) { [weak self] note in
                guard let self, let viewport = self.keyboardViewport, let terminal = viewport.terminal else { return }
                let initialWidth = viewport.bounds.width
                defer { self.keyboardNotificationWidth = initialWidth }
                let presentationOffset = terminal.layer.presentation()?.affineTransform().ty ?? 0
                self.layoutIfNeeded()
                let previousInset = self.notificationBottomConstraint?.constant
                self.keyboardFrame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero
                self.updateKeyboardInset()
                guard self.notificationBottomConstraint?.constant != previousInset else { return }
                let initialTopRow = terminal.getTerminal().getTopVisibleRow()
                let cellHeight = terminal.getOptimalFrameSize().height / CGFloat(max(1, terminal.getTerminal().rows))
                // The snapshot fills rows the resized terminal no longer covers; glyphs stay unscaled.
                let snapshot = self.snapshotView(afterScreenUpdates: false)
                snapshot?.frame = self.bounds
                snapshot?.isUserInteractionEnabled = false
                self.keyboardSnapshot?.removeFromSuperview()
                if let snapshot { viewport.insertSubview(snapshot, belowSubview: terminal) }
                self.keyboardSnapshot = snapshot
                let duration = note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0
                let curve = note.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? 0
                UIView.animate(withDuration: duration, delay: 0, options: [UIView.AnimationOptions(rawValue: curve << 16), .beginFromCurrentState, .allowUserInteraction]) {
                    self.layoutIfNeeded()
                    guard viewport.bounds.width == initialWidth else {
                        snapshot?.removeFromSuperview()
                        if self.keyboardSnapshot === snapshot { self.keyboardSnapshot = nil }
                        return
                    }
                    let rowOffset = -CGFloat(terminal.getTerminal().getTopVisibleRow() - initialTopRow) * cellHeight - presentationOffset
                    UIView.performWithoutAnimation {
                        terminal.transform = CGAffineTransform(translationX: 0, y: -rowOffset)
                    }
                    UIView.animate(withDuration: duration, delay: 0, options: [UIView.AnimationOptions(rawValue: curve << 16), .allowUserInteraction]) {
                        terminal.transform = .identity
                    }
                    snapshot?.transform = CGAffineTransform(translationX: 0, y: rowOffset)
                } completion: { [weak self, weak snapshot] _ in
                    snapshot?.removeFromSuperview()
                    if self?.keyboardSnapshot === snapshot { self?.keyboardSnapshot = nil }
                }
            })
        } else {
            terminal.translatesAutoresizingMaskIntoConstraints = false
            addSubview(terminal)
            NSLayoutConstraint.activate([
                terminal.topAnchor.constraint(equalTo: topAnchor),
                terminal.leadingAnchor.constraint(equalTo: leadingAnchor),
                terminal.trailingAnchor.constraint(equalTo: trailingAnchor)
            ])
            if #available(iOS 15.0, *) {
                keyboardLayoutGuide.followsUndockedKeyboard = UIDevice.current.userInterfaceIdiom == .pad
                let bottom = terminal.bottomAnchor.constraint(equalTo: keyboardLayoutGuide.topAnchor)
                bottom.isActive = true
                keyboardBottomConstraint = bottom
            } else {
                let bottom = terminal.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor)
                bottom.isActive = true
                notificationBottomConstraint = bottom
                for name in [UIResponder.keyboardWillChangeFrameNotification, UIResponder.keyboardWillHideNotification] {
                    keyboardObservers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                        guard let self = self else { return }
                        self.keyboardFrame = note.name == UIResponder.keyboardWillHideNotification ? .zero :
                            (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero)
                        self.updateKeyboardInset()
                    })
                }
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        keyboardObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if #available(iOS 15.0, *), let bottom = keyboardBottomConstraint {
            var correction: CGFloat = 0
            if UIDevice.current.userInterfaceIdiom == .phone, let terminal, terminal.isFirstResponder,
               let accessory = terminal.inputAccessoryView as? PhoneKeyboardToolbar, accessory.window != nil {
                // Keep the terminal above the accessory.
                let visibleBottom = convert(accessory.bounds, from: accessory).minY
                correction = visibleBottom - keyboardLayoutGuide.layoutFrame.minY
            }
            if abs(bottom.constant - correction) > 0.5 {
                bottom.constant = correction
                setNeedsLayout()
            }
        }
        updateKeyboardInset()
    }

    private func updateKeyboardInset() {
        guard let bottom = notificationBottomConstraint, let window = window else { return }
        let windowFrame = window.convert(keyboardFrame, from: nil as UIWindow?)
        let intersection = bounds.intersection(convert(windowFrame, from: window))
        var visibleBottom = intersection.minY
        if #available(iOS 26, *), let accessory = keyboardViewport?.terminal?.inputAccessoryView,
           let previousWidth = keyboardNotificationWidth, keyboardViewport?.bounds.width != previousWidth,
           keyboardFrame.height <= accessory.bounds.height {
            // A concurrent keyboard show and rotation can report only the accessory; the guide tracks the software keyboard.
            let guideIntersection = bounds.intersection(keyboardLayoutGuide.layoutFrame)
            if !guideIntersection.isNull, !guideIntersection.isEmpty {
                visibleBottom = min(visibleBottom, guideIntersection.minY)
            }
        }
        if !intersection.isNull, !intersection.isEmpty, let terminal, terminal.isFirstResponder,
           let accessory = terminal.inputAccessoryView as? PhoneKeyboardToolbar, accessory.window === window,
           !accessory.isHidden, accessory.bounds.height > 0 {
            // On iOS 26 iPhone, the app-window accessory is excluded from the notification's keyboard frame.
            visibleBottom -= accessory.bounds.height
        }
        let inset = intersection.isNull || intersection.isEmpty ? 0 : max(0, bounds.maxY - visibleBottom - safeAreaInsets.bottom)
        let panelInset = inset > 0 ? (terminal?.inputAccessoryView as? PhoneKeyboardToolbar)?.pinnedPanelHeight ?? 0 : 0
        if bottom.constant != -(inset + panelInset) {
            bottom.constant = -(inset + panelInset)
            setNeedsLayout()
        }
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

class WebviewCoordinator: NSObject, UIGestureRecognizerDelegate, WKNavigationDelegate {
    let webView: WKWebView
    init(webView: WKWebView) {self.webView = webView}
    
    @objc func handleGobackToTerminal(_ gesture: UIScreenEdgePanGestureRecognizer) {
        guard gesture.state == .recognized else {return}
        if !webView.canGoBack {
            NotificationCenter.default.post(name: .init("hideWebView"), object: nil)
        }
    }
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return !webView.canGoBack
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
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
        webView.navigationDelegate = context.coordinator
        
        let edgeSwipe = UIScreenEdgePanGestureRecognizer(target: context.coordinator,
                                                         action: #selector(context.coordinator.handleGobackToTerminal(_:)))
        edgeSwipe.edges = .left
        edgeSwipe.delegate = context.coordinator
        webView.addGestureRecognizer(edgeSwipe)
        
        return webView
    }
    
    func makeCoordinator() -> WebviewCoordinator {
        WebviewCoordinator(webView: webView)
    }
    func updateUIView(_ uiView: WebViewType, context: Context) {
        NSLog("updateUIView: url= \(uiView.url)")
        if (uiView.url != nil) { return } // Already loaded the page
        uiView.isOpaque = false
    }
}

public var toolbarShouldBeShown = true
public var showToolbar = true
public var useSystemToolbar = UIDevice.current.model.hasPrefix("iPad")
public var isiPad = UIDevice.current.model.hasPrefix("iPad")
public var showKeyboardAtStartup = true
// .fullScreen is too much for floating KB + toolbar, ignoreSafeArea seems to work,
// automatic detection causes blank screen when switching back-forth
// Make this a user-defined setup, with "ignoreSafeArea" the default.
public var viewBehavior: ViewBehavior = .ignoreSafeArea
final class TerminalHostingController: UIHostingController<ContentView> {
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        guard let scene = view.window?.windowScene?.delegate as? SceneDelegate else { return }
        scene.editorToolbar.prepareForRotation(to: size, with: coordinator)
    }

    override var keyCommands: [UIKeyCommand]? {
        let toolbar = UIKeyCommand(input: "t", modifierFlags: [.alternate, .command], action: #selector(toggleToolbar), discoverabilityTitle: showToolbar ? "Hide Key Toolbar" : "Show Key Toolbar")
        if #available(iOS 15, *) {
            toolbar.wantsPriorityOverSystemBehavior = true
        }
        return [toolbar] + (super.keyCommands ?? [])
    }

    @objc private func toggleToolbar(_ sender: UIKeyCommand) {
        (view.window?.windowScene?.delegate as? SceneDelegate)?.toggleKeyToolbar()
    }

}

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
    @State private var localShowWebView: Bool = false

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
                guard showWebView && localShowWebView else { return }
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
                        dynamicIsland = 15
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
                        } else if (terminalview.view.inputAccessoryView?.bounds.height ?? 0) > 0  {
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
            .onReceive(NotificationCenter.default.publisher(for: .init("showWebView"), object: webview.webView)) { _ in
                keyboardHeight = 0
                frameHeight = isiPad ? 0 : geometry.size.height
                frameWidth = geometry.size.width
                localShowWebView = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .init("hideWebView"))) { _ in
                localShowWebView = false
                showWebView = false
                showKeyboardAtStartup = true
                _ = terminalview.view.becomeFirstResponder()
            }
                                                                
            // iPhones
            .if(!isiPad && showWebView && localShowWebView) {
                $0.frame(height: min(frameHeight, geometry.size.height)).position(x: frameWidth / 2, y: frameHeight / 2 - dynamicIsland )
            }
            // if nothing is defined, the size is geometry.size.height
            .if((viewBehavior == .ignoreSafeArea || viewBehavior == .original) && isiPad && showWebView && localShowWebView) {
                $0.frame(maxHeight: geometry.size.height - frameHeight)
            }
            .if(((viewBehavior == .ignoreSafeArea || viewBehavior == .fullScreen)) && isiPad && showWebView && localShowWebView) {
                $0.ignoresSafeArea(.container, edges: .bottom)
            }
        }
        // Read local state first so SwiftUI observes visibility while the global flag is false.
        .if(!(localShowWebView && showWebView)) {
            $0.ignoresSafeArea(.keyboard, edges: .bottom)
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
