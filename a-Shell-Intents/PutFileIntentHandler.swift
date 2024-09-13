//
//  PutFileHandler.swift
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

class PutFileIntentHandler: INExtension, PutFileIntentHandling
{
    
    let application: UIApplication
    
    init(application: UIApplication) {
        self.application = application
    }
    
    // PutFileIntent
    func resolveFile(for intent: PutFileIntent, with completion: @escaping ([INFileResolutionResult]) -> Void) {
        var result: [INFileResolutionResult] = []
        if let fileList = intent.file {
            for file in fileList {
                result.append(INFileResolutionResult.success(with: file))
            }
        } else {
            result.append(INFileResolutionResult.needsValue())
        }
        completion(result)
    }
    
    // PutFileIntent
    func resolveOverwrite(for intent: PutFileIntent, with completion: @escaping (INBooleanResolutionResult) -> Void) {
        if let overwrite = intent.overwrite {
            completion(INBooleanResolutionResult.success(with: overwrite as! Bool))
        } else {
            completion(INBooleanResolutionResult.success(with: true)) // overwrite by default
        }
    }
    
    // PutFileIntent
    func handle(intent: PutFileIntent, completion: @escaping (PutFileIntentResponse) -> Void) {
        guard let groupUrl = FileManager().containerURL(forSecurityApplicationGroupIdentifier:"group.AsheKube.a-Shell") else {
            completion(PutFileIntentResponse(code: .failureRequiringAppLaunch, userActivity: nil))
            return
        }
        if let fileList = intent.file {
            FileManager().changeCurrentDirectoryPath(groupUrl.path)
            // default value is success, any error will cause a failure
            var intentResponse = PutFileIntentResponse(code: .success, userActivity: nil)
            for file in fileList {
                if (FileManager().fileExists(atPath: file.filename) && (intent.overwrite != 1)) {
                    intentResponse = PutFileIntentResponse(code: .failure, userActivity: nil)
                    intentResponse.error = "File \(file.filename) already exists."
                    completion(intentResponse)
                    return
                }
                var localURL = URL(fileURLWithPath: groupUrl.path)
                localURL = localURL.appendingPathComponent(file.filename)
                if let distantURL = file.fileURL {
                    do {
                        // request permission with secure URL:
                        let isSecuredURL = distantURL.startAccessingSecurityScopedResource()
                        let isReadable = FileManager().isReadableFile(atPath: distantURL.path)
                        guard isSecuredURL && isReadable else {
                            intentResponse = PutFileIntentResponse(code: .failure, userActivity: nil)
                            intentResponse.error = "Could not get permission to access file \(file.filename)."
                            completion(intentResponse)
                            return
                        }
                        if (FileManager().fileExists(atPath: localURL.path) && (intent.overwrite == 1)) {
                            try FileManager().setAttributes([.immutable : false], ofItemAtPath: localURL.path)
                            try FileManager().removeItem(at: localURL)
                        }
                        try FileManager().copyItem(at: distantURL, to: localURL)
                        if (isSecuredURL) {
                            distantURL.stopAccessingSecurityScopedResource()
                        }
                    }
                    catch {
                        intentResponse = PutFileIntentResponse(code: .failure, userActivity: nil)
                        intentResponse.error = "Could not create file \(file.filename): \(error.localizedDescription)"
                        completion(intentResponse)
                    }
                } else {
                    intentResponse = PutFileIntentResponse(code: .failure, userActivity: nil)
                    intentResponse.error = "Could not access file \(file.filename)."
                    completion(intentResponse)
                }
            }
            completion(intentResponse)
        } else {
            completion(PutFileIntentResponse(code: .failure, userActivity: nil))
        }
    }
    
}
