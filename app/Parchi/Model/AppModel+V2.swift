import Foundation
import ParchiCore

extension AppModel {
    /// Main PIN of each city we cover; the true-price endpoint needs 6 digits.
    static let cityPIN = ["Muradnagar": "201206", "Meerut": "250001", "Modinagar": "201204",
                          "Ghaziabad": "201001", "Hapur": "245101", "Noida": "201301"]

    var areaName: String { location.centre.name }
    var areaPIN: String { Self.cityPIN[areaName] ?? "201206" }

    /// Mock mode shows these, clearly labelled "Demo". Live mode only ever shows what the server counted.
    static let demoReliability: [String: SellerReliability] = [
        "truemeds": SellerReliability(sellerID: "truemeds", score: 0.78, orders: 23),
        "apollo": SellerReliability(sellerID: "apollo", score: 0.93, orders: 41),
        "redcliffe": SellerReliability(sellerID: "redcliffe", score: 0.90, orders: 30),
        "healthians": SellerReliability(sellerID: "healthians", score: 0.86, orders: 18),
        "medkart": SellerReliability(sellerID: "medkart", score: 0.81, orders: 12),
    ]

    func refreshReliability() async {
        guard backend.mode == .live else {
            reliabilityScores = Self.demoReliability
            reliabilityIsDemo = true
            return
        }
        guard let client = backend.makeClient() else { return }
        do {
            let rows = try await V2Client(client: client).reliability(area: areaName)
            reliabilityScores = Dictionary(rows.map { ($0.sellerID, $0) }, uniquingKeysWith: { first, _ in first })
            reliabilityIsDemo = false
        } catch {
            reliabilityScores = [:]   // no data is shown as no chip, never as a made-up number
        }
    }

    func reliabilityNote(_ sellerID: String) -> String? {
        guard let row = reliabilityScores[sellerID], row.orders > 0 else { return nil }
        let outOfTen = Int((row.score * 10).rounded())
        return "\(reliabilityIsDemo ? "Demo · " : "")Delivers about \(outOfTen) of 10 in \(areaName) (\(row.orders) orders)"
    }

    func truePriceNote(_ sellerID: String) -> String? {
        guard let info = truePrices[sellerID], info.enough, let extra = info.medianExtraPaise else { return nil }
        return "Real extra fees reported: \(rupees(max(extra, 0))) (\(info.reports) reports)"
    }

    func refreshTruePrices() async {
        guard backend.mode == .live, let client = backend.makeClient(), let plan = approvedPlan ?? plan else { return }
        for sellerID in plan.sellerIDs {
            if let info = try? await V2Client(client: client).truePrice(seller: sellerID, pincode: areaPIN) { truePrices[sellerID] = info }
        }
    }

    /// A7: "What did you pay?". Optional, never blocks. Returns a short message for the sheet.
    func reportPaid(sellerID: String, rupees paid: Int) async -> String {
        guard backend.mode == .live, let orderID = liveOrderID, let client = backend.makeClient(), let approved = approvedPlan else {
            return "Thanks. Demo mode: nothing was sent."
        }
        let items = approved.lines.filter { $0.sellerID == sellerID }.reduce(0) { $0 + $1.price }
        do {
            try await V2Client(client: client).paid(orderID: orderID, sellerID: sellerID, paidPaise: paid * 100, itemsPaise: items, pincode: areaPIN)
            await refreshTruePrices()
            return "Thanks, saved. It helps show the real price."
        } catch {
            return (error as? LiveError)?.message ?? "Could not send. Try again on Wi-Fi."
        }
    }

    /// A6: register the refill watch for medicines that have a dose schedule. The reader does not give schedules yet,
    /// so today this does nothing (Care falls back to the local maths); it is ready the day schedules arrive.
    func registerRefillWatch(items: [(name: String, quantity: Int, schedule: String)]) async {
        guard backend.mode == .live, !items.isEmpty, let client = backend.makeClient() else { return }
        let day = ISOTime.format(.now, "yyyy-MM-dd")
        _ = try? await V2Client(client: client).watchRefill(items: items, startDate: day)
    }
}
