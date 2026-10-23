// Counts real nearby pharmacies / labs that Apple Maps returns around a point.
// Usage: swift mapkit_nearby.swift <lat> <lon> <radius_m> <out.json>
import Foundation
import MapKit

let a = CommandLine.arguments
let center = CLLocationCoordinate2D(latitude: Double(a[1])!, longitude: Double(a[2])!)
let radius = Double(a[3])!
let outPath = a[4]

let queries = ["pharmacy", "chemist", "medical store", "Jan Aushadhi Kendra",
               "pathology lab", "diagnostic centre", "blood test lab", "Dr Lal PathLabs", "Thyrocare"]

func search(_ q: String) async -> [[String: Any]] {
    let req = MKLocalSearch.Request()
    req.naturalLanguageQuery = q
    req.region = MKCoordinateRegion(center: center, latitudinalMeters: radius * 2, longitudinalMeters: radius * 2)
    req.resultTypes = .pointOfInterest
    do {
        let resp = try await MKLocalSearch(request: req).start()
        let here = CLLocation(latitude: center.latitude, longitude: center.longitude)
        return resp.mapItems.map { item in
            let loc = item.placemark.location ?? here
            return ["name": item.name ?? "",
                    "phone": item.phoneNumber ?? "",
                    "category": item.pointOfInterestCategory?.rawValue ?? "",
                    "lat": loc.coordinate.latitude, "lon": loc.coordinate.longitude,
                    "dist_m": Int(loc.distance(from: here)),
                    "url": item.url?.absoluteString ?? ""]
        }
    } catch {
        return [["error": "\(error)"]]
    }
}

var all: [String: Any] = [:]
for q in queries {
    let r = await search(q)
    all[q] = r
    let within = r.filter { (($0["dist_m"] as? Int) ?? Int.max) <= Int(radius) }.count
    print("\(q): \(r.count) results, \(within) within \(Int(radius)) m")
}
let data = try JSONSerialization.data(withJSONObject: all, options: [.prettyPrinted])
try data.write(to: URL(fileURLWithPath: outPath))
