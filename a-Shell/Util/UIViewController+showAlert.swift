//
//  UIViewController+Alerts.swift
//  OpenTerm
//
//  Created by Louis D'hauwe on 01/04/2018.
//  Copyright © 2018 Silver Fox. All rights reserved.
//

import Foundation
import UIKit

extension SceneDelegate {
    
    func showAlert(_ title: String, message: String? = nil, callbackBtnTitle: String? = nil, retryCallback: (() -> Void)? = nil, dismissCallback: (() -> Void)? = nil) {
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        if let retry = retryCallback, let callbackTitle = callbackBtnTitle {
            
            alert.addAction(UIAlertAction(title: callbackTitle, style: .default, handler: { (_) -> Void in
                retry()
            }))
            
            if let dismiss = dismissCallback {
                
                alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: { (_) -> Void in
                    dismiss()
                }))
                
            }
            
        } else {
            
            if let dismiss = dismissCallback {
                
                alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: { (_) -> Void in
                    dismiss()
                }))
                
            } else {
                
                alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
                
            }
            
        }
        
        let rootVC = self.window?.rootViewController
        DispatchQueue.main.async {
            rootVC?.present(alert, animated: false) { () -> Void in
            }
        }
        
    }
    
    func showErrorAlert(_ error: Error?) {
        
        showErrorAlert(error, res: nil, retryCallback: nil, dismissCallback: nil)
    }
    
    func showErrorAlert(_ error: Error? = nil, res: HTTPURLResponse? = nil, retryCallback: (() -> Void)? = nil, dismissCallback: (() -> Void)? = nil) {
        
        let errorTitle = "Error"
        var errorMessage = ""
        
        if errorMessage == "" {
            // TODO: add error code?
            if let error = error {
                errorMessage = error.localizedDescription
            }
        }
        
        if errorMessage == "" {
            
            errorMessage = "An error occurred"
            
        }
        
        if retryCallback == nil {
            
            self.showAlert(errorTitle, message: errorMessage, callbackBtnTitle: "Retry", dismissCallback: dismissCallback)
            
        } else {
            
            self.showAlert(errorTitle, message: errorMessage, callbackBtnTitle: "Retry", retryCallback: retryCallback, dismissCallback: dismissCallback)
            
        }
        
    }
    
}
