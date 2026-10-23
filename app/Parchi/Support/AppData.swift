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
    /// Download date of the bundled Jan Aushadhi list ("2026-10-23"); nil in a bundle built before the list was added.
    let janAushadhiListDate: String?

    enum CodingKeys: String, CodingKey {
        case inputFolder = "input_folder"
        case buildDate = "build_date"
        case counts
        case janAushadhiListDate = "janaushadhi_list_date"
    }
}

/// Loads a big bundled file the first time it is needed (and only once), so the app starts without parsing 6 MB.
final class LazyValue<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value?
    private var loaded = false
    private let make: @Sendable () -> Value

    init(_ make: @escaping @Sendable () -> Value) { self.make = make }

    var get: Value {
        lock.lock()
        defer { lock.unlock() }
        if !loaded { value = make(); loaded = true }
        return value!   // set just above; Value is Optional where "no data" is a valid result
    }
}

/// What the catalogue says about one written medicine: the product chosen and the price for the prescribed quantity.
struct CatalogueOffer: Equatable {
    let match: CatalogueMatch
    let price: CatalogueLinePrice
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

    /// Catalogue MRPs of every brand (engine/catalogue/brand_mrp.json) and the official Jan Aushadhi list.
    /// Both load on first use; a missing or broken file means "no offer", never a crash.
    private let mrpIndex: LazyValue<CatalogueMRPIndex?>
    private let janAushadhiIndex: LazyValue<JanAushadhiIndex?>

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

        let mrpURL = reader("brand_mrp")
        let jaURL = reader("janaushadhi_products")
        mrpIndex = LazyValue {
            guard let url = mrpURL else {
                AppData.log.warning("brand_mrp.json is not in the app bundle; no catalogue prices")
                return nil
            }
            do { return try CatalogueMRPIndex(json: Data(contentsOf: url)) } catch {
                AppData.log.warning("brand_mrp.json could not be read (\(error.localizedDescription, privacy: .public)); no catalogue prices")
                return nil
            }
        }
        janAushadhiIndex = LazyValue {
            guard let url = jaURL else {
                AppData.log.warning("janaushadhi_products.json is not in the app bundle; no Jan Aushadhi equivalents")
                return nil
            }
            do { return JanAushadhiIndex(products: try JanAushadhiIndex.products(fromJSON: Data(contentsOf: url))) } catch {
                AppData.log.warning("janaushadhi_products.json could not be read (\(error.localizedDescription, privacy: .public)); no Jan Aushadhi equivalents")
                return nil
            }
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

    // MARK: Catalogue MRP + Jan Aushadhi (any medicine)

    /// Loads both files now (call from a background task at launch so the first plan does not wait for them).
    func prewarmCatalogue() {
        _ = mrpIndex.get
        _ = janAushadhiIndex.get
    }

    /// The catalogue product and the MRP price for what the parchi says (`brand` = the written name, "Glycomet SR"),
    /// or nil when the catalogue has no product of exactly that brand, strength and kind.
    /// Also nil when the pack size cannot be read or the quantity is absurd: a missing price is honest, a guessed one is not.
    func catalogueOffer(brand: String, strength: String?, quantity: Int = 1) -> CatalogueOffer? {
        guard let match = mrpIndex.get?.match(name: brand, strength: strength, quantity: quantity),
              let price = match.pricedLine(quantity: quantity) else { return nil }
        return CatalogueOffer(match: match, price: price)
    }

    /// Why there is no catalogue price for this written medicine ("pack size unclear"); nil when there is one.
    func catalogueMiss(brand: String, strength: String?, quantity: Int = 1) -> CatalogueMiss? {
        guard let lookup = mrpIndex.get?.lookup(name: brand, strength: strength, quantity: quantity) else { return nil }
        if case .miss(let miss) = lookup { return miss }
        return nil
    }

    /// H1/X from the salts of the matched catalogue product: the second check after the brand table.
    func catalogueSchedule(brand: String, strength: String?, quantity: Int = 1) -> Schedule? {
        mrpIndex.get?.match(name: brand, strength: strength, quantity: quantity)?.schedule(using: scheduleCheck)
    }

    /// The Jan Aushadhi product with the same salt, strength, form and release type, or nil. Only ever shown as "Ask your doctor".
    func janAushadhiEquivalent(brand: String, strength: String?, quantity: Int = 1) -> JanAushadhiEquivalent? {
        guard let match = mrpIndex.get?.match(name: brand, strength: strength, quantity: quantity) else { return nil }
        return janAushadhiIndex.get?.equivalent(for: match, quantity: quantity)
    }

    /// Date of the Jan Aushadhi list in the bundle.
    var janAushadhiListDate: Date {
        PriceSource.date(fromISO: dataVersion?.janAushadhiListDate) ?? JanAushadhiIndex.bundledListDate
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
