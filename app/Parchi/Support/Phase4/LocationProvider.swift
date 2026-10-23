import CoreLocation
import Foundation
import Observation
import ParchiCore
import SwiftUI

/// Where to search for shops and labs (gaps U1, U15). Uses a location fix when allowed and inside our area;
/// otherwise the city the patient picked; otherwise KIET. Nothing here is ever sent anywhere.
@MainActor
@Observable
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    enum Status: Equatable {
        case notAsked, locating, located, denied, unavailable
    }

    static let cityKey = "parchi.city"

    private(set) var status: Status = .notAsked
    private(set) var fix: CLLocationCoordinate2D?
    var chosenCity: City? { didSet { UserDefaults.standard.set(chosenCity?.name, forKey: Self.cityKey) } }

    @ObservationIgnored private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        chosenCity = UserDefaults.standard.string(forKey: Self.cityKey).flatMap { Cities.named($0) }
        apply(manager.authorizationStatus)
    }

    /// The point the app should centre on, and its label.
    var centre: City {
        if let fix, Cities.isServed(latitude: fix.latitude, longitude: fix.longitude) {
            return City(name: "Your location", latitude: fix.latitude, longitude: fix.longitude)
        }
        return chosenCity ?? Cities.defaultCentre
    }

    /// True when the app should show the city picker: no usable fix and no city chosen yet.
    var needsCityPicker: Bool {
        if let fix, Cities.isServed(latitude: fix.latitude, longitude: fix.longitude) { return false }
        return chosenCity == nil
    }

    /// Ask only when the patient taps "Use my location" (reason shown first by the caller).
    func requestLocation() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            status = .locating
            manager.requestLocation()
        default:
            status = .denied
        }
    }

    func choose(_ city: City) { chosenCity = city }

    private func apply(_ authorization: CLAuthorizationStatus) {
        switch authorization {
        case .denied, .restricted: status = .denied
        case .authorizedWhenInUse, .authorizedAlways: if status == .notAsked { status = .locating; manager.requestLocation() }
        default: break
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let authorization = manager.authorizationStatus
        Task { @MainActor in self.apply(authorization) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        Task { @MainActor in
            self.fix = coordinate
            self.status = .located
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.status = .unavailable }
    }
}

/// City picker shown when location is denied, unavailable or outside our area (U1).
struct CityPickerView: View {
    let location: LocationProvider
    var onDone: () -> Void = {}

    var body: some View {
        List {
            Section {
                Button {
                    location.requestLocation()
                } label: {
                    Label("Use my location", systemImage: "location")
                }
                Text(statusText).font(.footnote).foregroundStyle(.secondary)
            } footer: {
                Text("Parchi uses your location to show shops and labs near you. The map search sends the area around you to Apple Maps; Parchi does not save it.")
            }
            Section("Or choose your city") {
                ForEach(Cities.all) { city in
                    Button {
                        location.choose(city)
                        onDone()
                    } label: {
                        HStack {
                            Text(city.name)
                            Spacer()
                            if location.chosenCity == city { Image(systemName: "checkmark").accessibilityLabel("Selected") }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
            Section {
                LabeledContent("Searching around", value: location.centre.name)
            }
        }
        .navigationTitle("Your city")
    }

    private var statusText: String {
        switch location.status {
        case .notAsked: return "Not asked yet."
        case .locating: return "Finding you…"
        case .located:
            return Cities.isServed(latitude: location.fix?.latitude ?? 0, longitude: location.fix?.longitude ?? 0)
                ? "Using your location." : "Your location is outside the cities we cover. Please choose a city."
        case .denied: return "Location is off for Parchi. Choose a city, or turn it on in the Settings app."
        case .unavailable: return "Couldn't get your location. Choose a city."
        }
    }
}
