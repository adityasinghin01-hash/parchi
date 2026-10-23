import Foundation
import Testing
@testable import ParchiCore

@Test func sixCitiesInTheFallbackPicker() {
    #expect(Cities.all.map(\.name) == ["Muradnagar", "Meerut", "Modinagar", "Ghaziabad", "Hapur", "Noida"])
    #expect(Cities.named("meerut")?.latitude == 28.9963)
    #expect(Cities.named("Delhi") == nil)
}

@Test func nearestCityFromAPoint() {
    #expect(Cities.nearest(latitude: 28.752441, longitude: 77.49902).name == "Muradnagar") // KIET
    #expect(Cities.nearest(latitude: 28.99, longitude: 77.70).name == "Meerut")
    #expect(Cities.nearest(latitude: 28.60, longitude: 77.30).name == "Noida")
    #expect(Cities.nearest(latitude: 28.6712, longitude: 77.4120).name == "Ghaziabad")        // exactly on a centre
    #expect(Cities.nearest(latitude: 28.74, longitude: 77.77).name == "Hapur")
}

@Test func nearestFromOutsideTheListAnswers() {
    #expect(Cities.nearest(latitude: 28.61, longitude: 77.21).name == "Noida")      // central Delhi
    #expect(!Cities.nearest(latitude: 37.77, longitude: -122.42).name.isEmpty)       // Simulator default (California)
}

@Test func distanceIsSane() {
    let km = Cities.distanceKm(28.7734, 77.5034, 28.9963, 77.7062) // Muradnagar → Meerut
    #expect(km > 25 && km < 40)
    #expect(Cities.distanceKm(28.0, 77.0, 28.0, 77.0) == 0)
}

@Test func servedArea() {
    #expect(Cities.isServed(latitude: 28.752441, longitude: 77.49902))   // KIET
    #expect(Cities.isServed(latitude: 28.61, longitude: 77.21))          // Delhi
    #expect(!Cities.isServed(latitude: 37.77, longitude: -122.42))       // Simulator default
}

@Test func nearestToACity() {
    #expect(Cities.nearest(to: Cities.named("Muradnagar")!).name == "Modinagar")
    #expect(Cities.nearest(to: Cities.named("Noida")!).name == "Ghaziabad")
}
