import Foundation
import os
import ParchiCore

// The real data collected on 23 Oct 2026 (labs, lab prices, product links, test names, H1/X), built by
// tools/build_app_data.py into engine/catalogue/*.json and bundled with the app. Money is integer paise.
// Every price carries a PriceSource (kind + date) so the UI can say where it is from and when.

struct LabOption: Codable, Equatable, Identifiable {
    enum HomeCollection: String, Codable { case yes, no, unknown }

    let city: String
    let lab: String
    let homeCollection: HomeCollection
    let bookingURL: String?
    let phone: String?
    let sourceURL: String?
    let dateSeen: String?

    var id: String { "\(city)|\(lab)" }

    enum CodingKeys: String, CodingKey {
        case city, lab, phone
        case homeCollection = "home_collection"
        case bookingURL = "booking_url"
        case sourceURL = "source_url"
        case dateSeen = "date_seen"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        city = try c.decode(String.self, forKey: .city)
        lab = try c.decode(String.self, forKey: .lab)
        homeCollection = (try? c.decode(HomeCollection.self, forKey: .homeCollection)) ?? .unknown
        bookingURL = try c.decodeIfPresent(String.self, forKey: .bookingURL)
        phone = try c.decodeIfPresent(String.self, forKey: .phone)
        sourceURL = try c.decodeIfPresent(String.self, forKey: .sourceURL)
        dateSeen = try c.decodeIfPresent(String.self, forKey: .dateSeen)
    }
}

struct LabPriceRecord: Codable, Equatable {
    let pricePaise: Int
    let priceText: String?
    let sourceURL: String?
    let dateSeen: String?

    enum CodingKeys: String, CodingKey {
        case pricePaise = "price_paise"
        case priceText = "price_text"
        case sourceURL = "source_url"
        case dateSeen = "date_seen"
    }
}

/// One seller's product page for one medicine. A missing price stays nil: never invented.
struct ProductLink: Codable, Equatable {
    let productURL: String
    let pricePaise: Int?
    let mrpPaise: Int?
    let dateSeen: String?

    enum CodingKeys: String, CodingKey {
        case productURL = "product_url"
        case pricePaise = "price_paise"
        case mrpPaise = "mrp_paise"
        case dateSeen = "date_seen"
    }
}

struct DataVersion: Codable, Equatable {
    struct Counts: Codable, Equatable {
        let labs: Int
        let labPrices: Int
        let productLinks: Int
        let productLinksWithPrice: Int
        let testsCanonical: Int
        let scheduleH1X: Int
        let brandSchedule: Int?

        enum CodingKeys: String, CodingKey {
            case labs
            case labPrices = "lab_prices"
            case productLinks = "product_links"
            case productLinksWithPrice = "product_links_with_price"
            case testsCanonical = "tests_canonical"
            case scheduleH1X = "schedule_h1_x"
            case brandSchedule = "brand_schedule"
        }
    }

    let inputFolder: String
    let buildDate: String?
    let counts: Counts

    enum CodingKeys: String, CodingKey {
        case inputFolder = "input_folder"
        case buildDate = "build_date"
        case counts
    }
}

/// Loads the bundled JSON once. A missing or broken file gives empty data and a logged warning, never a crash.
final class AppData: Sendable {
    static let shared = AppData()

    private static let log = Logger(subsystem: "in.tessanova.parchi", category: "AppData")

    let dataVersion: DataVersion?
    /// For the Confirm screen: written test name -> exact / ask / unknown.
    let testCatalogue: TestCatalogue
    /// H1/X: the UI says "buy in person with the original parchi".
    let scheduleCheck: ScheduleCheck

    private let labs: [LabOption]
    private let labPrices: [String: [String: [String: LabPriceRecord]]]   // city -> lab -> test -> price
    private let links: [String: [String: ProductLink]]                      // medicine_key -> seller -> link

    /// Loads from the app bundle (JSON files sit at the bundle root).
    convenience init(bundle: Bundle = .main) {
        self.init(reader: { name in bundle.url(forResource: name, withExtension: "json") })
    }

    /// Loads from a folder of JSON files (tests, previews).
    convenience init(directory: URL) {
        self.init(reader: { name in directory.appendingPathComponent("\(name).json") })
    }

    private init(reader: (String) -> URL?) {
        func load<T: Decodable>(_ name: String, as type: T.Type) -> T? {
            guard let url = reader(name) else {
                AppData.log.warning("\(name, privacy: .public).json is not in the app bundle; using empty data")
                return nil
            }
            do {
                return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
            } catch {
                AppData.log.warning("\(name, privacy: .public).json could not be read (\(error.localizedDescription, privacy: .public)); using empty data")
                return nil
            }
        }
        func loadData(_ name: String) -> Data? {
            guard let url = reader(name) else {
                AppData.log.warning("\(name, privacy: .public).json is not in the app bundle; using empty data")
                return nil
            }
            return try? Data(contentsOf: url)
        }

        dataVersion = load("DATA_VERSION", as: DataVersion.self)
        labs = load("labs", as: [LabOption].self) ?? []
        labPrices = load("lab_prices", as: [String: [String: [String: LabPriceRecord]]].self) ?? [:]
        links = load("product_links", as: [String: [String: ProductLink]].self) ?? [:]

        if let data = loadData("tests_canonical"), let catalogue = try? TestCatalogue(json: data) {
            testCatalogue = catalogue
        } else {
            AppData.log.warning("tests_canonical.json missing or unreadable; test names will all be unknown")
            testCatalogue = TestCatalogue(tests: [])
        }

        if let schedule = loadData("schedule_h1_x") {
            // brand_schedule.json is optional: without it only salt-level checks work.
            let brands = loadData("brand_schedule")
            if let check = try? ScheduleCheck(scheduleJSON: schedule, brandJSON: brands) {
                scheduleCheck = check
            } else if let check = try? ScheduleCheck(scheduleJSON: schedule) {
                AppData.log.warning("brand_schedule.json unreadable; brand-level H1/X check is off")
                scheduleCheck = check
            } else {
                AppData.log.warning("schedule_h1_x.json unreadable; H1/X check is off")
                scheduleCheck = ScheduleCheck(entries: [])
            }
        } else {
            scheduleCheck = ScheduleCheck(entries: [])
        }
    }

    // MARK: Labs

    /// Confirmed lab chains in a city (case-insensitive), by name. Empty when we have none (e.g. nothing for a town).
    func labOptions(city: String) -> [LabOption] {
        labs.filter { $0.city.caseInsensitiveCompare(city) == .orderedSame }
            .sorted { $0.lab < $1.lab }
    }

    /// Price of one lab for one canonical test, with where/when it was seen.
    func labPrice(city: String, lab: String, test: String) -> (paise: Int, source: PriceSource)? {
        guard let record = record(city: city, lab: lab, test: test) else { return nil }
        return Self.priced(record)
    }

    /// Every lab's price for the test in the city, cheapest first.
    func labPrices(city: String, test: String) -> [(lab: String, paise: Int, source: PriceSource)] {
        guard let byLab = value(in: labPrices, key: city) else { return [] }
        return byLab.compactMap { lab, tests -> (lab: String, paise: Int, source: PriceSource)? in
            guard let record = value(in: tests, key: test), let priced = Self.priced(record) else { return nil }
            return (lab, priced.paise, priced.source)
        }
        .sorted { ($0.paise, $0.lab) < ($1.paise, $1.lab) }
    }

    /// Cheapest lab price for the test in the city (nil if we have none: do not copy prices from another city).
    func labPrice(city: String, test: String) -> (paise: Int, source: PriceSource)? {
        labPrices(city: city, test: test).first.map { ($0.paise, $0.source) }
    }

    // MARK: Product links

    /// The seller's product page for a demo medicine (key like "azithral_500"), with a price only if we read one.
    func productLink(medicine: String, seller: String) -> ProductLink? {
        guard let bySeller = value(in: links, key: medicine) else { return nil }
        return value(in: bySeller, key: seller)
    }

    /// Selling price seen on the product page, with its source; nil when the page showed none.
    func productPrice(medicine: String, seller: String) -> (paise: Int, source: PriceSource)? {
        guard let link = productLink(medicine: medicine, seller: seller), let paise = link.pricePaise,
              let date = PriceSource.date(fromISO: link.dateSeen) else { return nil }
        return (paise, PriceSource(kind: .online, dateSeen: date))
    }

    /// Sellers that have a page for this medicine.
    func sellers(medicine: String) -> [String] {
        (value(in: links, key: medicine).map { Array($0.keys) } ?? []).sorted()
    }

    // MARK: Helpers

    private func record(city: String, lab: String, test: String) -> LabPriceRecord? {
        guard let byLab = value(in: labPrices, key: city), let tests = value(in: byLab, key: lab) else { return nil }
        return value(in: tests, key: test)
    }

    private static func priced(_ record: LabPriceRecord) -> (paise: Int, source: PriceSource)? {
        guard let date = PriceSource.date(fromISO: record.dateSeen) else { return nil } // no date, no price on screen
        return (record.pricePaise, PriceSource(kind: .online, dateSeen: date))
    }

    private func value<V>(in map: [String: V], key: String) -> V? {
        if let hit = map[key] { return hit }
        return map.first { $0.key.caseInsensitiveCompare(key) == .orderedSame }?.value
    }
}
