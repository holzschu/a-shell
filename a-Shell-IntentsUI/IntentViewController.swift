//
//  IntentViewController.swift
//  a-Shell-IntentsUI
//
//  Created by Nicolas Holzschuch on 15/05/2020.
//  Copyright © 2020 AsheKube. All rights reserved.
//

import IntentsUI

// You will want to replace this or add other intents as appropriate.
// The intents whose interactions you wish to handle must be declared in the extension's Info.plist.


class IntentViewController: UIViewController, INUIHostedViewControlling {
        
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        preferredContentSize = view.intrinsicContentSize
    }
        
    // MARK: - INUIHostedViewControlling

    // Prepare your view controller for the interaction to handle.
    func configureView(for parameters: Set<INParameter>, of interaction: INInteraction, interactiveBehavior: INUIInteractiveBehavior, context: INUIHostedViewContext, completion: @escaping (Bool, Set<INParameter>, CGSize) -> Void) {
        // Do configuration here, including preparing views and calculating a desired size for presentation.
        // TODO (wishlist): disable button at bottom, make alert smaller in width
        
        let responseView = UITextView(frame: CGRect(x: 0, y: 0, width: self.extensionContext!.hostedViewMaximumAllowedSize.width, height: 100))
        responseView.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        view.autoresizesSubviews = true
        if interaction.intentHandlingStatus == .success {
            if let response = interaction.intentResponse as? ExecuteCommandIntentResponse {
                responseView.text = response.property
            } else if let response = interaction.intentResponse as? GetFileIntentResponse{
                responseView.text = response.file?.filename
            } else if let response = interaction.intentResponse as? PutFileIntentResponse{
                let intent = interaction.intent as! PutFileIntent
                responseView.font = UIFont.systemFont(ofSize: 13)
                responseView.text = "File " + intent.file!.filename + " successfully created."
            }
            responseView.sizeToFit()
            view.addSubview(responseView)
            view.sizeToFit()
            let height = responseView.frame.height
            let width = responseView.frame.width
            completion(true, [], CGSize(width: width, height: height))
            return
        }
        // .failure and .continueInApp do not go through "IntentsUI".
        completion(false, parameters, self.desiredSize)
    }
    
    var desiredSize: CGSize {
        return self.extensionContext!.hostedViewMaximumAllowedSize
    }
    var emptySize: CGSize {
        return .zero
    }

}
