import CoreGraphics
import Foundation
import ParchiCore
import Vision
#if canImport(UIKit)
import UIKit
#endif

/// What the phone itself could read from a PRINTED parchi.
struct OnPhoneReadResult: Equatable {
    /// Medicine and test lines the reader is sure of, in page order (same type the server reader returns).
    var lines: [ReaderLine]
    /// Raw text of lines that look like a medicine or test but that the parser is not sure of. Never turned into a medicine.
    var needsHelp: [String]
    /// Plain-language, honest summary for the person using the app.
    var note: String
}

/// Reads a printed parchi on the phone: Apple Vision (no network, nothing written to disk, no logging)
/// -> rows (`LineGrouper`) -> `PrintedParser` -> `ReaderLine`. Handwriting is NOT supported; what Vision cannot
/// read as printed text ends up in `needsHelp` or is dropped, never guessed into a medicine.
struct OnPhoneReader {
    let parser: PrintedParser
    let tests: TestCatalogue?

    init(parser: PrintedParser, tests: TestCatalogue? = nil) {
        self.parser = parser
        self.tests = tests
    }

    /// Uses the catalogue files bundled in the app (brand strengths, canonical tests).
    init(bundle: Bundle = .main) {
        var catalogue: Catalogue?
        if let url = bundle.url(forResource: "brand_strengths", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let map = try? JSONDecoder().decode([String: [String]].self, from: data) {
            catalogue = Catalogue(strengths: map.mapValues(Set.init))
        }
        var testCatalogue: TestCatalogue?
        if let url = bundle.url(forResource: "tests_canonical", withExtension: "json"),
           let data = try? Data(contentsOf: url) {
            testCatalogue = try? TestCatalogue(json: data)
        }
        self.init(parser: PrintedParser(catalogue: catalogue), tests: testCatalogue)
    }

    // MARK: - Reading

    #if canImport(UIKit)
    func read(_ image: UIImage) async -> OnPhoneReadResult {
        guard let cg = image.cgImage else { return interpret(boxes: [], aspect: 1) }
        return await read(cgImage: cg, orientation: CGImagePropertyOrientation(image.imageOrientation))
    }
    #endif

    func read(cgImage: CGImage, orientation: CGImagePropertyOrientation = .up) async -> OnPhoneReadResult {
        let swapped = [.left, .right, .leftMirrored, .rightMirrored].contains(orientation)
        let (w, h) = swapped ? (cgImage.height, cgImage.width) : (cgImage.width, cgImage.height)
        let aspect = CGFloat(w) / CGFloat(max(h, 1))
        let boxes = await Task.detached(priority: .userInitiated) {
            Self.recognise(cgImage, orientation: orientation)
        }.value
        return interpret(boxes: boxes, aspect: aspect)
    }

    /// English pass first. A Hindi (hi-IN) pass is added only when this Vision version supports it AND the English pass found
    /// nothing medicine-shaped (a mostly-Hindi page); Hindi boxes that overlap English ones are dropped.
    static func recognise(_ image: CGImage, orientation: CGImagePropertyOrientation) -> [OCRBox] {
        var boxes = pass(image, orientation: orientation, languages: ["en-US"])
        if !boxes.contains(where: { looksLikeMedicineCue($0.text) }), supports("hi-IN") {
            let extra = pass(image, orientation: orientation, languages: ["hi-IN", "en-US"])
                .filter { new in !boxes.contains { $0.rect.intersects(new.rect) } }
            boxes += extra
        }
        return boxes
    }

    private static func supports(_ language: String) -> Bool {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        return ((try? request.supportedRecognitionLanguages()) ?? []).contains(language)
    }

    private static func pass(_ image: CGImage, orientation: CGImagePropertyOrientation, languages: [String]) -> [OCRBox] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false      // brand names are not dictionary words
        request.recognitionLanguages = languages
        let handler = VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:])
        guard (try? handler.perform([request])) != nil else { return [] }
        return (request.results ?? []).compactMap { obs in
            guard let top = obs.topCandidates(1).first else { return nil }
            return OCRBox(text: top.string, rect: obs.boundingBox, confidence: top.confidence)
        }
    }

    // MARK: - Interpreting (pure, testable without Vision)

    func interpret(boxes: [OCRBox], aspect: CGFloat) -> OnPhoneReadResult {
        interpret(rows: LineGrouper.group(boxes, aspect: aspect).map(Self.rowText))
    }

    /// A row is its boxes joined left to right. When the row starts with something that is not a medicine (a side column
    /// like "c/o Dx: ...") and a later box starts with a dosage form ("Tab", "Syr"...), the row starts at that box.
    static func rowText(_ row: TextLine) -> String {
        guard row.boxes.count > 1, !startsWithFormWord(row.boxes[0].text),
              let k = row.boxes.indices.dropFirst().first(where: { startsWithFormWord(row.boxes[$0].text) }) else { return row.text }
        return row.boxes[k...].map(\.text).joined(separator: " ")
    }

    func interpret(rows: [String]) -> OnPhoneReadResult {
        var lines: [ReaderLine] = []
        var needsHelp: [String] = []

        for text in rows.flatMap({ Self.split(Self.clean($0)) }) where !text.isEmpty {
            switch classify(text) {
            case .medicine(let line): lines.append(line)
            case .tests(let found, let unknown):
                lines += found.map { ReaderLine(kind: "test", name: $0, strength: nil, quantity: nil, schedule: nil) }
                needsHelp += unknown
            case .needsHelp: needsHelp.append(text)
            case .ignore: break
            }
        }
        return OnPhoneReadResult(lines: lines, needsHelp: needsHelp, note: Self.note(lines: lines.count, unsure: needsHelp.count))
    }

    enum Verdict: Equatable { case medicine(ReaderLine), tests([String], unknown: [String]), needsHelp, ignore }

    func classify(_ text: String) -> Verdict {
        let startsWithForm = Self.startsWithFormWord(text)

        if !startsWithForm, let list = Self.testList(in: text) {
            var found: [String] = [], unknown: [String] = []
            for name in list.names {
                // "Inv:", "Investigations:", "Get done:" list tests only; "Adv:" may also hold plain advice, so a name must be a known test.
                if list.explicit { found.append(name); continue }
                guard let tests, canonicalTest(for: name, catalogue: tests) != .unknown else { unknown.append(name); continue }
                found.append(name)
            }
            return .tests(found, unknown: unknown)
        }
        if !startsWithForm, Self.isHeaderOrFooter(text) { return .ignore }

        let item = parser.parse(line: text)
        let medicineShaped = item.confidence > 0.1 && (item.form != nil || item.brand != nil)
        if medicineShaped {
            // Sure = the parser's own confident threshold AND a form AND a brand were read. Anything less is for the person to check.
            if item.isConfident, item.form != nil, let brand = item.brand, !brand.isEmpty {
                return .medicine(ReaderLine(kind: "medicine", name: brand, strength: item.strength,
                                            quantity: item.quantityHint, schedule: item.schedule?.code))
            }
            return .needsHelp
        }
        return Self.hasMedicineClue(text) ? .needsHelp : .ignore
    }

    // MARK: - Text rules

    static func clean(_ raw: String) -> String {
        var t = raw.replacingOccurrences(of: "\u{00A0}", with: " ").split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        t = String(t.prefix(160))
        // Vision often drops the space after a bullet or a form word: "-Tab", "T.FLOXMED", "SolISOTROY", "MR1-1-1".
        for (regex, template) in glueFixes {
            t = regex.stringByReplacingMatches(in: t, range: NSRange(t.startIndex..., in: t), withTemplate: template)
        }
        return t
    }

    private static let glueFixes: [(NSRegularExpression, String)] = [
        (rx(#"^(\W{0,2}[-—–•])(?=[A-Za-z])"#), "$1 "),                                       // "-Inj CEFTINEZ"
        (rx(#"^(\W{0,3}(?:\d{1,2}\s*[).]\s*)?)([TC]\.)(?=[A-Za-z]{3,})"#), "$1$2 "),            // "T.FLOXMED"
        (try! NSRegularExpression(pattern: #"^(\W{0,3}(?:\d{1,2}\s*[).]\s*)?)(Tab|Cap|Syr|Syp|Sol|Inj|Gtt)(?=[A-Z]{3,})"#), "$1$2 "),   // "SolISOTROY" (case-sensitive)
        (rx(#"([A-Za-z])(?=[0-9]\s*-\s*[0-9]\s*-\s*[0-9](?![\d/\w]))"#), "$1 "),                // "MR1-1-1"
    ]

    private static func rx(_ pattern: String) -> NSRegularExpression {
        // Patterns are literals in this file; a typo should fail loudly in the unit tests, not at a user's phone.
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }

    private static func matches(_ regex: NSRegularExpression, _ s: String) -> Bool {
        regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil
    }

    private static let formStart = rx(#"^\W{0,3}(?:\d{1,2}\s*[).]\s*)?(?:rx\s*)?(?:tab|tabs|tablet|cap|caps|capsule|syp|syr|syrup|susp|inj|injection|drops?|e/d|gtt|cream|oint|ointment|gel|lotion|inh|inhaler|sachet|powder|spray|nasal spray|respules?|rotacap|t\.|c\.)(?![A-Za-z])"#)

    /// A leading dosage-form word that starts a medicine line: an optional bullet or number first, then Tab / T. / Cap / C. / Syr ...,
    /// then a word of 3+ letters (the brand). Full words like "Tablet" are left out on purpose: after a brand they are not line starts.
    private static let startRx = rx(#"(?:(?<=\s)(?<!\d\s)|^)((?:\d{1,2}\s*[).]|[-—–•])\s*)?((?:tab|tabs|cap|caps|syp|syr|syrup|inj|e/d|drops|gtt|cream|oint|gel|lotion|inh|respules?|rotacap|sachet|powder|spray|nasal spray|sol|t\.|c\.)\.?)\s+(?=[A-Za-z]{3,})"#)

    /// One printed row can hold more than one medicine ("1) Tab A ... 2) Tab B ...", "Tab A x 3d Tab B ..."), or a side column
    /// of other text before the medicine ("c/o loose motions - T. Hypercin ..."). Cuts the row at each line start:
    /// text before the first start is dropped when it is not itself a medicine line; later starts begin a new line.
    static func split(_ text: String) -> [String] {
        let starts = startRx.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { m -> (Range<String.Index>, Bool, String)? in
            guard let r = Range(m.range, in: text) else { return nil }
            let marked = m.range(at: 1).location != NSNotFound
            let word = Range(m.range(at: 2), in: text).map { String(text[$0]).lowercased() } ?? ""
            return (r, marked, word)
        }
        guard let first = starts.first else { return [text] }
        var cuts: [String.Index] = []
        if first.0.lowerBound == text.startIndex || startsWithFormWord(text) {
            cuts.append(text.startIndex)
        } else {
            let head = String(text[..<first.0.lowerBound])
            // Dropping a head is only safe when something marks the line start (a bullet, a number, or a full "tab"/"cap" word);
            // "Dr. T. Sharma MBBS" must not turn into a medicine line.
            guard first.1 || !["t.", "c."].contains(first.2), !isHeaderOrFooter(head) || first.1 else { return [text] }
            cuts.append(first.0.lowerBound)
        }
        for s in starts where s.0.lowerBound > cuts[0] {
            let segment = String(text[cuts.last!..<s.0.lowerBound])
            if startsWithFormWord(segment) { cuts.append(s.0.lowerBound) }
        }
        var parts: [String] = []
        for (i, c) in cuts.enumerated() {
            let end = i + 1 < cuts.count ? cuts[i + 1] : text.endIndex
            var part = String(text[c..<end]).trimmingCharacters(in: .whitespaces)
            if part.lowercased().hasSuffix(" rx") { part = String(part.dropLast(3)).trimmingCharacters(in: .whitespaces) }
            if !part.isEmpty { parts.append(part) }
        }
        return parts
    }

    static func startsWithFormWord(_ s: String) -> Bool { matches(formStart, s) }

    /// Patient, doctor, clinic, vitals, dates, phone numbers and similar. Never a medicine, even if a stray word looks like a form.
    private static let headerRx = rx(
        #"^\W{0,3}(?:dr\b|doctor|reg\b|reg\.|regn|name\b|patient|age\b|sex\b|date\b|dt\b|ph\b|phone|mob|mobile|tel\b|address|addr\b|timings?|emergency|bp\b|pulse|temp\b|spo2|wt\b|weight|ht\b|height|bmi|c/o|dx\b|diagnosis|provisional|complaints?|history|allergies|not valid|valid|hospital|clinic|nursing|signature|sign\b|stamp|review|f/u|follow|next visit|rx\s*$|page\b|opd\b|uhid|mr\s?no|visit|consultant|mbbs|md\b|ms\b|dnb|specialist|www\.|email|e-mail)"#)
    private static let credentialRx = rx(#"\b(?:mbbs|m\.?d\.?|m\.?s\.?|dnb|dgo|dch|bams|bhms|clinic|hospital|nursing home|polyclinic|health cent(?:re|er)|medical cent(?:re|er)|reg\.? ?no)\b"#)

    static func isHeaderOrFooter(_ s: String) -> Bool { matches(headerRx, s) || matches(credentialRx, s) }

    private static let testPrefix = rx(#"^\W{0,3}(adv(?:ice)?|inv(?:estigations?)?|get done|tests?(?: advised)?|lab)\s*[:\-]\s*(.+)$"#)

    /// "Adv: CBC, HbA1c" -> ["CBC", "HbA1c"], as written.
    static func testList(in s: String) -> (names: [String], explicit: Bool)? {
        guard let m = testPrefix.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
              let head = Range(m.range(at: 1), in: s), let r = Range(m.range(at: 2), in: s) else { return nil }
        let explicit = !s[head].lowercased().hasPrefix("adv")
        let names = s[r].split(whereSeparator: { $0 == "," || $0 == ";" || $0 == "+" })
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " .-:")) }
            .filter { $0.count >= 2 }
        return names.isEmpty ? nil : (names, explicit)
    }

    private static let clueRx = rx(#"(?:\b\d+(?:\.\d+)?\s*(?:mg|mcg|ml|iu)\b|(?<![\d/\w])[0-9Ol]\s*[-+]\s*[0-9Ol]\s*[-+]\s*[0-9Ol](?![\d/\w])|\b(?:bd|tds|qid|sos|od)\s*$|\bx\s*\d+\s*(?:d|days?)\b)"#)

    /// Something a medicine line carries (a strength with unit, a 1-0-1 pattern, "x 5 days") although no form was read.
    static func hasMedicineClue(_ s: String) -> Bool { matches(clueRx, s) }

    static func looksLikeMedicineCue(_ s: String) -> Bool { startsWithFormWord(s) || hasMedicineClue(s) }

    // MARK: - Note

    static func note(lines: Int, unsure: Int) -> String {
        if lines == 0 && unsure == 0 {
            return "Nothing could be read on this phone. Handwriting cannot be read here. Add the medicines yourself."
        }
        if lines == 0 || unsure > lines {
            return "Handwriting could not be read on this phone. Only a few lines were read. Check every line and add the rest yourself."
        }
        let base = "Read on this phone. Printed text only. Check every line."
        return unsure == 0 ? base : base + " \(unsure) line\(unsure == 1 ? "" : "s") could not be read for sure."
    }
}

#if canImport(UIKit)
extension CGImagePropertyOrientation {
    init(_ o: UIImage.Orientation) {
        switch o {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
#endif
