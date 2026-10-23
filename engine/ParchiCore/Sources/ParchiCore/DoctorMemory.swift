import Foundation

/// WHO "P-drugs": every doctor prescribes mostly from a personal list. Parchi learns that list from
/// confirmed scans (doctor identified from the letterhead) and uses it to break ties when a
/// handwritten word could be several brands.
public struct DoctorMemory: Codable, Sendable {
    /// doctor key -> brand -> times confirmed
    public private(set) var counts: [String: [String: Int]] = [:]

    public init() {}

    public mutating func record(doctor: String, confirmedBrands: [String]) {
        let key = doctor.lowercased()
        for brand in confirmedBrands {
            counts[key, default: [:]][brand.uppercased(), default: 0] += 1
        }
    }

    /// Re-ranks reading candidates (brand, model score 0...1): brands this doctor has written before
    /// get a boost proportional to how often, so an ambiguous scrawl resolves to the doctor's usual brand.
    public func rerank(doctor: String, candidates: [(brand: String, score: Double)], weight: Double = 0.3) -> [(brand: String, score: Double)] {
        let history = counts[doctor.lowercased()] ?? [:]
        let total = Double(history.values.reduce(0, +))
        guard total > 0 else { return candidates.sorted { $0.score > $1.score } }
        return candidates
            .map { candidate in
                let prior = Double(history[candidate.brand.uppercased()] ?? 0) / total
                return (candidate.brand, candidate.score + weight * prior)
            }
            .sorted { $0.1 > $1.1 }
    }
}
