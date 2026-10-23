import Foundation

/// Dosage form written at the start of a printed prescription line ("Tab", "Cap.", "Syp", "Inj"...).
public enum DoseForm: String, Codable, Sendable, CaseIterable {
    case tab, cap, syp, inj, drops, cream, oint, gel, lotion, inhaler, powder, spray

    /// The Jan Aushadhi form family, or nil when the written form is ambiguous ("Drops" may be eye, ear or oral).
    public var jaForm: JAForm? {
        switch self {
        case .tab: return .tablet
        case .cap: return .capsule
        case .syp: return .liquid
        case .inj: return .injection
        case .cream, .oint, .gel, .lotion: return .topical
        case .inhaler: return .inhaler
        case .powder: return .powder
        case .drops, .spray: return nil
        }
    }
}

/// How often to take it, as printed. `code` is "1-0-1" style or OD/BD/TDS/QID/HS/SOS.
public struct DoseSchedule: Equatable, Sendable {
    public let code: String
    /// Doses in a day, nil for "as needed" (SOS / PRN) and "stat".
    public let dosesPerDay: Double?

    public init(code: String, dosesPerDay: Double?) {
        self.code = code
        self.dosesPerDay = dosesPerDay
    }
}

/// One printed line, read into fields. A field is nil when the line does not say it; nothing is guessed.
public struct ParsedItem: Equatable, Sendable {
    /// The line exactly as given.
    public let rawLine: String
    public let form: DoseForm?
    /// Brand as written (OCR-repaired only when the repaired word is a real catalogue brand). Nil when the line is not a medicine line.
    public let brand: String?
    /// "40 mg", "500 mg", "125 mg/5 ml", or just "40" when no unit was printed.
    public let strength: String?
    public let schedule: DoseSchedule?
    public let days: Int?
    /// Pack quantity: printed ("#10", "qty 10", "x 10 tabs"), else doses per day x days for tablets and capsules.
    public let quantityHint: Int?
    /// A single dose written as a volume ("5 ml" for a syrup). Not a strength.
    public let doseAmount: String?
    /// 0...1. At or above `PrintedParser.confidentThreshold` the line is safe to pre-fill, below it the person must confirm.
    public let confidence: Double
    /// Brand and strength checked against the catalogue (nil when no catalogue was given or no brand was read).
    public let check: CheckResult?

    public var isConfident: Bool { confidence >= PrintedParser.confidentThreshold }
}

/// Reads printed prescription lines as Apple Vision returns them. Works offline, no model.
///
/// Rules: a line becomes a medicine only if it has a dosage form (or a strength together with a schedule);
/// every other line (doctor name, date, advice) comes back with no fields and confidence 0.1.
/// OCR confusions (O/0, l/I/1) are repaired only inside numbers and schedules, and in a brand only when
/// the repaired word is a real brand in the catalogue.
public struct PrintedParser: Sendable {
    public static let confidentThreshold = 0.7

    public let catalogue: Catalogue?

    public init(catalogue: Catalogue? = nil) {
        self.catalogue = catalogue
    }

    public func parse(lines: [String]) -> [ParsedItem] { lines.map(parse(line:)) }

    public func parse(line rawLine: String) -> ParsedItem {
        var work = Self.normalise(rawLine)
        work = Self.stripListMarker(work)
        work = Self.gluePerVolume(work)

        // Fixed-format pieces first, so their digits are not mistaken for a strength.
        let schedulePattern = Self.extractPatternSchedule(&work)
        let duration = Self.extractDuration(&work)
        let printedQuantity = Self.extractQuantity(&work)

        var tokens = Self.tokenise(work)
        let formAt = Self.findForm(in: tokens)
        var form: DoseForm?
        var formTrailing = false
        if let formAt {
            form = formAt.form
            formTrailing = formAt.trailing
            tokens.remove(at: formAt.index)
        }
        if let first = tokens.first, first.lowercased() == "rx" { tokens.removeFirst() }

        var schedule = schedulePattern
        var strength: String?
        var doseAmount: String?
        var brandTokens: [String] = []
        var brandOpen = true
        var skipNumber = false
        var i = 0
        while i < tokens.count {
            let token = tokens[i]
            i += 1
            if let code = Self.wordSchedule(token), brandTokens.count >= 1 || !brandOpen {
                if schedule == nil { schedule = code }
                brandOpen = false
                continue
            }
            if Self.isStopWord(token) {
                brandOpen = false
                skipNumber = ["x", "×", "for", "x."].contains(token.lowercased())
                continue
            }
            if let number = Self.number(token) {
                brandOpen = false
                if skipNumber { skipNumber = false; continue }
                // unit may be glued ("40mg") or the next token ("40", "mg")
                var unit = number.unit
                var perVolume = number.perVolume
                if unit == nil, i < tokens.count, let u = Self.unitWord(tokens[i]) {
                    unit = u
                    i += 1
                    if i < tokens.count, let pv = Self.perVolumeToken(tokens[i]) { perVolume = pv; i += 1 }
                } else if unit != nil, perVolume == nil, i < tokens.count, let pv = Self.perVolumeToken(tokens[i]) {
                    perVolume = pv
                    i += 1
                }
                if unit == "ml", perVolume == nil {
                    if doseAmount == nil { doseAmount = "\(number.value) ml" }
                } else if strength == nil {
                    strength = Self.formatStrength(value: number.value, unit: unit, perVolume: perVolume)
                }
                continue
            }
            if let split = Self.splitGluedBrand(token) {
                if brandOpen, brandTokens.isEmpty {
                    brandTokens.append(split.brand)
                    brandOpen = false
                    if strength == nil { strength = split.strength }
                }
                continue
            }
            skipNumber = false
            guard token.first?.isLetter == true else { continue }
            if token.hasSuffix(":") { brandOpen = false; continue }
            if brandOpen, brandTokens.count < 3 {
                brandTokens.append(token.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:")))
            }
        }

        let hasMedicineShape = form != nil || (strength != nil && schedule != nil)
        // "Advice: syrup after meals": a form word after other words only counts with a strength or a schedule beside it.
        let trailingNeedsEvidence = formTrailing && strength == nil && schedule == nil
        guard hasMedicineShape, !trailingNeedsEvidence, !brandTokens.isEmpty || form != nil else {
            return Self.unparsed(rawLine)
        }
        // A form with no brand ("Tab 1-0-1") is a medicine line we cannot name: keep the form only.
        var brand = brandTokens.isEmpty ? nil : brandTokens.joined(separator: " ")

        var check: CheckResult?
        if let catalogue, let b = brand {
            brand = Self.repairBrand(b, catalogue: catalogue)
            let firstWord = String(brand!.split(separator: " ").first ?? "")
            check = catalogue.check(brand: firstWord, strength: strength.map(Self.strengthNumber))
        }

        let days = duration
        var quantity = printedQuantity
        if quantity == nil, let perDay = schedule?.dosesPerDay, let days, form == .tab || form == .cap {
            quantity = Int((perDay * Double(days)).rounded(.up))
        }

        var confidence = 0.0
        if form != nil { confidence += 0.35 }
        if brand != nil { confidence += 0.25 }
        if strength != nil { confidence += 0.15 }
        if schedule != nil { confidence += 0.15 }
        if days != nil || printedQuantity != nil { confidence += 0.10 }
        switch check {
        case .some(.unknownBrand): confidence = min(confidence, 0.5)
        case .some(.strengthMismatch): confidence = min(confidence, 0.6)
        case .some(.confirmed): confidence = min(confidence + 0.05, 1.0)
        default: break
        }
        // No form or no brand: never above "please confirm", whatever else the line says.
        if brand == nil || form == nil { confidence = min(confidence, 0.5) }

        return ParsedItem(rawLine: rawLine, form: form, brand: brand, strength: strength, schedule: schedule,
                          days: days, quantityHint: quantity, doseAmount: doseAmount,
                          confidence: (confidence * 100).rounded() / 100, check: check)
    }

    // MARK: - Pieces

    static func unparsed(_ rawLine: String) -> ParsedItem {
        ParsedItem(rawLine: rawLine, form: nil, brand: nil, strength: nil, schedule: nil, days: nil,
                   quantityHint: nil, doseAmount: nil, confidence: 0.1, check: nil)
    }

    static func normalise(_ s: String) -> String {
        s.replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "–", with: "-").replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "‐", with: "-")
            .split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    private static let markerRx = JAText.regex(#"^\s*(?:[0-9lI]{1,2}\s*[).]\s*(?=\S)|[•*·]\s*|-\s+)"#)

    static func stripListMarker(_ s: String) -> String {
        guard let m = JAText.firstMatch(markerRx, in: s), let r = Range(m.range, in: s) else { return s }
        // "1.5 mg" is not a list marker: a marker's digit is followed by ")" or ". " + a letter.
        let rest = String(s[r.upperBound...])
        if s[..<r.upperBound].contains(".") , rest.first?.isLetter != true { return s }
        return rest
    }

    private static let perVolumeGlueRx = JAText.regex(#"(\d)\s*(mg|mcg|µg|ug|gm|g)\s*/\s*(\d*)\s*ml\b"#)

    /// "125 mg / 5 ml" -> "125mg/5ml" so it stays one token.
    static func gluePerVolume(_ s: String) -> String {
        perVolumeGlueRx.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "$1$2/$3ml")
    }

    // 1-0-1, 1-0-0-1, 1/2-0-1/2, l-O-l (OCR), 1+0+1
    private static let doseTok = #"(?:\d/\d|[0-9OolI|½¼])"#
    private static let patternRx = JAText.regex(#"(?<![\d/\w])("# + doseTok + #")\s*[-+]\s*("# + doseTok + #")\s*[-+]\s*("# + doseTok + #")(?:\s*[-+]\s*("# + doseTok + #"))?(?![\d/\w])"#)

    private static func doseValue(_ t: String) -> Double? {
        switch t {
        case "½": return 0.5
        case "¼": return 0.25
        case "O", "o": return 0
        case "l", "I", "|": return 1
        default:
            if t.contains("/") {
                let p = t.split(separator: "/").compactMap { Double($0) }
                return p.count == 2 && p[1] != 0 ? p[0] / p[1] : nil
            }
            return Double(t)
        }
    }

    static func extractPatternSchedule(_ s: inout String) -> DoseSchedule? {
        guard let m = JAText.firstMatch(patternRx, in: s), let whole = Range(m.range, in: s) else { return nil }
        var codes: [String] = []
        var total = 0.0
        for g in 1...4 {
            guard let t = JAText.group(m, g, in: s) else { continue }
            guard let v = doseValue(t) else { return nil }
            // Real prescriptions use small doses; "9-9-9" is not a schedule.
            guard v <= 4 else { return nil }
            total += v
            codes.append(v == v.rounded() ? String(Int(v)) : (t.contains("/") || t == "½" || t == "¼" ? t : String(v)))
        }
        // a pattern with no dose at all ("0-0-0") is noise
        guard total > 0 else { return nil }
        s.replaceSubrange(whole, with: " ")
        return DoseSchedule(code: codes.joined(separator: "-"), dosesPerDay: total)
    }

    private static let wordCodes: [String: (String, Double?)] = [
        "OD": ("OD", 1), "QD": ("OD", 1), "BD": ("BD", 2), "BID": ("BD", 2), "TDS": ("TDS", 3), "TID": ("TDS", 3),
        "QID": ("QID", 4), "QDS": ("QID", 4), "HS": ("HS", 1), "SOS": ("SOS", nil), "PRN": ("SOS", nil),
        "STAT": ("STAT", nil),
    ]

    static func wordSchedule(_ rawToken: String) -> DoseSchedule? {
        var t = rawToken.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:()")).uppercased()
        guard (2...4).contains(t.count) else { return nil }
        // OCR: "0D" for "OD", "B1D" for "BID"
        if t.allSatisfy({ $0.isLetter || $0 == "0" || $0 == "1" }) {
            t = String(t.map { $0 == "0" ? "O" : ($0 == "1" ? "I" : $0) })
        }
        guard let (code, perDay) = wordCodes[t] else { return nil }
        return DoseSchedule(code: code, dosesPerDay: perDay)
    }

    private static let durationRx = JAText.regex(#"(?:(?<!\w)(x|×|for)\s*|(?<![\w.]))([0-9Oo]{1,3})\s*(days?|dys|d|weeks?|wks?|w|months?|mo)(?![a-z])"#)

    /// "x 15 days", "x3d", "for 5 days", "1 week". A bare "d"/"w" counts only after x / for.
    static func extractDuration(_ s: inout String) -> Int? {
        var searchFrom = s.startIndex
        while let m = JAText.firstMatch(durationRx, in: String(s[searchFrom...])) {
            let sub = String(s[searchFrom...])
            guard let whole = Range(m.range, in: sub) else { return nil }
            let lead = JAText.group(m, 1, in: sub)
            let unit = (JAText.group(m, 3, in: sub) ?? "").lowercased()
            let digits = String((JAText.group(m, 2, in: sub) ?? "").map { $0 == "O" || $0 == "o" ? "0" : $0 })
            let bare = unit == "d" || unit == "w" || unit == "mo"
            if let n = Int(digits), n > 0, n <= 365, lead != nil || !bare {
                let days: Int
                switch unit.first {
                case "w": days = n * 7
                case "m": days = n * 30
                default: days = n
                }
                // translate the match range back to the full string and blank it
                let start = s.index(searchFrom, offsetBy: sub.distance(from: sub.startIndex, to: whole.lowerBound))
                let end = s.index(searchFrom, offsetBy: sub.distance(from: sub.startIndex, to: whole.upperBound))
                s.replaceSubrange(start..<end, with: " ")
                return days
            }
            // not a duration: skip past this match and look again
            let skipTo = sub.distance(from: sub.startIndex, to: whole.upperBound)
            searchFrom = s.index(searchFrom, offsetBy: skipTo)
        }
        return nil
    }

    private static let quantityRx = JAText.regex(#"(?:#\s*|\bqty\.?:?\s*|\bx\s*(?=\d+\s*(?:tabs?|tablets?|caps?|capsules?|nos|pcs)\b))(\d{1,3})(?:\s*(?:tabs?|tablets?|caps?|capsules?|nos|pcs)\b)?"#)

    static func extractQuantity(_ s: inout String) -> Int? {
        guard let m = JAText.firstMatch(quantityRx, in: s), let whole = Range(m.range, in: s) else { return nil }
        let digits = JAText.group(m, 1, in: s)
        guard let n = digits.flatMap(Int.init), n > 0 else { return nil }
        s.replaceSubrange(whole, with: " ")
        return n
    }

    static func tokenise(_ s: String) -> [String] {
        var out: [String] = []
        for piece in s.split(whereSeparator: { $0 == " " || $0 == "," }).map(String.init) {
            // "Tab.Pan" -> "Tab", "Pan"
            if let dot = piece.firstIndex(of: "."), dot != piece.startIndex,
               formWord(String(piece[..<dot])) != nil, piece.index(after: dot) < piece.endIndex {
                out.append(String(piece[..<dot]))
                out.append(String(piece[piece.index(after: dot)...]))
            } else {
                out.append(piece)
            }
        }
        return out
    }

    // MARK: form

    private static let formWords: [String: DoseForm] = [
        "tab": .tab, "tabs": .tab, "tablet": .tab, "tablets": .tab, "tb": .tab,
        "cap": .cap, "caps": .cap, "capsule": .cap, "capsules": .cap,
        "syp": .syp, "syr": .syp, "syrup": .syp, "susp": .syp, "suspension": .syp, "sol": .syp, "solution": .syp,
        "inj": .inj, "injection": .inj,
        "drops": .drops, "drop": .drops, "gtt": .drops,
        "cream": .cream, "oint": .oint, "ointment": .oint, "gel": .gel, "lotion": .lotion,
        "inh": .inhaler, "inhaler": .inhaler, "rotacap": .inhaler, "rotacaps": .inhaler, "respules": .inhaler, "mdi": .inhaler,
        "powder": .powder, "sachet": .powder, "pwd": .powder,
        "spray": .spray,
    ]

    static func formWord(_ token: String) -> DoseForm? {
        formWords[token.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".,;:()"))]
    }

    /// The form is the first token, or glued to it ("Tab.Pan"), or follows the brand ("Dolo 650 Tablet") within the first 4 tokens.
    /// In the "follows the brand" case every token before it must look like part of a medicine name.
    static func findForm(in tokens: [String]) -> (form: DoseForm, index: Int, trailing: Bool)? {
        guard !tokens.isEmpty else { return nil }
        var start = 0
        if tokens[0].lowercased() == "rx", tokens.count > 1 { start = 1 }
        if let f = formWord(tokens[start]) { return (f, start, false) }
        for index in (start + 1)..<min(tokens.count, start + 5) where index < tokens.count {
            if let f = formWord(tokens[index]), index > start {
                let before = tokens[start..<index]
                if before.allSatisfy({ ($0.first?.isLetter == true || $0.first?.isNumber == true) && $0.count <= 14 }) { return (f, index, true) }
            }
        }
        return nil
    }

    // MARK: numbers and strengths

    private static let numberRx = JAText.regex(#"^([0-9OolI]*[0-9][0-9OolI]*(?:\.[0-9OolI]+)?|\.\d+)\s*(mg|rng|mcg|µg|ug|gm|g|ml|iu|%)?(?:/(\d*)\s*(ml))?\.?$"#)

    static func number(_ token: String) -> (value: String, unit: String?, perVolume: String?)? {
        guard let m = JAText.firstMatch(numberRx, in: token) else { return nil }
        guard let raw = JAText.group(m, 1, in: token) else { return nil }
        let value = String(raw.map { c -> Character in
            switch c {
            case "O", "o": return "0"
            case "l", "I": return "1"
            default: return c
            }
        })
        let unit = JAText.group(m, 2, in: token).map(canonicalUnit)
        var perVolume: String?
        if JAText.group(m, 4, in: token) != nil {
            let v = JAText.group(m, 3, in: token) ?? ""
            perVolume = "\(v.isEmpty ? "1" : v) ml"
        }
        return (value, unit, perVolume)
    }

    private static func canonicalUnit(_ u: String) -> String {
        switch u.lowercased() {
        case "rng": return "mg"
        case "gm": return "g"
        case "ug", "µg": return "mcg"
        default: return u.lowercased()
        }
    }

    static func unitWord(_ token: String) -> String? {
        let t = token.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".,;"))
        return ["mg", "rng", "mcg", "µg", "ug", "gm", "g", "ml", "iu", "%"].contains(t) ? canonicalUnit(t) : nil
    }

    /// "/5ml" as its own token.
    static func perVolumeToken(_ token: String) -> String? {
        guard token.hasPrefix("/"), let m = JAText.firstMatch(JAText.regex(#"^/(\d*)\s*ml$"#), in: token) else { return nil }
        let v = JAText.group(m, 1, in: token) ?? ""
        return "\(v.isEmpty ? "1" : v) ml"
    }

    static func formatStrength(value: String, unit: String?, perVolume: String?) -> String {
        var s = value
        if let unit { s += " \(unit)" }
        if let perVolume { s += "/\(perVolume)" }
        return s
    }

    /// Leading digits only, which is what `Catalogue` stores ("40 mg" -> "40").
    /// Grams are converted to mg ("1 g" -> "1000") because catalogue names carry mg.
    static func strengthNumber(_ strength: String) -> String {
        let number = String(strength.prefix { $0.isNumber || $0 == "." })
        let unit = strength.dropFirst(number.count).trimmingCharacters(in: .whitespaces)
        if unit.hasPrefix("g"), let v = Double(number) {
            let mg = v * 1000
            return mg == mg.rounded() ? String(Int(mg)) : String(mg)
        }
        return number
    }

    private static let gluedRx = JAText.regex(#"^([A-Za-z]{3,}?)-?(\d{2,4})(mg)?$"#)

    /// "Dolo650", "Telma-40" -> brand + strength.
    static func splitGluedBrand(_ token: String) -> (brand: String, strength: String)? {
        guard let m = JAText.firstMatch(gluedRx, in: token), let brand = JAText.group(m, 1, in: token),
              let digits = JAText.group(m, 2, in: token) else { return nil }
        let unit = JAText.group(m, 3, in: token)
        return (brand, unit == nil ? digits : "\(digits) mg")
    }

    private static let stopWords: Set<String> = [
        "x", "×", "x.", "for", "iv", "im", "sc", "po", "ac", "pc", "after", "before", "food", "with", "daily", "morning",
        "night", "at", "bedtime", "per", "if", "needed", "continue", "as", "and", "then", "tab", "tabs",
        "apply", "take", "use", "local", "application", "instill", "massage", "rub", "put", "inhale", "gargle", "orally",
    ]

    static func isStopWord(_ token: String) -> Bool {
        stopWords.contains(token.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".,;:")))
    }

    // MARK: brand repair against the catalogue

    private static let lookalikes: [Character: [Character]] = ["0": ["O"], "1": ["I", "L"], "5": ["S"], "8": ["B"]]

    /// OCR reads "AZ1THRAL" for "AZITHRAL". The brand is changed only when exactly one repaired spelling is a real brand
    /// in the catalogue; otherwise it is left as read.
    static func repairBrand(_ brand: String, catalogue: Catalogue) -> String {
        let key = brand.filter(\.isLetter).uppercased()
        if catalogue.strengths[key] != nil { return brand }
        let words = brand.split(separator: " ").map(String.init)
        guard let first = words.first else { return brand }
        let letters = first.filter(\.isLetter).count
        let digits = first.filter { lookalikes[$0] != nil }
        guard letters >= 3, !digits.isEmpty, digits.count <= 3, first.count == letters + first.filter(\.isNumber).count else { return brand }
        var candidates: [String] = [""]
        for ch in first {
            if let subs = lookalikes[ch] {
                candidates = candidates.flatMap { prefix in subs.map { prefix + String($0) } }
            } else {
                candidates = candidates.map { $0 + String(ch) }
            }
        }
        let real = candidates.filter { catalogue.strengths[$0.uppercased()] != nil }
        guard real.count == 1, let fixed = real.first else { return brand }
        return ([fixed] + words.dropFirst()).joined(separator: " ")
    }
}
