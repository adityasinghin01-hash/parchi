import Foundation

/// A city the patient can pick when location is off or denied (gap U1/U15).
public struct City: Codable, Hashable, Sendable, Identifiable {
    public var name: String
    public var latitude: Double
    public var longitude: Double
    public var id: String { name }

    public init(name: String, latitude: Double, longitude: Double) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
    }
}

public enum Cities {
    /// Centres from the places scripts in parchi-research (osm_places.py) and the brief.
    public static let all: [City] = [
        City(name: "Muradnagar", latitude: 28.7734, longitude: 77.5034),
        City(name: "Meerut", latitude: 28.9963, longitude: 77.7062),
        City(name: "Modinagar", latitude: 28.8321, longitude: 77.5771),
        City(name: "Ghaziabad", latitude: 28.6712, longitude: 77.4120),
        City(name: "Hapur", latitude: 28.7395, longitude: 77.7790),
        City(name: "Noida", latitude: 28.5706, longitude: 77.3272),
    ]

    /// KIET campus, used when there is neither a location nor a chosen city.
    public static let defaultCentre = City(name: "KIET, Muradnagar", latitude: 28.752441, longitude: 77.49902)

    public static func named(_ name: String) -> City? {
        all.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    /// Straight-line distance in km (haversine).
    public static func distanceKm(_ aLat: Double, _ aLon: Double, _ bLat: Double, _ bLon: Double) -> Double {
        let radius = 6371.0
        let dLat = (bLat - aLat) * .pi / 180
        let dLon = (bLon - aLon) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2)
            + cos(aLat * .pi / 180) * cos(bLat * .pi / 180) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * radius * asin(min(1, sqrt(h)))
    }

    /// The listed city whose centre is closest to a point.
    public static func nearest(latitude: Double, longitude: Double) -> City {
        all.min { distanceKm(latitude, longitude, $0.latitude, $0.longitude) < distanceKm(latitude, longitude, $1.latitude, $1.longitude) }
            ?? defaultCentre
    }

    /// Farther than this from every listed city and we are outside the area we cover (for example the
    /// Simulator's default California location), so the app asks for a city instead of using the fix.
    public static let serviceRadiusKm = 100.0

    public static func isServed(latitude: Double, longitude: Double) -> Bool {
        let city = nearest(latitude: latitude, longitude: longitude)
        return distanceKm(latitude, longitude, city.latitude, city.longitude) <= serviceRadiusKm
    }

    /// The listed city closest to another city (never itself). Handy for "other cities near you".
    public static func nearest(to city: City) -> City {
        all.filter { $0.name != city.name }
            .min { distanceKm(city.latitude, city.longitude, $0.latitude, $0.longitude) < distanceKm(city.latitude, city.longitude, $1.latitude, $1.longitude) }
            ?? defaultCentre
    }
}
