import AVFoundation
import CoreLocation
import Observation
import Photos
import UserNotifications

enum WelcomePermission: String, CaseIterable, Identifiable {
    case location, camera, notifications, usage
    var id: String { rawValue }
    var title: String {
        switch self {
        case .location: return "Location"
        case .camera: return "Camera & Photos"
        case .notifications: return "Notifications"
        case .usage: return "Usage Data (optional)"
        }
    }
    var subtitle: String {
        switch self {
        case .location: return "Find nearby pharmacies and labs\nand show accurate prices"
        case .camera: return "Scan your prescription from camera,\nphotos or WhatsApp"
        case .notifications: return "Reminders for medicines, tests\nand important updates"
        case .usage: return "Helps us improve accuracy\nand experiences"
        }
    }
    var symbol: String {
        switch self {
        case .location: return "mappin.circle.fill"
        case .camera: return "camera.fill"
        case .notifications: return "bell.fill"
        case .usage: return "chart.bar.fill"
        }
    }
}

@MainActor @Observable final class WelcomePermissionStore: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    var status = ""
    var busy = false
    override init() {
        super.init()
        locationManager.delegate = self
    }
    func requestLocation() {
        let authorization = locationManager.authorizationStatus
        if authorization == .notDetermined {
            busy = true
            locationManager.requestWhenInUseAuthorization()
        } else {
            updateLocationStatus(authorization)
        }
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Ignore the delegate's initial callback until the user explicitly asks.
        guard busy else { return }
        updateLocationStatus(manager.authorizationStatus)
    }
    private func updateLocationStatus(_ authorization: CLAuthorizationStatus) {
        busy = false
        switch authorization {
        case .authorizedAlways, .authorizedWhenInUse: status = "Location access is allowed while using Parchi."
        case .denied, .restricted: status = "Location access is off. You can choose an area manually when needed, or change access in Settings."
        default: status = "Choose whether to allow location access."
        }
    }
    func requestCamera() async {
        busy = true
        let allowed = await AVCaptureDevice.requestAccess(for: .video)
        status = allowed ? "Camera access is allowed." : "Camera access is off. You can change it in Settings."
        busy = false
    }
    func requestPhotos() async {
        busy = true
        let result = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        switch result {
        case .authorized: status = "Photo access is allowed."
        case .limited: status = "Only your selected photos are available to Parchi."
        default: status = "Photo access is off. You can change it in Settings."
        }
        busy = false
    }
    func requestNotifications() async {
        busy = true
        do {
            let allowed = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            status = allowed ? "Notifications are allowed. No reminders have been scheduled yet." : "Notifications are off. You can change this later in Settings."
        } catch { status = "Could not update notification access. Please try again." }
        busy = false
    }
}
