import Foundation

// MARK: - Public types

/// Dosage-form families used to compare a prescribed medicine with a Jan Aushadhi product.
/// Two products are only comparable when they are in the same family (a tablet is never offered for a syrup).
public enum JAForm: String, Codable, Sendable, CaseIterable {
    case tablet
    case capsule
    /// Syrup, oral suspension, oral solution (the list also has external solutions; the salt and strength must still agree).
    case liquid
    /// Eye, ear or nasal drops.
    case drops
    case injection
    case inhaler
    /// Ointment, cream, gel, lotion.
    case topical
    case gargle
    /// Oral powder or sachet.
    case powder
}

/// Release behaviour. "Gastro-resistant", "enteric coated" and "delayed release" are `.standard`
/// because that is how the plain tablet of those drugs (e.g. pantoprazole) is made.
/// A plain tablet is never matched to a prolonged-release one, or the reverse.
public enum JAVariant: String, Codable, Sendable, CaseIterable {
    case standard
    /// Prolonged / sustained / extended / modified release (SR, XR, ER, CR, PR).
    case modifiedRelease
    /// Dispersible, mouth-dissolving, chewable, sublingual, effervescent.
    case dispersible
}

/// One row of the official Jan Aushadhi product list.
public struct JAProduct: Sendable, Equatable {
    public let productId: Int
    public let genericName: String
    public let unitSize: String
    /// Rupees, as the list prints it. Rows with 0 or no MRP are not priced and are never matched.
    public let mrpRupees: Double

    public init(productId: Int, genericName: String, unitSize: String, mrpRupees: Double) {
        self.productId = productId
        self.genericName = genericName
        self.unitSize = unitSize
        self.mrpRupees = mrpRupees
    }
}

/// A Jan Aushadhi product with the same salt(s), the same strength(s), the same form and the same release type.
///
/// IMPORTANT, product rule: this is only ever shown as **"Ask your doctor"** (a question the patient can
/// take to the prescriber or pharmacist). The app never swaps a medicine, never pre-selects this product,
/// never ranks it into a plan on its own, and never says it is "the same" or "equivalent".
public struct JAMatch: Equatable, Sendable {
    public let productId: Int
    /// The name exactly as printed on the Jan Aushadhi list (whitespace cleaned).
    public let productName: String
    /// Pack size as printed on the list, e.g. "10's".
    public let unitSize: String
    /// MRP of that pack in paise (list MRP; Jan Aushadhi Kendras sell at this price).
    public let mrpPaise: Int
    /// Every price carries a source and a date: kind `.mrp`, dated with the list's download date.
    public let source: PriceSource
    /// Human-readable source, shown next to the price.
    public let sourceName: String
}

// MARK: - Index

/// Matches a (salt, strength, form) triple to products on the official Jan Aushadhi list.
///
/// Rules (exactness over coverage, a missed match costs nothing, a wrong one could hurt):
/// * the set of salts must be identical; combination salts are order-insensitive;
/// * every salt must have the identical strength (units are converted, 0.5 mg == 500 mcg; `%` and `IU` are separate);
/// * the form family and the release type must be identical;
/// * a per-volume strength (`5 mg per 5 ml`) must be identical on both sides;
/// * products whose name cannot be fully understood (a salt without a strength, an unknown form) are never matched.
///
/// Brand to salt is NOT done here. The caller supplies the salt. See `JAMatch` for how a result may be shown.
public struct JanAushadhiIndex: Sendable {
    public static let listName = "Jan Aushadhi official product list"
    /// Download date of the list saved in `docs/research/evidence/janaushadhi_products_2026-10-23.json`.
    public static let bundledListDate: Date = PriceSource.date(fromISO: "2026-10-23") ?? .distantPast

    private struct Entry: Sendable {
        let product: JAProduct
        let name: String
        let paise: Int
    }

    private let byKey: [String: [Entry]]
    private let source: PriceSource
    /// Rows given to the index.
    public let productCount: Int
    /// Rows that are priced and whose name was fully understood, i.e. that can ever be matched.
    public let matchableCount: Int
    /// Rows without an MRP (listed but not priced).
    public let unpricedCount: Int

    public init(products: [JAProduct], listDate: Date = JanAushadhiIndex.bundledListDate) {
        source = PriceSource(kind: .mrp, dateSeen: listDate)
        var map: [String: [Entry]] = [:]
        var matchable = 0
        var unpriced = 0
        for product in products {
            guard product.mrpRupees > 0 else { unpriced += 1; continue }
            let name = JAText.clean(product.genericName)
            guard let parsed = JAName.parse(name), let key = parsed.key else { continue }
            map[key, default: []].append(Entry(product: product, name: name, paise: Int((product.mrpRupees * 100).rounded())))
            matchable += 1
        }
        for key in map.keys { map[key]?.sort { $0.product.productId < $1.product.productId } }
        byKey = map
        productCount = products.count
        matchableCount = matchable
        unpricedCount = unpriced
    }

    /// Decodes the saved Jan Aushadhi response (`responseBody.newProductResponsesList`).
    public static func products(fromJSON data: Data) throws -> [JAProduct] {
        struct Envelope: Decodable {
            struct Body: Decodable { let newProductResponsesList: [Row] }
            struct Row: Decodable {
                let productId: Int?
                let genericName: String?
                let unitSize: String?
                let mrp: Double?
            }
            let responseBody: Body
        }
        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        return envelope.responseBody.newProductResponsesList.enumerated().compactMap { offset, row in
            guard let name = row.genericName else { return nil }
            return JAProduct(productId: row.productId ?? offset, genericName: name,
                             unitSize: row.unitSize ?? "", mrpRupees: row.mrp ?? 0)
        }
    }

    /// The Jan Aushadhi product for exactly this medicine, or nil.
    ///
    /// - Parameters:
    ///   - salt: one salt (`"Telmisartan"`) or several joined by `+`, `,`, `/`, `&` or `and`
    ///     (`"Paracetamol + Aceclofenac"`). Salt-form words (hydrochloride, sodium...) are ignored.
    ///   - strength: one strength per salt in the same order, joined the same way (`"40 mg"`, `"325 mg + 100 mg"`),
    ///     optionally with a per-volume suffix for liquids (`"125 mg/5 ml"`). A number without a unit means mg.
    ///   - form: dosage-form family.
    ///   - variant: release type; defaults to `.standard`.
    /// - Returns: when several packs match (10's and 50's), the one that appears first on the list.
    ///   Use `matches` to see all of them.
    public func match(salt: String, strength: String, form: JAForm, variant: JAVariant = .standard) -> JAMatch? {
        matches(salt: salt, strength: strength, form: form, variant: variant).first
    }

    /// Every pack that matches, in list order.
    public func matches(salt: String, strength: String, form: JAForm, variant: JAVariant = .standard) -> [JAMatch] {
        guard let key = JAName.queryKey(salt: salt, strength: strength, form: form, variant: variant),
              let entries = byKey[key] else { return [] }
        return entries.map {
            JAMatch(productId: $0.product.productId, productName: $0.name, unitSize: $0.product.unitSize,
                    mrpPaise: $0.paise, source: source, sourceName: Self.listName)
        }
    }
}

// MARK: - Name understanding (internal)

enum JAText {
    static func clean(_ s: String) -> String {
        s.replacingOccurrences(of: "\u{00A0}", with: " ")
            .split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    static func regex(_ pattern: String) -> NSRegularExpression {
        // Patterns are constants checked by the tests; a bad one would fail every test loudly.
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }

    static func firstMatch(_ regex: NSRegularExpression, in s: String) -> NSTextCheckingResult? {
        regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s))
    }

    static func has(_ regex: NSRegularExpression, in s: String) -> Bool { firstMatch(regex, in: s) != nil }

    static func group(_ m: NSTextCheckingResult, _ i: Int, in s: String) -> String? {
        guard i < m.numberOfRanges, let r = Range(m.range(at: i), in: s) else { return nil }
        return String(s[r])
    }
}

enum JAUnit: Int, Sendable { case mass = 0, iu, percent }

/// An amount in canonical units: mass in micrograms, IU, or percent; stored x1000 to stay an integer.
struct JAAmount: Hashable, Comparable, Sendable {
    let unit: JAUnit
    let milli: Int64

    static func < (a: JAAmount, b: JAAmount) -> Bool { (a.unit.rawValue, a.milli) < (b.unit.rawValue, b.milli) }
    var token: String { "\(unit.rawValue):\(milli)" }

    static func make(value: Double, unit rawUnit: String) -> JAAmount? {
        let u = rawUnit.lowercased()
        let unit: JAUnit
        var factor = 1.0
        switch u {
        case "", "mg": unit = .mass; factor = 1000
        case "mcg", "µg", "μg", "ug": unit = .mass
        case "g", "gm": unit = .mass; factor = 1_000_000
        case "iu": unit = .iu
        case "%": unit = .percent
        default: return nil
        }
        guard value.isFinite, value > 0 else { return nil }
        return JAAmount(unit: unit, milli: Int64((value * factor * 1000).rounded()))
    }
}

struct JAName {
    struct Component { let salt: String; let amount: JAAmount? }

    let components: [Component]
    let form: JAForm?
    let variant: JAVariant
    /// Volume the strength refers to, in micro-litres x1000 (5 ml -> 5000); nil when none is printed.
    let perVolume: Int?

    /// Lookup key, nil when the name cannot be matched exactly.
    var key: String? {
        guard let form, !components.isEmpty, components.allSatisfy({ $0.amount != nil }) else { return nil }
        return JAName.makeKey(components: components.map { ($0.salt, $0.amount!) }, form: form, variant: variant, perVolume: perVolume)
    }

    static func makeKey(components: [(String, JAAmount)], form: JAForm, variant: JAVariant, perVolume: Int?) -> String {
        let parts = components.map { "\($0.0)@\($0.1.token)" }.sorted().joined(separator: "|")
        return "\(form.rawValue)/\(variant.rawValue)/\(perVolume.map(String.init) ?? "-")/\(parts)"
    }

    // MARK: query

    static func queryKey(salt: String, strength: String, form: JAForm, variant: JAVariant) -> String? {
        let salts = splitList(salt).map(saltKey).filter { !$0.isEmpty }
        guard !salts.isEmpty, Set(salts).count == salts.count,
              let parsed = parseAmounts(strength), parsed.amounts.count == salts.count else { return nil }
        return makeKey(components: Array(zip(salts, parsed.amounts)), form: form, variant: variant, perVolume: parsed.perVolume)
    }

    private static let listSplit = JAText.regex(#"\s*(?:\+|,|;|/|&|\band\b|\bwith\b)\s*"#)

    static func splitList(_ s: String) -> [String] {
        let range = NSRange(s.startIndex..., in: s)
        let marked = listSplit.stringByReplacingMatches(in: s, range: range, withTemplate: "\u{1}")
        return marked.split(separator: "\u{1}", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private static let perVolumeRx = JAText.regex(#"(?:/|\bper\b)\s*(\d+(?:\.\d+)?)?\s*ml\b"#)
    private static let weightVolumeRx = JAText.regex(#"\s*\b(?:w/w|w/v|v/v)\b"#)
    private static let amountPieceRx = JAText.regex(#"^\s*(\d+(?:\.\d+)?)\s*(mg|mcg|µg|μg|ug|gm|g|iu|%)?\s*(?:w/[wv]|v/v)?\s*$"#)

    /// Parses `"325 mg + 100 mg"`, `"40"`, `"125mg/5ml"`.
    static func parseAmounts(_ raw: String) -> (amounts: [JAAmount], perVolume: Int?)? {
        var s = JAText.clean(raw.lowercased())
        var perVolume: Int?
        if let m = JAText.firstMatch(perVolumeRx, in: s), let whole = Range(m.range, in: s) {
            let n = JAText.group(m, 1, in: s).flatMap(Double.init) ?? 1
            perVolume = Int((n * 1000).rounded())
            s.removeSubrange(whole)
        }
        s = weightVolumeRx.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "")
        // Slashes in "325/100" separate salts; the per-volume and "w/v" slashes are already gone.
        let pieces = splitList(s)
        guard !pieces.isEmpty else { return nil }
        var amounts: [JAAmount] = []
        for piece in pieces {
            guard let m = JAText.firstMatch(amountPieceRx, in: piece),
                  let value = JAText.group(m, 1, in: piece).flatMap(Double.init),
                  let amount = JAAmount.make(value: value, unit: JAText.group(m, 2, in: piece) ?? "") else { return nil }
            amounts.append(amount)
        }
        return (amounts, perVolume)
    }

    // MARK: salt normalisation

    private static let saltFormWords: Set<String> = [
        "hydrochloride", "dihydrochloride", "hcl", "hydrobromide", "bromide", "sodium", "potassium", "calcium", "magnesium",
        "trihydrate", "dihydrate", "monohydrate", "anhydrous", "sesquihydrate", "besilate", "besylate", "maleate", "sulfate",
        "phosphate", "tartrate", "succinate", "fumarate", "hemifumarate", "acetate", "citrate", "mesylate", "medoxomil",
        "proxetil", "axetil", "disoproxil", "dipropionate", "propionate", "furoate", "nitrate", "oxalate", "tromethamine",
    ]
    private static let dropWords: Set<String> = ["ip", "bp", "usp", "nf"]
    private static let wordSynonyms: [String: String] = [
        "amoxycillin": "amoxicillin", "aciclovir": "acyclovir", "cefalexin": "cephalexin", "acetaminophen": "paracetamol",
        "salbutamol": "albuterol", "levosalbutamol": "levalbuterol", "cotrimoxazole": "co trimoxazole",
    ]
    private static let phraseSynonyms: [String: String] = [
        "potassium clavulanate": "clavulanic acid", "clavulanate": "clavulanic acid",
        "acetylsalicylic acid": "aspirin", "sodium valproate": "valproate", "valproic acid": "valproate",
    ]

    /// Lower-case canonical salt name: spelling variants and salt-form words (hydrochloride, sodium...) removed.
    /// If the name *starts* with such a word ("Sodium Valproate", "Calcium Carbonate") nothing is removed from it.
    static func saltKey(_ raw: String) -> String {
        let letters = raw.lowercased().map { $0.isLetter ? $0 : " " }
        var words = String(letters).split(separator: " ").map(String.init)
            .map { $0.replacingOccurrences(of: "sulph", with: "sulf") }
            .filter { !dropWords.contains($0) }
            .map { wordSynonyms[$0] ?? $0 }
        // "co-trimoxazole" arrives as two words after hyphen removal; keep it joined so both spellings agree.
        if words.count >= 2, words[0] == "co" { words = [words[0] + words[1]] + words.dropFirst(2) }
        if let first = words.first, !saltFormWords.contains(first) {
            let kept = [first] + words.dropFirst().filter { !saltFormWords.contains($0) }
            words = kept
        }
        let joined = words.joined(separator: " ")
        return phraseSynonyms[joined] ?? joined
    }

    // MARK: product names

    private static let strengthRx = JAText.regex(#"(\d+(?:\.\d+)?)\s*(?:(mg|mcg|µg|μg|ug|gm|g|iu)(?![a-z])|(%))"#)
    private static let splitRx = JAText.regex(#"\s*(?:,|\+|;|\band\b|\bwith\b|&)\s*"#)

    private static let stopWords: Set<String> = [
        "tablet", "tablets", "tab", "capsule", "capsules", "injection", "infusion", "syrup", "suspension", "solution", "liquid",
        "emulsion", "elixir", "gel", "cream", "ointment", "lotion", "drops", "drop", "inhaler", "inhalation", "powder", "sachet",
        "granules", "ip", "bp", "usp", "oral", "per", "for", "eye", "ear", "nasal", "dispersible", "chewable", "sublingual",
        "effervescent", "mouth", "dissolving", "prolonged", "sustained", "extended", "modified", "release", "gastro", "gastroresistant",
        "enteric", "delayed", "coated", "controlled", "paediatric", "pediatric", "film", "soft", "softgel", "w/v", "w/w", "v/v", "gargle", "mouthwash", "wash", "jelly", "spray",
        "shampoo", "paint", "lozenges", "pen", "dusting", "pessary", "kit",
    ]

    private static func stripsAsStop(_ token: String) -> Bool {
        let t = token.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".,;:()"))
        if stopWords.contains(t) { return true }
        // "gastro-resistant", "prolonged-release", "gastro-resistant"
        return t.contains("release") || t.contains("resist") || t.contains("coated")
    }

    static func parse(_ rawName: String) -> JAName? {
        var s = JAText.clean(rawName.lowercased())
        guard !s.isEmpty else { return nil }
        let form = detectForm(s)
        let variant = detectVariant(s)

        var perVolume: Int?
        if let m = JAText.firstMatch(perVolumeRx, in: s), let whole = Range(m.range, in: s) {
            let n = JAText.group(m, 1, in: s).flatMap(Double.init) ?? 1
            perVolume = Int((n * 1000).rounded())
            s.removeSubrange(whole)
        }
        s = flattenParentheses(s)

        var components: [Component] = []
        let range = NSRange(s.startIndex..., in: s)
        let marked = splitRx.stringByReplacingMatches(in: s, range: range, withTemplate: "\u{1}")
        for segment in marked.split(separator: "\u{1}") {
            let seg = String(segment)
            var saltWords: [String] = []
            for token in seg.split(separator: " ") {
                let t = String(token)
                if t.first?.isNumber == true || stripsAsStop(t) { break }
                saltWords.append(t.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:()")))
            }
            let salt = saltKey(saltWords.joined(separator: " "))
            guard !salt.isEmpty else { continue }
            var amount: JAAmount?
            if let m = JAText.firstMatch(strengthRx, in: seg), let value = JAText.group(m, 1, in: seg).flatMap(Double.init) {
                amount = JAAmount.make(value: value, unit: JAText.group(m, 2, in: seg) ?? JAText.group(m, 3, in: seg) ?? "")
            }
            components.append(Component(salt: salt, amount: amount))
        }
        guard !components.isEmpty else { return nil }
        return JAName(components: components, form: form, variant: variant, perVolume: perVolume)
    }


    /// "co-trimoxazole (sulfamethoxazole 200mg and trimethoprim 40mg) oral suspension" -> use the bracket.
    /// Brackets that add no strengths ("(enteric coated)", "(aspirin)") are dropped.
    private static func flattenParentheses(_ s: String) -> String {
        var outside = ""
        var groups: [String] = []
        var depth = 0
        var current = ""
        for ch in s {
            if ch == "(" { depth += 1; if depth == 1 { current = ""; continue } }
            if ch == ")" , depth > 0 {
                depth -= 1
                if depth == 0 { groups.append(current); continue }
            }
            if depth > 0 { current.append(ch) } else { outside.append(ch) }
        }
        if depth > 0 { groups.append(current) } // unbalanced: keep what was inside
        let outsideHasStrength = JAText.has(strengthRx, in: outside)
        let groupText = groups.joined(separator: ", ")
        guard !outsideHasStrength, JAText.has(strengthRx, in: groupText) else { return outside }
        // "Co-trimoxazole (Sulfamethoxazole 200mg and Trimethoprim 40mg)": the bracket holds the salts.
        // "Fexofenadine Hydrochloride Suspension (30mg)": the bracket holds only the strength.
        let bare = strengthRx.stringByReplacingMatches(in: groupText, range: NSRange(groupText.startIndex..., in: groupText), withTemplate: " ")
        let hasOwnSalts = JAText.has(JAText.regex(#"[a-z]{3,}"#), in: bare)
        return hasOwnSalts ? groupText : outside + " " + groupText
    }

    private static let rxInjection = JAText.regex(#"injection|infusion|\binj\b"#)
    private static let rxInhaler = JAText.regex(#"inhal(?:er|ation)\b|respules|rotacaps?|nebuli|respirator solution|\bmdi\b"#)
    private static let rxTablet = JAText.regex(#"\btablets?\b|\btab\b"#)
    private static let rxCapsule = JAText.regex(#"\bcapsules?\b"#)
    private static let rxGargle = JAText.regex(#"gargle|mouth ?wash"#)
    private static let rxDrops = JAText.regex(#"\bdrops?\b"#)
    private static let rxDropsSite = JAText.regex(#"\b(?:eye|ear|nasal)\b"#)
    private static let rxOther = JAText.regex(#"\b(?:eye|ear|nasal)\b|spray|shampoo|\bpaint\b|\bsoap\b|dusting|enema|suppositor|pessary|vaginal|patch|\bpen\b|\bkit\b"#)
    private static let rxLiquid = JAText.regex(#"\bsyrup\b|suspension|\bsolution\b|\bliquid\b|emulsion|elixir"#)
    private static let rxTopical = JAText.regex(#"\bointment\b|\bcream\b|\bgel\b|\blotion\b"#)
    private static let rxPowder = JAText.regex(#"\bsachets?\b|\bpowder\b|\bgranules\b"#)

    static func detectForm(_ s: String) -> JAForm? {
        if JAText.has(rxInjection, in: s) { return .injection }
        if JAText.has(rxInhaler, in: s) { return .inhaler }
        if JAText.has(rxTablet, in: s) { return .tablet }
        if JAText.has(rxCapsule, in: s) { return .capsule }
        if JAText.has(rxGargle, in: s) { return .gargle }
        if JAText.has(rxDrops, in: s) { return JAText.has(rxDropsSite, in: s) ? .drops : .liquid }
        if JAText.has(rxOther, in: s) { return nil }
        if JAText.has(rxLiquid, in: s) { return .liquid }
        if JAText.has(rxTopical, in: s) { return .topical }
        if JAText.has(rxPowder, in: s) { return .powder }
        return nil
    }

    private static let rxModified = JAText.regex(#"prolonged|sustained|extended|modified[- ]?release|controlled[- ]?release|long[- ]acting|\b(?:sr|xr|er|cr|pr|xl)\b"#)
    private static let rxDispersible = JAText.regex(#"dispersible|dissolving|chewable|sublingual|effervescent|orodispersible"#)

    static func detectVariant(_ s: String) -> JAVariant {
        if JAText.has(rxModified, in: s) { return .modifiedRelease }
        if JAText.has(rxDispersible, in: s) { return .dispersible }
        return .standard
    }
}
