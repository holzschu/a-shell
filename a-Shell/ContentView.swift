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

struct ServiceIndicator: Identifiable {
    let id: String
    let color: SwiftUI.Color
    let title: String
    let details: [String]
    var stop: (() -> Void)? = nil
}

final class ServiceIndicators: ObservableObject {
    static let shared = ServiceIndicators()
    @Published private(set) var items: [ServiceIndicator] = []

    func set(_ item: ServiceIndicator) {
        DispatchQueue.main.async {
            self.items.removeAll { $0.id == item.id }
            self.items.append(item)
            self.items.sort { $0.id < $1.id }
        }
    }

    func remove(id: String) {
        DispatchQueue.main.async { self.items.removeAll { $0.id == id } }
    }
}

struct ServiceIndicatorSymbols: View {
    let items: [ServiceIndicator]
    let foreground: SwiftUI.Color
    var controlHeight: CGFloat = 44

    var body: some View {
        HStack(spacing: 8) {
            ForEach(items) { item in
                Circle()
                    .fill(item.color)
                    .overlay(Circle().stroke(foreground.opacity(0.7), lineWidth: 0.5))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 12)
        .frame(minWidth: 44, minHeight: controlHeight)
    }
}

struct ServiceIndicatorDetails: View {
    let items: [ServiceIndicator]
    let background: SwiftUI.Color
    let foreground: SwiftUI.Color
    let accent: SwiftUI.Color
    let dismiss: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        Label {
                            Text(item.title).font(.headline)
                        } icon: {
                            Circle().fill(item.color).frame(width: 8, height: 8)
                        }
                        .accessibilityIdentifier("service-title-" + item.id)
                        ForEach(Array(item.details.enumerated()), id: \.offset) { _, line in
                            Text(line).font(.subheadline).textSelection(.enabled)
                        }
                        if let stop = item.stop {
                            Button("Stop " + item.title, role: .destructive) {
                                stop()
                                dismiss()
                            }
                            .foregroundColor(accent)
                            .accessibilityIdentifier("service-stop-" + item.id)
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundColor(foreground)
        .background(background)
        .tint(accent)
    }
}

struct ServiceIndicatorPlacement: UIViewRepresentable {
    let terminal: TerminalView
    let items: [ServiceIndicator]
    let background: UIColor
    let foreground: UIColor
    let accent: UIColor

    final class PlacementView: UIView {
        var updatePlacement: (() -> Void)?
        override func layoutSubviews() {
            super.layoutSubviews()
            updatePlacement?()
        }
        override func didMoveToWindow() {
            super.didMoveToWindow()
            updatePlacement?()
        }
        override func safeAreaInsetsDidChange() {
            super.safeAreaInsetsDidChange()
            updatePlacement?()
        }
    }

    final class Coordinator: NSObject, UIAdaptivePresentationControllerDelegate {
        var content: ServiceIndicatorPlacement?
        var detailsHost: UIHostingController<ServiceIndicatorDetails>?
        var statusHost: UIHostingController<AnyView>?
        var toolbarItem: UIBarButtonItem?
        weak var toolbar: UIToolbar?
        var statusHeight: CGFloat?
        var renderedContent: ServiceIndicatorPlacement?
        var updating = false

        func details(for content: ServiceIndicatorPlacement) -> ServiceIndicatorDetails {
            ServiceIndicatorDetails(items: content.items, background: Color(uiColor: content.background), foreground: Color(uiColor: content.foreground), accent: Color(uiColor: content.accent), dismiss: { [weak self] in self?.dismissDetails() })
        }

        func dismissDetails() {
            guard let host = detailsHost else { return }
            detailsHost = nil
            let terminal = content?.terminal
            host.dismiss(animated: true) { terminal?.becomeFirstResponder() }
        }

        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            detailsHost = nil
            content?.terminal.becomeFirstResponder()
        }

        func showDetails() {
            guard detailsHost == nil, let content = content,
                  let parent = content.terminal.window?.rootViewController else { return }
            let host = UIHostingController(rootView: details(for: content))
            host.view.backgroundColor = content.background
            host.modalPresentationStyle = .pageSheet
            host.presentationController?.delegate = self
            detailsHost = host
            content.terminal.resignFirstResponder()
            parent.present(host, animated: true)
        }

        func detach() {
            if let item = toolbarItem { toolbar?.items?.removeAll { $0 === item } }
            toolbar = nil
            toolbarItem = nil
            dismissDetails()
            statusHost?.willMove(toParent: nil)
            statusHost?.view.removeFromSuperview()
            statusHost?.removeFromParent()
        }

        func update() {
            guard !updating else { return }
            updating = true
            defer { updating = false }
            guard let content = content, !content.items.isEmpty,
                  let window = content.terminal.window, let parent = window.rootViewController else {
                detach()
                return
            }
            let changed = renderedContent.map { previous in
                previous.background != content.background || previous.foreground != content.foreground || previous.accent != content.accent || previous.items.count != content.items.count || zip(previous.items, content.items).contains {
                    $0.id != $1.id || $0.color != $1.color || $0.title != $1.title || $0.details != $1.details
                }
            } ?? true
            renderedContent = content
            if changed, let detailsHost = detailsHost { detailsHost.rootView = details(for: content) }
            let insets = window.safeAreaInsets
            let width = max(44, CGFloat(content.items.count * 16 + 16))
            let height = insets.top > 0 ? min(44, insets.top) : 44
            let bounds = parent.view.bounds
            let terminalFrame = content.terminal.convert(content.terminal.bounds, to: parent.view)
            var frame: CGRect?
            if insets.top > 0 {
                frame = CGRect(x: bounds.width * 0.28 - width / 2, y: (insets.top - height) / 2, width: width, height: height)
            } else if insets.right >= width {
                frame = CGRect(x: bounds.maxX - (insets.right + width) / 2, y: terminalFrame.midY - height / 2, width: width, height: height)
            } else if insets.left >= width {
                frame = CGRect(x: (insets.left - width) / 2, y: terminalFrame.midY - height / 2, width: width, height: height)
            }
            if let frame = frame, !frame.intersects(terminalFrame) {
                let status = AnyView(ServiceIndicatorSymbols(items: content.items, foreground: Color(uiColor: content.foreground), controlHeight: height)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Running services")
                    .accessibilityValue(content.items.map(\.title).joined(separator: ", "))
                    .accessibilityIdentifier("service-indicator-status"))
                if statusHost == nil {
                    statusHost = UIHostingController(rootView: status)
                    if #available(iOS 16.4, *) { statusHost?.safeAreaRegions = [] }
                    statusHost?.view.backgroundColor = .clear
                    statusHost?.view.isUserInteractionEnabled = false
                }
                if let statusHost = statusHost {
                    if changed || statusHeight != height { statusHost.rootView = status }
                    statusHeight = height
                    let attaching = statusHost.parent == nil
                    if attaching { parent.addChild(statusHost) }
                    if statusHost.view.superview !== parent.view { parent.view.addSubview(statusHost.view) }
                    statusHost.view.frame = frame
                    if attaching { statusHost.didMove(toParent: parent) }
                }
            } else {
                // No free chrome: the stock keyboard toolbar still shows the status.
                statusHost?.willMove(toParent: nil)
                statusHost?.view.removeFromSuperview()
                statusHost?.removeFromParent()
            }
            if let accessory = content.terminal.inputAccessoryView as? UIToolbar, accessory.bounds.height >= 44 {
                if toolbar !== accessory || !(accessory.items ?? []).contains(where: { $0 === toolbarItem }) {
                    if let item = toolbarItem { toolbar?.items?.removeAll { $0 === item } }
                    let item = UIBarButtonItem(title: nil, image: UIImage(systemName: "info.circle"), primaryAction: UIAction { [weak self] _ in self?.showDetails() }, menu: nil)
                    item.accessibilityIdentifier = "service-indicators"
                    item.accessibilityLabel = "Running services"
                    item.accessibilityValue = content.items.map(\.title).joined(separator: ", ")
                    item.tintColor = content.accent
                    toolbar = accessory
                    toolbarItem = item
                    // Keep the service control visible when UIKit overflows the toolbar.
                    accessory.items = [item] + (accessory.items ?? [])
                }
                if changed {
                    toolbarItem?.accessibilityValue = content.items.map(\.title).joined(separator: ", ")
                    toolbarItem?.tintColor = content.accent
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> PlacementView {
        let view = PlacementView()
        view.isUserInteractionEnabled = false
        view.updatePlacement = { [weak coordinator = context.coordinator] in coordinator?.update() }
        return view
    }
    func updateUIView(_ view: PlacementView, context: Context) {
        context.coordinator.content = self
        context.coordinator.update()
    }
    static func dismantleUIView(_ view: PlacementView, coordinator: Coordinator) {
        view.updatePlacement = nil
        coordinator.detach()
    }
}

@_cdecl("ashell_sshd_status")
public func sshdStatus(_ sessions: Int32, _ port: Int32, _ fingerprint: UnsafePointer<CChar>?, _ stop: (@convention(c) () -> Void)?) {
    guard sessions >= 0 else {
        ServiceIndicators.shared.remove(id: "sshd")
        return
    }
    let hostKey = fingerprint.map { String(cString: $0) } ?? "unavailable"
    ServiceIndicators.shared.set(ServiceIndicator(id: "sshd", color: sessions > 0 ? .green : .yellow, title: "SSH", details: [
        "State: listening",
        "Port: \(port)",
        "Active sessions: \(sessions)",
        "Host key: \(hostKey)"
    ], stop: stop.map { action in
        { DispatchQueue.global(qos: .userInitiated).async { action() } }
    }))
}

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

        return TerminalContainerView(terminal: view)
    }
    
    func updateUIView(_ uiView: UIView, context: Context)
    {
        
    }
}


final class TerminalContainerView: UIView {
    private var legacyBottomConstraint: NSLayoutConstraint?
    private var keyboardFrame = CGRect.zero
    private var keyboardObservers: [NSObjectProtocol] = []

    init(terminal: TerminalView) {
        super.init(frame: .zero)
        terminal.translatesAutoresizingMaskIntoConstraints = false
        addSubview(terminal)
        NSLayoutConstraint.activate([
            terminal.topAnchor.constraint(equalTo: topAnchor),
            terminal.leadingAnchor.constraint(equalTo: leadingAnchor),
            terminal.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        if #available(iOS 15.0, *) {
            keyboardLayoutGuide.followsUndockedKeyboard = UIDevice.current.userInterfaceIdiom == .pad
            terminal.bottomAnchor.constraint(equalTo: keyboardLayoutGuide.topAnchor).isActive = true
        } else {
            let bottom = terminal.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor)
            bottom.isActive = true
            legacyBottomConstraint = bottom
            for name in [UIResponder.keyboardWillChangeFrameNotification, UIResponder.keyboardWillHideNotification] {
                keyboardObservers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                    guard let self = self else { return }
                    self.keyboardFrame = note.name == UIResponder.keyboardWillHideNotification ? .zero :
                        (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero)
                    self.updateLegacyKeyboardInset()
                })
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
        updateLegacyKeyboardInset()
    }

    private func updateLegacyKeyboardInset() {
        guard let bottom = legacyBottomConstraint, let window = window else { return }
        let windowFrame = window.convert(keyboardFrame, from: nil as UIWindow?)
        let intersection = bounds.intersection(convert(windowFrame, from: window))
        let inset = intersection.isNull || intersection.isEmpty ? 0 : max(0, bounds.maxY - intersection.minY - safeAreaInsets.bottom)
        if bottom.constant != -inset {
            bottom.constant = -inset
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
public var useSystemToolbar = UIDevice.current.model.hasPrefix("iPad")
public var isiPad = UIDevice.current.model.hasPrefix("iPad")
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
    @ObservedObject private var services = ServiceIndicators.shared
    @State private var serviceBackground = UIColor.systemBackground
    @State private var serviceForeground = UIColor.label
    @State private var serviceAccent = UIColor.link
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
        .background(ServiceIndicatorPlacement(terminal: terminalview.view, items: services.items, background: serviceBackground, foreground: serviceForeground, accent: serviceAccent))
        .onAppear { updateServiceTheme() }
        .onReceive(NotificationCenter.default.publisher(for: .init("terminalThemeChanged"), object: terminalview.view)) { _ in
            updateServiceTheme()
        }
    }

    private func updateServiceTheme() {
        serviceBackground = terminalview.view.nativeBackgroundColor
        serviceForeground = terminalview.view.nativeForegroundColor
        serviceAccent = terminalview.view.caretColor
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView()
        }
    }
}
