//
//  AppDelegate+TeX.swift
//  
//
//  Created by Nicolas Holzschuch on 04/09/2019.
//

import Foundation
import UserNotifications
import ios_system

private let texmf_distResource = NSBundleResourceRequest(tags: ["texmf-dist"])
private let texmf_dist_fontsResource = NSBundleResourceRequest(tags: ["texmf-dist-fonts"])
private let texmf_dist_fonts_type1Resource = NSBundleResourceRequest(tags: ["texmf-dist-fonts-type1"])
private let opentypeResource = NSBundleResourceRequest(tags: ["opentype"])

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
    
    
    override func observeValue(forKeyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        let texmf_dist_fonts_type1Size = 216544.0
        let texmf_dist_fontsSize = 335332.0
        let texmf_distSize = 313392.0
        percentTeXDownloadComplete = 100.0 * (texmf_dist_fontsSize * texmf_dist_fontsResource.progress.fractionCompleted +
            texmf_dist_fonts_type1Size * texmf_dist_fonts_type1Resource.progress.fractionCompleted +
            texmf_distSize * texmf_distResource.progress.fractionCompleted)
            / (texmf_dist_fontsSize + texmf_dist_fonts_type1Size + texmf_distSize)

        if (percentTeXDownloadComplete >= 100.0) {
            NSLog("All resources have been downloaded: \(texmf_dist_fontsResource.progress.fractionCompleted)")
            downloadingTeX = false
            self.TeXEnabled = true
            addCommandList(Bundle.main.path(forResource: "texCommandsDictionary", ofType: "plist"))
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
        let libraryURL = try! FileManager().url(for: .libraryDirectory,
                                                in: .userDomainMask,
                                                appropriateFor: nil,
                                                create: true)
        NSLog("Begin downloading texlive resources")
        
        NSLog("Copying texlive into $LIBRARY")
        // Copy every file in the entire directory (because it can be written on, replaced, etc)
        // make sure ~/Library/texlive exists:
        // For some reason, using an on-demand resource here does not allow a full depth traversal
        // (many files missing). So texlive is always included with the app.
        let localURL = libraryURL.appendingPathComponent("texlive") // $HOME/Library/texlive
        do {
            if (FileManager().fileExists(atPath: localURL.path) && !localURL.isDirectory) {
                try FileManager().removeItem(at: localURL)
            }
            if (!FileManager().fileExists(atPath: localURL.path)) {
                try FileManager().createDirectory(atPath: localURL.path, withIntermediateDirectories: true)
            }
        } catch {
            NSLog("Error in creating texlive directory: \(error)")
            downloadingTeX = false
            UserDefaults.standard.set(false, forKey: "TeXEnabled")
            downloadingTeXError = error.localizedDescription
            self.TeXEnabled = false
            return
        }
        for directory in TeXDirectories {
            do {
                let localDirectory = libraryURL.appendingPathComponent(directory)
                if (FileManager().fileExists(atPath: localDirectory.path) && !localDirectory.isDirectory) {
                    try FileManager().removeItem(at: localDirectory)
                }
                // Create directory first:
                if (!FileManager().fileExists(atPath: localDirectory.path)) {
                    try FileManager().createDirectory(atPath: localDirectory.path, withIntermediateDirectories: true)
                }
            } catch {
                NSLog("Error in creating directory: \(error)")
                continue
            }
        }
        for file in TeXFiles {
            if let distantFileURL = Bundle.main.path(forResource: file, ofType: nil) {
                do {
                    let localFileURL = libraryURL.appendingPathComponent(file as! String)
                    var localFileExists = FileManager().fileExists(atPath: localFileURL.path)
                    if (localFileExists && !localFileURL.isDirectory) {
                        try FileManager().removeItem(at: localFileURL)
                        localFileExists = FileManager().fileExists(atPath: localFileURL.path)
                    }
                    // Create directory first:
                    try FileManager().copyItem(at: URL(fileURLWithPath: distantFileURL), to: localFileURL)
                } catch {
                    NSLog("Error in copying texlive file: \(error)")
                    continue
                }
            }
        }
        NSLog("done copying texlive at $HOME/Library")
        // Once texlive is downloaded, we start texmf_dist:
        texmf_distResource.loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent
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
                        do {
                            try FileManager().createSymbolicLink(at: localFileURL, withDestinationURL: distantFileURL)
                        }
                        catch {
                            NSLog("Error in copying texlive file: \(error)")
                        }
                    }
                }
                NSLog("Done linking texmf-dist resource")
            }
            // Once texmf_distResource is completed, we start texmf_dist_fonts:
            texmf_dist_fontsResource.loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent
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
                // Once texmf_dist_fonts is loaded, we start texmf_dist_fonts_type1:
                texmf_dist_fonts_type1Resource.loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent
                NSLog("Begin downloading texmf-dist-fonts-type1 resources")
                texmf_dist_fonts_type1Resource.beginAccessingResources(completionHandler: { (error) in
                    if let error = error {
                        var message = "Error in downloading texmf-dist-fonts-type1 files: "
                        message.append(error.localizedDescription)
                        NSLog(message) // Also show alert
                        downloadingTeX = false
                        downloadingTeXError = message
                        UserDefaults.standard.set(false, forKey: "TeXEnabled")
                        self.TeXEnabled = false
                        return
                    } else {
                        NSLog("texmf-dist-fonts-type1 resource succesfully downloaded")
                        // link the sub-directory in the right place:
                        if let archiveFileLocation = texmf_dist_fonts_type1Resource.bundle.path(forResource: "texlive_2019_texmf-dist_fonts_type1", ofType: nil) {
                            // Is the host directory available? If not create it.
                            let archiveURL = URL(fileURLWithPath: archiveFileLocation)
                            let localURL = libraryURL.appendingPathComponent("texlive/2019/texmf-dist/fonts") // $HOME/Library/texlive/2019/texmf-dist/fonts
                            if (FileManager().fileExists(atPath: localURL.path) && !localURL.isDirectory) {
                                try! FileManager().removeItem(at: localURL)
                            }
                            if (!FileManager().fileExists(atPath: localURL.path)) {
                                try! FileManager().createDirectory(atPath: localURL.path, withIntermediateDirectories: true)
                            }
                            let localFileURL = localURL.appendingPathComponent("type1")
                            if (FileManager().fileExists(atPath: localFileURL.path)) {
                                try! FileManager().removeItem(at: localFileURL)
                            }
                            try! FileManager().createSymbolicLink(at: localFileURL, withDestinationURL: archiveURL)
                        }
                        NSLog("Done linking texmf-dist-fonts-type1 resource")
                    }
                })
                texmf_dist_fonts_type1Resource.progress.addObserver(self, forKeyPath: "fractionCompleted", options: .new, context: nil)
            })
            texmf_dist_fontsResource.progress.addObserver(self, forKeyPath: "fractionCompleted", options: .new, context: nil)
        })
        texmf_distResource.progress.addObserver(self, forKeyPath: "fractionCompleted", options: .new, context: nil)
    }

    func disableTeX() {
        NSLog("Deactivating TeX")
        // First, deactivate the commands:
        downloadingTeX = false
        TeXEnabled = false
        activateFakeTeXCommands()
        // De-activate the resources -- if they are already there:
        texmf_distResource.endAccessingResources()
        texmf_dist_fontsResource.endAccessingResources()
        texmf_dist_fonts_type1Resource.endAccessingResources()
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
        let libraryURL = try! FileManager().url(for: .libraryDirectory,
                                                in: .userDomainMask,
                                                appropriateFor: nil,
                                                create: true)
        // First, wait until TeX is done:
        opentypeResource.loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent
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
        // If there was an error in downloading, we can end up here, but with settings set to false:
        if (UserDefaults.standard.bool(forKey: "TeXOpenType")) {
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
            }
        }
    }

    func disableOpentype() {
        NSLog("Deactivating LuaTeX")
        // First, deactivate the commands:
        downloadingOpentype = false
        OpentypeEnabled = false
        activateFakeTeXCommands()
        // De-activate the resource:
        opentypeResource.endAccessingResources()
        // Finally, remove everything:
        let libraryURL = try! FileManager().url(for: .libraryDirectory,
                                                in: .userDomainMask,
                                                appropriateFor: nil,
                                                create: true)
        let localURL = libraryURL.appendingPathComponent("texlive/2019/texmf-dist/fonts")
        let enumerator = ["opentype", "truetype"]
        for file in enumerator {
            let localFileURL = localURL.appendingPathComponent(file)
            if (FileManager().fileExists(atPath: localFileURL.path)) {
                try! FileManager().removeItem(at: localFileURL)
            }
        }
    }
    
}
