import Foundation

/// When in the day a dose is taken. Used to lay out "today's doses" on the Care screen.
public enum DoseSlot: String, Codable, CaseIterable, Sendable {
    case morning, afternoon, evening, night
}

/// Pure dose and refill maths. Nothing here recommends a dose: it only reads what the doctor wrote.
public enum Doses {
    /// Refill reminder lead time: "Refill in N days" is the days left minus this.
    public static let refillLeadDays = 3

    /// Units taken per day from what the doctor wrote.
    /// "1-0-1" → 2, "0-0-1" → 1, "1/2-0-1/2" → 1, "OD"/"HS" → 1, "BD" → 2, "TDS" → 3, "QID" → 4.
    /// "0-0-0" → 0. Unreadable or "as needed" (SOS/PRN) → nil, because no refill date can be promised.
    public static func dosesPerDay(schedule: String) -> Double? {
        let text = normalise(schedule)
        guard !text.isEmpty else { return nil }
        switch text {
        case "OD", "QD", "HS", "QHS", "ONCEDAILY": return 1
        case "BD", "BID", "TWICEDAILY": return 2
        case "TDS", "TID": return 3
        case "QID", "QDS": return 4
        default: break
        }
        guard let parts = pattern(text) else { return nil }
        return parts.reduce(0, +)
    }

    /// Which parts of the day a dose falls in. "1-0-1" → morning, night. Empty when unknown or zero.
    public static func doseSlots(schedule: String) -> [DoseSlot] {
        let text = normalise(schedule)
        switch text {
        case "OD", "QD", "ONCEDAILY": return [.morning]
        case "HS", "QHS": return [.night]
        case "BD", "BID", "TWICEDAILY": return [.morning, .night]
        case "TDS", "TID": return [.morning, .afternoon, .night]
        case "QID", "QDS": return [.morning, .afternoon, .evening, .night]
        default: break
        }
        guard let parts = pattern(text) else { return [] }
        let slots: [DoseSlot]
        switch parts.count {
        case 3: slots = [.morning, .afternoon, .night]
        case 4: slots = [.morning, .afternoon, .evening, .night]
        default: return []
        }
        return zip(slots, parts).filter { $0.1 > 0 }.map(\.0)
    }

    /// Whole days of medicine left after `daysElapsed` days of taking it, never below 0.
    /// A partial last day does not count: 10 units at 3 a day is 3 days. nil when the daily dose is unknown or zero.
    public static func daysLeft(quantity: Int, dosesPerDay: Double?, daysElapsed: Int = 0) -> Int? {
        guard let perDay = dosesPerDay, perDay > 0, quantity >= 0 else { return nil }
        let remaining = Double(quantity) - Double(max(0, daysElapsed)) * perDay
        guard remaining > 0 else { return 0 }
        return Int((remaining / perDay + 1e-9).rounded(.down))
    }

    /// Days from now until the refill reminder: days left minus `refillLeadDays`, never below 0 ("refill now").
    public static func refillInDays(quantity: Int, dosesPerDay: Double?, daysElapsed: Int = 0) -> Int? {
        daysLeft(quantity: quantity, dosesPerDay: dosesPerDay, daysElapsed: daysElapsed).map { max(0, $0 - refillLeadDays) }
    }

    /// Calendar day of the refill reminder. `started` is the day the patient began taking the pack.
    public static func refillDate(quantity: Int, dosesPerDay: Double?, started: Date, now: Date = Date(),
                                  calendar: Calendar = .current) -> Date? {
        let begin = calendar.startOfDay(for: started)
        let today = calendar.startOfDay(for: now)
        let elapsed = max(0, calendar.dateComponents([.day], from: begin, to: today).day ?? 0)
        guard let wait = refillInDays(quantity: quantity, dosesPerDay: dosesPerDay, daysElapsed: elapsed) else { return nil }
        return calendar.date(byAdding: .day, value: wait, to: today)
    }

    // MARK: Parsing

    private static func normalise(_ schedule: String) -> String {
        schedule.uppercased()
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: " ", with: "")
    }

    /// "1-0-1", "1/2-0-1/2", "0.5-0-1", "1-1-1-1". Needs 3 or 4 numeric parts.
    private static func pattern(_ text: String) -> [Double]? {
        let parts = text.split(separator: "-", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3 || parts.count == 4 else { return nil }
        var values: [Double] = []
        for part in parts {
            guard let value = number(part), value >= 0 else { return nil }
            values.append(value)
        }
        return values
    }

    private static func number(_ part: String) -> Double? {
        if part.contains("/") {
            let pieces = part.split(separator: "/", omittingEmptySubsequences: false)
            guard pieces.count == 2, let top = Double(pieces[0]), let bottom = Double(pieces[1]), bottom > 0 else { return nil }
            return top / bottom
        }
        return Double(part)
    }
}
