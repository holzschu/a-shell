//
//  localWebServer.swift
//  localWebServer
//
//  Created by Nicolas Holzschuch on 12/10/2025.
//  Copyright © 2025 AsheKube. All rights reserved.
//

import Foundation
import ExtensionFoundation

// Due to Indentifier conventions, if this ever works, it will have to be a different source code for a-Shell and a-Shell mini.

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
        return false
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
        NSLog("Entered localWebServer init")
    }

    @AppExtensionPoint.Bind
    var boundExtensionPoint: AppExtensionPoint {
        AppExtensionPoint.Identifier(host: "AsheKube.app.a-Shell", name: "localWebServer")
    }
}
