import Foundation
import ParchiCore

/// Paise → "₹1,030.40" with Indian digit grouping.
func rupees(_ paise: Paise) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.locale = Locale(identifier: "en_IN")
    formatter.currencyCode = "INR"
    formatter.maximumFractionDigits = paise % 100 == 0 ? 0 : 2
    return formatter.string(from: NSNumber(value: Double(paise) / 100)) ?? "₹\(paise / 100)"
}

func readyText(minutes: Int) -> String {
    if minutes < 60 { return "in \(minutes) min" }
    if minutes < 24 * 60 { return "in \(minutes / 60) h" }
    let days = minutes / (24 * 60)
    return days == 1 ? "in 1 day" : "in \(days) days"
}
