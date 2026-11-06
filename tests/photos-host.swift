// External iOS boundaries for the host command contract. Foundation I/O stays real.
import Foundation
import CryptoKit
import Darwin

let thread_stdout = stdout
let thread_stderr = stderr
let runningInExtension = false
func convertCArguments(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> [String]? {
    return (0..<Int(argc)).map { String(cString: argv![$0]!) }
}
func ios_getBookmarkedVersion(_ path: ContiguousArray<CChar>) -> UnsafePointer<CChar> {
    return UnsafePointer(strdup("~/Documents/Photos"))
}
class UIViewController {
    var presentedViewController: UIViewController? { nil }
    var view: View? { View() }
}
class View { var window: UIWindow? { UIWindow() } }
class UIWindow { var rootViewController: UIViewController? { UIViewController() } }
class SceneDelegate { var window: UIWindow? { UIWindow() } }
let currentDelegate: SceneDelegate? = SceneDelegate()

enum PHAuthorizationStatus { case notDetermined, authorized, limited, denied }
class PHPhotoLibrary {
    static func shared() -> PHPhotoLibrary { PHPhotoLibrary() }
    static func authorizationStatus(for access: Access) -> PHAuthorizationStatus {
        return ProcessInfo.processInfo.environment["PHOTOS_TEST_ACCESS"] == "full" ? .authorized : .limited
    }
    enum Access { case readWrite }
    static func requestAuthorization(for access: Access, handler: (PHAuthorizationStatus) -> Void) { handler(.limited) }
    func presentLimitedLibraryPicker(from controller: UIViewController, completionHandler: @escaping ([String]) -> Void) {
        // A delayed system callback makes fetching before dismissal observable.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            try! Data().write(to: URL(fileURLWithPath: ProcessInfo.processInfo.environment["PHOTOS_TEST_HOME"]! + "/picker-finished"))
            completionHandler([])
        }
    }
}
class PHFetchResult {
    let assets: [PHAsset]
    init(_ names: [String] = []) { assets = names.map { PHAsset($0) } }
    var count: Int { assets.count }
    func object(at index: Int) -> PHAsset { assets[index] }
}
class PHAsset {
    let localIdentifier: String
    init(_ name: String) { localIdentifier = name }
    let modificationDate: Date? = nil
    static func fetchAssets(with options: Any?) -> PHFetchResult {
        let home = ProcessInfo.processInfo.environment["PHOTOS_TEST_HOME"]!
        let changed = Foundation.FileManager.default.fileExists(atPath: home + "/picker-finished")
        try! Data((changed ? "changed" : "initial").utf8).write(to: URL(fileURLWithPath: home + "/fetched"))
        return PHFetchResult(changed ? ["B", "C"] : ["A", "B"])
    }
    static func fetchAssets(withLocalIdentifiers identifiers: [String], options: Any?) -> PHFetchResult { PHFetchResult() }
}
enum PHAssetResourceType: Int { case photo, video, audio, alternatePhoto, pairedVideo }
class PHAssetResource {
    let name: String
    init(_ name: String) { self.name = name }
    let type = PHAssetResourceType.photo
    let filename: String? = "fixture.png"
    let originalFilename = "fixture.png"
    static func assetResources(for asset: PHAsset) -> [PHAssetResource] { [PHAssetResource(asset.localIdentifier)] }
}
class PHAssetResourceRequestOptions { var isNetworkAccessAllowed = false }
class PHAssetResourceManager {
    static func `default`() -> PHAssetResourceManager { PHAssetResourceManager() }
    func requestData(for resource: PHAssetResource, options: PHAssetResourceRequestOptions, dataReceivedHandler: (Data) -> Void, completionHandler: (Error?) -> Void) -> Int { dataReceivedHandler(Data((resource.name + "\n").utf8)); completionHandler(nil); return 0 }
    func cancelDataRequest(_ request: Int) {}
}
// Redirect only the system Documents location into an isolated disposable home.
class FileManager: Foundation.FileManager, @unchecked Sendable {
    static let fixture = FileManager()
    override class var `default`: FileManager { fixture }
    override func urls(for directory: SearchPathDirectory, in domainMask: SearchPathDomainMask) -> [URL] {
        return [URL(fileURLWithPath: ProcessInfo.processInfo.environment["PHOTOS_TEST_HOME"]!)]
    }
}
