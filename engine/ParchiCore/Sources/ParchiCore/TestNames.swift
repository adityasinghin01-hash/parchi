import Foundation

/// Result of mapping a test name written on a parchi to our canonical list.
public enum CanonicalMatch: Equatable, Sendable {
    /// One test, no look-alike: safe to use.
    case exact(String)
    /// Could be several tests (Free vs Total T3/T4, HbA1c vs average glucose, fasting vs PP sugar...).
    /// The Confirm screen must ASK the patient; never guess.
    case ambiguous([String])
    /// Not in the list: ask / show as typed.
    case unknown
}

/// One row of `tests_canonical.json` (only the fields the engine needs).
public struct CanonicalTest: Codable, Sendable, Equatable {
    public enum Fasting: Sendable, Equatable { case required, notRequired, unknown }

    public let name: String
    public let synonyms: [String]
    /// Look-alike tests that must not be silently swapped for this one.
    public let confusableWith: [String]
    public let fasting: Fasting

    public init(name: String, synonyms: [String], confusableWith: [String] = [], fasting: Fasting = .unknown) {
        self.name = name
        self.synonyms = synonyms
        self.confusableWith = confusableWith
        self.fasting = fasting
    }

    enum CodingKeys: String, CodingKey {
        case name = "test_canonical"
        case synonyms
        case confusableWith = "confusable_with"
        case fasting = "fasting_required"
    }

    private struct Confusable: Codable { let test: String }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        synonyms = try c.decodeIfPresent([String].self, forKey: .synonyms) ?? []
        confusableWith = (try c.decodeIfPresent([Confusable].self, forKey: .confusableWith) ?? []).map(\.test)
        if let flag = try? c.decode(Bool.self, forKey: .fasting) {
            fasting = flag ? .required : .notRequired
        } else {
            fasting = .unknown // the file uses the string "unknown"
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encode(synonyms, forKey: .synonyms)
        try c.encode(confusableWith.map { Confusable(test: $0) }, forKey: .confusableWith)
        switch fasting {
        case .required: try c.encode(true, forKey: .fasting)
        case .notRequired: try c.encode(false, forKey: .fasting)
        case .unknown: try c.encode("unknown", forKey: .fasting)
        }
    }
}

/// Lookup tables built once from the canonical list.
public struct TestCatalogue: Sendable {
    public let tests: [CanonicalTest]

    private let exactIndex: [String: [String]]   // spaces/punctuation/case-insensitive full alias -> canonical names
    private let looseIndex: [String: [String]]   // same, ignoring filler words ("test", "level")
    private let stemIndex: [String: [String]]    // alias without qualifiers (free/total/fasting/...) -> canonical names
    private let confusableIndex: [String: [String]]  // look-alike name -> canonical names that list it
    private let stemOfConfusable: [String: [String]] // stem of a look-alike name -> look-alike names

    public init(tests: [CanonicalTest]) {
        self.tests = tests
        var exact: [String: [String]] = [:]
        var loose: [String: [String]] = [:]
        var stem: [String: [String]] = [:]
        var confusable: [String: [String]] = [:]
        var confusableStem: [String: [String]] = [:]

        func add(_ map: inout [String: [String]], _ key: String, _ name: String) {
            guard !key.isEmpty else { return }
            if !(map[key]?.contains(name) ?? false) { map[key, default: []].append(name) }
        }

        for test in tests {
            for alias in [test.name] + test.synonyms {
                for variant in TestKey.variants(of: alias) {
                    add(&exact, TestKey.strict(variant), test.name)
                    add(&loose, TestKey.loose(variant), test.name)
                    add(&stem, TestKey.stem(variant), test.name)
                }
            }
            for other in test.confusableWith {
                for variant in TestKey.variants(of: other) {
                    add(&confusable, TestKey.strict(variant), test.name)
                    add(&confusable, TestKey.loose(variant), test.name)
                    add(&confusableStem, TestKey.stem(variant), other)
                }
            }
        }
        exactIndex = exact
        looseIndex = loose
        stemIndex = stem
        confusableIndex = confusable
        stemOfConfusable = confusableStem
    }

    /// Decodes `tests_canonical.json` ({"tests": [...]}).
    public init(json: Data) throws {
        struct File: Decodable { let tests: [CanonicalTest] }
        self.init(tests: try JSONDecoder().decode(File.self, from: json).tests)
    }

    fileprivate func match(_ written: String) -> CanonicalMatch {
        let strict = TestKey.strict(written)
        let loose = TestKey.loose(written)
        guard !strict.isEmpty else { return .unknown }

        // 1. The written name is a known name/synonym (or its abbreviation in brackets).
        let direct = exactIndex[strict] ?? looseIndex[loose] ?? []
        if direct.count > 1 { return .ambiguous(direct) }       // e.g. "UA" = urine analysis or uric acid
        if let only = direct.first {
            // Exact only if no look-alike differs from it by a missing qualifier alone
            // (written "Thyroid profile" while "Thyroid profile free" exists).
            let lookalikes = (tests.first { $0.name == only }?.confusableWith ?? [])
                .filter { TestKey.hasQualifier($0) && TestKey.stem($0) == strict }
            return lookalikes.isEmpty ? .exact(only) : .ambiguous([only] + lookalikes)
        }

        // 2. The qualifier is missing: "T3" could be Free or Total, "blood sugar" fasting / PP / random.
        if !TestKey.hasQualifier(written) {
            let stem = TestKey.stem(written)
            if let hits = stemIndex[stem], !stem.isEmpty {
                var candidates = hits
                for name in stemOfConfusable[stem] ?? [] where !candidates.contains(name) { candidates.append(name) }
                return .ambiguous(candidates)
            }
        }

        // 3. The written name is a look-alike of a test we know: ask which one is meant.
        if let owners = confusableIndex[strict] ?? confusableIndex[loose] {
            return .ambiguous(owners + [written.trimmingCharacters(in: .whitespacesAndNewlines)])
        }
        return .unknown
    }
}

/// Maps a test name as written on the parchi to the canonical name (case/space/punctuation-insensitive).
/// `.ambiguous` results must be asked on the confirm screen, never guessed.
public func canonicalTest(for written: String, catalogue: TestCatalogue) -> CanonicalMatch {
    catalogue.match(written)
}

enum TestKey {
    static let fillers: Set<String> = ["test", "tests", "level", "levels", "estimation"]
    static let qualifiers: Set<String> = [
        "free", "total", "fasting", "random", "post", "prandial", "postprandial", "pp", "2", "hours", "hour", "hr", "hrs",
    ]
    static let specimens: Set<String> = ["blood", "plasma", "serum"]

    static func words(_ text: String) -> [String] {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .lowercased()
            .split(whereSeparator: { !($0.isLetter || $0.isNumber) })
            .map(String.init)
    }

    static func strict(_ text: String) -> String { words(text).joined() }

    static func loose(_ text: String) -> String { words(text).filter { !fillers.contains($0) }.joined() }

    static func stem(_ text: String) -> String {
        words(text).filter { !fillers.contains($0) && !qualifiers.contains($0) && !specimens.contains($0) }.joined()
    }

    static func hasQualifier(_ text: String) -> Bool { words(text).contains { qualifiers.contains($0) } }

    /// The alias itself, without any bracket, and each bracket's content:
    /// "Fasting blood sugar (FBS)" -> [whole, "Fasting blood sugar", "FBS"].
    static func variants(of alias: String) -> [String] {
        var outside = ""
        var inside: [String] = []
        var current = ""
        var depth = 0
        for ch in alias {
            if ch == "(" {
                depth += 1
                if depth == 1 { current = ""; outside.append(" ") }
            } else if ch == ")" && depth > 0 {
                depth -= 1
                if depth == 0 { inside.append(current) }
            } else if depth > 0 {
                current.append(ch)
            } else {
                outside.append(ch)
            }
        }
        if depth > 0 { inside.append(current) } // unclosed bracket
        var result = [alias]
        for part in [outside] + inside where !words(part).isEmpty && !result.contains(part) { result.append(part) }
        return result
    }
}
