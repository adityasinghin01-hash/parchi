// Apple Maps search over a grid of points around a city centre, de-duplicated.
// Usage: places_grid <city> <lat> <lon> <radius_km> <out.json>
import Foundation
import MapKit

let a = CommandLine.arguments
let city = a[1]
let center = CLLocationCoordinate2D(latitude: Double(a[2])!, longitude: Double(a[3])!)
let radiusKm = Double(a[4])!
let outPath = a[5]

let spacingKm = 3.0
let boxMeters = 5000.0
let queries: [(String, String)] = [
    ("pharmacy", "pharmacy"), ("chemist", "pharmacy"), ("medical store", "pharmacy"),
    ("Jan Aushadhi Kendra", "pharmacy"), ("pathology lab", "lab"), ("diagnostic centre", "lab"),
]

// 1° latitude ≈ 111.32 km; longitude shrinks with cos(lat).
let kmPerLat = 111.32
let kmPerLon = 111.32 * cos(center.latitude * .pi / 180)
var points: [CLLocationCoordinate2D] = []
var y = -radiusKm
while y <= radiusKm {
    var x = -radiusKm
    while x <= radiusKm {
        if (x * x + y * y).squareRoot() <= radiusKm {
            points.append(CLLocationCoordinate2D(latitude: center.latitude + y / kmPerLat, longitude: center.longitude + x / kmPerLon))
        }
        x += spacingKm
    }
    y += spacingKm
}

struct Place { var name: String; var phone: String; var category: String; var lat: Double; var lon: Double; var url: String; var kind: String; var queries: Set<String> }
var found: [String: Place] = [:]
var requests = 0, errors = 0

func search(_ q: String, kind: String, at p: CLLocationCoordinate2D) async {
    let req = MKLocalSearch.Request()
    req.naturalLanguageQuery = q
    req.region = MKCoordinateRegion(center: p, latitudinalMeters: boxMeters, longitudinalMeters: boxMeters)
    req.resultTypes = .pointOfInterest
    for attempt in 0..<3 {
        requests += 1
        do {
            let resp = try await MKLocalSearch(request: req).start()
            for item in resp.mapItems {
                let loc = item.placemark.coordinate
                let key = "\((item.name ?? "").lowercased())|\(String(format: "%.4f,%.4f", loc.latitude, loc.longitude))"
                if found[key] == nil {
                    found[key] = Place(name: item.name ?? "", phone: item.phoneNumber ?? "", category: item.pointOfInterestCategory?.rawValue ?? "",
                                       lat: loc.latitude, lon: loc.longitude, url: item.url?.absoluteString ?? "", kind: kind, queries: [])
                }
                found[key]!.queries.insert(q)
            }
            return
        } catch {
            errors += 1
            // MapKit throttles bursts; back off and retry.
            try? await Task.sleep(nanoseconds: UInt64(5_000_000_000 * (attempt + 1)))
        }
    }
}

for p in points {
    for (q, kind) in queries {
        await search(q, kind: kind, at: p)
        try? await Task.sleep(nanoseconds: 1_300_000_000)
    }
}

let here = CLLocation(latitude: center.latitude, longitude: center.longitude)
let rows: [[String: Any]] = found.values.map { p in
    ["city": city, "name": p.name, "phone": p.phone, "category": p.category, "kind": p.kind,
     "jan_aushadhi": p.name.lowercased().contains("jan aushadhi") || p.name.lowercased().contains("janaushadhi") || p.name.lowercased().contains("pmbjk"),
     "lat": p.lat, "lon": p.lon, "dist_from_centre_m": Int(CLLocation(latitude: p.lat, longitude: p.lon).distance(from: here)),
     "url": p.url, "queries": p.queries.sorted()]
}.sorted { ($0["dist_from_centre_m"] as! Int) < ($1["dist_from_centre_m"] as! Int) }
let iso = ISO8601DateFormatter().string(from: Date())
let out: [String: Any] = ["city": city, "centre": [center.latitude, center.longitude], "radius_km": radiusKm, "grid_points": points.count,
                          "requests": requests, "errors": errors, "source": "Apple Maps via MapKit MKLocalSearch", "collected_at": iso, "places": rows]
try JSONSerialization.data(withJSONObject: out, options: [.prettyPrinted, .sortedKeys]).write(to: URL(fileURLWithPath: outPath))
print("\(city): \(rows.count) places, \(points.count) grid points, \(requests) requests, \(errors) errors")
