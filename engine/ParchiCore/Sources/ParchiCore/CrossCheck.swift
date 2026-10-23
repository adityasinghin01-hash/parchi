import Foundation

/// Cheque-style cross-validation: banks accept a cheque only when the amount in words agrees with
/// the amount in figures. Parchi accepts a read medicine only when the brand and the strength agree
/// with a product that really exists.
public enum CheckResult: Equatable, Sendable {
    /// Brand and strength match a real product.
    case confirmed(brand: String, strength: String)
    /// Brand exists but this strength does not; the real strengths are offered as one-tap choices.
    case strengthMismatch(brand: String, read: String, available: [String])
    /// Brand exists and no strength was read.
    case strengthMissing(brand: String, available: [String])
    /// Brand not in the catalogue; closest real brands are offered.
    case unknownBrand(read: String, suggestions: [String])
}

public struct Catalogue: Sendable {
    /// Upper-cased brand -> set of strengths seen in real product names (e.g. "TELMA" -> ["20", "40", "80"]).
    public let strengths: [String: Set<String>]

    public init(strengths: [String: Set<String>]) {
        self.strengths = strengths
    }

    /// Builds the catalogue from product names such as "Telma 40 Tablet" or "Pan 40mg Tablet".
    public init(productNames: [String]) {
        var map: [String: Set<String>] = [:]
        for name in productNames {
            let parts = name.split(separator: " ")
            guard let first = parts.first else { continue }
            let brand = first.filter(\.isLetter).uppercased()
            guard brand.count >= 3 else { continue }
            var set = map[brand, default: []]
            for part in parts.dropFirst() {
                let number = String(part.prefix { $0.isNumber || $0 == "." })
                if !number.isEmpty { set.insert(number) }
            }
            map[brand] = set
        }
        strengths = map
    }

    public func check(brand rawBrand: String, strength rawStrength: String?) -> CheckResult {
        let brand = rawBrand.filter(\.isLetter).uppercased()
        guard let known = strengths[brand] else {
            return .unknownBrand(read: rawBrand, suggestions: suggestions(for: brand))
        }
        let available = known.sorted { (Double($0) ?? 0) < (Double($1) ?? 0) }
        guard let raw = rawStrength, !raw.isEmpty else {
            return .strengthMissing(brand: brand, available: available)
        }
        let strength = String(raw.prefix { $0.isNumber || $0 == "." })
        if known.contains(strength) {
            return .confirmed(brand: brand, strength: strength)
        }
        return .strengthMismatch(brand: brand, read: strength, available: available)
    }

    /// Closest brands by edit distance, so a misread like "TELIA" offers "TELMA".
    public func suggestions(for brand: String, limit: Int = 3) -> [String] {
        strengths.keys
            .filter { abs($0.count - brand.count) <= 2 }
            .map { ($0, editDistance($0, brand)) }
            .filter { $0.1 <= 2 }
            .sorted { ($0.1, $0.0) < ($1.1, $1.0) }
            .prefix(limit)
            .map(\.0)
    }
}

func editDistance(_ a: String, _ b: String) -> Int {
    let a = Array(a), b = Array(b)
    if a.isEmpty { return b.count }
    if b.isEmpty { return a.count }
    var previous = Array(0...b.count)
    var current = [Int](repeating: 0, count: b.count + 1)
    for i in 1...a.count {
        current[0] = i
        for j in 1...b.count {
            current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
        }
        swap(&previous, &current)
    }
    return previous[b.count]
}
