import Foundation

/// K18: the brands a person can type in by hand. Built from the bundled `brand_mrp.json`, so every suggestion can be PRICED
/// (the same file the plan reads its catalogue MRP from). Nothing here is invented: strengths are the ones in the catalogue.
struct ManualBrandIndex: Sendable {
    static let maxSuggestions = 20

    /// Brand keys as in the catalogue: letters only, upper case ("DOLO", "MONTAIRLC"), at least 3 letters, sorted.
    /// (Anything shorter or with a digit can never be matched to a price, so it is never suggested.)
    let brands: [String]
    private let entries: [String: String]

    init?(json data: Data) {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let raw = root["brands"] as? [String: String] else { return nil }
        var kept: [String: String] = [:]
        kept.reserveCapacity(raw.count)
        for (key, value) in raw where Self.isPriceable(key) { kept[key] = value }
        entries = kept
        brands = kept.keys.sorted()
    }

    /// Same rule as `CatalogueMRPIndex.brandKey`: the key is the written name's letters, upper-cased, at least 3 of them.
    private static func isPriceable(_ key: String) -> Bool {
        key.count >= 3 && key.allSatisfy { $0.isASCII && $0.isLetter && $0.isUppercase }
    }

    /// "Montair LC" -> "MONTAIRLC", "dolo" -> "DOLO". Letters only, like the catalogue's own key.
    static func key(for text: String) -> String {
        String(text.filter(\.isLetter)).uppercased()
    }

    func contains(brand text: String) -> Bool { entries[Self.key(for: text)] != nil }

    /// Live suggestions: brands that start with what was typed first, then brands that contain it; each group alphabetical;
    /// case-insensitive; at most 20. Empty for an empty query.
    func suggestions(for query: String) -> [String] {
        let q = Self.key(for: query)
        guard !q.isEmpty else { return [] }
        var result: [String] = []
        // `brands` is sorted: the prefix matches are one contiguous run, found by binary search.
        var lo = 0, hi = brands.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if brands[mid] < q { lo = mid + 1 } else { hi = mid }
        }
        var i = lo
        while i < brands.count, brands[i].hasPrefix(q), result.count < Self.maxSuggestions {
            result.append(brands[i])
            i += 1
        }
        if result.count < Self.maxSuggestions {
            for brand in brands where !brand.hasPrefix(q) && brand.contains(q) {
                result.append(brand)
                if result.count == Self.maxSuggestions { break }
            }
        }
        return result
    }

    /// The strengths this brand really has in the catalogue ("40", "0.25"), smallest first. Empty when none of its products
    /// has a number in the name (then the screen asks for a number).
    func strengths(brand text: String) -> [String] {
        guard let entry = entries[Self.key(for: text)] else { return [] }
        var seen = Set<String>()
        var list: [String] = []
        for row in entry.split(separator: ";") {
            let strength = String(row.prefix { $0 != "," })
            if !strength.isEmpty, seen.insert(strength).inserted { list.append(strength) }
        }
        return list.sorted { (Double($0) ?? 0, $0) < (Double($1) ?? 0, $1) }
    }

    /// What goes on the Confirm line for a catalogue brand: "Dolo", "Montairlc" (the catalogue key has no spaces).
    static func displayName(forBrand key: String) -> String { key.capitalized }
}

/// Loads `ManualBrandIndex` once, off the main thread. The first call parses the 6 MB file; later calls return at once.
actor ManualBrandStore {
    static let shared = ManualBrandStore()
    private var index: ManualBrandIndex?
    private var task: Task<ManualBrandIndex?, Never>?

    func load() async -> ManualBrandIndex? {
        if let index { return index }
        if let task { return await task.value }
        let task = Task.detached(priority: .userInitiated) { () -> ManualBrandIndex? in
            guard let url = Bundle.main.url(forResource: "brand_mrp", withExtension: "json"),
                  let data = try? Data(contentsOf: url) else { return nil }
            return ManualBrandIndex(json: data)
        }
        self.task = task
        let loaded = await task.value
        index = loaded
        self.task = nil
        return loaded
    }
}
