import CoreLocation
import Foundation
import MapKit
import Observation
import ParchiCore

/// One place on the Plan Map / in its list. MapKit results live in memory only (never bundled, saved or logged).
struct MapShop: Identifiable, Hashable {
    enum Kind: Hashable { case chemist, janAushadhi }

    let id: String
    let name: String
    var address: String?
    var phone: String?
    var distanceM: Int?
    var latitude: Double?
    var longitude: Double?
    var kind: Kind
    /// Set for shops from the plan data (no coordinates, so list only). Replies from "Ask nearby shops" map back by this id.
    var planSellerID: String?
    /// The MapKit result, so Directions can hand it to Maps. Not Hashable, so it is kept out of ==/hash.
    var mapItem: MKMapItem?

    static func == (a: MapShop, b: MapShop) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var distanceText: String? {
        guard let distanceM else { return nil }
        return distanceM < 1000 ? "\(distanceM) m" : String(format: "%.1f km", Double(distanceM) / 1000)
    }

    /// Jan Aushadhi Kendras are found by name ("Pradhan Mantri Bhartiya Janaushadhi Kendra", "Jan Aushadhi Kendra", "PMBJK").
    static func kind(forName name: String) -> Kind {
        let flat = name.lowercased().filter { $0.isLetter || $0.isNumber }
        return ["janaushadhi", "pmbjk", "pmbjp", "pmbi"].contains { flat.contains($0) } ? .janAushadhi : .chemist
    }

    /// Stable id for one place (name + ~10 m grid), so the same shop from two searches is one row.
    static func makeID(name: String, latitude: Double, longitude: Double) -> String {
        let flat = name.lowercased().filter { $0.isLetter || $0.isNumber }
        return "map-\(flat)-\(Int((latitude * 10_000).rounded()))-\(Int((longitude * 10_000).rounded()))"
    }
}

/// Live MapKit search for the Plan Map. Results stay in this object (memory); nothing is written to disk.
@MainActor
@Observable
final class ShopSearchModel {
    enum State: Equatable { case idle, loading, loaded, failed }

    /// The three searches the brief asks for.
    static let queries = ["pharmacy", "chemist", "Jan Aushadhi Kendra"]
    static let maxShops = 30
    nonisolated static let timeout: Duration = .seconds(12)

    private(set) var state: State = .idle
    private(set) var shops: [MapShop] = []
    private var loadedKey: String?

    /// Launch aids for tests (no Apple data involved): `-mapTestShops 1` = three clearly fake shops, `-mapOffline 1` = search fails.
    static var testShops: Bool { UserDefaults.standard.bool(forKey: "mapTestShops") }
    static var forceOffline: Bool { UserDefaults.standard.bool(forKey: "mapOffline") }

    /// Test hook: replaces the MapKit search (query, region) -> items (nil = failed). nil = the real MapKit search.
    nonisolated(unsafe) static var searchOverride: (@Sendable (String, MKCoordinateRegion) async -> [MKMapItem]?)?

    /// Bumped by every `load`; a search that finishes after a newer one started (or the centre moved) is dropped.
    @ObservationIgnored private var generation = 0

    func load(around centre: City, force: Bool = false) async {
        let key = "\(centre.latitude),\(centre.longitude)"
        if !force, loadedKey == key, state == .loaded || state == .loading { return }
        // A new search centre: the old city's shops must not stay tappable under the new city while the searches run.
        if loadedKey != key { shops = [] }
        generation += 1
        let mine = generation
        loadedKey = key
        state = .loading
        if Self.forceOffline { shops = []; state = .failed; return }
        if Self.testShops { shops = Self.fixtures(around: centre); state = .loaded; return }

        let region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: centre.latitude, longitude: centre.longitude),
                                        latitudinalMeters: 6000, longitudinalMeters: 6000)
        let origin = CLLocation(latitude: centre.latitude, longitude: centre.longitude)
        var found: [String: MapShop] = [:]
        var anySucceeded = false
        for query in Self.queries {
            guard stillCurrent(mine) else { return abandon(mine) }
            guard let items = await Self.search(query, in: region) else { continue }
            anySucceeded = true
            for item in items {
                let coordinate = item.placemark.coordinate
                guard CLLocationCoordinate2DIsValid(coordinate), let name = item.name, !name.isEmpty else { continue }
                let id = MapShop.makeID(name: name, latitude: coordinate.latitude, longitude: coordinate.longitude)
                guard found[id] == nil else { continue }
                let distance = Int(origin.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)))
                found[id] = MapShop(id: id, name: name, address: Self.address(of: item.placemark), phone: item.phoneNumber,
                                    distanceM: distance, latitude: coordinate.latitude, longitude: coordinate.longitude,
                                    kind: query.hasPrefix("Jan") ? .janAushadhi : MapShop.kind(forName: name), mapItem: item)
            }
        }
        guard stillCurrent(mine) else { return abandon(mine) }
        guard anySucceeded else { shops = []; state = .failed; return }
        shops = Array(found.values.sorted { ($0.distanceM ?? .max) < ($1.distanceM ?? .max) }.prefix(Self.maxShops))
        state = .loaded
    }

    private func stillCurrent(_ mine: Int) -> Bool { !Task.isCancelled && mine == generation }

    /// This search was cancelled or replaced. If nothing replaced it, forget that it was running so the next `load` starts again
    /// (otherwise the model would stay in \"loading\" for a centre nobody is searching any more).
    private func abandon(_ mine: Int) {
        guard mine == generation else { return }
        shops = []
        state = .idle
        loadedKey = nil
    }

    /// nil = the search failed (no internet, MapKit error, timeout). [] = it worked and found nothing.
    nonisolated private static func search(_ query: String, in region: MKCoordinateRegion) async -> [MKMapItem]? {
        if let override = searchOverride { return await override(query, region) }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = region
        request.resultTypes = .pointOfInterest
        let search = MKLocalSearch(request: request)
        // Cancelling the task (the centre changed, the screen closed) cancels the running Apple Maps search too.
        return await withTaskCancellationHandler {
            await withTaskGroup(of: [MKMapItem]?.self) { group in
                group.addTask { try? await search.start().mapItems }
                group.addTask {
                    try? await Task.sleep(for: timeout)
                    search.cancel()
                    return nil
                }
                let first = await group.next() ?? nil
                group.cancelAll()
                return first
            }
        } onCancel: {
            search.cancel()
        }
    }

    private static func address(of placemark: MKPlacemark) -> String? {
        let parts = [placemark.subThoroughfare, placemark.thoroughfare, placemark.subLocality, placemark.locality]
            .compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    /// Fake shops for UI tests only (names say so). Placed 400 m to 1.2 km from the centre.
    private static func fixtures(around centre: City) -> [MapShop] {
        let specs: [(String, MapShop.Kind, Double, Double, String?)] = [
            ("Test Chemist A", .chemist, 0.004, 0.002, "+91 98765 43210"),
            ("Test Chemist B", .chemist, -0.006, 0.005, nil),
            ("Test Jan Aushadhi Kendra", .janAushadhi, 0.008, -0.006, nil),
        ]
        let origin = CLLocation(latitude: centre.latitude, longitude: centre.longitude)
        return specs.map { name, kind, dLat, dLon, phone in
            let lat = centre.latitude + dLat, lon = centre.longitude + dLon
            return MapShop(id: MapShop.makeID(name: name, latitude: lat, longitude: lon), name: name, address: "Test address (not a real shop)",
                           phone: phone, distanceM: Int(origin.distance(from: CLLocation(latitude: lat, longitude: lon))),
                           latitude: lat, longitude: lon, kind: kind, planSellerID: nil, mapItem: nil)
        }
    }
}
