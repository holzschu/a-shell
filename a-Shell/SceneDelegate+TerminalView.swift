//
//  SceneDelegate+TerminalView.swift
//  a-Shell
//
//  Created by Nicolas Holzschuch on 24/12/2025.
//  Copyright © 2025 AsheKube. All rights reserved.
//
import SwiftTerm // for the terminal window
import ios_system
import TipKit // for helpful tips

extension SceneDelegate {
    
    func longestCommonPrefix(_ strs: [String]) -> String {
        guard let first = strs.first else { return "" }
        
        var prefix = first
        
        for str in strs {
            while !str.hasPrefix(prefix) {
                prefix = String(prefix.dropLast())
                if prefix.isEmpty { return "" }
            }
        }
        
        return prefix
    }
    
    func fillAutocompleteSuggestions(command: String) {
        var mainCommand = command
        autocompleteSuggestions = []
        autocompletePosition = 0
        autocompleteOptions = false
        if (currentCommand != "") && (!currentCommand.hasPrefix("dash")) && (!currentCommand.hasPrefix("sh")) {
            // a command is running, suggestions are only from command history
            for suggestion in commandHistory {
                if suggestion.hasPrefix(command) {
                    var shortenedSugg = suggestion
                    shortenedSugg.removeFirst(command.count)
                    if !autocompleteSuggestions.contains(shortenedSugg) && (shortenedSugg.count > 0) {
                        autocompleteSuggestions.append(shortenedSugg)
                    }
                }
            }
            // the last command entered is the suggestion:
            autocompletePosition = autocompleteSuggestions.count - 1
        } else {
            // no commands are running:
            // suggestions are history + available commands
            for suggestion in history.reversed() { // reversed so the latest command appears first
                if suggestion.hasPrefix(command) {
                    var shortenedSugg = suggestion
                    shortenedSugg.removeFirst(command.count)
                    if !autocompleteSuggestions.contains(shortenedSugg) && (shortenedSugg.count > 0) {
                        autocompleteSuggestions.append(shortenedSugg)
                    }
                }
            }
            // Are we autocompleting a command or something else?
            // TODO: this creates problems for "\ " and quoted spaces. We just need first and last components.
            let commandParts = command.components(separatedBy: " ")
            // NSLog("commandParts: \(commandParts)")
            mainCommand = commandParts[0]
            var autocompleteCommands = false
            if (commandParts.count <= 1) || (commandParts.last!.contains("|")) {
                autocompleteCommands = true
                mainCommand = commandParts.last!
                if let alternateScreenRange = mainCommand.range(of: "|") { // case with ls|grep
                    mainCommand.removeSubrange(command.startIndex..<alternateScreenRange.upperBound)
                }
            } else {
                // case with "ls | grep"
                let beforeCurrentElement = commandParts[commandParts.count - 2]
                if (beforeCurrentElement.hasSuffix("|")) {
                    autocompleteCommands = true
                    mainCommand = commandParts.last!
                } else if (beforeCurrentElement.contains("|")) {
                    mainCommand = beforeCurrentElement
                    if let alternateScreenRange = mainCommand.range(of: "|") { // case with ls|grep
                        mainCommand.removeSubrange(mainCommand.startIndex..<alternateScreenRange.upperBound)
                    }
                } else {
                    var previousPart = ""
                    for part in commandParts.reversed() {
                        if (part.hasSuffix("|")) {
                            mainCommand = previousPart
                            break
                        } else if (part.contains("|")) {
                            mainCommand = part
                            if let alternateScreenRange = mainCommand.range(of: "|") { // case with ls|grep
                                mainCommand.removeSubrange(mainCommand.startIndex..<alternateScreenRange.upperBound)
                                break
                            }
                        }
                        previousPart = part
                    }
                }
            }
            if autocompleteCommands {
                // Autocompleting a command:
                // The aliases go first:
                let aliasArray = aliasesAsArray() as! [String]?
                for suggestion in aliasArray! { // alphabetical order
                    if suggestion.hasPrefix(mainCommand) {
                        var shortenedSugg = suggestion
                        shortenedSugg.removeFirst(mainCommand.count)
                        if (!autocompleteSuggestions.contains(shortenedSugg)) && (!autocompleteSuggestions.contains(shortenedSugg + " ")) {
                            // add a space so we're ready with the arguments
                            autocompleteSuggestions.append(shortenedSugg + " ")
                        }
                    }
                }
                // Followed by the actual commands:
                for suggestion in commandsArray() { // alphabetical order
                    if suggestion.hasPrefix(mainCommand) {
                        var shortenedSugg = suggestion
                        shortenedSugg.removeFirst(mainCommand.count)
                        if (!autocompleteSuggestions.contains(shortenedSugg)) && (!autocompleteSuggestions.contains(shortenedSugg + " ")) {
                            // add a space so we're ready with the arguments, unless it's a directory:
                            if (!shortenedSugg.hasSuffix("/")) {
                                autocompleteSuggestions.append(shortenedSugg + " ")
                            } else {
                                autocompleteSuggestions.append(shortenedSugg)
                            }
                        }
                    }
                }
                // also list the matching files and directories in the current dir:
                var matchingDirectory = URL(fileURLWithPath: mainCommand)
                var filePrefix = ""
                if (!mainCommand.hasSuffix("/")) {
                    filePrefix = URL(fileURLWithPath: mainCommand).lastPathComponent
                    matchingDirectory = URL(fileURLWithPath: mainCommand).deletingLastPathComponent()
                }
                NSLog("directory: \(matchingDirectory) prefix: \(filePrefix)")
                var isDirectory: ObjCBool = false
                if FileManager().fileExists(atPath: matchingDirectory.path, isDirectory: &isDirectory) {
                    if isDirectory.boolValue {
                        let buf = stat.init()
                        let pbuf = UnsafeMutablePointer<stat>.allocate(capacity: 1)
                        pbuf.initialize(to: buf)
                        do {
                            var filePaths = try FileManager().contentsOfDirectory(atPath: matchingDirectory.path)
                            filePaths.sort() // alphabetical order
                            // Add all non hidden-files first, then all hidden files:
                            for file in filePaths {
                                if (!file.hasPrefix(filePrefix)) {
                                    continue
                                }
                                if (file.hasPrefix(".")) {
                                    continue
                                }
                                if !matchingDirectory.path.hasPrefix(Bundle.main.resourcePath!) {
                                    // We only check for exec status for files outside $APPDIR, because files inside $APPDIR cannot have the x bit set
                                    // On iOS, isExecutableFile() and access() always returns false so we use stat()
                                    let returnValue = stat((matchingDirectory.path + "/" + file).utf8CString, pbuf)
                                    if pbuf.pointee.st_mode & (S_IXOTH|S_IXUSR|S_IXGRP) == 0 {
                                        continue
                                    }
                                }
                                var newCommand = URL(fileURLWithPath: file).lastPathComponent
                                if (URL(fileURLWithPath: matchingDirectory.path + "/" + file).isDirectory) {
                                    newCommand.append("/")
                                }
                                // Do not add a command if it is already present:
                                var shortenedSugg = newCommand
                                shortenedSugg.removeFirst(filePrefix.count)
                                if (!autocompleteSuggestions.contains(shortenedSugg)) && (!autocompleteSuggestions.contains(shortenedSugg + " ")) {
                                    // add a space so we're ready with the arguments, unless it's a directory:
                                    if (!shortenedSugg.hasSuffix("/")) {
                                        autocompleteSuggestions.append(shortenedSugg + " ")
                                    } else {
                                        autocompleteSuggestions.append(shortenedSugg)
                                    }
                                }
                            }
                            for file in filePaths {
                                if (!file.hasPrefix(filePrefix)) {
                                    continue
                                }
                                if (!file.hasPrefix(".")) {
                                    continue
                                }
                                if !matchingDirectory.path.hasPrefix(Bundle.main.resourcePath!) {
                                    // We only check for exec status for files outside $APPDIR, because files inside $APPDIR cannot have the x bit set
                                    // On iOS, isExecutableFile() and access() always returns false so we use stat()
                                    let returnValue = stat((matchingDirectory.path + "/" + file).utf8CString, pbuf)
                                    if pbuf.pointee.st_mode & (S_IXOTH|S_IXUSR|S_IXGRP) == 0 {
                                        continue
                                    }
                                }
                                var newCommand = URL(fileURLWithPath: file).lastPathComponent
                                if (URL(fileURLWithPath: matchingDirectory.path + "/" + file).isDirectory) {
                                    newCommand.append("/")
                                }
                                // Do not add a command if it is already present:
                                var shortenedSugg = newCommand
                                shortenedSugg.removeFirst(filePrefix.count)
                                if (!autocompleteSuggestions.contains(shortenedSugg)) && (!autocompleteSuggestions.contains(shortenedSugg + " ")) {
                                    // add a space so we're ready with the arguments, unless it's a directory:
                                    if (!shortenedSugg.hasSuffix("/")) {
                                        autocompleteSuggestions.append(shortenedSugg + " ")
                                    } else {
                                        autocompleteSuggestions.append(shortenedSugg)
                                    }
                                }
                            }
                        } catch {
                            // The directory is unreadable, move to next one
                            NSLog("Can not list content of directory: \(mainCommand)")
                        }
                    }
                }
            } else {
                // We have already entered a command:
                let futureCommand = aliasedCommand(mainCommand)
                let commandOperatesOn = operatesOn(futureCommand)
                let optionList = getoptString(futureCommand)
                let lastElement = commandParts.last
                var directoryForListing = lastElement
                if (futureCommand == "z") {
                    // Autocomplete by matching directories using regexps
                    // so "z a/b[tab]" will autocomplete to "cd auto/blocking"
                    // or create a list of all previously used directories that match a/b
                    var keys: [String]
                    NSLog("regexp, before: \(directoryForListing)")
                    if let directoryForListing = directoryForListing?.replacingOccurrences(of: ".", with: "\\.").replacingOccurrences(of: "/", with: ".*/.*") {
                        NSLog("regexp, after: \(directoryForListing)")
                        do {
                            let regex = try NSRegularExpression(pattern: directoryForListing, options: [])
                            // select keys from dictionary that match argument. Using partial match.
                            let result = directoriesUsed.filter( { regex.matches(in: $0.key, range: NSRange($0.key.startIndex..<$0.key.endIndex, in: $0.key)).count > 0 } )
                            if (result.count == 0) {
                                // No matches in history. Search local directory, same regexp.
                                let filePaths = try FileManager().contentsOfDirectory(atPath: FileManager().currentDirectoryPath)
                                var result = filePaths.filter( { regex.matches(in: $0, range: NSRange($0.startIndex..<$0.endIndex, in: $0)).count > 0 } )
                                if (result.count > 1) {
                                    let localDirCompact = String(cString: ios_getBookmarkedVersion(FileManager().currentDirectoryPath.utf8CString)) + "/"
                                    result = result.sorted(by: { current, next in rankDirectory(dir: current, base: localDirCompact) > rankDirectory(dir: next, base: localDirCompact)})
                                }
                            }
                            keys = result.keys.sorted()
                            keys = keys.sorted(by: { current, next in rankDirectory(dir: current, base: nil) > rankDirectory(dir: next, base: nil)})
                            for key in keys {
                                autocompleteSuggestions.append(key.replacingOccurrences(of: " ", with: "\\ "))
                            }
                            return
                        } catch {
                            NSLog("Error getting Z files from directory: \(directoryForListing): \(error.localizedDescription)")
                        }
                    }
                } else if (lastElement?.first == "-") {
                    // options, like "-l"
                    if (optionList != nil) {
                        for i in 0..<optionList!.count {
                            var option = String(optionList![optionList!.index(optionList!.startIndex, offsetBy: i)])
                            if (option != ":") {
                                if (i < optionList!.count - 1) {
                                    // if an option is followed by ":", then it expects an argument, so we add a space:
                                    let nextChar = optionList![optionList!.index(optionList!.startIndex, offsetBy: i + 1)]
                                    if (nextChar == ":") {
                                        option = option + " "
                                    }
                                }
                                if (!lastElement!.contains(option)) && (!command.contains("-" + String(option))) {
                                    autocompleteOptions = true
                                    autocompleteSuggestions.append(String(option))
                                }
                            }
                        }
                    }
                } else if (lastElement?.first == "$") {
                    // environment variable
                    if (lastElement!.contains("/")) {
                        let directoryComponents = lastElement!.split(separator: "/", maxSplits: 1)
                        var environmentVariable = String(directoryComponents[0])
                        environmentVariable.removeFirst()
                        if directoryComponents.count == 1 {
                            if environmentVariable.hasSuffix("/") {
                                environmentVariable.removeLast()
                            }
                            directoryForListing = String(cString: ios_getenv(environmentVariable)) + "/"
                        } else {
                            directoryForListing = String(cString: ios_getenv(environmentVariable)) + "/" + String(directoryComponents[1])
                        }
                    } else {
                        let environmentVariables = environmentAsArray()
                        for envVar in environmentVariables! {
                            if let envVarString = envVar as? String {
                                let variableName = "$" + envVarString
                                if variableName.hasPrefix(lastElement!) {
                                    let envVarParts = envVarString.split(separator: "=", maxSplits: 1)
                                    var shortenedSugg = String(envVarParts[0])
                                    var pointsToDirectory = false
                                    if (envVarParts.count > 0) {
                                        if URL(fileURLWithPath: String(envVarParts[1])).isDirectory {
                                            pointsToDirectory = true
                                        }
                                    }
                                    if (commandOperatesOn == "directory") && !pointsToDirectory {
                                        continue
                                    }
                                    if ((commandOperatesOn == "file") || (commandOperatesOn == "directory")) &&
                                        (envVarParts.count > 0) && pointsToDirectory {
                                        shortenedSugg += "/"
                                    }
                                    shortenedSugg.removeFirst(lastElement!.count - 1)
                                    if (!autocompleteSuggestions.contains(shortenedSugg)) {
                                        autocompleteSuggestions.append(shortenedSugg)
                                    }
                                }
                            }
                        }
                    }
                } else if (lastElement?.first == "~") {
                    let storedNamesDictionary = UserDefaults.standard.dictionary(forKey: "bookmarkNames") ?? [:]
                    if (lastElement!.contains("/")) {
                        let directoryComponents = lastElement!.split(separator: "/", maxSplits: 1)
                        var bookmarkName = String(directoryComponents[0])
                        bookmarkName.removeFirst()
                        if directoryComponents.count == 1 {
                            if (bookmarkName.hasSuffix("/")) {
                                bookmarkName.removeLast()
                            }
                            if let path = storedNamesDictionary[bookmarkName] as? String {
                                directoryForListing = path + "/"
                            } else {
                                NSLog("Unable to extract path for \(bookmarkName)")
                            }
                        } else {
                            let urlPath = storedNamesDictionary[bookmarkName]
                            let path = (urlPath as! String)
                            directoryForListing = path + "/" + String(directoryComponents[1])
                        }
                    } else {
                        var sortedKeys = storedNamesDictionary.keys.sorted() // alphabetical order
                        if (commandOperatesOn == "directory") {
                            // sort directories in order of use:
                            sortedKeys = sortedKeys.sorted(by: { current, next in rankDirectory(dir:"~" + current, base: nil) > rankDirectory(dir:"~" + next, base: nil)})
                        }
                        for key in sortedKeys {
                            var pointsToDirectory = false
                            if let path = storedNamesDictionary[key] as? String {
                                if (URL(fileURLWithPath: path).isDirectory) {
                                    pointsToDirectory = true
                                }
                            }
                            if (commandOperatesOn == "directory") && !pointsToDirectory {
                                continue
                            }
                            var bookmarkName = "~" + key
                            if bookmarkName.hasPrefix(lastElement!) {
                                if ((commandOperatesOn == "file") || (commandOperatesOn == "directory")) && pointsToDirectory {
                                    bookmarkName += "/"
                                }
                                bookmarkName.removeFirst(lastElement!.count)
                                bookmarkName = bookmarkName.replacingOccurrences(of: " ", with: "\\ ")
                                if (!autocompleteSuggestions.contains(bookmarkName)) {
                                    autocompleteSuggestions.append(bookmarkName)
                                }
                            }
                        }
                    }
                }
                if (!autocompleteOptions) {
                    // add the content of the directory in directoryForListing
                    var prefix = ""
                    if let directoryForListing = directoryForListing {
                        var directory = directoryForListing
                        if (directoryForListing == "") {
                            directory = "."
                        }
                        var matchingPath = URL(fileURLWithPath: directoryForListing).lastPathComponent
                        if URL(fileURLWithPath: directoryForListing).isDirectory {
                            matchingPath = ""
                            if !directory.hasSuffix("/") && (directoryForListing != "") {
                                prefix = "/"
                            }
                        } else {
                            directory.removeLast(matchingPath.count)
                            if (directory == "") {
                                directory = "."
                            }
                        }
                        do {
                            var filePaths = try FileManager().contentsOfDirectory(atPath: directory)
                            filePaths.sort() // alphabetical order
                            if (commandOperatesOn == "directory") {
                                // sort directories in order of use:
                                var directoryForSorting = directory
                                if (directoryForSorting == ".") {
                                    if (directoryForSorting == ".") {
                                        directoryForSorting = FileManager().currentDirectoryPath
                                    } else if (directoryForSorting.hasPrefix("./")) {
                                        directoryForSorting = directoryForSorting.replacingOccurrences(of: "./", with: FileManager().currentDirectoryPath + "/")
                                    } else {
                                        directoryForSorting = FileManager().currentDirectoryPath + "/" + directoryForSorting
                                    }
                                }
                                let localDirCompact = String(cString: ios_getBookmarkedVersion(directoryForSorting.utf8CString))
                                filePaths = filePaths.sorted(by: { current, next in rankDirectory(dir:current, base: localDirCompact) > rankDirectory(dir:next, base: localDirCompact)})
                                // NSLog("after sorting: \(filePaths)")
                            }
                            // Add all non hidden-files first, then all hidden files:
                            for filePath in filePaths {
                                let fullPath = directory + "/" + filePath
                                // NSLog("path = \(fullPath) , isDirectory: \(URL(fileURLWithPath: fullPath).isDirectory)")
                                let isDirectory = URL(fileURLWithPath: fullPath).isDirectory
                                if (commandOperatesOn == "directory") && !isDirectory {
                                    continue
                                }
                                var filePath = fullPath
                                if (isDirectory) {
                                    filePath += "/"
                                }
                                filePath.removeFirst(directory.count + 1)
                                if filePath.hasPrefix(".") {
                                    continue
                                }
                                // NSLog("Checking \(filePath) against \"\(matchingPath)\": \(filePath.hasPrefix(matchingPath))")
                                if (matchingPath == "") {
                                    filePath = prefix + filePath
                                    filePath = filePath.replacingOccurrences(of: " ", with: "\\ ")
                                    if (!autocompleteSuggestions.contains(filePath)) {
                                        autocompleteSuggestions.append(filePath)
                                    }
                                } else if filePath.hasPrefix(matchingPath) {
                                    var shortenedSugg = filePath
                                    shortenedSugg.removeFirst(matchingPath.count)
                                    shortenedSugg = shortenedSugg.replacingOccurrences(of: " ", with: "\\ ")
                                    // NSLog("Adding \"\(shortenedSugg)\"")
                                    if (!autocompleteSuggestions.contains(shortenedSugg)) {
                                        autocompleteSuggestions.append(shortenedSugg)
                                    }
                                }
                            }
                            for filePath in filePaths {
                                let fullPath = directory + "/" + filePath
                                // NSLog("path = \(fullPath) , isDirectory: \(URL(fileURLWithPath: fullPath).isDirectory)")
                                let isDirectory = URL(fileURLWithPath: fullPath).isDirectory
                                if (commandOperatesOn == "directory") && !isDirectory {
                                    continue
                                }
                                var filePath = fullPath
                                if (isDirectory) {
                                    filePath += "/"
                                }
                                filePath.removeFirst(directory.count + 1)
                                if !filePath.hasPrefix(".") {
                                    continue
                                }
                                if (matchingPath == "") {
                                    filePath = prefix + filePath
                                    filePath = filePath.replacingOccurrences(of: " ", with: "\\ ")
                                    if (!autocompleteSuggestions.contains(filePath)) {
                                        autocompleteSuggestions.append(filePath)
                                    }
                                } else if filePath.hasPrefix(matchingPath) {
                                    var shortenedSugg = filePath
                                    shortenedSugg.removeFirst(matchingPath.count)
                                    shortenedSugg = shortenedSugg.replacingOccurrences(of: " ", with: "\\ ")
                                    if (!autocompleteSuggestions.contains(shortenedSugg)) {
                                        autocompleteSuggestions.append(shortenedSugg)
                                    }
                                }
                            }
                        }
                        catch {
                            NSLog("unable to list files in \(directory): \(error)")
                        }
                    }
                    
                }
            }
        }
    }
    
    // prints a string for autocomplete and move the rest of the command around, even if it is over multiple lines.
    // keep the command as it is until autocomplete has been accepted.
    func printAutocompleteString(suggestion: String) {
        // clear entire buffer, then reprint
        terminalView?.feed(text: escape + "[0J"); // delete display after cursor
        terminalView?.clearToEndOfLine()
        if (terminalView!.tintColor.getBrightness() > terminalView!.backgroundColor!.getBrightness()) {
            // We are in dark mode. Use yellow font for higher contrast
            terminalView?.feed(text: escape + "[33m")  // yellow
        } else {
            // light mode
            terminalView?.feed(text: escape + "[32m")  // yellow
            
        }
        terminalView?.feed(text: suggestion)
        terminalView?.feed(text: escape + "[39m")  // back to normal foreground color
    }
    
    func updateAutocomplete(text: String) {
        // remove all suggestions that don't fit the new string
        let currentSuggestion = autocompleteSuggestions[autocompletePosition]
        if (!autocompleteOptions) {
            autocompleteSuggestions.removeAll(where: { !$0.hasPrefix(text) })
        } else {
            // - remove suggestions that are not options and don't match
            // - keep suggestions that are not options and match (but shorten them)
            // - if there is a suggestion that is an option, and matches, and expects and argument, remove all other options but keep history
            // - (options will be approximated as "suggestions that are one letter or one letter + space)
            // if there are suggestions from history that fit the new case, keep them and keep autocomplete
            var optionExpectsArgument = false
            for s in autocompleteSuggestions {
                if s == text + " " {
                    optionExpectsArgument = true
                    break
                }
            }
            var optionMatch = text
            if (optionExpectsArgument) {
                optionMatch += " "
            }
            autocompleteSuggestions.removeAll(where: { $0 == optionMatch })
            if (optionExpectsArgument) {
                autocompleteSuggestions.removeAll(where: { !$0.hasPrefix(optionMatch) })
                commandBeforeCursor += " "
                terminalView?.feed(text: " ")
                autocompleteOptions = false
                if (autocompleteSuggestions.count < 1) {
                    autocompleteRunning = false
                } else {
                    autocompletePosition = 0
                    for i in 0..<autocompleteSuggestions.count {
                        var shortenedSugg = autocompleteSuggestions[i]
                        if (shortenedSugg == currentSuggestion) {
                            autocompletePosition = i
                        }
                        shortenedSugg.removeFirst(optionMatch.count)
                        autocompleteSuggestions[i] = shortenedSugg
                    }
                }
                return
            } else {
                autocompleteSuggestions.removeAll(where: { !$0.hasPrefix(optionMatch) && (
                    ($0.count > 1) &&
                    !(($0.count == 2) && ($0.hasSuffix(" ")))
                )})
            }
        }
        switch (autocompleteSuggestions.count) {
        case 0:
            stopAutocomplete()
        case 1:
            // erase everything
            terminalView?.feed(text: escape + "[0J"); // delete display after cursor
            terminalView?.clearToEndOfLine()
            var suggestion = autocompleteSuggestions[0]
            suggestion.removeFirst(text.count)
            commandBeforeCursor += suggestion
            terminalView?.feed(text: suggestion)
            terminalView?.saveCursorPosition()
            terminalView?.feed(text: commandAfterCursor) // prints the rest of the line
            terminalView?.restoreCursorPosition()
            autocompleteRunning = false
        default:
            autocompletePosition = min (autocompletePosition, autocompleteSuggestions.count - 1)
            for i in 0..<autocompleteSuggestions.count {
                var shortenedSugg = autocompleteSuggestions[i]
                if (shortenedSugg == currentSuggestion) {
                    autocompletePosition = i
                }
                // Shorten all suggestions that are not an option
                if !autocompleteOptions || !((shortenedSugg.count == 1) || ((shortenedSugg.count == 2) && shortenedSugg.hasSuffix(" "))) {
                    shortenedSugg.removeFirst(text.count)
                    autocompleteSuggestions[i] = shortenedSugg
                }
            }
            let prefix = longestCommonPrefix(autocompleteSuggestions)
            for i in 0..<autocompleteSuggestions.count {
                var shortenedSugg = autocompleteSuggestions[i]
                shortenedSugg.removeFirst(prefix.count)
                autocompleteSuggestions[i] = shortenedSugg
            }
            commandBeforeCursor += prefix
            terminalView?.feed(text: prefix) // prints the rest of the line
            terminalView?.saveCursorPosition()
            printAutocompleteString(suggestion: autocompleteSuggestions[autocompletePosition])
            terminalView?.feed(text: commandAfterCursor) // prints the rest of the line
            terminalView?.restoreCursorPosition()
            autocompleteRunning = true
        }
    }
    
    func stopAutocomplete() {
        autocompleteRunning = false
        autocompleteSuggestions = []
        autocompletePosition = 0
        terminalView?.feed(text: escape + "[0J"); // delete display after cursor
        terminalView?.clearToEndOfLine()
        terminalView?.saveCursorPosition()
        terminalView?.feed(text: commandAfterCursor) // prints the rest of the line
        terminalView?.restoreCursorPosition()
    }
    
    func findNextWord(string: String) -> String {
        let regex = try? NSRegularExpression(pattern: "(\\b)", options: [])
        let results = regex?.matches(in: string, options: [], range: NSRange(string.startIndex..., in: string))
        var returnValue = ""
        var offset = 0
        if let matches = results {
            for match in matches {
                let range = match.range
                let subString = string[string.index(string.startIndex, offsetBy:offset)..<string.index(string.startIndex, offsetBy: range.lowerBound)]
                returnValue += subString
                if (subString != " ") && subString != "/" && subString != "" {
                    return returnValue
                }
                offset = range.upperBound
            }
        }
        // If there's no word boundary, return the entire string:
        return string
    }
    
    private func title(_ button: UIBarButtonItem) -> String? {
        if let possibleTitles = button.possibleTitles {
            for attemptedTitle in possibleTitles {
                if (attemptedTitle.count > 0) {
                    return attemptedTitle
                }
            }
        }
        return button.title
    }
    
    // TerminalViewDelegate stubs:
    func sizeChanged(source: SwiftTerm.TerminalView, newCols: Int, newRows: Int) {
        if (newRows != height) || (newCols != width) {
            ios_setWindowSize(Int32(newCols), Int32(newRows), self.persistentIdentifier?.toCString())
        }
        if (newRows != height) {
            height = newRows
            setenv("LINES", "\(height)".toCString(), 1)
        }
        if (newCols != width) {
            width = newCols
            setenv("COLUMNS", "\(width)".toCString(), 1)
        }
        NSLog("Resized window: \(newCols) x \(newRows)")
    }
    
    // None of these are called.
    func setTerminalTitle(source: SwiftTerm.TerminalView, title: String) {
        // Nope
    }
    
    func hostCurrentDirectoryUpdate(source: SwiftTerm.TerminalView, directory: String?) {
        NSLog("hostCurrentDirectoryUpdate: \(directory)")
    }
    
    func send(source: SwiftTerm.TerminalView, data: ArraySlice<UInt8>) {
        // This is where I treat the incoming keypress
        if (currentCommand != "") && (commandBeforeCursor == "") && (commandAfterCursor == "") {
            // Sets the position of the end of the prompt for commands inside commands:
            terminalView!.setPromptEnd()
        }
        if var string = String (bytes: data, encoding: .utf8) {
            // print("string: \(string)")
            if (controlOn) {
                // a) switch control off
                controlOn = false
                if #available(iOS 15.0, *) {
                    if (!useSystemToolbar) {
                        for button in editorToolbar.items! {
                            if title(button) == "control" {
                                button.isSelected = controlOn
                                break
                            }
                        }
                    } else {
                        var foundControl = false
                        if let leftButtonGroups = terminalView?.inputAssistantItem.leadingBarButtonGroups {
                            for leftButtonGroup in leftButtonGroups {
                                for button in leftButtonGroup.barButtonItems {
                                    if title(button) == "control" {
                                        foundControl = true
                                        button.isSelected = controlOn
                                        break
                                    }
                                }
                            }
                        }
                        if (!foundControl) {
                            if let rightButtonGroups = terminalView?.inputAssistantItem.trailingBarButtonGroups {
                                for rightButtonGroup in rightButtonGroups {
                                    for button in rightButtonGroup.barButtonItems {
                                        if title(button) == "control" {
                                            button.isSelected = controlOn
                                            break
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                // b) extract control code:
                string = string.uppercased()
                switch string {
                    // transform control-arrows into alt-arrows:
                case escape + "OA": // up arrow (application mode)
                    fallthrough
                case escape + "[A": // up arrow
                    string = escape + "[1;3A";  // Alt-Up arrow
                case escape + "OB": // down arrow (application mode)
                    fallthrough
                case escape + "[B": // down arrow
                    string = escape + "[1;3B";  // Alt-Down arrow
                case escape + "OC": // right arrow (application mode)
                    fallthrough
                case escape + "[C": // right arrow
                    string = escape + "[1;3C";  // Alt-right arrow
                case escape + "OD": // left arrow (application mode)
                    fallthrough
                case escape + "[D": // left arrow
                    string = escape + "[1;3D";  // Alt-left arrow
                default:
                    // create a control-something character
                    if let controlChar = string.first {
                        if let asciiCode = controlChar.asciiValue {
                            if (asciiCode == 0x7f) { // control-delete (on screen keyboard) is mapped to alt-delete
                                string = escape + "\u{007F}"
                            } else if (asciiCode > 64) {
                                string = String(UnicodeScalar(asciiCode - 64))
                            }
                        }
                    }
                }
            }
            if (currentCommand != "") {
                // If there is an interactive command running, we send the data to its stdin thread
                // active pager (interactive command): gets all the input sent through TTY:
                if (ios_activePager() != 0) {
                    if (tty_file_input != nil) {
                        let savedSession = ios_getContext()
                        ios_switchSession(self.persistentIdentifier?.toCString())
                        ios_setContext(UnsafeMutableRawPointer(mutating: self.persistentIdentifier?.toCString()))
                        ios_setStreams(self.stdin_file, self.stdout_file, self.stdout_file)
                        if let data = string.data(using: .utf8) {
                            tty_file_input?.write(data)
                        }
                        // We can get a session context that is not a valid UUID (InExtension, shSession...)
                        // In that case, don't switch back to it:
                        if let stringPointer = UnsafeMutablePointer<CChar>(OpaquePointer(savedSession)) {
                            let savedSessionIdentifier = String(cString: stringPointer)
                            if let uuid = UUID(uuidString: savedSessionIdentifier) {
                                ios_switchSession(savedSession)
                                ios_setContext(savedSession)
                            }
                        }
                        NSLog("after pager input: \(terminalView!.getTerminal().getCursorLocation())")
                    }
                    return
                }
                // from here on, we can assume ios_activePager() == 0
                // If there is an interactive webAssembly command running:
                if (interactiveCommandRunning || terminalView!.getTerminal().isCurrentBufferAlternate)
                    && (javascriptRunning && (thread_stdin_copy != nil)) {
                    // Q: how many commands are using interactive input, besides nnn?
                    webView?.evaluateJavaScript("inputString += '\(string.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "'", with: "\\'").replacingOccurrences(of: "\n", with: "\\n").replacingOccurrences(of: "\r", with: "\\n"))'; commandIsRunning;") { (result, error) in
                        // if let error = error { print(error) }
                        if let result = result as? Bool {
                            if (!result) {
                                self.endWebAssemblyCommand(error: 0, message: "")
                            }
                        }
                    }
                    return
                }
                if (!javascriptRunning && executeWebAssemblyCommandsRunning) {
                    // There seems to be cases where the webassembly command did not terminate properly.
                    // We catch it here:
                    webView?.evaluateJavaScript("commandIsRunning;") { (result, error) in
                        // if let error = error { print(error) }
                        if let result = result as? Bool {
                            if (!result) {
                                self.endWebAssemblyCommand(error: 0, message: "")
                            }
                        }
                    }
                }
                // Special case: help() and license() in ipython are not interactive.
                var helpRunningInIpython = false
                if (currentCommand.hasPrefix("ipython") || currentCommand.hasPrefix("isympy")) {
                    if let lastLine = terminalView?.getLastPrompt() {
                        if (lastLine.hasSuffix("help> ") ||
                            lastLine.hasSuffix("Hit Return for more, or q (and Return) to quit: ") ||
                            lastLine.hasSuffix("Do you really want to exit ([y]/n)? ")) {
                            helpRunningInIpython = true
                        }
                    }
                }
                // interactive command: send the data directly
                if (interactiveCommandRunning || terminalView!.getTerminal().isCurrentBufferAlternate) && !helpRunningInIpython {
                    ios_switchSession(self.persistentIdentifier?.toCString())
                    ios_setContext(UnsafeMutableRawPointer(mutating: self.persistentIdentifier?.toCString()));
                    ios_setStreams(self.stdin_file, self.stdout_file, self.stdout_file)
                    // Interactive commands: just send the input to them. Allows Vim to map control-D to down half a page.
                    guard let data = string.data(using: .utf8) else { return }
                    guard stdin_file_input != nil else { return }
                    // TODO: don't send data if pipe already closed (^D followed by another key)
                    // (store a variable that says the pipe has been closed)
                    // NSLog("Writing (interactive) \(command) to stdin")
                    stdin_file_input?.write(data)
                    lastKeyboardInput += string
                    return
                }
            }
            // terminal sending button event (if not handled by the command):
            var cursorTracking = false
            var cursorTrackingRow = 0
            var cursorTrackingColumn = 0
            if (string.hasPrefix(escape + "[M")) {
                var tracking = string
                tracking.removeFirst((escape + "[M").count)
                cursorTracking = true
                cursorTrackingRow = Int(tracking.last?.asciiValue ?? 32) - 32
                cursorTrackingColumn = Int(tracking[tracking.index(tracking.startIndex, offsetBy: 1)].asciiValue ?? 32) - 32
                NSLog("tracking: \(cursorTrackingRow) \(cursorTrackingColumn)")
            }
            // TODO: don't send data if pipe already closed (^D followed by another key)
            // (store a variable that says the pipe has been closed)
            // NSLog("Writing (not interactive) \(command) to stdin")
            // stdin_file_input?.write(data)
            // insert mode does not work, so we keep our own version of the command line.
            if (cursorTracking) {
                if (autocompleteRunning) {
                    stopAutocomplete()
                }
                if let distance = terminalView?.setCursorPosition(x: cursorTrackingColumn - 1, y: cursorTrackingRow - 1) {
                    let command = commandBeforeCursor + commandAfterCursor
                    if (distance <= 0) || command.count == 0 {
                        // beginning of line
                        commandBeforeCursor = ""
                        commandAfterCursor = command
                        terminalView?.moveToBeginningOfLine()
                    } else {
                        NSLog("tracking, command: \(command) distance: \(distance)")
                        var length = 0
                        commandBeforeCursor = ""
                        for c in command {
                            var characterWidth = NSAttributedString(string: String(c), attributes: [.font: terminalView?.font]).size().width
                            if (characterWidth > 1.4 * basicCharWidth) {
                                length += 2
                                // "large" characters: takes two columns
                            } else {
                                length += 1
                            }
                            NSLog("character: \(c) length: \(length) distance: \(distance)")
                            commandBeforeCursor += String(c)
                            if (length >= distance) {
                                break
                            }
                        }
                        if (command.count > commandBeforeCursor.count) {
                            commandAfterCursor = command
                            commandAfterCursor.removeFirst(commandBeforeCursor.count)
                        }
                        NSLog("\(commandBeforeCursor) -- \(commandAfterCursor)")
                    }
                }
                return
            }
            // NSLog("received string: \"\(string)\"")
            // remove the copy-paste-select menu if it is visible:
            if UIMenuController.shared.isMenuVisible {
                UIMenuController.shared.hideMenu()
            }
            switch (string) {
            case endOfTransmission: // also control-D: delete character after cursor
                // Stop standard input for the command:
                if (currentCommand != "") {
                    guard stdin_file_input != nil else {
                        // no command running, maybe it ended without us knowing:
                        printPrompt()
                        return
                    }
                    if (javascriptRunning) {
                        // send the current input to WebAssembly, then terminate the command:
                        // Anything after the cursor is ignored
                        webView?.evaluateJavaScript("inputString += '\(commandBeforeCursor + string)'; commandIsRunning;") { (result, error) in
                            // if let error = error { print(error) }
                            if let result = result as? Bool {
                                if (!result) {
                                    self.endWebAssemblyCommand(error: 0, message: "")
                                }
                            }
                        }
                        commandBeforeCursor = ""
                        commandAfterCursor = ""
                        return
                    } else {
                        do {
                            try stdin_file_input?.close()
                        }
                        catch {
                            // NSLog("Could not close stdin input.")
                        }
                        stdin_file_input = nil
                        commandBeforeCursor = ""
                        commandAfterCursor = ""
                        printPrompt()
                        return
                    }
                } else {
                    fallthrough // case where control D acts as delete
                }
            case escape + "[3~":   // Delete key
                if (autocompleteRunning) {
                    stopAutocomplete()
                }
                if (commandAfterCursor.count > 0) {
                    if let firstChar = commandAfterCursor.first {
                        commandAfterCursor.removeFirst()
                        terminalView?.clearToEndOfLine()
                        terminalView?.saveCursorPosition()
                        if (commandAfterCursor.count > 0) {
                            terminalView?.feed(text: commandAfterCursor)
                        } else {
                            terminalView?.feed(text: " ")
                        }
                        terminalView?.restoreCursorPosition()
                    }
                }
            case interrupt:
                if autocompleteRunning {
                    stopAutocomplete()
                } else {
                    if (currentCommand != "") && (!javascriptRunning) {
                        // Calling ios_kill while executing webAssembly or JavaScript is a bad idea.
                        // Do we have a way to interrupt JS execution in WkWebView?
                        ios_kill() // TODO: add printPrompt() here if no command running
                    }
                    if (currentCommand == "") {
                        // disable auto-complete menu if running
                        // don't execute command, move to next line, print prompt
                        commandBeforeCursor = ""
                        commandAfterCursor = ""
                        terminalView?.feed(text: "\r\n")
                        printPrompt()
                    }
                }
            case "\u{0008}": // control H - delete
                fallthrough
            case deleteBackward:
                // send arrow-left, then delete-char, but only if there is something to delete:
                if (terminalView!.selectionActive) {
                    terminalView?.deleteSelection()
                } else if autocompleteRunning {
                    stopAutocomplete()
                } else {
                    if (commandBeforeCursor.count > 0) {
                        terminalView?.moveUpIfNeeded()
                        if let lastChar = commandBeforeCursor.last {
                            // NSLog("deleting: \"\(lastChar)\"")
                            commandBeforeCursor.removeLast()
                            let characterWidth = NSAttributedString(string: String(lastChar), attributes: [.font: terminalView?.font]).size().width
                            if (characterWidth > 1.4 * basicCharWidth) {
                                // "large" characters: delete two columns
                                terminalView?.feed(text: escape + "[D")
                                terminalView?.feed(text: escape + "[P")
                            }
                            terminalView?.feed(text: escape + "[D")
                            terminalView?.feed(text: escape + "[P")
                        }
                    }
                    if (commandAfterCursor.count > 0) {
                        // redraw the end of the line
                        terminalView?.saveCursorPosition()
                        terminalView?.clearToEndOfLine()
                        terminalView?.feed(text: commandAfterCursor)
                        terminalView?.restoreCursorPosition()
                    }
                }
            case tabulation: // autocomplete
                // NSLog("received tab. Autocomplete running: \(autocompleteRunning)")
                if (autocompleteRunning) {
                    if (autocompleteOptions) {
                        // insert the option, keep running autocomplete:
                        let string = autocompleteSuggestions[autocompletePosition]
                        commandBeforeCursor += string
                        terminalView?.feed(text: string) // prints the string
                        updateAutocomplete(text: string)
                    } else {
                        commandBeforeCursor += autocompleteSuggestions[autocompletePosition]
                        terminalView?.feed(text: autocompleteSuggestions[autocompletePosition])
                        if (autocompleteSuggestions[autocompletePosition].hasSuffix("/")) {
                            autocompleteRunning = false
                            #if DEACTIVATED
                            // single suggestion, is a directory: fill again but don't force
                            fillAutocompleteSuggestions(command: commandBeforeCursor)
                            // NSLog("suggestions: \(autocompleteSuggestions)")
                            if (autocompleteSuggestions.count > 0) {
                                terminalView?.saveCursorPosition()
                                printAutocompleteString(suggestion: autocompleteSuggestions[autocompletePosition])
                                terminalView?.feed(text: commandAfterCursor) // prints the rest of the line
                                terminalView?.restoreCursorPosition()
                                autocompleteRunning = true
                            } else {
                                autocompleteRunning = false
                            }
                            #endif
                        } else {
                            autocompleteSuggestions = []
                            autocompletePosition = 0
                            autocompleteRunning = false
                            var currentCommandVoiceOver = commandBeforeCursor
                            if (commandAfterCursor.count > 0) {
                                currentCommandVoiceOver += " insertion point "
                                currentCommandVoiceOver += commandAfterCursor
                            }
                            UIAccessibility.post(notification: .announcement, argument: currentCommandVoiceOver)
                        }
                    }
                } else {
                    // standard version, first time we press tab
                    fillAutocompleteSuggestions(command: commandBeforeCursor)
                    // Check if all suggestions start with the same substring:
                    let commonPrefix = longestCommonPrefix(autocompleteSuggestions)
                    for i in 0..<autocompleteSuggestions.count {
                        var shortenedSugg = autocompleteSuggestions[i]
                        shortenedSugg.removeFirst(commonPrefix.count)
                        autocompleteSuggestions[i] = shortenedSugg
                    }
                    NSLog("suggestions: \(autocompleteSuggestions)")
                    if (commandBeforeCursor.hasPrefix("z ")) {
                        commandBeforeCursor = "cd "
                        terminalView?.moveToBeginningOfLine()
                        terminalView?.saveCursorPosition()
                        terminalView?.clearToEndOfLine()
                        terminalView?.feed(text: commandBeforeCursor)
                    }
                    commandBeforeCursor += commonPrefix
                    terminalView?.feed(text: commonPrefix)
                    if (autocompleteSuggestions.count > 1) {
                        terminalView?.saveCursorPosition()
                        printAutocompleteString(suggestion: autocompleteSuggestions[autocompletePosition])
                        terminalView?.feed(text: commandAfterCursor) // prints the rest of the line
                        terminalView?.restoreCursorPosition()
                        autocompleteRunning = true
                    } else if (commonPrefix.hasSuffix("/")) {
                        autocompleteRunning = false
                        #if DEACTIVATED
                        // Single suggestion, is a directory: fill again but don't force acceptance.
                        fillAutocompleteSuggestions(command: commandBeforeCursor)
                        if (autocompleteSuggestions.count > 0) {
                            terminalView?.saveCursorPosition()
                            printAutocompleteString(suggestion: autocompleteSuggestions[autocompletePosition])
                            terminalView?.feed(text: commandAfterCursor) // prints the rest of the line
                            terminalView?.restoreCursorPosition()
                            autocompleteRunning = true
                        } else {
                            autocompleteRunning = false
                        }
                        #endif
                    }
                    if (!autocompleteRunning) {
                        var currentCommandVoiceOver = commandBeforeCursor
                        if (commandAfterCursor.count > 0) {
                            currentCommandVoiceOver += " insertion point "
                            currentCommandVoiceOver += commandAfterCursor
                        }
                        UIAccessibility.post(notification: .announcement, argument: currentCommandVoiceOver)
                    }
                }
            case escape + "OA": // up arrow (application mode)
                fallthrough
            case escape + "[A": // up arrow
                if (autocompleteRunning) {
                    autocompletePosition -= 1
                    if (autocompletePosition < 0) {
                        autocompletePosition = autocompleteSuggestions.count - 1
                    }
                    terminalView?.saveCursorPosition()
                    printAutocompleteString(suggestion: autocompleteSuggestions[autocompletePosition])
                    terminalView?.feed(text: commandAfterCursor) // prints the rest of the line
                    terminalView?.restoreCursorPosition()
                } else {
                    if (currentCommand == "") {
                        NSLog("Up arrow, position= \(historyPosition) count= \(history.count)")
                        if (historyPosition > 0) {
                            historyPosition -= 1
                            terminalView?.moveToBeginningOfLine()
                            terminalView?.clearToEndOfLine()
                            terminalView?.feed(text: history[historyPosition])
                            commandBeforeCursor = history[historyPosition]
                            commandAfterCursor = ""
                            delayedVoiceOver(message: commandBeforeCursor)
                        }
                    } else {
                        NSLog("Up arrow, position= \(commandHistoryPosition) count= \(commandHistory.count)")
                        if (commandHistoryPosition > 0) {
                            commandHistoryPosition -= 1
                            terminalView?.moveToBeginningOfLine()
                            terminalView?.clearToEndOfLine()
                            terminalView!.setPromptEnd() // Required? Why?
                            terminalView?.feed(text: commandHistory[commandHistoryPosition])
                            commandBeforeCursor = commandHistory[commandHistoryPosition]
                            commandAfterCursor = ""
                            delayedVoiceOver(message: commandBeforeCursor)
                        }
                    }
                }
            case escape + "OB": // down arrow (application mode)
                fallthrough
            case escape + "[B": // down arrow
                if (autocompleteRunning) {
                    autocompletePosition += 1
                    if (autocompletePosition > autocompleteSuggestions.count - 1) {
                        autocompletePosition = 0
                    }
                    terminalView?.saveCursorPosition()
                    printAutocompleteString(suggestion: autocompleteSuggestions[autocompletePosition])
                    terminalView?.feed(text: commandAfterCursor) // prints the rest of the line
                    terminalView?.restoreCursorPosition()
                } else {
                    if (currentCommand == "") {
                        NSLog("Down arrow, position= \(historyPosition) count= \(history.count)")
                        if (historyPosition < history.count - 1) {
                            historyPosition += 1
                            terminalView?.moveToBeginningOfLine()
                            terminalView?.clearToEndOfLine()
                            if (historyPosition < history.count) {
                                terminalView?.feed(text: history[historyPosition])
                                commandBeforeCursor = history[historyPosition]
                                commandAfterCursor = ""
                                delayedVoiceOver(message: commandBeforeCursor)
                            }
                        } else {
                            historyPosition = history.count
                            terminalView?.moveToBeginningOfLine()
                            terminalView?.clearToEndOfLine()
                            terminalView?.feed(text: " ") // force redraw
                            terminalView?.moveToBeginningOfLine()
                            commandBeforeCursor = ""
                            commandAfterCursor = ""
                            delayedVoiceOver(message: "empty line")
                        }
                    } else {
                        NSLog("Down arrow, position= \(commandHistoryPosition) count= \(commandHistory.count)")
                        if (commandHistoryPosition < commandHistory.count - 1) {
                            commandHistoryPosition += 1
                            terminalView?.moveToBeginningOfLine()
                            terminalView?.clearToEndOfLine()
                            if (commandHistoryPosition < commandHistory.count) {
                                NSLog("sending \(commandHistory[commandHistoryPosition])")
                                terminalView?.feed(text: commandHistory[commandHistoryPosition])
                                commandBeforeCursor = commandHistory[commandHistoryPosition]
                                commandAfterCursor = ""
                                delayedVoiceOver(message: commandBeforeCursor)
                            }
                        } else {
                            commandHistoryPosition = commandHistory.count
                            terminalView?.moveToBeginningOfLine()
                            terminalView?.clearToEndOfLine()
                            terminalView?.feed(text: " ") // force redraw
                            terminalView?.moveToBeginningOfLine()
                            commandBeforeCursor = ""
                            commandAfterCursor = ""
                            delayedVoiceOver(message: " empty line ")
                        }
                    }
                }
            case escape + "OD": // left arrow (application mode)
                fallthrough
            case escape + "[D": // left arrow
                if (terminalView!.selectionActive) {
                    terminalView?.moveToBeginningOfSelection()
                    if autocompleteRunning {
                        stopAutocomplete()
                    }
                } else if autocompleteRunning {
                    stopAutocomplete()
                } else {
                    if (commandBeforeCursor.count > 0) {
                        if let lastChar = commandBeforeCursor.last {
                            commandBeforeCursor.removeLast()
                            commandAfterCursor = String(lastChar) + commandAfterCursor
                            terminalView?.moveUpIfNeeded()
                            let characterWidth = NSAttributedString(string: String(lastChar), attributes: [.font: terminalView?.font]).size().width
                            if (characterWidth > 1.4 * basicCharWidth) {
                                terminalView?.feed(text: escape + "[D")
                            }
                            terminalView?.feed(text: escape + "[D")
                            delayedVoiceOver(message: String(lastChar))
                        }  else {
                            delayedVoiceOver(message: " beginning of line ")
                        }
                    } else {
                        delayedVoiceOver(message: " beginning of line")
                    }
                }
            case escape + "OC": // right arrow (application mode)
                fallthrough
            case escape + "[C": // right arrow
                if (terminalView!.selectionActive) {
                    terminalView?.moveToEndOfSelection()
                    if autocompleteRunning {
                        stopAutocomplete()
                    }
                } else if autocompleteRunning {
                    // autocomplete up to the next word boundary
                    let string = findNextWord(string: autocompleteSuggestions[autocompletePosition])
                    commandBeforeCursor += string
                    terminalView?.feed(text: string) // prints the string
                    updateAutocomplete(text: string)
                    #if DEACTIVATED
                    if (commandBeforeCursor.hasSuffix("/") && (!autocompleteRunning || (autocompleteSuggestions[autocompletePosition].count == 0))) {
                        // We completed a directory. Let's list the content:
                        fillAutocompleteSuggestions(command: commandBeforeCursor)
                        if (autocompleteSuggestions.count > 0) {
                            terminalView?.saveCursorPosition()
                            printAutocompleteString(suggestion: autocompleteSuggestions[autocompletePosition])
                            terminalView?.feed(text: commandAfterCursor) // prints the rest of the line
                            terminalView?.restoreCursorPosition()
                            autocompleteRunning = true
                        } else {
                            autocompleteRunning = false
                        }
                    }
                    #endif
                } else {
                    if (commandAfterCursor.count > 0) {
                        if let firstChar = commandAfterCursor.first {
                            commandAfterCursor.removeFirst()
                            commandBeforeCursor = commandBeforeCursor + String(firstChar)
                            terminalView?.moveDownIfNeeded()
                            let characterWidth = NSAttributedString(string: String(firstChar), attributes: [.font: terminalView?.font]).size().width
                            if (characterWidth > 1.4 * basicCharWidth) {
                                terminalView?.feed(text: escape + "[C")
                            }
                            terminalView?.feed(text: escape + "[C")
                            if (commandAfterCursor.count > 0) {
                                delayedVoiceOver(message: String(commandAfterCursor.first!))
                            } else {
                                delayedVoiceOver(message: " end of line ")
                            }
                        }
                    } else {
                        delayedVoiceOver(message: " end of line ")
                        NSLog("Cannot move right")
                    }
                }
            case escape + "[1;3D":  // Alt-left arrow, move to previous word
                fallthrough
            case escape + "[1;5D":  // Control-left arrow (external keyboard)
                fallthrough
            case escape + "b":      // Alt-left arrow (SwiftTerm version)
                if (autocompleteRunning) {
                    stopAutocomplete()
                }
                while (commandBeforeCursor.count > 0) {
                    if let lastChar = commandBeforeCursor.last {
                        commandBeforeCursor.removeLast()
                        commandAfterCursor = String(lastChar) + commandAfterCursor
                        terminalView?.moveUpIfNeeded()
                        let characterWidth = NSAttributedString(string: String(lastChar), attributes: [.font: terminalView?.font]).size().width
                        if (characterWidth > 1.4 * basicCharWidth) {
                            terminalView?.feed(text: escape + "[D")
                        }
                        terminalView?.feed(text: escape + "[D")
                        if !lastChar.isLetter {
                            break
                        }
                    }
                }
                if (commandAfterCursor.count > 0) {
                    delayedVoiceOver(message: String(commandAfterCursor.first!))
                } else {
                    delayedVoiceOver(message: " beginning of line ")
                }
            case escape + "[1;3C":  // Alt-right arrow, move to next word
                fallthrough
            case escape + "[1;5C":  // Control-right arrow (external keyboard)
                fallthrough
            case escape + "f":      // Alt-right arrow (SwiftTerm version)
                if (autocompleteRunning) {
                    stopAutocomplete()
                }
                while (commandAfterCursor.count > 0) {
                    if let firstChar = commandAfterCursor.first {
                        commandAfterCursor.removeFirst()
                        commandBeforeCursor = commandBeforeCursor + String(firstChar)
                        terminalView?.moveDownIfNeeded()
                        let characterWidth = NSAttributedString(string: String(firstChar), attributes: [.font: terminalView?.font]).size().width
                        if (characterWidth > 1.4 * basicCharWidth) {
                            terminalView?.feed(text: escape + "[C")
                        }
                        terminalView?.feed(text: escape + "[C")
                        if !firstChar.isLetter {
                            break
                        }
                    }
                }
                if (commandAfterCursor.count > 0) {
                    delayedVoiceOver(message: String(commandAfterCursor.first!))
                } else {
                    delayedVoiceOver(message: " end of line ")
                }
            case "\u{0018}": // control X, stop autocomplete
                fallthrough
            case "\u{001A}": // control Z, stop autocomplete
                fallthrough
            case escape:    // escape, stop autocomplete
                if (autocompleteRunning) {
                    stopAutocomplete()
                }
            case "\u{0001}": // control A, move to beginning of line
                if (autocompleteRunning) {
                    stopAutocomplete()
                }
                commandAfterCursor = commandBeforeCursor + commandAfterCursor
                commandBeforeCursor = ""
                terminalView?.moveToBeginningOfLine()
                terminalView?.getTerminal().updateFullScreen()
                terminalView?.updateDisplay()
                UIAccessibility.post(notification: .announcement, argument: "insertion point " + commandAfterCursor)
            case "\u{0005}": // control E, move to end of line
                if (autocompleteRunning) {
                    stopAutocomplete()
                }
                commandBeforeCursor = commandBeforeCursor + commandAfterCursor
                commandAfterCursor = ""
                terminalView?.moveToEndOfLine()
                terminalView?.getTerminal().updateFullScreen()
                terminalView?.updateDisplay()
                UIAccessibility.post(notification: .announcement, argument: commandBeforeCursor + " insertion point")
            case "\u{000B}": // control K: kill until end of line
                if (autocompleteRunning) {
                    stopAutocomplete()
                }
                terminalView?.clearToEndOfLine()
                commandAfterCursor = ""
                terminalView?.getTerminal().updateFullScreen()
                terminalView?.updateDisplay()
                UIAccessibility.post(notification: .announcement, argument: commandBeforeCursor + " insertion point")
            case "\u{0015}": // control U: kill from cursor to beginning of the line
                if (autocompleteRunning) {
                    stopAutocomplete()
                }
                commandBeforeCursor = ""
                terminalView?.moveToBeginningOfLine()
                terminalView?.saveCursorPosition()
                terminalView?.clearToEndOfLine()
                if (commandAfterCursor.count > 0) {
                    terminalView?.feed(text: commandAfterCursor) // prints the rest of the line
                } else {
                    terminalView?.feed(text: " ") // force redraw
                }
                terminalView?.restoreCursorPosition()
                UIAccessibility.post(notification: .announcement, argument: "insertion point " + commandAfterCursor)
            case escape + "\u{0008}": // alt delete on external keyboard
                fallthrough
            case escape + "\u{007F}": // alt delete on keyboard: delete (backward) until the beginning of current word
                NSLog("alt-delete received")
                if (autocompleteRunning) {
                    stopAutocomplete()
                }
                while (commandBeforeCursor.count > 0) {
                    if let lastChar = commandBeforeCursor.last {
                        if !lastChar.isLetter {
                            break
                        }
                        commandBeforeCursor.removeLast()
                        terminalView?.moveUpIfNeeded()
                        let characterWidth = NSAttributedString(string: String(lastChar), attributes: [.font: terminalView?.font]).size().width
                        if (characterWidth > 1.4 * basicCharWidth) {
                            terminalView?.feed(text: escape + "[D")
                            terminalView?.feed(text: escape + "[P")
                        }
                        terminalView?.feed(text: escape + "[D")
                        terminalView?.feed(text: escape + "[P")
                    }
                }
                var currentCommandVoiceOver = commandBeforeCursor
                if (commandAfterCursor.count > 0) {
                    currentCommandVoiceOver += " insertion point "
                    currentCommandVoiceOver += commandAfterCursor
                }
                UIAccessibility.post(notification: .announcement, argument: currentCommandVoiceOver)
            case "\u{0017}": // control W: delete (backward) until the next space
                fallthrough
            case escape + "\u{0017}": // control W: delete (backward) until the next space
                if (autocompleteRunning) {
                    stopAutocomplete()
                }
                // remove all white spaces at the end:
                while (commandBeforeCursor.count > 0) {
                    if let lastChar = commandBeforeCursor.last {
                        if !lastChar.isWhitespace {
                            break
                        }
                        commandBeforeCursor.removeLast()
                        terminalView?.moveUpIfNeeded()
                        terminalView?.feed(text: escape + "[D")
                        terminalView?.feed(text: escape + "[P")
                    } else {
                        break
                    }
                }
                // then remove all non-white space characters until a white space:
                while (commandBeforeCursor.count > 0) {
                    if let lastChar = commandBeforeCursor.last {
                        if lastChar.isWhitespace {
                            break
                        }
                        commandBeforeCursor.removeLast()
                        terminalView?.moveUpIfNeeded()
                        let characterWidth = NSAttributedString(string: String(lastChar), attributes: [.font: terminalView?.font]).size().width
                        if (characterWidth > 1.4 * basicCharWidth) {
                            terminalView?.feed(text: escape + "[D")
                            terminalView?.feed(text: escape + "[P")
                        }
                        terminalView?.feed(text: escape + "[D")
                        terminalView?.feed(text: escape + "[P")
                    } else {
                        break
                    }
                }
                var currentCommandVoiceOver = commandBeforeCursor
                if (commandAfterCursor.count > 0) {
                    currentCommandVoiceOver += " insertion point "
                    currentCommandVoiceOver += commandAfterCursor
                }
                UIAccessibility.post(notification: .announcement, argument: currentCommandVoiceOver)
                terminalView?.currentCommandVoiceOver = currentCommandVoiceOver
            case "\u{000C}":  // control L: clear screen
                clearScreen()
                commandBeforeCursor = ""
                commandAfterCursor = ""
                printPrompt()
            case carriageReturn:
                if (autocompleteRunning) {
                    // validate current suggestion
                    // overwrite suggestion in default color
                    terminalView?.feed(text: autocompleteSuggestions[autocompletePosition])
                    commandBeforeCursor += autocompleteSuggestions[autocompletePosition]
                    autocompleteSuggestions = []
                    autocompletePosition = 0
                    autocompleteRunning = false
                }
                if (currentCommand == "") {
                    let commandLine = (commandBeforeCursor + commandAfterCursor).trimmingCharacters(in: .whitespaces)
                    commandBeforeCursor = ""
                    commandAfterCursor = ""
                    terminalView?.saveCursorPosition() // for VoiceOver
                    executeCommand(command: commandLine)
                    windowPrintedContent += lastUsedPrompt + commandLine + "\n\r"
                    terminalView?.feed(text: "\n\r")
                } else {
                    let commandLine = (commandBeforeCursor + commandAfterCursor).trimmingCharacters(in: .whitespaces)
                    commandBeforeCursor = ""
                    commandAfterCursor = ""
                    terminalView?.saveCursorPosition() // for VoiceOver
                    terminalView?.feed(text: "\n\r")
                    windowPrintedContent += commandLine + "\n\r"
                    // webAssembly commands:
                    stdinString = commandLine + "\n"
                    NSLog("webAssembly: \(stdinString)")
                    if (javascriptRunning && (thread_stdin_copy != nil)) {
                        // non-interactive WebAssembly commands:
                        webView?.evaluateJavaScript("inputString += '\(stdinString.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "'", with: "\\'").replacingOccurrences(of: "\n", with: "\\n").replacingOccurrences(of: "\r", with: "\\n"))'; commandIsRunning;") { (result, error) in
                            // if let error = error { print(error) }
                            if let result = result as? Bool {
                                if (!result) {
                                    self.endWebAssemblyCommand(error: 0, message: "")
                                }
                            }
                        }
                    }
                    guard let data = (commandLine + "\n").data(using: .utf8) else { return }
                    guard stdin_file_input != nil else { return }
                    // store command in local command history, reset if it's different:
                    if (currentCommand != lastCommand) {
                        lastCommand = currentCommand
                        commandHistory = []
                        commandHistoryPosition = 0
                    }
                    if (commandHistory.last != commandLine) && (commandLine != "") {
                        commandHistory.append(commandLine)
                        while (commandHistory.count > 100) {
                            commandHistory.removeFirst()
                        }
                    }
                    commandHistoryPosition = commandHistory.count
                    // TODO: don't send data if pipe already closed (^D followed by another key)
                    // (store a variable that says the pipe has been closed)
                    stdin_file_input?.write(data)
                }
            case " ": // space: end autocomplete
                if (autocompleteRunning) {
                    stopAutocomplete()
                }
                fallthrough
            default:
                // remove the Copy/Paste/etc menu if it is visible
                // Default, send to term
                if (terminalView!.selectionActive) {
                    terminalView?.deleteSelection()
                }
                commandBeforeCursor += string
                terminalView?.feed(text: string) // prints the string
                if autocompleteRunning {
                    updateAutocomplete(text: string)
                    #if DEACTIVATED
                    if (commandBeforeCursor.hasSuffix("/") && (!autocompleteRunning || (autocompleteSuggestions[autocompletePosition].count == 0))) {
                        // We just completed a directory. Let's list the content:
                        fillAutocompleteSuggestions(command: commandBeforeCursor)
                        if (autocompleteSuggestions.count > 0) {
                            terminalView?.saveCursorPosition()
                            printAutocompleteString(suggestion: autocompleteSuggestions[autocompletePosition])
                            terminalView?.feed(text: commandAfterCursor) // prints the rest of the line
                            terminalView?.restoreCursorPosition()
                            autocompleteRunning = true
                        } else {
                            autocompleteRunning = false
                        }
                    }
                    #endif
                } else {
                    if (commandAfterCursor.count > 0) {
                        // redraw the end of the line
                        terminalView?.saveCursorPosition()
                        terminalView?.clearToEndOfLine()
                        terminalView?.feed(text: commandAfterCursor) // prints the rest of the line
                        terminalView?.restoreCursorPosition()
                    }
                }
            }
            // Send the current command to VoiceOver, only if running autocomplete:
            if UIAccessibility.isVoiceOverRunning {
                var currentCommandVoiceOver = ""
                // Only speak the command when autocomplete is running:
                if (autocompleteRunning) && (autocompleteSuggestions[autocompletePosition].count > 0) {
                    if (commandBeforeCursor.count > 0) {
                        currentCommandVoiceOver = commandBeforeCursor
                    }
                    currentCommandVoiceOver += " autocomplete suggestion " + autocompleteSuggestions[autocompletePosition]
                    if (commandAfterCursor.count > 0) {
                        currentCommandVoiceOver += " end suggestion "
                        currentCommandVoiceOver += commandAfterCursor
                    }
                    NSLog("voiceOver: \(currentCommandVoiceOver)")
                    delayedVoiceOver(message: currentCommandVoiceOver)
                } else if (commandBeforeCursor.count > 0) || (commandAfterCursor.count > 0) {
                    currentCommandVoiceOver = commandBeforeCursor + " insertion point " + commandAfterCursor
                }
                terminalView?.currentCommandVoiceOver = currentCommandVoiceOver
            }
        } else {
            NSLog("Failure of conversion: \(data)")
        }
    }
    
    func scrolled(source: SwiftTerm.TerminalView, position: Double) {
        //
    }
    
    func requestOpenLink(source: SwiftTerm.TerminalView, link: String, params: [String : String]) {
        if let fixedup = link.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            if let url = NSURLComponents(string: fixedup) {
                if let nested = url.url {
                    UIApplication.shared.open (nested)
                }
            }
        }
    }
    
    func clipboardCopy(source: SwiftTerm.TerminalView, content: Data) {
        if let str = String (bytes: content, encoding: .utf8) {
            UIPasteboard.general.string = str
        }
    }
    
    func rangeChanged(source: SwiftTerm.TerminalView, startY: Int, endY: Int) {
        //
    }
    
    @objc
    func zoomGestureHandler (_ gestureRecognizer:  UIPinchGestureRecognizer) {
        if gestureRecognizer.state == .began {
            zoomGestureInitialSize = terminalFontSize ?? factoryFontSize
            if (terminalFontSize == nil) {
                terminalFontSize = factoryFontSize
            }
        }
        if gestureRecognizer.state == .began || gestureRecognizer.state == .changed {
            terminalFontSize = zoomGestureInitialSize * Float(1 + (gestureRecognizer.scale - 1) / 5)
            NSLog("scaling gesture: scale= \(gestureRecognizer.scale) fontsize= \(terminalFontSize!)")
            if let terminalFont = UIFont(name: terminalFontName ?? factoryFontName, size: CGFloat(terminalFontSize!)) {
                terminalView?.font = terminalFont
                basicCharWidth = NSAttributedString(string: "m", attributes: [.font: self.terminalView?.font]).size().width
                terminalView?.getTerminal().updateFullScreen()
                terminalView?.updateDisplay()
            }
        }
    }

    @objc
    // handling two-fingers swipe. One-fingers swipe are handled by the system
    // (and select text in Vim, scroll elsewhere)
    func scrollGestureHandler (_ gestureRecognizer:  UIPanGestureRecognizer) {
        if (gestureRecognizer.state == .ended) || (gestureRecognizer.state == .cancelled) {
            return
        }
        guard gestureRecognizer.view != nil else { return }
        let piece = gestureRecognizer.view!
        // Get the changes in the X and Y directions relative to
        // the superview's coordinate space.
        let translation = gestureRecognizer.translation(in: piece.superview)
        let velocity = gestureRecognizer.velocity(in: piece.superview)
        NSLog("scrolling translation detected: \(translation) velocity: \(velocity)")
        if (gestureRecognizer.state == .began) {
            scrollGestureOrigin = .zero
        }
        var scrollDisplacement: CGPoint = translation
        scrollDisplacement.x -= scrollGestureOrigin.x
        scrollDisplacement.y -= scrollGestureOrigin.y
        // --> Number of arrows to send must be proportional to distance.
        var verticalDisplacement = CGFloat(terminalFontSize ?? factoryFontSize)
        let horizontalDisplacement = basicCharWidth
        let vimRunning = currentCommand.hasPrefix("vim ") || currentCommand == "vim"
        let lessRunning = currentCommand.hasPrefix("less ")
        || currentCommand.contains("|less") || currentCommand.contains("| less")
        || currentCommand.hasPrefix("man ") || currentCommand.hasPrefix("perldoc ")
        if (lessRunning) {
            // only vertical displacement, and reversed
            if (scrollDisplacement.y > 0) {
                let steps = floor(scrollDisplacement.y / verticalDisplacement)
                for _ in 0..<Int(steps) {
                    sendArrow(direction: "up")
                }
                scrollGestureOrigin.y += steps * verticalDisplacement
                scrollGestureOrigin.x = translation.x
            } else {
                let steps = floor(-scrollDisplacement.y / verticalDisplacement)
                for _ in 0..<Int(steps) {
                    sendArrow(direction: "down")
                }
                scrollGestureOrigin.y -= steps * verticalDisplacement
                scrollGestureOrigin.x = translation.x
            }
            return
        }
        if (!vimRunning) {
            verticalDisplacement *= 2
        }
        NSLog("total translation detected: \(scrollDisplacement.x/horizontalDisplacement) \(scrollDisplacement.y/verticalDisplacement)")
        if abs(scrollDisplacement.x) > abs(scrollDisplacement.y) {
            // lateral gesture
            if (scrollDisplacement.x > 0) {
                let steps = floor(scrollDisplacement.x / horizontalDisplacement)
                for _ in 0..<Int(steps) {
                    sendArrow(direction: "right")
                }
                scrollGestureOrigin.x += steps * horizontalDisplacement
                scrollGestureOrigin.y = translation.y
            } else {
                let steps = floor(-scrollDisplacement.x / horizontalDisplacement)
                for _ in 0..<Int(steps) {
                    sendArrow(direction: "left")
                }
                scrollGestureOrigin.x -= steps * horizontalDisplacement
                scrollGestureOrigin.y = translation.y            }
        } else {
            // vertical gesture
            if (scrollDisplacement.y > 0) {
                let steps = floor(scrollDisplacement.y / verticalDisplacement)
                for _ in 0..<Int(steps) {
                    sendArrow(direction: "down")
                }
                scrollGestureOrigin.y += steps * verticalDisplacement
                scrollGestureOrigin.x = translation.x
            } else {
                let steps = floor(-scrollDisplacement.y / verticalDisplacement)
                for _ in 0..<Int(steps) {
                    sendArrow(direction: "up")
                }
                scrollGestureOrigin.y -= steps * verticalDisplacement
                scrollGestureOrigin.x = translation.x
            }
        }
    }

    // VoiceOver and arrow buttons: speak the new command line with a slight delay.
    // Also applies to autocomplete suggestions since they can be cause by arrows.
    // We use the same timer as outputToTerminalView
    func delayedVoiceOver(message: String) {
        if (UIAccessibility.isVoiceOverRunning && !terminalView!.getTerminal().isCurrentBufferAlternate) {
            if (self.readContentTimer.isValid) {
                // restart the timer each time we add new content
                self.readContentTimer.invalidate()
            }
            self.readContentTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false, block: {_ in
                self.lastKeyboardInput = ""
                if (message.count > 0) {
                    UIAccessibility.post(notification: .announcement, argument: message)
                }
            })
        }
    }
}
