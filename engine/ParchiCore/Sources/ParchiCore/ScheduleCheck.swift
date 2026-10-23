import Foundation

/// Schedule H1 / X of the Drugs Rules: sold only on a valid prescription, with records kept.
/// Parchi never routes these to delivery: the UI says "buy in person with the original parchi".
public enum Schedule: String, Codable, Sendable, Equatable {
    case h1 = "H1"
    case x = "X"

    public var inPersonMessage: String { "Buy in person with the original parchi" }
}

/// One row of `schedule_h1_x.json`.
public struct ScheduleEntry: Codable, Sendable, Equatable {
    public let schedule: Schedule
    public let salt: String
    public let sourceURL: String
    public let date: String?
    public let dateSeen: String?

    public init(schedule: Schedule, salt: String, sourceURL: String = "", date: String? = nil, dateSeen: String? = nil) {
        self.schedule = schedule
        self.salt = salt
        self.sourceURL = sourceURL
        self.date = date
        self.dateSeen = dateSeen
    }

    enum CodingKeys: String, CodingKey {
        case schedule, salt, date
        case sourceURL = "source_url"
        case dateSeen = "date_seen"
    }
}

/// One row of `brand_schedule.json` (brand -> the H1/X salt found in its real composition).
public struct BrandScheduleEntry: Codable, Sendable, Equatable {
    public let schedule: Schedule
    public let salt: String

    public init(schedule: Schedule, salt: String) {
        self.schedule = schedule
        self.salt = salt
    }
}

public struct ScheduleCheck: Sendable {
    private let bySalt: [String: ScheduleEntry]
    private let byBrand: [String: BrandScheduleEntry]

    public init(entries: [ScheduleEntry], brands: [String: BrandScheduleEntry] = [:]) {
        var map: [String: ScheduleEntry] = [:]
        for entry in entries {
            let key = Self.saltKey(entry.salt)
            // X is stricter than H1 if a salt were ever listed twice.
            if let existing = map[key], existing.schedule == .x { continue }
            map[key] = entry
        }
        bySalt = map
        var brandMap: [String: BrandScheduleEntry] = [:]
        for (brand, entry) in brands { brandMap[Self.brandKey(brand)] = entry }
        byBrand = brandMap
    }

    public init(scheduleJSON: Data, brandJSON: Data? = nil) throws {
        let decoder = JSONDecoder()
        let entries = try decoder.decode([ScheduleEntry].self, from: scheduleJSON)
        let brands = try brandJSON.map { try decoder.decode([String: BrandScheduleEntry].self, from: $0) } ?? [:]
        self.init(entries: entries, brands: brands)
    }

    /// H1/X schedule for one salt name ("tramadol", "Ketamine HCl", "ALPRAZOLAM 0.5 mg"), else nil.
    /// Case/space/punctuation-insensitive; strengths and "hydrochloride"/"HCl" suffixes are ignored.
    public func isInPersonOnly(salt: String) -> Schedule? {
        bySalt[Self.saltKey(salt)]?.schedule
    }

    /// Full row (source URL, gazette date) for the salt, for "why?" screens.
    public func entry(forSalt salt: String) -> ScheduleEntry? {
        bySalt[Self.saltKey(salt)]
    }

    /// Strictest schedule among the salts of a composition such as "Paracetamol (325mg) + Tramadol (37.5mg)".
    public func isInPersonOnly(composition: String) -> Schedule? {
        let found = composition.split(separator: "+").compactMap { isInPersonOnly(salt: String($0)) }
        return found.contains(.x) ? .x : found.first
    }

    /// H1/X by brand (first word, letters only, like `Catalogue`), from real product compositions.
    /// A brand is listed when at least half of its active products contain an H1/X salt; the salts of the exact catalogue product
    /// the parchi matches are checked separately (`CatalogueMatch.schedule(using:)`), so a mixed brand line is not flagged as a whole.
    public func isInPersonOnly(brand: String) -> Schedule? {
        byBrand[Self.brandKey(brand)]?.schedule
    }

    public var saltCount: Int { bySalt.count }
    public var brandCount: Int { byBrand.count }

    static func brandKey(_ brand: String) -> String {
        let first = brand.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? brand
        return first.filter(\.isLetter).uppercased()
    }

    static func saltKey(_ salt: String) -> String {
        var text = ""
        var depth = 0
        for ch in salt.lowercased() {
            if ch == "(" { depth += 1; text.append(" ") }
            else if ch == ")" { depth = max(0, depth - 1) }
            else if depth == 0 { text.append(ch) }
        }
        let dropped: Set<String> = ["hydrochloride", "hcl", "mg", "mcg", "ug", "g", "ml", "iu"]
        let words = text.split(whereSeparator: { !($0.isLetter || $0.isNumber) })
            .map(String.init)
            .filter { !($0.first?.isNumber ?? true) && !dropped.contains($0) }
        return words.joined(separator: " ")
    }
}
