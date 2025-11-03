//
//  localWebServerMini.swift
//  localWebServer
//
//  Created by Nicolas Holzschuch on 12/10/2025.
//  Copyright © 2025 AsheKube. All rights reserved.
//

import Foundation
import ExtensionFoundation
import Vapor // for our local server for WebAssembly
import NIOSSL // for TLS (https) authentification

// Due to Indentifier conventions, if this ever works, it will have to be a different source code for a-Shell and a-Shell mini.

var localServerApp: Application?

/// The AppExtensionConfiguration that will be provided by this extension.
/// This is typically defined by the extension host in a framework.
struct localWebServerConfiguration<E:localWebServerExtension>: AppExtensionConfiguration {
    
    let appExtension: E
    
    init(_ appExtension: E) {
        NSLog("localWebServer: init configuration called")
        self.appExtension = appExtension
    }
    
    /// Determine whether to accept the XPC connection from the host.
    func accept(connection: NSXPCConnection) -> Bool {
        NSLog("localWebServer: received connection request")
        // TODO: Configure the XPC connection and return true
        return true
    }
}

/// The AppExtension protocol to which this extension will conform.
/// This is typically defined by the extension host in a framework.
protocol localWebServerExtension : AppExtension { }

extension localWebServerExtension {
    var configuration: localWebServerConfiguration<some localWebServerExtension> {
        NSLog("localWebServer: received configuration request")
        // Return your extension's configuration upon request.
        return localWebServerConfiguration(self)
    }
}

@main
class localWebServer: localWebServerExtension {
    required init() {
        NSLog("Entered localWebServerMini init")
        do {
            localServerApp = try await Application.make()
            // Vapor prints a lot of info on the console. No need to add ours.
            // TODO: restart localServerApp.server if unable to connect --> how?
            // No websocket support for now: it's not needed for a-Shell
            localServerApp?.http.server.configuration.hostname = "127.0.0.1"
            // Make sure the servers for the different apps don't interfere with each other:
            localServerApp?.http.server.configuration.port = 8334 // a-Shell mini
            localServerApp?.http.server.configuration.tlsConfiguration = .makeServerConfiguration(
                certificateChain: try NIOSSLCertificate.fromPEMFile(Bundle.main.resourcePath! + "/localCertificate.pem").map { .certificate($0) },
                privateKey: try NIOSSLPrivateKeySource.privateKey(NIOSSLPrivateKey(file: Bundle.main.resourcePath! + "/localCertificateKey.pem", format: .pem))
            )
            localServerApp?.get("**") { request -> Response in
                let urlPath = request.url.path
                // Load ~/Library/node_modules first if it exists:
                // This also loads ~/Library/wasm.html and ~/Library/require.js if the user really wants to.
                let libraryURL = try! FileManager().url(for: .libraryDirectory,
                                                        in: .userDomainMask,
                                                        appropriateFor: nil,
                                                        create: true)
                let localFilePath = libraryURL.path + urlPath
                let rootFilePath = Bundle.main.resourcePath! + urlPath
                var fileName: String? = nil
                // NSLog("file requested: \(urlPath). Trying \(localFilePath)  and \(rootFilePath)")
                if (FileManager().fileExists(atPath: localFilePath) && !URL(fileURLWithPath: localFilePath).isDirectory) {
                    fileName = localFilePath
                } else if (FileManager().fileExists(atPath: rootFilePath) && !URL(fileURLWithPath: rootFilePath).isDirectory) {
                    fileName = rootFilePath
                }
                // NSLog("file found: \(fileName)")
                if (fileName != nil) {
                    var headers = HTTPHeaders()
                    if (urlPath.hasSuffix(".html")) {
                        headers.add(name: .contentType, value: "text/html")
                    } else if (urlPath.hasSuffix(".js")) {
                        headers.add(name: .contentType, value: "application/javascript")
                    } else if (urlPath.hasSuffix(".wasm")) {
                        // NSLog("setting the header to application/wasm")
                        headers.add(name: .contentType, value: "application/wasm")
                    }
                    // These headers get us a "crossOriginIsolated == true;"
                    headers.add(name: "Cross-Origin-Embedder-Policy", value: "require-corp")
                    headers.add(name: "Cross-Origin-Opener-Policy", value: "same-origin")
                    headers.add(name: "Cross-Origin-Resource-Policy", value: "same-origin")
                    do {
                        // Binary access to the file, because we could be serving WASM files
                        let body = try Data(contentsOf: URL(fileURLWithPath: fileName!))
                        // NSLog("Returned \(urlPath) with \(fileName!)")
                        return Response(status: .ok, headers: headers, body: Response.Body(data: body))
                    }
                    catch {
                        NSLog("File: \(String(describing: fileName)) could not access: \(error).")
                        return Response(status: .forbidden)
                    }
                }
                // NSLog("\(urlPath): not found")
                return Response(status: .notFound)
            }
            try localServerApp?.server.start()
        }
        catch {
            NSLog("Unable to start the vapor server: \(error)")
            exit(0)
        }
    }

    @AppExtensionPoint.Bind
    var boundExtensionPoint: AppExtensionPoint {
        AppExtensionPoint.Identifier(host: "AsheKube.app.a-Shell-mini", name: "localWebServer")
    }
}
