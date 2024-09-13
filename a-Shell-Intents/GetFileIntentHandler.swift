//
//  GetFileHandler.swift
//  a-Shell
//
//  Created by Maarten den Braber on 23/05/2024.
//  Copyright © 2024 AsheKube. All rights reserved.
//

import Intents
import ios_system
// import a_Shell

// As an example, this class is set up to handle Message intents.
// You will want to replace this or add other intents as appropriate.
// The intents you wish to handle must be declared in the extension's Info.plist.

// You can test your example integration by saying things to Siri like:
// "Send a message using <myApp>"
// "<myApp> John saying hello"
// "Search for messages in <myApp>"

class GetFileIntentHandler: INExtension, GetFileIntentHandling
{
    
    let application: UIApplication
    
        init(application: UIApplication) {
        self.application = application
    }
    
    // GetFileIntent
    func resolveErrorIfNotFound(for intent: GetFileIntent, with completion: @escaping (INBooleanResolutionResult) -> Void) {
        if let errorIfNotFound = intent.errorIfNotFound {
            if (errorIfNotFound == true) {
                completion(INBooleanResolutionResult.success(with: true))
            } else {
                completion(INBooleanResolutionResult.success(with: false))
            }
        } else {
            completion(INBooleanResolutionResult.needsValue())
        }
    }

    // GetFileIntent
    func resolveFileName(for intent: GetFileIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
        var result: INStringResolutionResult
        if let fileName = intent.fileName {
            if (fileName.count > 0) {
                result = INStringResolutionResult.success(with: fileName)
            } else {
                result = INStringResolutionResult.needsValue()
            }
        } else {
            result = INStringResolutionResult.needsValue()
        }
        completion(result)
    }

    
    // GetFileIntent
    func handle(intent: GetFileIntent, completion: @escaping (GetFileIntentResponse) -> Void) {
        guard let groupUrl = FileManager().containerURL(forSecurityApplicationGroupIdentifier:"group.AsheKube.a-Shell") else {
            completion(GetFileIntentResponse(code: .failureRequiringAppLaunch, userActivity: nil))
            return
        }
        if let fileNames = intent.fileName {
            // Sometimes, we get multiple lines (or a single line that ends with "\n")
            let errorIfNotFound = intent.errorIfNotFound ?? true;
            if let fileName = fileNames.components(separatedBy: "\n").first {
                FileManager().changeCurrentDirectoryPath(groupUrl.path)
                if FileManager().fileExists(atPath: fileName) {
                    let fileURL = URL(fileURLWithPath: fileName)
                    let intentResponse = GetFileIntentResponse(code: .success, userActivity: nil)
                    do {
                        if #available(iOS 18.0, *) {
                            // Address a bug in iOS 18 that deletes the file when showing it
                            // but only if it was created with putFile.
                            if let urlData = try? Data(contentsOf: fileURL) {
                                intentResponse.file = INFile(data: urlData, filename: fileName, typeIdentifier: nil)
                            } else if (errorIfNotFound == true) {
                                let intentResponse = GetFileIntentResponse(code: .failure, userActivity: nil)
                                intentResponse.message = "Could not read content of file \(fileName)."
                                completion(intentResponse)
                                return
                            }
                        } else {
                            intentResponse.file = INFile(fileURL: fileURL, filename: fileName, typeIdentifier: nil)
                        }
                        completion(intentResponse)
                    }
                } else if (errorIfNotFound == true) {
                    let intentResponse = GetFileIntentResponse(code: .failure, userActivity: nil)
                    intentResponse.message = "File \(fileName) not found error"
                    completion(intentResponse)
                } else {
                    let intentResponse = GetFileIntentResponse(code: .success, userActivity: nil)
                    completion(intentResponse)
                }
                return
            }
        }
        let intentResponse = GetFileIntentResponse(code: .failure, userActivity: nil)
        intentResponse.message = "No filename provided."
        completion(intentResponse)
    }

    
}
