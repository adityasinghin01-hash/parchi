import Foundation
import Observation
import ParchiCore

/// One step per seller: pending -> opened -> itemsAdded -> atCheckout -> ordered | skipped.
/// Parchi only tracks the state. The USER taps "Add to cart" and "Pay" on the seller's own site.
enum CheckoutStepState: Int, Comparable {
    case pending, opened, itemsAdded, atCheckout, ordered, skipped

    static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
    var isFinished: Bool { self == .ordered || self == .skipped }

    var label: String {
        switch self {
        case .pending: return "Waiting"
        case .opened: return "Opened"
        case .itemsAdded: return "Items added"
        case .atCheckout: return "At checkout"
        case .ordered: return "Ordered ✓"
        case .skipped: return "Skipped"
        }
    }
}

struct CheckoutItem: Identifiable, Hashable {
    let id: String
    let name: String          // "Dolo 650"
    let searchText: String    // what "Find on page" looks for ("Dolo")
    let quantity: Int
    let isMedicine: Bool
    let productURL: URL?      // exact product page, if engine/catalogue/product_links.json has one
}

enum CheckoutStepKind: Hashable {
    case web      // the seller's own website in the in-app browser
    case message  // local shop: SMS composer on a device, share sheet in the Simulator
}

struct CheckoutStep: Identifiable, Hashable {
    let id: String            // seller id
    let sellerName: String
    let kind: CheckoutStepKind
    let items: [CheckoutItem]
    let startURL: URL?
    let phone: String?
    /// Text for the local-shop SMS.
    var messageBody: String {
        let lines = items.map { "- \($0.name)" + ($0.isMedicine ? " (qty \($0.quantity))" : "") }
        return "Hello, I would like to buy these. Please tell me what you have in stock and the total price:\n"
            + lines.joined(separator: "\n") + "\n(Sent from Parchi)"
    }
}

/// A learned order-confirmation page for one seller. Never invent one: see engine/catalogue/seller_confirm_patterns.json.
struct ConfirmPattern: Decodable {
    let seller_id: String
    let url_regex: String
}

@MainActor
@Observable
final class CheckoutFlow {
    let steps: [CheckoutStep]
    private(set) var states: [String: CheckoutStepState]
    private(set) var added: [String: Set<String>] = [:]
    private(set) var currentIndex: Int
    /// Item "Find on page" and the checklist focus on. Defaults to the first item not yet added.
    private(set) var focusedItemID: String?
    /// Claude wires re-planning here later.
    @ObservationIgnored var onSkip: (String) -> Void = { _ in }
    @ObservationIgnored private let patterns: [ConfirmPattern]

    init(steps: [CheckoutStep], patterns: [ConfirmPattern] = CheckoutFlow.loadPatterns(), startAt: Int = 0) {
        self.steps = steps
        self.patterns = patterns
        self.states = Dictionary(uniqueKeysWithValues: steps.map { ($0.id, CheckoutStepState.pending) })
        self.currentIndex = min(max(startAt, 0), steps.count)
        self.focusedItemID = self.currentIndex < steps.count ? steps[self.currentIndex].items.first?.id : nil
    }

    // MARK: Reading state

    var current: CheckoutStep? { currentIndex < steps.count ? steps[currentIndex] : nil }
    var isFinished: Bool { current == nil }
    var currentState: CheckoutStepState { current.map { states[$0.id] ?? .pending } ?? .ordered }
    func state(of stepID: String) -> CheckoutStepState { states[stepID] ?? .pending }
    func isAdded(_ itemID: String) -> Bool { current.map { added[$0.id]?.contains(itemID) ?? false } ?? false }
    var focusedItem: CheckoutItem? { current?.items.first { $0.id == focusedItemID } }
    var headerText: String {
        guard let step = current else { return "All steps done" }
        let n = step.items.count
        return "Step \(currentIndex + 1) of \(steps.count) · \(step.sellerName) · \(n) item\(n == 1 ? "" : "s")"
    }

    // MARK: Transitions (forward only)

    /// The step's page or composer was shown.
    func opened() {
        guard let step = current, currentState == .pending else { return }
        states[step.id] = .opened
    }

    func focus(itemID: String) {
        guard current?.items.contains(where: { $0.id == itemID }) == true else { return }
        focusedItemID = itemID
    }

    /// User says they added the focused item to the cart on the seller's site.
    func markAdded() {
        guard let step = current, let item = focusedItem, currentState == .opened || currentState == .itemsAdded else { return }
        added[step.id, default: []].insert(item.id)
        if added[step.id]?.count == step.items.count { states[step.id] = .itemsAdded }
        focusedItemID = step.items.first { !(added[step.id]?.contains($0.id) ?? false) }?.id ?? item.id
    }

    /// Local-shop step: the message was sent, so the whole list is "added".
    func markAllAdded() {
        guard let step = current, currentState == .opened || currentState == .itemsAdded else { return }
        added[step.id] = Set(step.items.map(\.id))
        states[step.id] = .itemsAdded
    }

    func goToCheckout() {
        guard let step = current, currentState == .opened || currentState == .itemsAdded else { return }
        states[step.id] = .atCheckout
    }

    /// User tap "Ordered ✓" (only after checkout was reached).
    func markOrdered() {
        guard let step = current, currentState == .atCheckout else { return }
        states[step.id] = .ordered
        advance()
    }

    func skipCurrent() {
        guard let step = current else { return }
        states[step.id] = .skipped
        advance()
        onSkip(step.id)
    }

    /// Auto-confirm only when a learned URL pattern for THIS seller matches. With no patterns this never fires.
    func pageChanged(to url: URL) {
        guard let step = current, currentState == .atCheckout else { return }
        let text = url.absoluteString
        for pattern in patterns where pattern.seller_id == step.id {
            if text.range(of: pattern.url_regex, options: .regularExpression) != nil {
                states[step.id] = .ordered
                advance()
                return
            }
        }
    }

    private func advance() {
        if let next = steps.indices.first(where: { !(states[steps[$0].id]?.isFinished ?? false) }) {
            currentIndex = next
            focusedItemID = steps[next].items.first?.id
        } else {
            currentIndex = steps.count
            focusedItemID = nil
        }
    }

    // MARK: Building steps from an approved plan

    nonisolated static func loadPatterns() -> [ConfirmPattern] {
        struct File: Decodable { let patterns: [ConfirmPattern] }
        guard let url = Bundle.main.url(forResource: "seller_confirm_patterns", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data) else { return [] }
        return file.patterns
    }

    /// Online first (no trip), then labs, then local shops; name order inside each group.
    static func steps(for plan: Plan, model: AppModel) -> [CheckoutStep] {
        func rank(_ c: Channel) -> Int {
            switch c {
            case .onlinePharmacy, .quickCommerce: return 0
            case .lab: return 1
            case .janAushadhi, .localChemist: return 2
            }
        }
        let links = SellerSites.productLinks()
        let ordered = plan.sellerIDs.sorted {
            let a = model.seller($0)?.channel ?? .localChemist, b = model.seller($1)?.channel ?? .localChemist
            return rank(a) != rank(b) ? rank(a) < rank(b) : model.sellerName($0) < model.sellerName($1)
        }
        return ordered.map { sellerID in
            let site = SellerSites.site(id: sellerID)
            let items: [CheckoutItem] = plan.lines.filter { $0.sellerID == sellerID }.compactMap { line in
                guard let rx = model.scenario.items.first(where: { $0.id == line.itemID }) else { return nil }
                let url = site.flatMap { links.url(for: rx, linkKey: $0.linkKey) }
                return CheckoutItem(id: rx.id, name: model.itemName(rx.id), searchText: String(rx.name.split(separator: " ").first ?? ""),
                                    quantity: rx.quantity, isMedicine: rx.kind == .medicine, productURL: url)
            }
            let channel = model.seller(sellerID)?.channel ?? .localChemist
            var start: URL? = items.compactMap(\.productURL).first
            if start == nil, let site {
                start = channel == .lab ? (SellerSites.labBookingURL(keyword: site.labKeyword) ?? site.home) : site.home
            }
            return CheckoutStep(id: sellerID, sellerName: model.sellerName(sellerID), kind: start == nil ? .message : .web,
                                items: items, startURL: start, phone: nil)
        }
    }
}
