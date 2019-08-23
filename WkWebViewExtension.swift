//
//  WKWebViewExtension.swift
//
//  Created by Robots & Pencils on 2016-03-10.
//  https://robotsandpencils.com/blog/swift-swizzling-adding-a-custom-toolbar-to-wkwebview/
//
import Foundation
import WebKit

private var ToolbarHandle: UInt8 = 0
// Ensure that keyboard appears automatically:
typealias OldClosureType =  @convention(c) (Any, Selector, UnsafeRawPointer, Bool, Bool, Any?) -> Void
typealias NewClosureType =  @convention(c) (Any, Selector, UnsafeRawPointer, Bool, Bool, Bool, Any?) -> Void

extension WKWebView {
    
    func addInputAccessoryView(toolbar: UIView?) {
        guard let toolbar = toolbar else { return }
        objc_setAssociatedObject(self, &ToolbarHandle, toolbar, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        var candidateView: UIView? = nil
        for view in self.scrollView.subviews {
            if String(describing: type(of: view)).hasPrefix("WKContent") {
                candidateView = view
            }
        }
        guard let targetView = candidateView else { return }
        let newClass: AnyClass? = classWithCustomAccessoryView(targetView: targetView)
        object_setClass(targetView, newClass!)
    }
    
    private func classWithCustomAccessoryView(targetView: UIView) -> AnyClass? {
        guard let targetSuperClass = targetView.superclass else { return nil }
        let customInputAccessoryViewClassName = "\(targetSuperClass)_CustomInputAccessoryView"
        
        var newClass: AnyClass? = NSClassFromString(customInputAccessoryViewClassName)
        if newClass == nil {
            newClass = objc_allocateClassPair(object_getClass(targetView), customInputAccessoryViewClassName, 0)
        } else {
            return newClass
        }
        
        let newMethod = class_getInstanceMethod(WKWebView.self, #selector(WKWebView.getCustomInputAccessoryView))
        class_addMethod(newClass.self, #selector(getter: UIResponder.inputAccessoryView), method_getImplementation(newMethod!), method_getTypeEncoding(newMethod!))
        
        objc_registerClassPair(newClass!);
        
        return newClass
    }
    
    @objc func getCustomInputAccessoryView() -> UIView? {
        var superWebView: UIView? = self
        while (superWebView != nil) && !(superWebView is WKWebView) {
            superWebView = superWebView?.superview
        }
        let customInputAccessory = objc_getAssociatedObject(superWebView, &ToolbarHandle)
        superWebView?.inputAssistantItem.leadingBarButtonGroups = []
        superWebView?.inputAssistantItem.trailingBarButtonGroups = []
        return customInputAccessory as? UIView
    }
    

    // Second extension, keyboardDisplayRequiresUserAction
    // solution from https://stackoverflow.com/questions/32449870/programmatically-focus-on-a-form-in-a-webview-wkwebview/48623286#48623286
    // First solution from @alexstaravoitau
    var keyboardDisplayRequiresUserAction: Bool? {
        get {
            return self.keyboardDisplayRequiresUserAction
        }
        set {
            self.setKeyboardRequiresUserInteraction(newValue ?? true)
        }
    }
    
    private var webContentView: UIView? {
        for subview in (self.scrollView.subviews) {
            if subview.classForCoder.description() == "WKContentView" {
                return subview
            }
            // adding the toolbar has changed the name of the view:
            if subview.classForCoder.description() == "WKApplicationStateTrackingView_CustomInputAccessoryView" {
                return subview
            }
        }
        return nil
    }
    
    func setKeyboardRequiresUserInteraction( _ value: Bool) {
        guard let WKContentView: AnyClass = NSClassFromString("WKContentView") else {
            print("keyboardDisplayRequiresUserAction extension: Cannot find the WKContentView class")
            return
        }
        // For iOS 13.*
        let selector: Selector = sel_getUid("_elementDidFocus:userIsInteracting:blurPreviousNode:activityStateChanges:userObject:")
        
        if let method = class_getInstanceMethod(WKContentView, selector) {
            let originalImp: IMP = method_getImplementation(method)
            let original: NewClosureType = unsafeBitCast(originalImp, to: NewClosureType.self)
            let block : @convention(block) (Any, UnsafeRawPointer, Bool, Bool, Bool, Any?) -> Void = { (me, arg0, arg1, arg2, arg3, arg4) in
                original(me, selector, arg0, !value, arg2, arg3, arg4)
            }
            let imp: IMP = imp_implementationWithBlock(block)
            method_setImplementation(method, imp)
        }
    }
    
}
