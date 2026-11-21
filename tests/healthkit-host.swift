import Foundation

// Exercise the portable archive API used by the phone command, with synthetic data only.
@main
struct ArchiveTest {
    static func main() throws {
        let destination = URL(fileURLWithPath: CommandLine.arguments[1])
        let workspace = destination.deletingLastPathComponent().appendingPathComponent("working")
        let archive = try HealthArchive(destination: destination, workspace: workspace)
        guard !FileManager.default.fileExists(atPath: destination.path) else {
            fatalError("Published before completion")
        }
        try archive.record(
            attributes: [
                "type": "HKQuantityTypeIdentifierHeartRate", "value": "60", "unit": "count/min",
                "startDate": "2026-01-01T00:00:00Z", "endDate": "2026-01-01T00:00:01Z",
                "sourceName": "Synthetic & <source> \"only\"\u{1}",
            ], metadata: ["HKUUID": "00000000-0000-0000-0000-000000000001"])
        try archive.workout(
            attributes: [
                "workoutActivityType": "HKWorkoutActivityTypeRunning",
                "startDate": "2026-01-01T00:00:00Z", "endDate": "2026-01-01T00:01:00Z",
                "duration": "1", "durationUnit": "min",
            ], metadata: [:],
            routes: [
                HealthArchive.Route(
                    identifier: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                    points: [.init(latitude: 0.00001, longitude: 180, elevation: 0.00001, time: "2026-01-01T00:00:00Z")]
                )
            ])
        try archive.deletion(
            identifier: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            type: "HKQuantityTypeIdentifierStepCount")
        try archive.finish()
        guard FileManager.default.fileExists(atPath: destination.path) else { fatalError("Missing archive") }
        do {
            _ = try HealthArchive(destination: destination, workspace: workspace)
            fatalError("Existing archive was accepted")
        } catch CocoaError.fileWriteFileExists {}
        let incomplete = destination.deletingLastPathComponent().appendingPathComponent("incomplete.zip")
        let interruptedWorkspace = workspace.deletingLastPathComponent().appendingPathComponent("interrupted")
        try FileManager.default.createDirectory(at: interruptedWorkspace, withIntermediateDirectories: false)
        let abandoned = interruptedWorkspace.appendingPathComponent("abandoned")
        try Data("stale synthetic output".utf8).write(to: abandoned)
        do {
            let interrupted = try HealthArchive(destination: incomplete, workspace: interruptedWorkspace)
            guard !FileManager.default.fileExists(atPath: abandoned.path) else {
                fatalError("Retained staging from a previous export")
            }
            try interrupted.record(attributes: ["type": "synthetic"], metadata: [:])
        }
        guard !FileManager.default.fileExists(atPath: incomplete.path) else {
            fatalError("Published incomplete archive")
        }
        guard !FileManager.default.fileExists(atPath: interruptedWorkspace.path) else {
            fatalError("Retained staging after an interrupted export")
        }
        print("PASS synthetic archive and overwrite refusal")
    }
}
