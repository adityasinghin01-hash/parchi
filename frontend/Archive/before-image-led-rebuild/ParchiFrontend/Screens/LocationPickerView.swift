import CoreLocation
import Observation
import SwiftUI

/// One-shot device location, only after a user tap. No background tracking or geocoding.
@MainActor @Observable
final class OnboardingLocationPicker: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    var busy = false
    var coordinate: CLLocationCoordinate2D?
    var failed = false
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }
    func request() {
        coordinate = nil; failed = false; busy = true
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        default: busy = false; failed = true
        }
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard busy else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        case .denied, .restricted: busy = false; failed = true
        default: break
        }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        busy = false
        guard let location = locations.last else { failed = true; return }
        coordinate = location.coordinate
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        busy = false; failed = true
    }
}

struct LocationPickerView: View {
    let language: ParchiLanguage
    let selection: String
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var device = OnboardingLocationPicker()
    private var cities: [(String, String)] { [("Muradnagar", "मुरादनगर"), ("Meerut", "मेरठ")] }
    private func text(_ en: String, _ hi: String) -> String { language.text(en, hi) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text(text("Where do you need care?", "आपको कहाँ सेवा चाहिए?"))
                        .font(.title2.bold()).accessibilityAddTraits(.isHeader)
                    HStack {
                        Image(systemName: "magnifyingglass").accessibilityHidden(true)
                        TextField(text("Area, city or PIN code", "इलाका, शहर या पिन कोड"), text: $query)
                            .accessibilityIdentifier("location.query")
                            .onSubmit { chooseQuery() }
                    }.modifier(ParchiFieldStyle())
                    Button { device.request() } label: {
                        HStack {
                            Image(systemName: "location.fill").accessibilityHidden(true)
                            Text(device.busy ? text("Finding your location…", "आपकी लोकेशन खोज रहे हैं…") : text("Use current location", "वर्तमान लोकेशन इस्तेमाल करें"))
                            Spacer()
                            if device.busy { ProgressView() }
                        }.frame(minHeight: 44)
                    }.disabled(device.busy).accessibilityIdentifier("location.current")
                    if device.failed {
                        FieldError(message: text("Location is unavailable. Enter your area or choose a city instead.", "लोकेशन उपलब्ध नहीं है। अपना इलाका लिखें या शहर चुनें।"))
                    }
                    Text(text("Or choose an area", "या इलाका चुनें")).font(.subheadline).foregroundStyle(ParchiTheme.muted)
                    ForEach(cities, id: \.0) { city in
                        if query.isEmpty || city.0.localizedCaseInsensitiveContains(query) || city.1.contains(query) {
                            Button { choose(text(city.0, city.1) + text(", Uttar Pradesh", ", उत्तर प्रदेश")) } label: {
                                HStack {
                                    Image(systemName: "mappin.and.ellipse").foregroundStyle(ParchiTheme.orange)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(text(city.0, city.1)).font(.body.weight(.semibold))
                                        Text(text("Uttar Pradesh", "उत्तर प्रदेश")).font(.caption).foregroundStyle(ParchiTheme.muted)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").accessibilityHidden(true)
                                }.frame(minHeight: 54)
                            }.buttonStyle(.plain).accessibilityIdentifier("location.\(city.0)")
                            Divider()
                        }
                    }
                    Text(text("Enter your area to select it. Live place search is not connected in this standalone UI.", "अपना इलाका लिखकर चुनें। इस अलग UI में लाइव सर्च नहीं जुड़ी है।"))
                        .font(.caption).foregroundStyle(ParchiTheme.muted)
                    ParchiPrimaryButton(title: text("Use this location", "यह लोकेशन चुनें")) { chooseQuery() }
                        .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                        .accessibilityIdentifier("location.select")
                }.padding(24)
            }
            .background(ParchiTheme.cream.ignoresSafeArea()).foregroundStyle(ParchiTheme.ink)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(text("Close", "बंद करें")) { dismiss() }
                }
            }
            .onChange(of: device.coordinate?.latitude) { _, _ in
                guard let point = device.coordinate else { return }
                // Coordinates are truthful until the shared app's location adapter supplies an area name.
                choose(text("Current location", "वर्तमान लोकेशन") + String(format: " · %.4f, %.4f", point.latitude, point.longitude))
            }
        }.tint(ParchiTheme.orange).onAppear { query = selection }
    }
    private func chooseQuery() {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.isEmpty { choose(value) }
    }
    private func choose(_ value: String) { onSelect(value); dismiss() }
}
