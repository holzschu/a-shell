//
//  AppDelegate+TeX.swift
//  
//
//  Created by Nicolas Holzschuch on 04/09/2019.
//

import Foundation
import UserNotifications
import ios_system

private let texmf_distResource = NSBundleResourceRequest(tags: ["texlive_2022_dist"])
private let texmf_varResource = NSBundleResourceRequest(tags: ["texlive_2022_var"])
private let texmf_dist_fontsResource = NSBundleResourceRequest(tags: ["texlive_2022_dist_fonts"])
private let texmf_dist_fonts_vfResource = NSBundleResourceRequest(tags: ["texlive_2022_texmf_dist_fonts_vf"])
private let texmf_dist_fonts_type1Resource = NSBundleResourceRequest(tags: ["texlive_2022_texmf_dist_fonts_type1"])
private let texmf_dist_fonts_opentypeResource = NSBundleResourceRequest(tags: ["texlive_2022_texmf_dist_fonts_oft_ttf"])

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
            replaceCommand("makeindex", "tex", true)
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
            // texlua asks if you want to install LuaTeX, but will be activated once TeX is enabled.
            replaceCommand("texlua", "luatex", true)
            replaceCommand("texluac", "luatex", true)
        }
        if (!TeXEnabled || !OpentypeEnabled) {
            replaceCommand("dvilualatex", "luatex", true)
            replaceCommand("dviluatex", "luatex", true)
            replaceCommand("lualatex", "luatex", true)
            replaceCommand("luatex", "luatex", true)
        }
    }
    
    
    override func observeValue(forKeyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        let texmf_dist_fonts_type1Size = 354116.0
        let texmf_dist_fontsSize = 344776.0
        let texmf_dist_fonts_vf_Size = 255004.0
        let texmf_distSize = 478968.0
        let texmf_varSize = 107112.0

        percentTeXDownloadComplete = 100.0 * (texmf_dist_fontsSize * texmf_dist_fontsResource.progress.fractionCompleted +
            texmf_dist_fonts_type1Size * texmf_dist_fonts_type1Resource.progress.fractionCompleted +
            texmf_dist_fonts_vf_Size * texmf_dist_fonts_vfResource.progress.fractionCompleted +
            texmf_varSize * texmf_varResource.progress.fractionCompleted +
            texmf_distSize * texmf_distResource.progress.fractionCompleted)
            / (texmf_dist_fontsSize + texmf_dist_fonts_type1Size + texmf_dist_fonts_vf_Size + texmf_distSize + texmf_varSize)

        if (percentTeXDownloadComplete >= 100.0) {
            NSLog("All resources have been downloaded: \(texmf_dist_fontsResource.progress.fractionCompleted)")
            downloadingTeX = false
            self.TeXEnabled = true
            addCommandList(Bundle.main.path(forResource: "texCommandsDictionary", ofType: "plist"))
            // Create all the commands:
            let libraryURL = try! FileManager().url(for: .libraryDirectory,
                                                       in: .userDomainMask,
                                                       appropriateFor: nil,
                                                       create: true)
            let localPath = libraryURL.appendingPathComponent("bin") // $HOME/Library/bin
            if (!FileManager().fileExists(atPath: localPath.path)) {
                do {
                    try (FileManager().createDirectory(at: localPath, withIntermediateDirectories: true))
                }
                catch {
                    NSLog("Unable to create binary directory \(localPath.path): \(error)")
                }
            }
            for script in TeXscripts {
                let command = localPath.path + "/" + script[0]
                let location = "../texlive/2022/texmf-dist/" + script[1]
                do {
                    if (FileManager().fileExists(atPath: command)) {
                        // NSLog("Removing existing file \(command)")
                        try FileManager().removeItem(atPath: command)
                    }
                    try FileManager().createSymbolicLink(atPath: command, withDestinationPath: location)
                }
                catch {
                    NSLog("Unable to create symbolic link at \(command) to \(location): \(error)")
                }
            }
            if let installedTexVersion = UserDefaults.standard.string(forKey: "TeXVersion") {
                if (installedTexVersion < "2022") {
                    // We have copied texlive/2021 to texlive/2022 in order to keep user-installed packages.
                    // We do a bit of cleanup to remove directories and files that are not included anymore:
                    let localUrl = libraryURL.appendingPathComponent("texlive/2022/") // $HOME/Library/bin
                    for directory in texlive_2021_directories {
                        let location = localUrl.appendingPathComponent(directory)
                        do {
                            if (FileManager().fileExists(atPath: location.path)) {
                                try FileManager().removeItem(at: location)
                            }
                        }
                        catch {
                            NSLog("Unable to remove directory at \(location): \(error)")
                            
                        }
                    }
                    for file in texlive_2021_files {
                        let location = localUrl.appendingPathComponent(file)
                        do {
                            if (FileManager().fileExists(atPath: location.path)) {
                                try FileManager().removeItem(at: location)
                            }
                        }
                        catch {
                            NSLog("Unable to remove file at \(location): \(error)")
                            
                        }
                    }
                }
            }
            UserDefaults.standard.setValue("2022", forKey: "TeXVersion")
        }
    }
    
    func copyContentsOfDirectory(at: URL, to: URL) {
        if let archiveEnumerator = FileManager().enumerator(at: at, includingPropertiesForKeys: nil, errorHandler: nil) {
            for case let fileURL as URL in archiveEnumerator {
                let filePath = fileURL.path
                // Make sure directory exists:
                var suffix = filePath
                if (suffix.hasPrefix(at.path)) {
                    suffix.removeFirst(at.path.count)
                } else {
                    if (at.path.hasPrefix("/private") && !suffix.hasPrefix("/private")) {
                        suffix = "/private" + filePath
                    } else if (!at.path.hasPrefix("/private") && suffix.hasPrefix("/private")) {
                        suffix.removeFirst("/private".count)
                    }
                    if (suffix.hasPrefix(at.path)) {
                        suffix.removeFirst(at.path.count)
                    } else {
                        NSLog("Could not identify suffix for \(filePath) from \(at.path)")
                        continue
                    }
                }
                let localPositionURL = to.appendingPathComponent(suffix)
                if (fileURL.isDirectory) {
                    do {
                        try FileManager().createDirectory(at: localPositionURL, withIntermediateDirectories: true, attributes: nil)
                    }
                    catch {
                        NSLog("copyContentOfDirectory: Could not create directory at \(fileURL.path) from \(localPositionURL.path)")
                    }
                } else {
                    let localDirectory = localPositionURL.deletingLastPathComponent()
                    if (!FileManager().fileExists(atPath: localDirectory.path)) {
                        do {
                            try FileManager().createDirectory(at: localDirectory, withIntermediateDirectories: true, attributes: nil)
                        }
                        catch {
                            NSLog("copyContentOfDirectory: Could not create directory at \(fileURL.path) from \(localPositionURL.path)")
                        }
                    } else if !localDirectory.isDirectory {
                        do {
                            try FileManager().removeItem(at: localDirectory)
                            try FileManager().createDirectory(at: localDirectory, withIntermediateDirectories: true, attributes: nil)
                        }
                        catch {
                            NSLog("copyContentOfDirectory: Could not remove file + create directory at \(fileURL.path) from \(localPositionURL.path)")
                        }
                    }
                    do {
                        if (!FileManager().fileExists(atPath: localPositionURL.path)) {
                            try FileManager().copyItem(at: fileURL, to: localPositionURL)
                        } else if (!FileManager().contentsEqual(atPath: fileURL.path, andPath: localPositionURL.path)) {
                            // Both files exist, they're different. We copy the new one:
                            // (necessary now that we copied texlive/2021 to texlive/2022)
                            try FileManager().removeItem(at: localPositionURL)
                            try FileManager().copyItem(at: fileURL, to: localPositionURL)
                        }
                    }
                    catch {
                        NSLog("copyContentOfDirectory: Could not copy \(fileURL.path) to \(localPositionURL.path)")
                    }
                }
            }
        }
    }
    
    func copyContentFromResource(resource: NSBundleResourceRequest, path: String) {
        if let archiveFileLocation = resource.bundle.path(forResource: path, ofType: nil) {
            let archiveURL = URL(fileURLWithPath: archiveFileLocation)
            let libraryURL = try! FileManager().url(for: .libraryDirectory,
                                                       in: .userDomainMask,
                                                       appropriateFor: nil,
                                                       create: true)
            let localURL = libraryURL.appendingPathComponent("texlive") // $HOME/Library/texlive
            copyContentsOfDirectory(at: archiveURL, to: localURL)
        } else {
            NSLog("Could not get location for On-Demand Resource: \(resource) with path \(path)")
        }
    }

    
    func downloadTeX() {
        // TODO: if TeX has been downloaded, don't download again.
        if (downloadingTeX) {
            return; // only run this function once
        }
        downloadingTeX = true;
        percentTeXDownloadComplete = 0.0
        // download the extensions: texlive, texmf-dist and texmf-dist-fonts
        let libraryURL = try! FileManager().url(for: .libraryDirectory,
                                                in: .userDomainMask,
                                                appropriateFor: nil,
                                                create: true)
        NSLog("Begin downloading texlive resources")
        NSLog("Copying texlive into $LIBRARY")
        let localURL = libraryURL.appendingPathComponent("texlive") // $HOME/Library/texlive
        // Create texlive:
        if (!createDirectory(localURL: localURL)) {
            downloadingTeX = false
            UserDefaults.standard.set(false, forKey: "TeXEnabled")
            self.TeXEnabled = false
            return
        }
        // If tl2021 exists, move it to 2022:
        let tl2021 = localURL.appendingPathComponent("2021")
        let tl2022 = localURL.appendingPathComponent("2022")
        if (FileManager().fileExists(atPath: tl2021.path) && !FileManager().fileExists(atPath: tl2022.path)) {
            do {
                try FileManager().moveItem(at: tl2021, to: tl2022)
            }
            catch {
                NSLog("Error in copying texlive 2021 to texlive 2022: \(error)")
            }
        }
        // Create texlive/2022:
        if (!FileManager().fileExists(atPath: tl2022.path)) {
            if (!createDirectory(localURL: tl2022)) {
                downloadingTeX = false
                UserDefaults.standard.set(false, forKey: "TeXEnabled")
                self.TeXEnabled = false
                return
            }
        }
        //  Then copy $APPDIR/forbidden_2022/2022 (files we cannot include in On-Demand Resources)s:
        if let forbidden = Bundle.main.resourceURL?.appendingPathComponent("forbidden_2022/2022") {
            copyContentsOfDirectory(at: forbidden, to: tl2022)
        }
        // If ~/Library/texlive/2019 still exists (unlikely, but...) keep its texmf-local directory
        let tl2019 = localURL.appendingPathComponent("2019")
        if (FileManager().fileExists(atPath: tl2019.path)) {
            // If ~/Library/texlive/2019/texmf-local exists, copy it to ~/Library/texmf-local:
            let tl2019_local = localURL.appendingPathComponent("2019").appendingPathComponent("texmf-local")
            if (FileManager().fileExists(atPath: tl2019_local.path) && tl2019_local.isDirectory) {
                do {
                    try FileManager().moveItem(at: tl2019_local, to: localURL.appendingPathComponent("texmf-local"))
                    try FileManager().removeItem(at: tl2019)
                }
                catch {
                    NSLog("Error in moving texmf-local to texlive: \(error)")
                }
            } else {
                do {
                    try FileManager().removeItem(at: tl2019)
                }
                catch {
                    NSLog("Error in removing texlive/2019: \(error)")
                }
            }
        }
        // Create ~/Library/texlive/texmf-local if it does not exist yet:
        let tl_local = localURL.appendingPathComponent("texmf-local")
        if (!FileManager().fileExists(atPath: tl_local.path)) {
            _ = createDirectory(localURL: tl_local)
        }
        // We load resources sequentially to avoid clogging networks and servers:
        texmf_distResource.loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent
        NSLog("Begin downloading texmf-dist resources")
        texmf_distResource.beginAccessingResources(completionHandler: { (error) in
            if let error = error {
                var message = "Error in downloading texmf-dist files: "
                message.append(error.localizedDescription)
                NSLog(message) // Also show alert?
                downloadingTeX = false
                UserDefaults.standard.set(false, forKey: "TeXEnabled")
                self.TeXEnabled = false
                return
            } else {
                NSLog("texmf-dist resource succesfully downloaded")
                // link the sub-directories in the right place:
                self.copyContentFromResource(resource: texmf_distResource, path: "texlive_2022_texmf_dist")
                NSLog("Done copying texmf-dist resource")
                // Release the resource:
                texmf_distResource.endAccessingResources()
                // Then texmf-var:
                texmf_varResource.loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent
                texmf_varResource.beginAccessingResources(completionHandler: { (error) in
                    if let error = error {
                        var message = "Error in downloading texmf-var files: "
                        message.append(error.localizedDescription)
                        NSLog(message) // Also show alert?
                        downloadingTeX = false
                        UserDefaults.standard.set(false, forKey: "TeXEnabled")
                        self.TeXEnabled = false
                        return
                    } else {
                        NSLog("texmf-var resource succesfully downloaded")
                        // link the sub-directories in the right place:
                        self.copyContentFromResource(resource: texmf_varResource, path: "texlive_2022_texmf_var")
                        NSLog("Done copying texmf-var resource")
                        // Release the resource:
                        texmf_varResource.endAccessingResources()
                        // Then texmf-dist/fonts:
                        texmf_dist_fontsResource.loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent
                        texmf_dist_fontsResource.beginAccessingResources(completionHandler: { (error) in
                            if let error = error {
                                var message = "Error in downloading texmf-fonts files: "
                                message.append(error.localizedDescription)
                                NSLog(message) // Also show alert?
                                downloadingTeX = false
                                UserDefaults.standard.set(false, forKey: "TeXEnabled")
                                self.TeXEnabled = false
                                return
                            } else {
                                NSLog("texmf-fonts resource succesfully downloaded")
                                // link the sub-directories in the right place:
                                self.copyContentFromResource(resource: texmf_dist_fontsResource, path: "texlive_2022_texmf_dist_fonts")
                                NSLog("Done copying texmf-fonts resource")
                                // Release the resource:
                                texmf_dist_fontsResource.endAccessingResources()
                                // Then texmf-dist/fonts/vf:
                                texmf_dist_fonts_vfResource.loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent
                                texmf_dist_fonts_vfResource.beginAccessingResources(completionHandler: { (error) in
                                    if let error = error {
                                        var message = "Error in downloading texmf-fonts VF files: "
                                        message.append(error.localizedDescription)
                                        NSLog(message) // Also show alert?
                                        downloadingTeX = false
                                        UserDefaults.standard.set(false, forKey: "TeXEnabled")
                                        self.TeXEnabled = false
                                        return
                                    } else {
                                        NSLog("texmf-fonts VF resource succesfully downloaded")
                                        // link the sub-directories in the right place:
                                        self.copyContentFromResource(resource: texmf_dist_fonts_vfResource, path: "texlive_2022_texmf_dist_fonts_vf")
                                        NSLog("Done copying texmf-fonts VF resource")
                                        // Release the resource:
                                        texmf_dist_fonts_vfResource.endAccessingResources()
                                    }
                                })
                                texmf_dist_fonts_vfResource.progress.addObserver(self, forKeyPath: "fractionCompleted", options: .new, context: nil)
                                // Then texmf-dist/fonts/type1:
                                texmf_dist_fonts_type1Resource.loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent
                                texmf_dist_fonts_type1Resource.beginAccessingResources(completionHandler: { (error) in
                                    if let error = error {
                                        var message = "Error in downloading texmf-fonts Type1 files: "
                                        message.append(error.localizedDescription)
                                        NSLog(message) // Also show alert?
                                        downloadingTeX = false
                                        UserDefaults.standard.set(false, forKey: "TeXEnabled")
                                        self.TeXEnabled = false
                                        return
                                    } else {
                                        NSLog("texmf-fonts Type1 resource succesfully downloaded")
                                        // link the sub-directories in the right place:
                                        self.copyContentFromResource(resource: texmf_dist_fonts_type1Resource, path: "texlive_2022_texmf_dist_fonts_type1")
                                        NSLog("Done copying texmf-fonts Type1 resource")
                                        // Release the resource:
                                        texmf_dist_fonts_type1Resource.endAccessingResources()
                                    }
                                })
                                texmf_dist_fonts_type1Resource.progress.addObserver(self, forKeyPath: "fractionCompleted", options: .new, context: nil)
                            }
                        })
                        texmf_dist_fontsResource.progress.addObserver(self, forKeyPath: "fractionCompleted", options: .new, context: nil)
                    }
                })
                texmf_varResource.progress.addObserver(self, forKeyPath: "fractionCompleted", options: .new, context: nil)
            }
        })
        texmf_distResource.progress.addObserver(self, forKeyPath: "fractionCompleted", options: .new, context: nil)
    }

    func disableTeX() {
        if (appVersion == "a-Shell-mini") {
            return
        }
        // Remove all sub-directories of ~/Library/texlive/*/ except texmf-local.
        // return ; // for debugging TeX
        NSLog("Deactivating TeX")
        // First, deactivate the commands:
        // De-activate the resources -- if they are already there:
        if (texmf_distResource.progress.fractionCompleted > 0) {
            texmf_distResource.endAccessingResources()
        }
        if (texmf_varResource.progress.fractionCompleted > 0) {
            texmf_varResource.endAccessingResources()
        }
        if (texmf_dist_fontsResource.progress.fractionCompleted > 0) {
            texmf_dist_fontsResource.endAccessingResources()
        }
        if (texmf_dist_fonts_vfResource.progress.fractionCompleted > 0) {
            texmf_dist_fonts_vfResource.endAccessingResources()
        }
        if (texmf_dist_fonts_type1Resource.progress.fractionCompleted > 0) {
            texmf_dist_fonts_type1Resource.endAccessingResources()
        }
        downloadingTeX = false
        TeXEnabled = false
        activateFakeTeXCommands()
        // Finally, remove everything:
        let libraryURL = try! FileManager().url(for: .libraryDirectory,
                                                in: .userDomainMask,
                                                appropriateFor: nil,
                                                create: true)
        let localURL = libraryURL.appendingPathComponent("texlive/")
        for year in ["2019", "2021", "2022"] {
            let yearDirectoryURL = localURL.appendingPathComponent(year)
            if (FileManager().fileExists(atPath: yearDirectoryURL.path) && yearDirectoryURL.isDirectory) {
                do {
                    let yearDirectoryContent = try FileManager().contentsOfDirectory(at: yearDirectoryURL, includingPropertiesForKeys: nil)
                    for dir in yearDirectoryContent {
                        if dir.lastPathComponent != "texmf-local" {
                            try FileManager().removeItem(at: dir)
                        }
                    }
                }
                catch {
                    NSLog("Error in removing directory from texlive/\(year): \(error)")
                }
            }
        }
        // Delete all the commands:
        let localPath = libraryURL.appendingPathComponent("bin") // $HOME/Library/bin
        for script in TeXscripts {
            let command = localPath.path + "/" + script[0]
            do {
                try FileManager().removeItem(atPath: command)
            }
            catch {
                NSLog("Unable to remove command at \(command)")
            }
        }

    }
    
    
    func downloadOpentype() {
        if (downloadingOpentype) {
            return // only run this function once
        }
        downloadingOpentype = true;
        percentOpentypeDownloadComplete = 0.0
        // download the extensions: texlive, texmf-dist and texmf-dist-fonts
        let libraryURL = try! FileManager().url(for: .libraryDirectory,
                                                in: .userDomainMask,
                                                appropriateFor: nil,
                                                create: true)
        // First, wait until TeX is done:
        texmf_dist_fonts_opentypeResource.loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent
        NSLog("Begin downloading LuaTeX ")
        texmf_dist_fonts_opentypeResource.beginAccessingResources(completionHandler: { (error) in
            if let error = error {
                var message = "Error in downloading LuaTeX: "
                message.append(error.localizedDescription)
                NSLog(message)
                downloadingOpentype = false
                UserDefaults.standard.set(false, forKey: "TeXOpenType")
                self.OpentypeEnabled = false
                return
            } else {
                NSLog("texmf-dist/fonts OpenType resource succesfully downloaded")
                // link the sub-directories in the right place:
                self.copyContentFromResource(resource: texmf_dist_fonts_opentypeResource, path: "texlive_2022_texmf_dist_fonts_oft_ttf")
                NSLog("Done copying texmf-dist/fonts OpenType resource")
                // Release the resource:
                texmf_dist_fonts_opentypeResource.endAccessingResources()
            }
        })
        moveFilesQueue.async{
            // In a queue, so as not to block the rest of the program.
            // Now, we wait until the resource is downloaded.
            while (texmf_dist_fonts_opentypeResource.progress.fractionCompleted < 1.0) {
                percentOpentypeDownloadComplete = texmf_dist_fonts_opentypeResource.progress.fractionCompleted
            }
            NSLog("Opentype fonts have been downloaded.")
            downloadingOpentype = false
            self.OpentypeEnabled = true
            addCommandList(Bundle.main.path(forResource: "luatexCommandsDictionary", ofType: "plist"))
            UserDefaults.standard.setValue("2022", forKey: "LuaTeXVersion")
        }
    }

    func disableOpentype() {
        if (appVersion == "a-Shell-mini") {
            return
        }
        // return ; // for debugging TeX
        NSLog("Deactivating LuaTeX")
        // First, deactivate the commands:
        // De-activate the resource:
        if (OpentypeEnabled || downloadingOpentype) {
            texmf_dist_fonts_opentypeResource.endAccessingResources()
        }
        downloadingOpentype = false
        OpentypeEnabled = false
        activateFakeTeXCommands()
        // Finally, remove everything:
        let libraryURL = try! FileManager().url(for: .libraryDirectory,
                                                in: .userDomainMask,
                                                appropriateFor: nil,
                                                create: true)
        let localURL = libraryURL.appendingPathComponent("texlive/2022/texmf-dist/fonts")
        for file in ["opentype", "truetype"] {
            let localFileURL = localURL.appendingPathComponent(file)
            if (FileManager().fileExists(atPath: localFileURL.path)) {
                do { try FileManager().removeItem(at: localFileURL) }
                catch { continue }
            }
        }
    }
}
