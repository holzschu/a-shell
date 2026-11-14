import Foundation
import Combine
import Darwin
let thread_stdout = stdout
let thread_stderr = stderr
// Replace persistent preferences at the platform boundary; never change host preferences.
final class UserDefaults {
    static let standard = UserDefaults()
    static let didChangeNotification = Notification.Name("preferences")
    private var enabled = false
    func bool(forKey: String) -> Bool { enabled }
    func set(_ value: Bool, forKey: String) { enabled = value }
}
let scenario = CommandLine.arguments[1]
let sampleDate = Date(timeIntervalSinceNow: scenario == "reduced-too-old" ? -1260 : -600)
let kCLDistanceFilterNone = 0.0
let kCLLocationAccuracyHundredMeters = 100.0
let kCLLocationAccuracyReduced = 5000.0
enum CLAuthorizationStatus { case authorizedAlways, authorizedWhenInUse, denied, restricted, notDetermined }
enum CLAccuracyAuthorization { case fullAccuracy, reducedAccuracy }
struct CLLocationCoordinate2D { let latitude = 1.0; let longitude = 2.0 }
final class CLLocation {
    let timestamp: Date
    let horizontalAccuracy = 5000.0
    let coordinate = CLLocationCoordinate2D()
    let altitude = 0.0, verticalAccuracy = 0.0, course = 0.0, speed = 0.0
    init(_ date: Date) { timestamp = date }
}
protocol CLLocationManagerDelegate: AnyObject {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation])
}
final class CLLocationManager {
    weak var delegate: CLLocationManagerDelegate?
    var pausesLocationUpdatesAutomatically = false
    var distanceFilter = 0.0, desiredAccuracy = 0.0
    var allowsBackgroundLocationUpdates = false, showsBackgroundLocationIndicator = false
    var authorizationStatus: CLAuthorizationStatus { .authorizedAlways }
    var accuracyAuthorization: CLAccuracyAuthorization { scenario.hasPrefix("reduced") ? .reducedAccuracy : .fullAccuracy }
    var location: CLLocation? { scenario == "reduced-delivery" ? nil : CLLocation(sampleDate) }
    func stopUpdatingLocation() {}
    func startUpdatingLocation() {}
    func requestWhenInUseAuthorization() {}
    func requestLocation() {
        guard scenario != "precise-no-fix" else { return }
        let date = scenario.hasPrefix("reduced") ? sampleDate : Date()
        DispatchQueue.main.async { self.delegate?.locationManager(self, didUpdateLocations: [CLLocation(date)]) }
    }
}
struct CLError: Error { enum Code { case locationUnknown }; var code: Code; static var locationUnknown: Code { .locationUnknown } }
class UIScene {
    enum ActivationState { case foregroundActive }
    var activationState: ActivationState { .foregroundActive }
    static let didActivateNotification = Notification.Name("activate")
}
class UIViewController {
    var presentedViewController: UIViewController? { nil }
    func present(_ value: Any, animated: Bool) {}
}
class UIWindow { var isKeyWindow = true; var rootViewController: UIViewController? = UIViewController() }
class UIWindowScene: UIScene { var windows = [UIWindow()] }
class UIApplication { static let shared = UIApplication(); var connectedScenes: [UIScene] = [UIWindowScene()] }
struct BackgroundSettings {}
struct UIHostingController<T> { init(rootView: T) {} }
