import Foundation

// The pure gate is the contract here. FixtureOS substitutes OS state/authentication, not the gate.
// This does not exercise UIKit mapping/presentation, Security ACLs or the native stream bridge.
func keychainSceneGateContract() throws {
    struct Row {
        let name: String
        let boundary: CredentialSceneGate.Boundary
        let activation: CredentialSceneGate.Activation
        var protectedDataAvailable = true
        var appInBackground = false
        var generationMatches = true
        var exportAuthorized = false
        let allowed: Bool
    }
    var rows = [
        Row(name: "entry-foregroundInactive-proceeds", boundary: .entry, activation: .inactive, allowed: true),
        Row(
            name: "presentation-foregroundInactive-proceeds", boundary: .presentation, activation: .inactive,
            allowed: true),
        Row(
            name: "export-foregroundInactive-after-auth-proceeds", boundary: .export, activation: .inactive,
            exportAuthorized: true, allowed: true),
        Row(
            name: "export-foregroundInactive-without-auth-denied", boundary: .export, activation: .inactive,
            allowed: false),
        Row(name: "export-active-without-auth-denied", boundary: .export, activation: .active, allowed: false),
    ]
    for boundary in [CredentialSceneGate.Boundary.entry, .presentation, .export] {
        for activation in [CredentialSceneGate.Activation.active, .inactive] {
            let label = "\(boundary)-\(activation)"
            rows += [
                Row(
                    name: "\(label)-valid-proceeds", boundary: boundary, activation: activation,
                    exportAuthorized: true, allowed: true),
                Row(
                    name: "\(label)-locked-denied", boundary: boundary, activation: activation,
                    protectedDataAvailable: false, exportAuthorized: true, allowed: false),
                Row(
                    name: "\(label)-app-background-denied", boundary: boundary, activation: activation,
                    appInBackground: true, exportAuthorized: true, allowed: false),
                // Current state can look foreground after return/unlock; an old generation still cannot proceed.
                Row(
                    name: "\(label)-old-generation-denied", boundary: boundary, activation: activation,
                    generationMatches: false, exportAuthorized: true, allowed: false),
            ]
        }
        rows.append(
            Row(
                name: "\(boundary)-scene-background-or-disconnected-denied", boundary: boundary,
                activation: .unavailable, exportAuthorized: true, allowed: false))
    }
    let os = FixtureOS()
    let bytes = Data([0, 255, 10, 13, 0, 128, 65])
    check(
        KeychainCommand.run(["set", "scene-fixture"], input: { bytes }, platform: os).status == 0,
        "scene gate fixture stored")
    for row in rows {
        os.interactionGate = {
            try CredentialSceneGate.require(
                row.boundary, activation: row.activation, protectedDataAvailable: row.protectedDataAvailable,
                appInBackground: row.appInBackground, generationMatches: row.generationMatches,
                exportAuthorized: row.exportAuthorized)
        }
        let result = KeychainCommand.run(["get", "scene-fixture"], input: { Data() }, platform: os)
        let passed =
            row.allowed
            ? result.status == 0 && result.output == bytes && result.diagnostic.isEmpty
            : result.status == 1 && result.output.isEmpty && !result.diagnostic.isEmpty
        guard passed else {
            fputs("FAIL scene-gate \(row.name): status/bytes did not match the contract\n", stderr)
            exit(1)
        }
        print("PASS scene-gate \(row.name)\(row.allowed ? " exact-bytes" : " zero-output")")
    }
}
