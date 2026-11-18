import Foundation

// Apple-style archive writer. Also usable on the host with synthetic samples.
final class HealthArchive {
    struct Point {
        let latitude: Double
        let longitude: Double
        let elevation: Double
        let time: String
    }

    struct Route {
        let identifier: UUID
        let points: [Point]
    }

    private let destination: URL
    private let staging: URL
    private let partial: URL
    private let xml: FileHandle
    private let deleted: FileHandle
    private var finished = false

    init(destination: URL) throws {
        let manager = FileManager.default
        guard !manager.fileExists(atPath: destination.path) else { throw CocoaError(.fileWriteFileExists) }
        self.destination = destination
        partial = destination.deletingLastPathComponent().appendingPathComponent("." + UUID().uuidString + ".partial")
        staging = destination.deletingLastPathComponent().appendingPathComponent(
            "apple_health_export-" + UUID().uuidString, isDirectory: true)
        try manager.createDirectory(
            at: staging, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        do {
            xml = try Self.open(staging.appendingPathComponent("export.xml"))
            deleted = try Self.open(staging.appendingPathComponent("deleted.jsonl"))
        } catch {
            try? manager.removeItem(at: staging)
            throw error
        }
        try write("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<HealthData locale=\"en_US\">\n")
    }

    deinit {
        try? xml.close()
        try? deleted.close()
        try? FileManager.default.removeItem(at: staging)
        try? FileManager.default.removeItem(at: partial)
    }

    private static var fileAttributes: [FileAttributeKey: Any] {
        #if os(iOS)
            [.posixPermissions: 0o600, .protectionKey: FileProtectionType.complete]
        #else
            [.posixPermissions: 0o600]
        #endif
    }

    private static func open(_ url: URL) throws -> FileHandle {
        guard FileManager.default.createFile(atPath: url.path, contents: nil, attributes: fileAttributes)
        else {
            throw CocoaError(.fileWriteUnknown)
        }
        return try FileHandle(forWritingTo: url)
    }

    private static func escaped(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
            .replacingOccurrences(of: "\n", with: "&#10;")
            .replacingOccurrences(of: "\r", with: "&#13;")
            .replacingOccurrences(of: "\t", with: "&#9;")
    }

    private static func attributes(_ values: [String: String]) -> String {
        values.keys.sorted().map { " \($0)=\"\(escaped(values[$0]!))\"" }.joined()
    }

    private func write(_ value: String) throws {
        try xml.write(contentsOf: Data(value.utf8))
    }

    private func metadata(_ values: [String: String]) throws {
        for key in values.keys.sorted() {
            try write("<MetadataEntry" + Self.attributes(["key": key, "value": values[key]!]) + "/>\n")
        }
    }

    func record(attributes: [String: String], metadata: [String: String]) throws {
        try write("<Record" + Self.attributes(attributes) + ">\n")
        try self.metadata(metadata)
        try write("</Record>\n")
    }

    func workout(attributes: [String: String], metadata: [String: String], routes: [Route]) throws {
        try write("<Workout" + Self.attributes(attributes) + ">\n")
        try self.metadata(metadata)
        for route in routes {
            let directory = staging.appendingPathComponent("workout-routes")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let path = "workout-routes/" + route.identifier.uuidString + ".gpx"
            let file = try Self.open(staging.appendingPathComponent(path))
            do {
                try file.write(
                    contentsOf: Data(
                        "<?xml version=\"1.0\"?><gpx version=\"1.1\" creator=\"a-Shell\" xmlns=\"http://www.topografix.com/GPX/1/1\"><trk><trkseg>\n"
                            .utf8))
                for point in route.points {
                    let attributes = Self.attributes(["lat": String(point.latitude), "lon": String(point.longitude)])
                    let node =
                        "<trkpt\(attributes)><ele>\(point.elevation)</ele><time>\(Self.escaped(point.time))</time></trkpt>\n"
                    try file.write(contentsOf: Data(node.utf8))
                }
                try file.write(contentsOf: Data("</trkseg></trk></gpx>\n".utf8))
                try file.synchronize()
                try file.close()
            } catch {
                try? file.close()
                throw error
            }
            try write("<WorkoutRoute><FileReference" + Self.attributes(["path": path]) + "/></WorkoutRoute>\n")
        }
        try write("</Workout>\n")
    }

    func deletion(identifier: UUID, type: String) throws {
        let data = try JSONSerialization.data(
            withJSONObject: ["uuid": identifier.uuidString, "type": type], options: [.sortedKeys])
        try deleted.write(contentsOf: data + Data([10]))
    }

    func finish() throws {
        guard !finished else { throw CocoaError(.fileWriteUnknown) }
        try write("</HealthData>\n")
        try xml.synchronize()
        try deleted.synchronize()
        try xml.close()
        try deleted.close()
        var coordinatorError: NSError?
        var copyError: Error?
        // Foundation supplies the ZIP snapshot; no second archiver or shell command.
        NSFileCoordinator().coordinate(readingItemAt: staging, options: .forUploading, error: &coordinatorError) {
            url in
            do { try FileManager.default.copyItem(at: url, to: partial) } catch { copyError = error }
        }
        if let error = coordinatorError ?? (copyError as NSError?) { throw error }
        try FileManager.default.setAttributes(Self.fileAttributes, ofItemAtPath: partial.path)
        let file = try FileHandle(forWritingTo: partial)
        try file.synchronize()
        try file.close()
        try FileManager.default.moveItem(at: partial, to: destination)
        finished = true
    }
}

#if os(iOS)
    import HealthKit
    import CoreLocation
    import UIKit
    import ios_system

    private let healthKitLock = NSLock()

    private struct HealthKitState: Codable {
        var anchors: [String: Data] = [:]
        var units: [String: String] = [:]
    }

    private enum HealthKitFailure: Error {
        case timedOut, unavailable, invalidSample
    }

    private func healthKitWorkoutName(_ value: UInt) -> String {
        // HKWorkoutActivityType.h numeric assignments, including retired activities.
        let names =
            "AmericanFootball Archery AustralianFootball Badminton Baseball Basketball Bowling Boxing Climbing Cricket CrossTraining Curling Cycling Dance DanceInspiredTraining Elliptical EquestrianSports Fencing Fishing FunctionalStrengthTraining Golf Gymnastics Handball Hiking Hockey Hunting Lacrosse MartialArts MindAndBody MixedMetabolicCardioTraining PaddleSports Play PreparationAndRecovery Racquetball Rowing Rugby Running Sailing SkatingSports SnowSports Soccer Softball Squash StairClimbing SurfingSports Swimming TableTennis Tennis TrackAndField TraditionalStrengthTraining Volleyball Walking WaterFitness WaterPolo WaterSports Wrestling Yoga Barre CoreTraining CrossCountrySkiing DownhillSkiing Flexibility HighIntensityIntervalTraining JumpRope Kickboxing Pilates Snowboarding Stairs StepTraining WheelchairWalkPace WheelchairRunPace TaiChi MixedCardio HandCycling DiscSports FitnessGaming CardioDance SocialDance Pickleball Cooldown"
            .split(separator: " ")
        if value > 0 && value <= names.count { return "HKWorkoutActivityType" + names[Int(value) - 1] }
        switch value {
        case 82: return "HKWorkoutActivityTypeSwimBikeRun"
        case 83: return "HKWorkoutActivityTypeTransition"
        case 84: return "HKWorkoutActivityTypeUnderwaterDiving"
        case 3000: return "HKWorkoutActivityTypeOther"
        default: return "HKWorkoutActivityType" + String(value)
        }
    }

    private func healthKitCategoryValue(_ sample: HKCategorySample) -> String {
        if sample.categoryType.identifier == "HKCategoryTypeIdentifierSleepAnalysis" {
            let names = ["InBed", "AsleepUnspecified", "Awake", "AsleepCore", "AsleepDeep", "AsleepREM"]
            if names.indices.contains(sample.value) { return "HKCategoryValueSleepAnalysis" + names[sample.value] }
        }
        return String(sample.value)
    }

    // Callback APIs finish on HealthKit queues. Never use command-thread FILE pointers there.
    private final class HealthKitReply<Value> {
        private let lock = NSLock()
        private let done = DispatchSemaphore(value: 0)
        private var result: Result<Value, Error>?

        func finish(_ value: Result<Value, Error>) {
            lock.lock()
            if result == nil {
                result = value
                done.signal()
            }
            lock.unlock()
        }

        func wait() throws -> Value {
            guard done.wait(timeout: .now() + 120) == .success else { throw HealthKitFailure.timedOut }
            lock.lock()
            defer { lock.unlock() }
            return try result!.get()
        }
    }

    private let healthKitDefaultTypes = [
        "HKQuantityTypeIdentifierHeartRate", "HKQuantityTypeIdentifierRestingHeartRate",
        "HKQuantityTypeIdentifierWalkingHeartRateAverage", "HKQuantityTypeIdentifierHeartRateVariabilitySDNN",
        "HKQuantityTypeIdentifierStepCount", "HKQuantityTypeIdentifierDistanceWalkingRunning",
        "HKQuantityTypeIdentifierDistanceCycling", "HKQuantityTypeIdentifierFlightsClimbed",
        "HKQuantityTypeIdentifierActiveEnergyBurned", "HKQuantityTypeIdentifierBasalEnergyBurned",
        "HKQuantityTypeIdentifierAppleExerciseTime", "HKQuantityTypeIdentifierAppleStandTime",
        "HKQuantityTypeIdentifierOxygenSaturation", "HKQuantityTypeIdentifierRespiratoryRate",
        "HKQuantityTypeIdentifierBodyMass", "HKQuantityTypeIdentifierBodyMassIndex",
        "HKQuantityTypeIdentifierBodyFatPercentage", "HKQuantityTypeIdentifierHeight",
        "HKQuantityTypeIdentifierBodyTemperature", "HKQuantityTypeIdentifierVO2Max",
        "HKQuantityTypeIdentifierBloodPressureSystolic", "HKQuantityTypeIdentifierBloodPressureDiastolic",
        "HKQuantityTypeIdentifierBloodGlucose", "HKCategoryTypeIdentifierSleepAnalysis",
        "HKWorkoutTypeIdentifier",
    ]

    private func healthKitType(_ identifier: String) -> HKSampleType? {
        if identifier == HKObjectType.workoutType().identifier { return HKObjectType.workoutType() }
        if identifier.hasPrefix("HKQuantityTypeIdentifier") {
            return HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier(rawValue: identifier))
        }
        if identifier.hasPrefix("HKCategoryTypeIdentifier") {
            return HKObjectType.categoryType(forIdentifier: HKCategoryTypeIdentifier(rawValue: identifier))
        }
        return nil
    }

    private func healthKitPage(_ store: HKHealthStore, type: HKSampleType, anchor: HKQueryAnchor?) throws -> (
        [HKSample], [HKDeletedObject], HKQueryAnchor
    ) {
        let reply = HealthKitReply<([HKSample], [HKDeletedObject], HKQueryAnchor)>()
        let query = HKAnchoredObjectQuery(type: type, predicate: nil, anchor: anchor, limit: 500) {
            _, samples, deleted, next, error in
            if let error = error {
                reply.finish(.failure(error))
            } else if let next = next {
                reply.finish(.success((samples ?? [], deleted ?? [], next)))
            } else {
                reply.finish(.failure(HealthKitFailure.invalidSample))
            }
        }
        store.execute(query)
        defer { store.stop(query) }
        return try reply.wait()
    }

    private func healthKitRoutes(_ store: HKHealthStore, workout: HKWorkout, date: ISO8601DateFormatter) throws
        -> [HealthArchive.Route]
    {
        let reply = HealthKitReply<[HKWorkoutRoute]>()
        let query = HKSampleQuery(
            sampleType: HKSeriesType.workoutRoute(), predicate: HKQuery.predicateForObjects(from: workout),
            limit: HKObjectQueryNoLimit, sortDescriptors: nil
        ) { _, samples, error in
            if let error = error {
                reply.finish(.failure(error))
            } else {
                reply.finish(.success(samples as? [HKWorkoutRoute] ?? []))
            }
        }
        store.execute(query)
        let samples: [HKWorkoutRoute]
        do { samples = try reply.wait() } catch {
            store.stop(query)
            throw error
        }
        store.stop(query)
        var routes: [HealthArchive.Route] = []
        for route in samples.sorted(by: { $0.uuid.uuidString < $1.uuid.uuidString }) {
            let pointsReply = HealthKitReply<[CLLocation]>()
            let lock = NSLock()
            var points: [CLLocation] = []
            let routeQuery = HKWorkoutRouteQuery(route: route) { _, locations, done, error in
                lock.lock()
                defer { lock.unlock() }
                if let error = error {
                    pointsReply.finish(.failure(error))
                    return
                }
                points.append(contentsOf: locations ?? [])
                if done { pointsReply.finish(.success(points)) }
            }
            store.execute(routeQuery)
            let locations: [CLLocation]
            do { locations = try pointsReply.wait() } catch {
                store.stop(routeQuery)
                throw error
            }
            store.stop(routeQuery)
            routes.append(
                HealthArchive.Route(
                    identifier: route.uuid,
                    points: locations.map {
                        HealthArchive.Point(
                            latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude,
                            elevation: $0.altitude, time: date.string(from: $0.timestamp))
                    }))
        }
        return routes
    }

    @_cdecl("healthkit_main")
    public func healthkitMain(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
        guard let args = convertCArguments(argc: argc, argv: argv) else { return 1 }
        let usage = """
            Usage: healthkit authorize [TYPE ...] | healthkit export [TYPE ...]
            Export HealthKit data to a local Apple Health-style ZIP. Exports are incremental per type.
            Defaults: Watch/iPhone quantities, sleep and workouts (including available GPS).
            TYPE: a HealthKit quantity/category identifier, or HKWorkoutTypeIdentifier.
            Authorize requires the foreground app and the system permission sheet.
            Export requires an unlocked device and prints the ZIP path.
            HealthKit reports denied read access as an empty result.
            Archives are saved in ~/Documents/HealthKit and include deleted UUIDs in deleted.jsonl.
            Workout routes are read when their workout is exported.

            """
        if args.count == 2 && ["--help", "-h"].contains(args[1]) {
            fputs(usage, thread_stdout)
            return 0
        }
        guard args.count >= 2 && ["authorize", "export"].contains(args[1]) else {
            fputs(usage, thread_stderr)
            return 2
        }
        let identifiers = args.count > 2 ? Array(args.dropFirst(2)) : healthKitDefaultTypes
        let types = identifiers.compactMap(healthKitType)
        guard types.count == identifiers.count, Set(identifiers).count == identifiers.count else {
            fputs("healthkit: invalid or repeated sample type; see --help.\n", thread_stderr)
            return 2
        }
        guard !Thread.isMainThread && !runningInExtension && HKHealthStore.isHealthDataAvailable(),
            Bundle.main.object(forInfoDictionaryKey: "NSHealthShareUsageDescription") != nil
        else {
            fputs("healthkit: run in the a-Shell app on a HealthKit-capable device.\n", thread_stderr)
            return 1
        }
        guard healthKitLock.try() else {
            fputs("healthkit: another export or authorization is running.\n", thread_stderr)
            return 1
        }
        defer { healthKitLock.unlock() }
        let available = DispatchQueue.main.sync { UIApplication.shared.isProtectedDataAvailable }
        guard available else {
            fputs("healthkit: unlock the phone before reading Health data; anchors unchanged.\n", thread_stderr)
            return 1
        }
        let store = HKHealthStore()
        do {
            if args[1] == "authorize" {
                let reply = HealthKitReply<Bool>()
                DispatchQueue.main.async {
                    guard UIApplication.shared.applicationState == .active else {
                        reply.finish(.failure(HealthKitFailure.unavailable))
                        return
                    }
                    var readTypes = Set<HKObjectType>(types)
                    if types.contains(HKObjectType.workoutType()) { readTypes.insert(HKSeriesType.workoutRoute()) }
                    store.requestAuthorization(toShare: [], read: readTypes) { success, error in
                        if let error = error { reply.finish(.failure(error)) } else { reply.finish(.success(success)) }
                    }
                }
                guard try reply.wait() else { throw HealthKitFailure.unavailable }
                fputs("{\"authorization_request_completed\":true,\"read_access_verified\":false}\n", thread_stdout)
                return 0
            }
            let manager = FileManager.default
            let home = URL(fileURLWithPath: NSHomeDirectory())
            let support = home.appendingPathComponent("Library/Application Support/HealthKit", isDirectory: true)
            let outbox = home.appendingPathComponent("Documents/HealthKit", isDirectory: true)
            for directory in [support, outbox] {
                try manager.createDirectory(
                    at: directory, withIntermediateDirectories: true,
                    attributes: [.posixPermissions: 0o700, .protectionKey: FileProtectionType.complete])
                var url = directory
                var resourceValues = URLResourceValues()
                resourceValues.isExcludedFromBackup = true
                try url.setResourceValues(resourceValues)
            }
            let stateURL = support.appendingPathComponent("anchors.json")
            var state =
                manager.fileExists(atPath: stateURL.path)
                ? try JSONDecoder().decode(HealthKitState.self, from: Data(contentsOf: stateURL)) : HealthKitState()
            let quantities = Set(types.compactMap { $0 as? HKQuantityType })
            if !quantities.isEmpty {
                let reply = HealthKitReply<[HKQuantityType: HKUnit]>()
                store.preferredUnits(for: quantities) { units, error in
                    if let error = error { reply.finish(.failure(error)) } else { reply.finish(.success(units)) }
                }
                for (type, unit) in try reply.wait() where state.units[type.identifier] == nil {
                    state.units[type.identifier] = unit.unitString
                }
            }
            let destination = outbox.appendingPathComponent(UUID().uuidString + ".zip")
            let archive = try HealthArchive(destination: destination)
            let date = ISO8601DateFormatter()
            date.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            for type in types {
                var anchor: HKQueryAnchor?
                if let data = state.anchors[type.identifier] {
                    anchor = try NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
                    guard anchor != nil else { throw HealthKitFailure.invalidSample }
                }
                while true {
                    let (samples, deleted, next) = try healthKitPage(store, type: type, anchor: anchor)
                    for sample in samples {
                        var attributes = [
                            "startDate": date.string(from: sample.startDate),
                            "endDate": date.string(from: sample.endDate),
                            "sourceName": sample.sourceRevision.source.name,
                        ]
                        if let version = sample.sourceRevision.version { attributes["sourceVersion"] = version }
                        var metadata = sample.metadata?.mapValues { String(describing: $0) } ?? [:]
                        metadata["HKUUID"] = sample.uuid.uuidString
                        if let workout = sample as? HKWorkout {
                            attributes["workoutActivityType"] = healthKitWorkoutName(
                                workout.workoutActivityType.rawValue)
                            attributes["duration"] = String(workout.duration)
                            attributes["durationUnit"] = "s"
                            try archive.workout(
                                attributes: attributes, metadata: metadata,
                                routes: healthKitRoutes(store, workout: workout, date: date))
                        } else {
                            attributes["type"] = type.identifier
                            if let quantity = sample as? HKQuantitySample, let unitString = state.units[type.identifier]
                            {
                                let unit = HKUnit(from: unitString)
                                attributes["unit"] = unitString
                                attributes["value"] = String(quantity.quantity.doubleValue(for: unit))
                            } else if let category = sample as? HKCategorySample {
                                attributes["value"] = healthKitCategoryValue(category)
                            } else {
                                throw HealthKitFailure.invalidSample
                            }
                            try archive.record(attributes: attributes, metadata: metadata)
                        }
                    }
                    for object in deleted { try archive.deletion(identifier: object.uuid, type: type.identifier) }
                    anchor = next
                    if samples.count + deleted.count < 500 { break }
                }
                state.anchors[type.identifier] = try NSKeyedArchiver.archivedData(
                    withRootObject: anchor!, requiringSecureCoding: true)
            }
            guard DispatchQueue.main.sync(execute: { UIApplication.shared.isProtectedDataAvailable }) else {
                throw HealthKitFailure.unavailable
            }
            try archive.finish()
            // Publish before committing anchors so a failed state write can replay the samples.
            try JSONEncoder().encode(state).write(to: stateURL, options: [.atomic, .completeFileProtection])
            fputs(String(cString: ios_getBookmarkedVersion(destination.path.utf8CString)) + "\n", thread_stdout)
            return 0
        } catch {
            // HealthKit and filesystem localized messages may contain private data or paths.
            fputs(
                "healthkit: operation failed; check authorization and protected-data availability. Retry export safely; incomplete batches do not advance anchors.\n",
                thread_stderr)
            return 1
        }
    }
#endif
