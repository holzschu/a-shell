//
//  ExecuteCommandHandler.swift
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

class ExecuteCommandIntentHandler: INExtension, ExecuteCommandIntentHandling
{

    let application: UIApplication
    
    init(application: UIApplication) {
        self.application = application
    }
    
    func resolveOpenWindow(for intent: ExecuteCommandIntent, with completion: @escaping (EnumResolutionResult) -> Void) {
        completion(EnumResolutionResult.success(with: intent.openWindow))
    }
    
    func resolveKeepGoing(for intent: ExecuteCommandIntent, with completion: @escaping (INBooleanResolutionResult) -> Void) {
        if let keepGoing = intent.keepGoing {
            completion(INBooleanResolutionResult.success(with: keepGoing as! Bool))
        } else {
            completion(INBooleanResolutionResult.success(with: false)) // Don't continue by default.
        }
    }
    
    let commandQueue = DispatchQueue(label: "executeCommand", qos: .utility)
    let sessionIdentifier = "inExtension"
    let endOfTransmission = "\u{0004}"  // control-D, used to signal end of transmission
    var response = ""
    var outputReceived = false

    // Implement handlers for each intent you wish to handle.
    func resolveCommand(for intent: ExecuteCommandIntent, with completion: @escaping ([INStringResolutionResult]) -> Void) {
        var result: [INStringResolutionResult] = []
        if let commands = intent.command {
            if (commands.count == 0) {
                result.append(INStringResolutionResult.needsValue())
                completion(result)
                return
            }
            for command in commands {
                // NSLog("command: \(command)")
                if (command.count > 0) {
                    result.append(INStringResolutionResult.success(with: command))
                } else {
                    result.append(INStringResolutionResult.needsValue())
                }
            }
        } else {
            result.append(INStringResolutionResult.needsValue())
        }
        completion(result)
    }
    

    // Commands that do not require interaction, access to local library files, access to local configuration files, access to JS...
    // Also imageMagick commands since I have added ImageMagick configuration files. Not python by default, but users can force it.
    let localCommands = ["awk", "calc", "cat", "chflags", "chksum", "chmod", "compress", "cp", "curl", "date", "diff", "dig", "du", "echo", "egrep", "env", "fgrep", "find", "grep", "gunzip", "gzip", "head", "host", "ifconfig", "lex", "link", "ln", "ls", "lua", "luac", "md5", "mkdir", "mv", "nc", "nslookup", "openurl", "pbcopy", "pbpaste",  "ping", "printenv", "pwd", "readlink", "rm", "rmdir", "say", "scp", "setenv", "sftp", "sort", "stat", "sum", "tail", "tar", "tee", "touch", "tr", "true", "uname", "uncompress", "uniq", "unlink", "unsetenv", "uptime", "wc", "whoami", "whois", "xargs", "xxd", "convert", "identify", "basename", "dirname", "expr"]

    func handle(intent: ExecuteCommandIntent, completion: @escaping (ExecuteCommandIntentResponse) -> Void) {
        if let commands = intent.command {
            var open = intent.openWindow // .open: always open the app. .close: never open the app
            let keepGoing = intent.keepGoing as? Bool
            if (open != .open) && (open != .close) {
               // Should we open the App to resolve this set of commands?
               // Make the decision based on all commands
                for command in commands {
                    let inner_commands = command.components(separatedBy: "\n")
                    for inner_command in inner_commands {
                        let arguments = inner_command.split(separator: " ")
                        if arguments.count == 0 { continue }
                        if localCommands.contains(String(arguments[0])) {
                            open = .close
                        } else {
                            open = .open // We need to open the app
                            break
                        }
                    }
                    if (open == .open) { break }
                }
            }
            guard let groupUrl = FileManager().containerURL(forSecurityApplicationGroupIdentifier:"group.AsheKube.a-Shell") else { completion(ExecuteCommandIntentResponse(code: .failureRequiringAppLaunch, userActivity: nil))
                return
            }
            if (open == .close) {
                // lightweight commands (no dependency on UI, nothing fancy, done in less than 5s)
                // == run in extension
                runningInExtension = true
                FileManager().changeCurrentDirectoryPath(groupUrl.path)
                response = ""
                var result:Int32 = 0
                for command in commands {
                    result = executeCommandInExtension(command: command)
                    if (result != 0) && (keepGoing != nil) && (!keepGoing!) { break } // Stop executing after an error
                }
                var intentResponse: ExecuteCommandIntentResponse
                // If keepGoing is set, don't stop the Shortcut even if the commands have failed.
                if (result == 0 || ((keepGoing != nil) && keepGoing!)) {
                    let activity = NSUserActivity(activityType: "AsheKube.app.a-Shell.ExecuteCommand")
                    intentResponse = ExecuteCommandIntentResponse(code: .success, userActivity: activity)
                } else {
                    intentResponse = ExecuteCommandIntentResponse(code: .failure, userActivity: nil)
                }
                runningInExtension = false
                intentResponse.property = response
                intentResponse.property1 = NSNumber(value: result)
                completion(intentResponse)
           } else {
                // other commands or debugging --> open the application and show the output
                var urlString = ""
                for command in commands {
                    if let string = command.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) {
                        urlString += string + "%0A" // newline
                    }
                }
                let activity = NSUserActivity(activityType: "AsheKube.app.a-Shell.ExecuteCommand")
                activity.userInfo!["url"] = URL(string: "ashell:" + urlString)
                // NSLog("Starting the app with command: " + (urlString.removingPercentEncoding ?? "<could not convert>"))
                completion(ExecuteCommandIntentResponse(code: .continueInApp, userActivity: activity))
            }
            return
        }
        completion(ExecuteCommandIntentResponse(code: .failure, userActivity: nil))
    }
    
    func executeCommandInExtension(command: String) -> Int32 {
        // set up streams for feedback:
        // Create new pipes for our own stdout/stderr
        // Get file for stdout/stderr that can be written to
        let stdin_pipe = Pipe()
        let stdin_file = fdopen(stdin_pipe.fileHandleForReading.fileDescriptor, "r")
        // Get file for stdout/stderr that can be written to.
        // Added sageguarding in pipe creation fails:
        let stdout_pipe = Pipe()
        let stdout_file = fdopen(stdout_pipe.fileHandleForWriting.fileDescriptor, "w")
        if (stdout_file == nil) {
            NSLog("Unable to create an output stream. I give up.")
            return -1
        }
        // Call the following functions when data is written to stdout/stderr.
        stdout_pipe.fileHandleForReading.readabilityHandler = self.onStdout
        // "normal" commands can go through ios_system
        // Make sure we're on the right session:
        ios_switchSession(sessionIdentifier)
        ios_setContext(UnsafeMutableRawPointer(mutating: sessionIdentifier.toCString()));
        thread_stdin  = nil
        thread_stdout = nil
        thread_stderr = nil
        // Set up the streams. nil for stdin, which will cause a crash if the command tries to read it.
        // (better than running forever)
        ios_setStreams(stdin_file, stdout_file, stdout_file)
        // Execute command (remove spaces at the beginning and end):
        // reset the LC_CTYPE (some commands (luatex) can change it):
        setenv("LC_CTYPE", "UTF-8", 1);
        setlocale(LC_CTYPE, "UTF-8");
        outputReceived = false
        var returnVal: Int32 = 0
        let commands = command.components(separatedBy: "\n")
        for command in commands {
            let pid = ios_fork()
            returnVal = ios_system(command)
            fflush(thread_stdout)
            ios_waitpid(pid)
            if (returnVal == 0) {
                // If there's already been an error (e.g. "command not found") no need to ask for more.
                returnVal = ios_getCommandStatus()
            }
        }
        fflush(thread_stdout)
        // Send info to the stdout handler that the command has finished:
        // let readOpen = fcntl(self.stdout_pipe!.fileHandleForReading.fileDescriptor, F_GETFD)
        let writeOpen = fcntl(stdout_pipe.fileHandleForWriting.fileDescriptor, F_GETFD)
        if (writeOpen >= 0) {
            // Pipe is still open, send information to close it, once all output has been processed.
            stdout_pipe.fileHandleForWriting.write(self.endOfTransmission.data(using: .utf8)!)
            while (!outputReceived) {
                fflush(thread_stdout)
            }
        }
        // Experimental: If it works, try removing the 4 lines above
        do {
            fclose(stdout_file)
            fclose(stdin_file)
            try stdout_pipe.fileHandleForWriting.close()
            try stdin_pipe.fileHandleForReading.close()
        }
        catch {
            NSLog("Error in closing pipes in MyExtension: \(error.localizedDescription)")
        }
        return returnVal
    }

    private func onStdout(_ stdout: FileHandle) {
        if (outputReceived) { return } // don't try to read after EOT
        let data = stdout.availableData
        guard (data.count > 0) else {
            return
        }
        if let string = String(data: data, encoding: String.Encoding.utf8) {
            // NSLog("received UTF8: " + string)
            var parsedString = string
            // remove all ANSI escape sequences:
            if let regex = try? NSRegularExpression(pattern: "([\\x1B\\x9B]\\[)[0-?]*[ -\\/]*[@-~]", options: .caseInsensitive) {
                parsedString = regex.stringByReplacingMatches(in: parsedString, options: [], range: NSRange(location: 0, length:  parsedString.count), withTemplate: " ")
            }
            if let regex2 = try? NSRegularExpression(pattern: "[\\x1B\\x9B]\\][0-?]*;", options: .caseInsensitive) {
                parsedString = regex2.stringByReplacingMatches(in: parsedString, options: [], range: NSRange(location: 0, length:  parsedString.count), withTemplate: " ")
            }
            parsedString = parsedString.replacingOccurrences(of: endOfTransmission, with: "")
            response = response + parsedString
            if (string.contains(endOfTransmission)) {
                outputReceived = true
            }
        } else if let string = String(data: data, encoding: String.Encoding.ascii) {
            NSLog("Couldn't convert data in stdout using UTF-8, resorting to ASCII: \(data)")
            var parsedString = string
            // remove all ANSI escape sequences:
            if let regex = try? NSRegularExpression(pattern: "([\\x1B\\x9B]\\[)[0-?]*[ -\\/]*[@-~]", options: .caseInsensitive) {
                parsedString = regex.stringByReplacingMatches(in: parsedString, options: [], range: NSRange(location: 0, length:  parsedString.count), withTemplate: " ")
            }
            if let regex2 = try? NSRegularExpression(pattern: "[\\x1B\\x9B]\\][0-?]*;", options: .caseInsensitive) {
                parsedString = regex2.stringByReplacingMatches(in: parsedString, options: [], range: NSRange(location: 0, length:  parsedString.count), withTemplate: " ")
            }
            parsedString = parsedString.replacingOccurrences(of: endOfTransmission, with: "")
            response = response + parsedString
            if (string.contains(endOfTransmission)) {
                outputReceived = true
            }
        } else {
            NSLog("Couldn't convert data in stdout: \(data)")
        }
    }
    
}
