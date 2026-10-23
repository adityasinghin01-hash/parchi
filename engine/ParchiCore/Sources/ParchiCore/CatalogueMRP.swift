import Foundation

// Catalogue MRPs for ANY medicine (plan gap U7) and the same-salt Jan Aushadhi product for it (gap U6).
// Data: engine/catalogue/brand_mrp.json, built by tools/build_catalogue_prices.py from the Medlex product list.
// Money is integer paise. A price taken from here is a printed MRP of a pack, never a shop's quote.

/// Release behaviour of a catalogue product. `unclear` = the name carries a letter code (MR, OD, LA...) that can mean
/// two things; such a product is priced but never matched to Jan Aushadhi.
public enum CatalogueRelease: String, Sendable, Equatable {
    case plain, modified, dispersible, unclear

    /// The Jan Aushadhi release type, nil when it cannot be told.
    public var jaVariant: JAVariant? {
        switch self {
        case .plain: return .standard
        case .modified: return .modifiedRelease
        case .dispersible: return .dispersible
        case .unclear: return nil
        }
    }

    private static let unclearRx = JAText.regex(#"\b(?:mr|od|la|tr)\b|retard|contin\b|depot|chrono|spansule"#)
    private static let modifiedRx = JAText.regex(#"prolonged|sustained|extended|modified[- ]?release|controlled[- ]?release|long[- ]acting|\b(?:sr|xr|er|cr|pr|xl)\b"#)
    private static let dispersibleRx = JAText.regex(#"dispersible|dissolving|chewable|sublingual|effervescent|orodispersible|\b(?:dt|md|mdt|odt)\b"#)

    /// Same rules as `detect_variant` in tools/build_catalogue_prices.py.
    public static func detect(in text: String) -> CatalogueRelease {
        let s = JAText.clean(text.lowercased())
        if JAText.has(unclearRx, in: s) { return .unclear }
        if JAText.has(modifiedRx, in: s) { return .modified }
        if JAText.has(dispersibleRx, in: s) { return .dispersible }
        return .plain
    }
}

/// One catalogue product group: brand + strength (+ extra words, dosage form, release type) with the pack of the lowest MRP per unit.
public struct CatalogueEntry: Equatable, Sendable {
    public let brand: String
    /// The number as in the product name ("40"); "" when the name has none.
    public let strength: String
    /// MRP of one pack, paise.
    public let mrpPaise: Int
    /// As the product list prints it: "strip of 10 tablets".
    public let packLabel: String
    /// "Telmisartan (40mg)", "Amoxycillin (500mg) + Clavulanic Acid (125mg)"; nil when unknown or the products disagree.
    public let salt: String?
    public let form: JAForm?
    public let release: CatalogueRelease
    /// Words after the brand that name a different medicine ("H" in "Telma H 40"); "" for the plain brand.
    public let extras: String
}

/// A catalogue entry chosen for a written medicine, with what had to be assumed to choose it.
public struct CatalogueMatch: Equatable, Sendable {
    public let entry: CatalogueEntry
    /// The parchi did not say plain / SR and only the other kind exists: the price is shown, Jan Aushadhi is not.
    public let releaseAssumed: Bool
    /// The parchi did not say tablet / syrup and the brand has several forms at this strength.
    public let formAmbiguous: Bool
    /// The parchi wrote the plain brand and the catalogue has it only with a marketing word (Duo, Forte), all with one salt.
    public let extrasAssumed: Bool

    /// Price for `quantity` units.
    public func linePrice(quantity: Int) -> CatalogueLinePrice {
        let units = PackSize.unitsPerPack(label: entry.packLabel)
        let packs = PackSize.packsNeeded(quantity: quantity, unitsPerPack: units)
        return CatalogueLinePrice(totalPaise: entry.mrpPaise * packs, packs: packs, perPackPaise: entry.mrpPaise,
                                  packLabel: entry.packLabel, packSizeKnown: units != nil)
    }

    /// True when a same-salt Jan Aushadhi product may be looked up for this line.
    public var allowsJanAushadhi: Bool {
        !releaseAssumed && !formAmbiguous && entry.release != .unclear && entry.salt != nil && entry.form != nil
    }
}

public struct CatalogueLinePrice: Equatable, Sendable {
    public let totalPaise: Paise
    public let packs: Int
    public let perPackPaise: Paise
    public let packLabel: String
    /// false: the pack label could not be read, one pack is priced and the screen must say so.
    public let packSizeKnown: Bool
}

public struct CatalogueMRPIndex: @unchecked Sendable {
    public enum LoadError: Error { case notAnObject, missingTable(String) }

    private let forms: [String]
    private let variants: [String]
    private let packs: [String]
    private let salts: [String]
    private let extras: [String]
    private let brands: NSDictionary
    public let brandCount: Int

    public init(json data: Data) throws {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw LoadError.notAnObject }
        func table(_ key: String) throws -> [String] {
            guard let t = root[key] as? [String] else { throw LoadError.missingTable(key) }
            return t
        }
        forms = try table("forms")
        variants = try table("variants")
        packs = try table("packs")
        salts = try table("salts")
        extras = try table("extras")
        guard let b = root["brands"] as? NSDictionary else { throw LoadError.missingTable("brands") }
        brands = b
        brandCount = b.count
    }

    public func contains(brand: String) -> Bool { brands.object(forKey: brand) != nil }

    /// Every entry of one brand key ("TELMA"), in file order.
    public func entries(brand: String) -> [CatalogueEntry] {
        guard let text = brands.object(forKey: brand) as? String else { return [] }
        return text.split(separator: ";").compactMap { decode(String($0), brand: brand) }
    }

    // "strength,m,p,fv,s,x"; s and x may be left out
    private func decode(_ row: String, brand: String) -> CatalogueEntry? {
        let f = row.split(separator: ",", omittingEmptySubsequences: false)
        guard f.count >= 4, let m = Int(f[1]), let p = Int(f[2]), let fv = Int(f[3]), packs.indices.contains(p) else { return nil }
        let s = f.count > 4 ? Int(f[4]) ?? 0 : 0
        let x = f.count > 5 ? Int(f[5]) ?? 0 : 0
        let formName = fv / 4 < forms.count ? forms[fv / 4] : ""
        let variantName = fv % 4 < variants.count ? variants[fv % 4] : ""
        return CatalogueEntry(
            brand: brand, strength: String(f[0]), mrpPaise: m, packLabel: packs[p],
            salt: s >= 1 && s <= salts.count ? salts[s - 1] : nil,
            form: formName.isEmpty ? nil : JAForm(rawValue: formName),
            release: variantName.isEmpty ? .plain : (CatalogueRelease(rawValue: variantName) ?? .unclear),
            extras: x >= 1 && x <= extras.count ? extras[x - 1] : "")
    }

    // MARK: Lookup for a written medicine

    private static let notExtra: Set<String> = Set("""
        tablet tablets tab capsule capsules cap caps syrup dry suspension oral solution liquid drops drop eye ear nasal \
        injection inj infusion cream gel ointment lotion powder sachet granules inhaler respules rotacap rotacaps spray \
        sr xr er cr pr xl mr od la tr dt md mdt odt soft gelatin chewable dispersible sugar free iv im vaccine mg ml gm g mcg iu \
        for of and with in
        """.split(separator: " ").map(String.init))

    /// "H" for "Telma H", "" for "Telma". Same rules as `extra_words` in tools/build_catalogue_prices.py.
    static func extraWords(afterBrandIn name: String) -> String {
        name.split(separator: " ").dropFirst().compactMap { part -> String? in
            let word = String(part.lowercased().filter { $0 >= "a" && $0 <= "z" })
            guard !word.isEmpty, let first = part.first, !first.isNumber, first != ".", !notExtra.contains(word) else { return nil }
            return word.uppercased()
        }.joined(separator: " ")
    }

    /// The catalogue's brand key for a written name, the way the app's `Catalogue` builds it: the whole name's letters
    /// if that is a brand ("Montair LC" -> MONTAIRLC), else the first word.
    func brandKey(for name: String) -> (brand: String, extras: String)? {
        let whole = String(name.filter(\.isLetter)).uppercased()
        if whole.count >= 3, contains(brand: whole) { return (whole, "") }
        guard let first = name.split(separator: " ").first else { return nil }
        let key = String(first.filter(\.isLetter)).uppercased()
        guard key.count >= 3, contains(brand: key) else { return nil }
        return (key, Self.extraWords(afterBrandIn: name))
    }

    /// The catalogue product for what the parchi says, or nil: never the product of a different strength, different
    /// extra words ("Telma 40" never gets the price of "Telma H 40"), a different stated form or a different stated
    /// release type (SR). `strength` is what the reader returned ("40", "40 mg", nil).
    public func match(name: String, strength: String?) -> CatalogueMatch? {
        guard let (brand, extras) = brandKey(for: name) else { return nil }
        let wanted = String((strength ?? "").trimmingCharacters(in: .whitespaces).prefix { $0.isNumber || $0 == "." })
        var pool = entries(brand: brand).filter { $0.strength == wanted }
        guard !pool.isEmpty else { return nil }

        let lower = name.lowercased()
        if let form = JAName.detectForm(lower) {
            pool = pool.filter { $0.form == form }
            guard !pool.isEmpty else { return nil }
        }
        // Extra words name a different medicine ("Telma H" has a second salt): they must be the same. The one exception:
        // the parchi writes the plain brand ("Augmentin 625") and the catalogue only has it with a marketing word
        // ("Augmentin 625 Duo"): accepted when every product at this strength has the same, known salt composition.
        var extrasAssumed = false
        let sameExtras = pool.filter { $0.extras == extras }
        if !sameExtras.isEmpty {
            pool = sameExtras
        } else if extras.isEmpty, pool.allSatisfy({ $0.salt != nil }), Set(pool.compactMap(\.salt)).count == 1 {
            extrasAssumed = true
        } else {
            return nil
        }

        // No form written: tablets and capsules first (almost every parchi line), then syrups, then injections and creams.
        let statedForm = JAName.detectForm(lower) != nil
        func rank(_ e: CatalogueEntry) -> Int {
            switch e.form {
            case .tablet?, .capsule?: return 0
            case .liquid?: return 1
            default: return 2
            }
        }
        if !statedForm, let best = pool.map(rank).min() { pool = pool.filter { rank($0) == best } }

        let written = CatalogueRelease.detect(in: lower)
        var releaseAssumed = false
        let sameRelease = pool.filter { $0.release == written }
        if !sameRelease.isEmpty {
            pool = sameRelease
        } else if written == .plain {
            releaseAssumed = true     // "Glycomet 500" and only the SR exists: price it, but do not look for a Jan Aushadhi product
        } else {
            return nil                // the parchi says SR / MR / DT and no such product exists at this strength
        }
        // Ambiguous (no Jan Aushadhi lookup) only when the best kind itself has two forms, e.g. a tablet and a capsule.
        let formAmbiguous = !statedForm && Set(pool.map { $0.form?.rawValue ?? "" }).count > 1
        guard let entry = pool.min(by: { $0.mrpPaise < $1.mrpPaise }) else { return nil }
        return CatalogueMatch(entry: entry, releaseAssumed: releaseAssumed, formAmbiguous: formAmbiguous, extrasAssumed: extrasAssumed)
    }
}

// MARK: - Jan Aushadhi equivalent of a catalogue entry

/// The same salt, strength, form and release type on the official Jan Aushadhi list. Only ever shown as "Ask your doctor".
public struct JanAushadhiEquivalent: Equatable, Sendable {
    public let match: JAMatch
    /// Cost of the prescribed quantity at the list's MRP.
    public let totalPaise: Paise
    public let packs: Int
    /// false: the list's pack size could not be read; `totalPaise` is one pack.
    public let packSizeKnown: Bool
}

extension JanAushadhiIndex {
    /// The salt and strength strings `match(salt:strength:form:variant:)` wants, from a catalogue composition like
    /// `"Amoxycillin (500mg) + Clavulanic Acid (125mg)"` -> (`"Amoxycillin + Clavulanic Acid"`, `"500 mg + 125 mg"`).
    /// nil when any part is unclear (no unit, different per-volume amounts, a salt name that contains a list separator).
    private static let compositionPartRx = JAText.regex(#"^(.*?)\s*\((\d+(?:\.\d+)?)\s*(mg|mcg|gm|g|iu|%)(?:\s*w/[wv]|\s*v/v)?(?:\s*/\s*(\d*(?:\.\d+)?)\s*ml)?\)$"#)

    static func query(fromComposition composition: String) -> (salt: String, strength: String)? {
        let partRx = compositionPartRx
        var names: [String] = []
        var amounts: [String] = []
        var volumes: Set<String> = []
        for raw in composition.components(separatedBy: " + ") {
            let part = JAText.clean(raw)
            guard let m = JAText.firstMatch(partRx, in: part),
                  let name = JAText.group(m, 1, in: part), !name.isEmpty,
                  let number = JAText.group(m, 2, in: part), let unit = JAText.group(m, 3, in: part) else { return nil }
            guard JAName.splitList(name).count == 1, !name.contains("+") else { return nil }
            names.append(name)
            amounts.append("\(number) \(unit)")
            if m.range(at: 4).location != NSNotFound {
                volumes.insert(JAText.group(m, 4, in: part).map { $0.isEmpty ? "1" : $0 } ?? "1")
            } else {
                volumes.insert("")
            }
        }
        guard !names.isEmpty, volumes.count == 1, let volume = volumes.first else { return nil }
        let suffix = volume.isEmpty ? "" : "/\(volume) ml"
        return (names.joined(separator: " + "), amounts.joined(separator: " + ") + suffix)
    }

    /// The Jan Aushadhi product with this catalogue entry's salt(s), strengths, form and release type, or nil.
    /// With several packs on the list the cheapest cost for `quantity` units wins (ties: first on the list).
    public func equivalent(for match: CatalogueMatch, quantity: Int) -> JanAushadhiEquivalent? {
        guard match.allowsJanAushadhi, let composition = match.entry.salt, let form = match.entry.form,
              let variant = match.entry.release.jaVariant,
              let q = Self.query(fromComposition: composition) else { return nil }
        let found = matches(salt: q.salt, strength: q.strength, form: form, variant: variant)
        let priced = found.map { m -> JanAushadhiEquivalent in
            let units = PackSize.unitsPerPack(janAushadhiUnitSize: m.unitSize)
            let packs = PackSize.packsNeeded(quantity: quantity, unitsPerPack: units)
            return JanAushadhiEquivalent(match: m, totalPaise: m.mrpPaise * packs, packs: packs, packSizeKnown: units != nil)
        }
        return priced.enumerated().min { ($0.element.totalPaise, $0.offset) < ($1.element.totalPaise, $1.offset) }?.element
    }
}
