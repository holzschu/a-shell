//
//  AppDelegate+TeX.swift
//  
//
//  Created by Nicolas Holzschuch on 04/09/2019.
//

import Foundation
import UserNotifications
import ios_system

extension AppDelegate {
    
    func activateFakeTeXCommands() {
        if (!TeXEnabled) {
            replaceCommand("amstex", "tex", true)
            replaceCommand("bibtex", "tex", true)
            replaceCommand("cslatex", "tex", true)
            replaceCommand("csplain", "tex", true)
            replaceCommand("eplain", "tex", true)
            replaceCommand("etex", "tex", true)
            replaceCommand("jadetex", "tex", true)
            replaceCommand("latex", "tex", true)
            replaceCommand("mex", "tex", true)
            replaceCommand("mllatex", "tex", true)
            replaceCommand("mltex", "tex", true)
            replaceCommand("pdfcslatex", "tex", true)
            replaceCommand("pdfcsplain", "tex", true)
            replaceCommand("pdfetex", "tex", true)
            replaceCommand("pdfjadetex", "tex", true)
            replaceCommand("pdflatex", "tex", true)
            replaceCommand("pdfmex", "tex", true)
            replaceCommand("pdftex", "tex", true)
            replaceCommand("pdfxmltex", "tex", true)
            replaceCommand("tex", "tex", true)
            replaceCommand("texsis", "tex", true)
            replaceCommand("utf8mex", "tex", true)
            replaceCommand("xmltex", "tex", true)
        }
        if (!TeXEnabled || !OpentypeEnabled) {
            replaceCommand("dvilualatex", "luatex", true)
            replaceCommand("dviluatex", "luatex", true)
            replaceCommand("lualatex", "luatex", true)
            replaceCommand("luatex", "luatex", true)
            replaceCommand("texlua", "luatex", true)
            replaceCommand("texluac", "luatex", true)
        }
    }
    

    func TeXnotification(title: String, message: String) {
        // Only activates if we are in the background. Probably OK since we don't want to intrude.
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.getNotificationSettings { (settings) in
            if (settings.authorizationStatus == .authorized) {
                let TeXsuccess = UNMutableNotificationContent()
                if settings.alertSetting == .enabled {
                    TeXsuccess.title = NSString.localizedUserNotificationString(forKey: title, arguments: nil)
                    TeXsuccess.body = NSString.localizedUserNotificationString(forKey: message, arguments: nil)
                }
                let TeXNotification = UNNotificationRequest(identifier: "TeXSuccess",
                                                                      content: TeXsuccess,
                                                                      trigger: UNTimeIntervalNotificationTrigger(timeInterval: (1), repeats: false))
                notificationCenter.add(TeXNotification, withCompletionHandler: { (error) in
                    if let error = error {
                        var message = "Error in setting up the alert: "
                        message.append(error.localizedDescription)
                        NSLog(message)
                    }
                })
                NSLog("Added the notification: \(message)")
            } else {
                NSLog("Alerts not authorized")
            }
        }
    }
    
    func downloadTeX() {
        if (downloadingTeX) {
            return; // only run this function once
        }
        downloadingTeX = true;
        downloadingTeXError = ""
        percentTeXDownloadComplete = 0.0
        // download the extensions: texlive, texmf-dist and texmf-dist-fonts
        let texliveResource = NSBundleResourceRequest(tags: ["texlive"])
        let libraryURL = try! FileManager().url(for: .libraryDirectory,
                                                in: .userDomainMask,
                                                appropriateFor: nil,
                                                create: true)
        NSLog("Begin downloading texlive resources")
        texliveResource.beginAccessingResources(completionHandler: { (error) in
            if let error = error {
                var message = "Error in downloading texlive files: "
                message.append(error.localizedDescription)
                NSLog(message)
                downloadingTeX = false
                downloadingTeXError = message
                UserDefaults.standard.set(false, forKey: "TeXEnabled")
                self.TeXEnabled = false
                return
            } else {
                NSLog("texlive resource succesfully downloaded")
                // Copy the entire directory:
                if let archiveFileLocation = texliveResource.bundle.path(forResource: "texlive", ofType: nil) {
                    let archiveURL = URL(fileURLWithPath: archiveFileLocation)
                    NSLog("downloaded texlive location: \(archiveFileLocation)")
                    // make sure ~/Library/texlive exists:
                    let localURL = libraryURL.appendingPathComponent("texlive") // $HOME/Library/texlive
                    do {
                        if (FileManager().fileExists(atPath: localURL.path) && !localURL.isDirectory) {
                            try FileManager().removeItem(at: localURL)
                        }
                        if (!FileManager().fileExists(atPath: localURL.path)) {
                            try! FileManager().createDirectory(atPath: localURL.path, withIntermediateDirectories: true)
                        }
                        if let enumerator = FileManager().enumerator(atPath: archiveFileLocation) {
                            for file in enumerator {
                                let localFileURL = localURL.appendingPathComponent(file as! String)
                                var localFileExists = FileManager().fileExists(atPath: localFileURL.path)
                                if (localFileExists && !localFileURL.isDirectory) {
                                    try FileManager().removeItem(at: localFileURL)
                                    localFileExists = FileManager().fileExists(atPath: localFileURL.path)
                                }
                                let distantFileURL = archiveURL.appendingPathComponent(file as! String)
                                if (distantFileURL.isDirectory) {
                                    if (!localFileExists) {
                                        try FileManager().createDirectory(at: localFileURL, withIntermediateDirectories: true)
                                    }
                                } else {
                                    try FileManager().copyItem(at: distantFileURL, to: localFileURL)
                                }
                                
                            }
                        }
                        NSLog("done copying texlive at $HOME/Library")
                    }
                    catch {
                        NSLog("Error in copying texlive directory: \(error)")
                        downloadingTeX = false
                        UserDefaults.standard.set(false, forKey: "TeXEnabled")
                        downloadingTeXError = error.localizedDescription
                        self.TeXEnabled = false
                        return
                    }
                }
            }
        })
        let texmf_distResource = NSBundleResourceRequest(tags: ["texmf-dist"])
        NSLog("Begin downloading texmf-dist resources")
        texmf_distResource.beginAccessingResources(completionHandler: { (error) in
            if let error = error {
                var message = "Error in downloading texmf-dist files: "
                message.append(error.localizedDescription)
                NSLog(message) // Also show alert
                downloadingTeX = false
                UserDefaults.standard.set(false, forKey: "TeXEnabled")
                self.TeXEnabled = false
                return
            } else {
                NSLog("texmf-dist resource succesfully downloaded")
                // link the sub-directories in the right place:
                if let archiveFileLocation = texmf_distResource.bundle.path(forResource: "texlive_2019_texmf-dist", ofType: nil) {
                    // Is the host directory available? If not create it.
                    let archiveURL = URL(fileURLWithPath: archiveFileLocation)
                    let localURL = libraryURL.appendingPathComponent("texlive/2019/texmf-dist") // $HOME/Library/texlive/2019/texmf-dist
                    if (FileManager().fileExists(atPath: localURL.path) && !localURL.isDirectory) {
                        try! FileManager().removeItem(at: localURL)
                    }
                    if (!FileManager().fileExists(atPath: localURL.path)) {
                        try! FileManager().createDirectory(atPath: localURL.path, withIntermediateDirectories: true)
                    }
                    let contents = try! FileManager().contentsOfDirectory(atPath: archiveURL.path)
                    for directory in contents {
                        let localFileURL = localURL.appendingPathComponent(directory)
                        if (FileManager().fileExists(atPath: localFileURL.path) && !localFileURL.isDirectory) {
                            try! FileManager().removeItem(at: localFileURL)
                        }
                        let distantFileURL = archiveURL.appendingPathComponent(directory)
                        try! FileManager().createSymbolicLink(at: localFileURL, withDestinationURL: distantFileURL)
                    }
                }
                NSLog("Done linking texmf-dist resource")
            }
        })
        let texmf_dist_fontsResource = NSBundleResourceRequest(tags: ["texmf-dist-fonts"])
        NSLog("Begin downloading texmf-dist-fonts resources")
        texmf_dist_fontsResource.beginAccessingResources(completionHandler: { (error) in
            if let error = error {
                var message = "Error in downloading texmf-dist-fonts files: "
                message.append(error.localizedDescription)
                NSLog(message) // Also show alert
                downloadingTeX = false
                downloadingTeXError = message
                UserDefaults.standard.set(false, forKey: "TeXEnabled")
                self.TeXEnabled = false
                return
            } else {
                NSLog("texmf-dist-fonts resource succesfully downloaded")
                // link the sub-directories in the right place:
                if let archiveFileLocation = texmf_dist_fontsResource.bundle.path(forResource: "texlive_2019_texmf-dist_fonts", ofType: nil) {
                    // Is the host directory available? If not create it.
                    let archiveURL = URL(fileURLWithPath: archiveFileLocation)
                    let localURL = libraryURL.appendingPathComponent("texlive/2019/texmf-dist/fonts") // $HOME/Library/texlive/2019/texmf-dist/fonts
                    if (FileManager().fileExists(atPath: localURL.path) && !localURL.isDirectory) {
                        try! FileManager().removeItem(at: localURL)
                    }
                    if (!FileManager().fileExists(atPath: localURL.path)) {
                        try! FileManager().createDirectory(atPath: localURL.path, withIntermediateDirectories: true)
                    }
                    let contents = try! FileManager().contentsOfDirectory(atPath: archiveURL.path)
                    for directory in contents {
                        let localFileURL = localURL.appendingPathComponent(directory)
                        if (FileManager().fileExists(atPath: localFileURL.path) && !localFileURL.isDirectory) {
                            try! FileManager().removeItem(at: localFileURL)
                        }
                        let distantFileURL = archiveURL.appendingPathComponent(directory)
                        try! FileManager().createSymbolicLink(at: localFileURL, withDestinationURL: distantFileURL)
                    }
                }
                NSLog("Done linking texmf-dist-fonts resource")
            }
        })
        moveFilesQueue.async{
            // Now, we wait until the three resources are done.
            // In a queue, so as not to block the rest of the program.
            while ((texliveResource.progress.fractionCompleted < 1.0) ||
                (texmf_distResource.progress.fractionCompleted < 1.0) ||
                (texmf_dist_fontsResource.progress.fractionCompleted < 1.0)) {
                    let texmf_dist_fontsSize = 1335624.0
                    let texmf_distSize = 524268.0
                    let texliveSize = 84704.0 
                    percentTeXDownloadComplete = 100.0 * (texmf_dist_fontsSize * texmf_dist_fontsResource.progress.fractionCompleted +
                        texmf_distSize * texmf_distResource.progress.fractionCompleted + texliveSize * texliveResource.progress.fractionCompleted) / (texmf_dist_fontsSize + texmf_distSize + texliveSize)
            }
            NSLog("All resources have been downloaded: \(texmf_dist_fontsResource.progress.fractionCompleted)")
            downloadingTeX = false
            self.TeXEnabled = true
            addCommandList(Bundle.main.path(forResource: "texCommandsDictionary", ofType: "plist"))
            self.TeXnotification(title: "TeX succesfully activated", message: "TeX is now activated")
        }
    }

    func disableTeX() {
        NSLog("Deactivating TeX")
        // First, deactivate the commands:
        downloadingTeX = false
        TeXEnabled = false
        activateFakeTeXCommands()
        // De-activate the resources:
        let texliveResource = NSBundleResourceRequest(tags: ["texlive"])
        texliveResource.endAccessingResources()
        let texmf_distResource = NSBundleResourceRequest(tags: ["texmf-dist"])
        texmf_distResource.endAccessingResources()
        let texmf_dist_fontsResource = NSBundleResourceRequest(tags: ["texmf-dist-fonts"])
        texmf_dist_fontsResource.endAccessingResources()
        // Finally, remove everything:
        let libraryURL = try! FileManager().url(for: .libraryDirectory,
                                                in: .userDomainMask,
                                                appropriateFor: nil,
                                                create: true)
        let localURL = libraryURL.appendingPathComponent("texlive/")
        if let enumerator = FileManager().enumerator(atPath: localURL.path) {
            // first loop: remove all files and links
            for file in enumerator {
                let localFileURL = localURL.appendingPathComponent(file as! String)
                if (FileManager().fileExists(atPath: localFileURL.path) && !localFileURL.isDirectory) {
                    try! FileManager().removeItem(at: localFileURL)
                }
            }
        }
        if let enumerator = FileManager().enumerator(atPath: localURL.path) {
            // second loop: remove all directories (now empty)
            for file in enumerator {
                let localFileURL = localURL.appendingPathComponent(file as! String)
                try! FileManager().removeItem(at: localFileURL)
            }
        }
    }
    
    
    func downloadOpentype() {
        if (downloadingOpentype) {
            return // only run this function once
        }
        downloadingOpentype = true;
        downloadingOpentypeError = ""
        percentOpentypeDownloadComplete = 0.0
        // download the extensions: texlive, texmf-dist and texmf-dist-fonts
        let opentypeResource = NSBundleResourceRequest(tags: ["opentype"])
        let libraryURL = try! FileManager().url(for: .libraryDirectory,
                                                in: .userDomainMask,
                                                appropriateFor: nil,
                                                create: true)
        NSLog("Begin downloading LuaTeX ")
        opentypeResource.beginAccessingResources(completionHandler: { (error) in
            if let error = error {
                var message = "Error in downloading LuaTeX: "
                message.append(error.localizedDescription)
                NSLog(message)
                downloadingOpentype = false
                downloadingOpentypeError = message
                UserDefaults.standard.set(false, forKey: "TeXOpenType")
                self.OpentypeEnabled = false
                return
            } else {
                NSLog("LuaTeX fonts succesfully downloaded")
                // link the two directories in place:
                if let archiveFileLocation = opentypeResource.bundle.path(forResource: "texlive_2019_texmf-dist_fonts_otf_ttf", ofType: nil) {
                    // Is the host directory available? If not create it.
                    let archiveURL = URL(fileURLWithPath: archiveFileLocation)
                    let localURL = libraryURL.appendingPathComponent("texlive/2019/texmf-dist/fonts") // $HOME/Library/texlive/2019/texmf-dist/fonts
                    if (FileManager().fileExists(atPath: localURL.path) && !localURL.isDirectory) {
                        try! FileManager().removeItem(at: localURL)
                    }
                    if (!FileManager().fileExists(atPath: localURL.path)) {
                        try! FileManager().createDirectory(atPath: localURL.path, withIntermediateDirectories: true)
                    }
                    let contents = try! FileManager().contentsOfDirectory(atPath: archiveURL.path)
                    for directory in contents {
                        let localFileURL = localURL.appendingPathComponent(directory)
                        if (FileManager().fileExists(atPath: localFileURL.path) && !localFileURL.isDirectory) {
                            try! FileManager().removeItem(at: localFileURL)
                        }
                        let distantFileURL = archiveURL.appendingPathComponent(directory)
                        try! FileManager().createSymbolicLink(at: localFileURL, withDestinationURL: distantFileURL)
                    }
                }
            }
        })
        moveFilesQueue.async{
            // In a queue, so as not to block the rest of the program.
            // Copy the files from $APPDIR/luatexfiles to $HOME/Library/texlive/2019/texmf-dist/luatexfiles
            let archiveURL = URL(fileURLWithPath: Bundle.main.path(forResource: "luatexfiles", ofType: nil)!)
            NSLog("Archive = \(archiveURL.path)")
            let localURL = libraryURL.appendingPathComponent("texlive/2019/texmf-dist/luatexfiles/")
            if (FileManager().fileExists(atPath: localURL.path) && !localURL.isDirectory) {
                try! FileManager().removeItem(at: localURL)
            }
            if (!FileManager().fileExists(atPath: localURL.path)) {
                try! FileManager().createDirectory(atPath: localURL.path, withIntermediateDirectories: true)
            }
            let contents = try! FileManager().contentsOfDirectory(atPath: archiveURL.path)
            for file in contents {
                let localFileURL = localURL.appendingPathComponent(file)
                do {
                    if (localFileURL.isSymbolicLink && !FileManager().fileExists(atPath: localFileURL.path)) {
                        try FileManager().removeItem(at: localFileURL)
                    }
                    let distantFileURL = archiveURL.appendingPathComponent(file)
                    try FileManager().createSymbolicLink(at: localFileURL, withDestinationURL: distantFileURL)
                } catch {
                    NSLog("Error copying \(localFileURL.path): \(error)")
                }
            }
            // Now, we wait until the resource is downloaded.
            while (opentypeResource.progress.fractionCompleted < 1.0) {
                    percentOpentypeDownloadComplete = opentypeResource.progress.fractionCompleted
            }
            NSLog("Opentype fonts have been downloaded.")
            downloadingOpentype = false
            self.OpentypeEnabled = true
            addCommandList(Bundle.main.path(forResource: "luatexCommandsDictionary", ofType: "plist"))
            self.TeXnotification(title: "LuaTeX succesfully activated", message: "LuaTeX is now activated")
            }
    }

    func disableOpentype() {
        NSLog("Deactivating LuaTeX")
        // First, deactivate the commands:
        downloadingOpentype = false
        OpentypeEnabled = false
        activateFakeTeXCommands()
        // De-activate the resource:
        let opentypeResource = NSBundleResourceRequest(tags: ["opentype"])
        opentypeResource.endAccessingResources()
        // Finally, remove everything:
        let libraryURL = try! FileManager().url(for: .libraryDirectory,
                                                in: .userDomainMask,
                                                appropriateFor: nil,
                                                create: true)
        let localURL = libraryURL.appendingPathComponent("texlive/2019/texmf-dist/fonts")
        let enumerator = ["opentype", "truetype"]
        for file in enumerator {
            let localFileURL = localURL.appendingPathComponent(file as! String)
            if (FileManager().fileExists(atPath: localFileURL.path)) {
                try! FileManager().removeItem(at: localFileURL)
            }
        }
    }
    
}
