import ExtensionFoundation
import Foundation

// Every extension identity compiles this same source and native pane adapter.
@main
final class PaneExtension: AppExtension {
    required init() {}

    @AppExtensionPoint.Bind
    var extensionPoint: AppExtensionPoint {
        AppExtensionPoint.Identifier(host: "@ASHELL_WORKER_HOST_IDENTIFIER@", name: "ShellWorker")
    }

    var configuration: some AppExtensionConfiguration { PaneConfiguration() }
}

struct PaneConfiguration: AppExtensionConfiguration {
    func accept(connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: AShellPaneWire.self)
        guard let service = ashell_worker_service() else { return false }
        connection.exportedObject = service
        // ios_system interposes exit/_exit as pthread_exit, which is invalid on
        // this dispatch callback. Process lifetime belongs to ExtensionFoundation.
        connection.invalidationHandler = { service.releasePane() }
        connection.resume()
        return true
    }
}
