import Foundation

/// How many units (tablets, capsules, vials) one pack holds, from the pack labels in the product lists,
/// and how many packs a prescribed quantity needs. Pure and total: an unreadable label gives nil, never a guess.
public enum PackSize {
    private static let measureUnits: Set<String> = ["ml", "l", "litre", "liter", "gm", "g", "mg", "mcg", "iu", "kg"]
    private static let labelRx = JAText.regex(#"^(.+?) of (\d+(?:\.\d+)?)\s+(\S+)"#)
    private static let jaCountRx = JAText.regex(#"^\s*(\d+)\s*['’]?\s*s\b"#)
    private static let jaMeasureRx = JAText.regex(#"^\s*\d+(?:\.\d+)?\s*(?:ml|l|g|gm|mg|mdi)\b"#)

    /// Catalogue pack label: `"strip of 10 tablets"` -> 10, `"bottle of 100 ml Syrup"` -> 1 (a bottle is one unit),
    /// `"vial of 1 Injection"` -> 1, `"tube of 15 gm Cream"` -> 1. nil when the label cannot be understood
    /// (`"vial of 5.5 µcg Powder"`, an empty label).
    public static func unitsPerPack(label: String) -> Int? {
        let s = JAText.clean(label.lowercased())
        guard let m = JAText.firstMatch(labelRx, in: s),
              let number = JAText.group(m, 2, in: s), let unitRaw = JAText.group(m, 3, in: s) else { return nil }
        let unit = unitRaw.trimmingCharacters(in: CharacterSet(charactersIn: ".,"))
        if measureUnits.contains(unit) { return 1 }
        guard !number.contains("."), let count = Int(number), count >= 1 else { return nil }
        return count
    }

    /// Jan Aushadhi list pack size: `"10's"` -> 10, `"100 ml"` -> 1, `"15 g"` -> 1, `"Vial"` -> 1; nil otherwise
    /// (`"Pair in Mono-Pack"`).
    public static func unitsPerPack(janAushadhiUnitSize text: String) -> Int? {
        let s = JAText.clean(text.lowercased())
        if let m = JAText.firstMatch(jaCountRx, in: s), let count = JAText.group(m, 1, in: s).flatMap(Int.init), count >= 1 {
            return count
        }
        if JAText.has(jaMeasureRx, in: s) || s.hasPrefix("vial") { return 1 }
        return nil
    }

    /// `ceil(quantity / unitsPerPack)`, at least 1. Unknown pack size: 1 pack (the caller must say so on screen).
    public static func packsNeeded(quantity: Int, unitsPerPack: Int?) -> Int {
        guard let units = unitsPerPack, units >= 1 else { return 1 }
        return max(1, (max(quantity, 1) + units - 1) / units)
    }
}
