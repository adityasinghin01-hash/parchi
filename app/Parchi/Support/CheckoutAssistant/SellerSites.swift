import Foundation
import ParchiCore

/// Where each seller lives on the web, plus lookups into the bundled catalogue files.
/// Seller ids match engine/scenarios/*.json; `linkKey` is the seller name used in engine/catalogue/product_links.json.
enum SellerSites {
    struct Site: Hashable {
        let id: String
        let name: String
        let linkKey: String?
        let home: URL
        var labKeyword: String? = nil
    }

    static let all: [Site] = [
        Site(id: "truemeds", name: "Truemeds", linkKey: "Truemeds", home: URL(string: "https://www.truemeds.in")!),
        Site(id: "onemg", name: "Tata 1mg", linkKey: "Tata 1mg", home: URL(string: "https://www.1mg.com")!),
        Site(id: "pharmeasy", name: "PharmEasy", linkKey: "PharmEasy", home: URL(string: "https://pharmeasy.in")!),
        Site(id: "medkart", name: "Medkart", linkKey: "Medkart", home: URL(string: "https://www.medkart.in")!),
        Site(id: "medplus", name: "MedPlus", linkKey: "MedPlus", home: URL(string: "https://www.medplusmart.com")!),
        Site(id: "netmeds", name: "Netmeds", linkKey: "Netmeds", home: URL(string: "https://www.netmeds.com")!),
        Site(id: "apollopharmacy", name: "Apollo Pharmacy", linkKey: "Apollo Pharmacy", home: URL(string: "https://www.apollopharmacy.in")!),
        Site(id: "blinkit", name: "Blinkit", linkKey: "Blinkit", home: URL(string: "https://blinkit.com")!),
        Site(id: "instamart", name: "Swiggy Instamart", linkKey: "Swiggy Instamart", home: URL(string: "https://www.swiggy.com/instamart")!),
        Site(id: "redcliffe", name: "Redcliffe Labs", linkKey: nil, home: URL(string: "https://redcliffelabs.com")!, labKeyword: "redcliffe"),
        Site(id: "healthians", name: "Healthians", linkKey: nil, home: URL(string: "https://www.healthians.com")!, labKeyword: "healthians"),
        Site(id: "apollo", name: "Apollo Diagnostics", linkKey: nil, home: URL(string: "https://apollodiagnostics.in")!, labKeyword: "apollo"),
        Site(id: "max", name: "Max Lab", linkKey: nil, home: URL(string: "https://www.maxlab.co.in")!, labKeyword: "max lab"),
    ]

    /// nil for local shops (doctor's shop, Jan Aushadhi): those use the message step.
    static func site(id: String) -> Site? { all.first { $0.id == id } }

    // MARK: product_links.json (job D creates it; missing file = empty, sellers fall back to home pages)

    struct ProductLinks {
        /// item key -> seller name -> product url
        let table: [String: [String: URL]]
        var isEmpty: Bool { table.isEmpty }

        func url(for item: RxItem, linkKey: String?) -> URL? {
            guard let linkKey else { return nil }
            let base = item.name.lowercased().map { $0.isLetter || $0.isNumber ? String($0) : "_" }.joined()
                .split(separator: "_").joined(separator: "_")
            let keys = [item.strength.map { "\(base)_\($0)" }, base].compactMap { $0 }
            for key in keys { if let url = table[key]?[linkKey] { return url } }
            return nil
        }

        /// First link we have for this seller (used by the probe screen).
        func firstURL(linkKey: String) -> URL? {
            table.keys.sorted().compactMap { table[$0]?[linkKey] }.first
        }

        /// Item key (e.g. "dolo_650") of that first link: the probe looks for its brand word in the page title.
        func firstItemKey(linkKey: String) -> String? {
            table.keys.sorted().first { table[$0]?[linkKey] != nil }
        }
    }

    static func productLinks() -> ProductLinks {
        struct Entry: Decodable { let product_url: String? }
        guard let url = Bundle.main.url(forResource: "product_links", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode([String: [String: Entry]].self, from: data) else { return ProductLinks(table: [:]) }
        var table: [String: [String: URL]] = [:]
        for (item, sellers) in raw {
            for (seller, entry) in sellers {
                if let text = entry.product_url, let link = URL(string: text), link.scheme == "https" { table[item, default: [:]][seller] = link }
            }
        }
        return ProductLinks(table: table)
    }

    /// Lab booking page from engine/catalogue/labs.json, only when it is for the demo city (Ghaziabad); otherwise the lab's home page.
    static func labBookingURL(keyword: String?, city: String = "Ghaziabad") -> URL? {
        guard let keyword,
              let url = Bundle.main.url(forResource: "labs", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return nil }
        let match = rows.first {
            ($0["city"] as? String) == city && (($0["lab"] as? String)?.lowercased().contains(keyword) ?? false)
        }
        return (match?["booking_url"] as? String).flatMap(URL.init(string:)).flatMap { $0.scheme == "https" ? $0 : nil }
    }
}
