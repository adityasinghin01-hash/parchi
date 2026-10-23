import Foundation
import Observation
import ParchiCore

/// Same shape as engine/scenarios/*.json (the files the parchi-plan CLI reads).
struct Scenario: Codable {
    var title: String
    var items: [RxItem]
    var sellers: [Seller]
    var offers: [Offer]
    var preferences: Preferences
    var simulateFailure: FailureSpec?

    struct FailureSpec: Codable {
        var sellerID: String
        var failure: Failure
    }
}

/// One line as the reader returned it, plus the brand–strength check result.
struct ReadLine: Identifiable {
    let id: String
    var item: RxItem
    var check: CheckResult?
    /// Tests only: how the written name maps to our canonical test list (nil for medicines).
    var testMatch: CanonicalMatch?
    /// Medicines only: H1/X, so Parchi never routes it to delivery and says "buy in person with the original parchi".
    var inPersonOnly: Schedule?
    /// The patient chose "Ask my doctor" for an ambiguous test: it is left out of the plan, never guessed.
    var askDoctor = false

    var needsAnswer: Bool {
        if case .ambiguous = testMatch, !askDoctor { return true }
        switch check {
        case .strengthMismatch, .unknownBrand: return true
        default: return false
        }
    }

    /// The canonical test name when the match is certain (used to look up lab prices); nil otherwise.
    var canonicalTestName: String? {
        if case .exact(let name)? = testMatch { return name }
        return nil
    }
}

enum OrderStatus: String {
    case placed = "Placed", rerouted = "Re-routed (Plan B)", cancelled = "Cancelled by seller"
}

@MainActor
@Observable
final class AppModel {
    private(set) var scenario: Scenario
    let catalogue: Catalogue
    /// Bundled real data (labs, lab prices, product links, test names, H1/X). See DATA_INTEGRATION.md.
    let data = AppData.shared
    /// Where to search (location fix, picked city, or KIET). Nothing here leaves the phone.
    let location = LocationProvider()
    /// Kept only so Settings can show the agreement record; the first-run consent screen is NOT mounted (see KIRO_REPORT_K8.md).
    let consent = ConsentStore()

    var lines: [ReadLine] = []
    var objective: Objective = .cheapest { didSet { replan() } }
    private(set) var plan: Plan?
    /// Catalogue-MRP prices for the confirmed medicines that the demo scenario has no offer for (itemID -> offer).
    private(set) var catalogueOffers: [String: CatalogueOffer] = [:]
    /// Confirmed medicines with no demo offer and no catalogue price: the plan cannot be completed without them.
    private(set) var catalogueMisses: [String] = []
    /// "Ask your doctor" Jan Aushadhi equivalents (itemID -> equivalent), for every confirmed medicine that has one.
    private(set) var janAushadhiAsks: [String: JanAushadhiEquivalent] = [:]
    private(set) var approvedPlan: Plan?
    private(set) var statuses: [String: OrderStatus] = [:]
    var planB: PlanBProposal?

    // Phase 3 (Support/ShopLab): Ask nearby shops + lab booking. Additive; unused until a sheet opens.
    let shopAsk = ShopAskModel()
    let labBooking = LabBookingModel()
    var shopLabSheet: ShopLabSheet?

    // Live backend (all unused while mode == .mock)
    let backend = BackendSettings()
    /// Plain-language problem with the server, shown in the Developer panel. nil = all fine.
    var backendError: String?
    private(set) var liveOrderID: String?
    private var idempotencyKeys: [Plan: String] = [:]   // one key per approved plan, so a retry never double-orders
    private var pollTask: Task<Void, Never>?
    private var trackVisible = false
    private var serverPlanVersion = 1
    private var proposalKey: String?                    // "seller|version" already posted/shown, so we do it once
    private var postedProposalVersion: Int?             // set only when the server holds the proposal now on screen
    private var replacementSellers: Set<String> = []
    /// Sellers the patient skipped in the Checkout Assistant; the planner ignores their offers.
    private(set) var skippedSellers: Set<String> = []

    // V2 (Smart Router A1, true price A7). Additive; with the switch off the plan is chosen by price only, exactly as before.
    var reliabilityScores: [String: SellerReliability] = [:]
    var reliabilityIsDemo = false
    var truePrices: [String: TruePriceInfo] = [:]
    private(set) var deliveredSellers: Set<String> = []
    /// Sellers the server says failed / were cancelled / were re-routed: never proposed again as a replacement.
    private(set) var inactiveSellers: Set<String> = []
    /// Dose schedules written on the demo parchi (items of `real_basket_cheapest.json`).
    static let demoSchedules = ["dolo": "1-0-1", "pan": "1-0-0", "telma": "1-0-0", "glycomet": "1-0-1", "azithral": "1-0-0", "montair": "0-0-1"]
    var preferReliable: Bool = UserDefaults.standard.bool(forKey: "parchi.preferReliable") {
        didSet { UserDefaults.standard.set(preferReliable, forKey: "parchi.preferReliable"); replan() }
    }

    init() {
        scenario = Self.load("real_basket_cheapest")
        catalogue = Self.loadCatalogue()
        // A shop's quote changes the plan the moment it arrives.
        shopAsk.onQuotesChanged = { [weak self] in self?.replan() }
        // Parse the 6 MB catalogue and the Jan Aushadhi list off the main thread, so the first plan does not wait for them.
        let data = data
        Task.detached(priority: .utility) { data.prewarmCatalogue() }
        // "Delete everything" posts this synchronously on the main thread: drop every in-memory copy of the patient's data.
        NotificationCenter.default.addObserver(forName: .parchiErased, object: nil, queue: nil) { [weak self] _ in
            MainActor.assumeIsolated { self?.eraseAll() }
        }
    }

    /// Forgets everything about the current parchi: lines, plan, approved plan, statuses, Plan B, the live order (polling stopped),
    /// shop replies, skipped sellers, lab bookings and the shop-ask state. Called by "Delete everything".
    func eraseAll() {
        resetLiveOrder()
        scenario = Self.load("real_basket_cheapest")
        lines = []
        plan = nil
        approvedPlan = nil
        statuses = [:]
        planB = nil
        catalogueOffers = [:]
        catalogueMisses = []
        janAushadhiAsks = [:]
        skippedSellers = []
        idempotencyKeys = [:]
        reliabilityScores = [:]
        truePrices = [:]
        backendError = nil
        shopLabSheet = nil
        shopAsk.eraseAll()
        labBooking.eraseAll()
    }

    // MARK: Reading (mock until Aditya Singhal's /read server is on the iMac)

    /// Simulates the reader on the demo parchi, with one realistic misread ("Telma 400").
    func readDemoParchi() {
        // Screenshots only: `-demoReader "Dolo:650:15;Augmentin:625:10"` loads those lines as if the reader had returned them
        // (a parchi that is not the demo basket), instead of the demo parchi.
        if let spec = UserDefaults.standard.string(forKey: "demoReader") {
            loadReaderLines(spec.split(separator: ";").map { part in
                let f = part.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
                return ReaderLine(kind: "medicine", name: f.first ?? "", strength: f.count > 1 && !f[1].isEmpty ? f[1] : nil,
                                  quantity: f.count > 2 ? Int(f[2]) : nil, schedule: nil)
            })
            resetLiveOrder()
            return
        }
        lines = scenario.items.map { item in
            var read = item
            if item.id == "telma" { read.strength = "400" }
            // Screenshots only: `-demoTestRead T3` makes the reader misread the thyroid test as that text (an ambiguous name).
            if item.id == "thyroid", let written = UserDefaults.standard.string(forKey: "demoTestRead") { read.name = written }
            var line = ReadLine(id: item.id, item: read, check: check(read))
            line.testMatch = item.kind == .test ? canonicalTest(for: read.name, catalogue: data.testCatalogue) : nil
            line.inPersonOnly = item.kind == .medicine ? data.scheduleCheck.isInPersonOnly(brand: item.name) : nil
            return line
        }
        skippedSellers = []
        plan = nil
        approvedPlan = nil
        statuses = [:]
        planB = nil
        catalogueOffers = [:]
        catalogueMisses = []
        janAushadhiAsks = [:]
        resetLiveOrder()
    }

    /// Lines from the reader (`POST /read`). The demo basket has real shop and online prices; every other medicine is priced
    /// at the catalogue MRP at the doctor's shop (`refreshCatalogue`, plan gap U7). Other tests still use lab prices only.
    func loadReaderLines(_ read: [ReaderLine]) {
        resetLiveOrder()   // a new parchi must never keep polling (or showing) the earlier Live order
        lines = read.enumerated().map { index, r in
            let kind: ItemKind = r.kind == "test" ? .test : .medicine
            return makeLine(RxItem(id: "r\(index + 1)", kind: kind, name: r.name, strength: r.strength, quantity: max(r.quantity ?? 1, 1)))
        }
        resetPlanState()
    }

    /// Adds one line by hand and leaves every other line, with its id, exactly as it is (the demo parchi keeps its own prices).
    func appendLine(_ item: RxItem) {
        resetLiveOrder()
        lines.append(makeLine(item))
        resetPlanState()
    }

    /// Removes one line by hand; the others keep their ids.
    func removeLine(_ id: String) {
        resetLiveOrder()
        lines.removeAll { $0.id == id }
        resetPlanState()
    }

    private func makeLine(_ item: RxItem) -> ReadLine {
        var line = ReadLine(id: item.id, item: item, check: check(item))
        line.testMatch = item.kind == .test ? canonicalTest(for: item.name, catalogue: data.testCatalogue) : nil
        line.inPersonOnly = item.kind == .medicine ? data.scheduleCheck.isInPersonOnly(brand: item.name) : nil
        return line
    }

    private func resetPlanState() {
        // The prescription changed: shop asks, replies and lab bookings made for the old lines must never be applied to the new ones
        // (line ids are reused, e.g. r2 after a removal). Saved phone numbers and the address are kept. (Codex R7 row 9)
        shopAsk.startOver()
        labBooking.startOver()
        skippedSellers = []
        plan = nil
        approvedPlan = nil
        statuses = [:]
        planB = nil
        catalogueOffers = [:]
        catalogueMisses = []
        janAushadhiAsks = [:]
    }

    func choose(strength: String, for lineID: String) {
        guard let i = lines.firstIndex(where: { $0.id == lineID }) else { return }
        lines[i].item.strength = strength
        lines[i].check = check(lines[i].item)
    }

    /// Catalogue keys are the first word of a product name ("Montair-LC" → MONTAIRLC, "Glycomet 500 SR" → GLYCOMET),
    /// so try the whole written name first, then its first word.
    private func check(_ item: RxItem) -> CheckResult? {
        guard item.kind == .medicine else { return nil }
        let whole = catalogue.check(brand: item.name, strength: item.strength)
        guard case .unknownBrand = whole, let first = item.name.split(separator: " ").first, first.count < item.name.count else { return whole }
        let byFirstWord = catalogue.check(brand: String(first), strength: item.strength)
        if case .unknownBrand = byFirstWord { return whole }
        return byFirstWord
    }

    /// The patient picks one of the tests we could not tell apart. Never guessed.
    func choose(test: String, for lineID: String) {
        guard let i = lines.firstIndex(where: { $0.id == lineID }) else { return }
        lines[i].item.name = test
        lines[i].testMatch = .exact(test)
        lines[i].askDoctor = false
    }

    /// "Ask my doctor": the test stays off the plan until the patient decides.
    func askDoctorAbout(testLine lineID: String) {
        guard let i = lines.firstIndex(where: { $0.id == lineID }) else { return }
        lines[i].askDoctor = true
    }

    var allConfirmed: Bool { !lines.contains(where: \.needsAnswer) }

    // MARK: Planning

    func confirmList() {
        // A test the demo scenario has no lab offers for (any test outside the demo parchi) is not planned: it is priced lab by lab
        // in the "Lab prices" section, so a parchi with medicines AND tests still gets a plan for the medicines.
        let labPriced = Set(scenario.offers.map(\.itemID))
        scenario.items = lines.filter { !$0.askDoctor && ($0.item.kind == .medicine || labPriced.contains($0.id)) }.map(\.item)
        refreshCatalogue()
        replan()
        Task { await refreshReliability(); if preferReliable { replan() } }
    }

    private var planner: Planner {
        var prefs = scenario.preferences
        prefs.objective = objective
        if preferReliable, !reliabilityScores.isEmpty {
            prefs.reliability = reliabilityScores.mapValues(\.score)
            prefs.reliabilityWeight = 1
        }
        return Planner(items: scenario.items, sellers: scenario.sellers, offers: plannerOffers, preferences: prefs)
    }

    // MARK: Catalogue prices (any medicine) + Jan Aushadhi equivalents

    /// The seller whose price the catalogue MRP stands for: the doctor's shop, at MRP.
    static let catalogueSellerID = "doctorshop"
    /// The catalogue and the Jan Aushadhi list were captured on this day.
    static let catalogueSeen = PriceSource.date(fromISO: "2026-10-23") ?? Date()

    /// For every confirmed medicine: a catalogue-MRP offer if the demo scenario has none for it, and the Jan Aushadhi
    /// "ask your doctor" equivalent if there is one (H1/X medicines never get one). Called when the list is confirmed.
    func refreshCatalogue() {
        var offers: [String: CatalogueOffer] = [:]
        var misses: [String] = []
        var asks: [String: JanAushadhiEquivalent] = [:]
        let demoPriced = Set(scenario.offers.map(\.itemID))
        for index in lines.indices where lines[index].item.kind == .medicine && !lines[index].askDoctor {
            let item = lines[index].item
            // Second H1/X check, from the salts of the matched catalogue product (the brand table is the first): a typed
            // "Oflo 200" is caught even though most Oflo products are not scheduled.
            if lines[index].inPersonOnly == nil,
               let schedule = data.catalogueSchedule(brand: item.name, strength: item.strength, quantity: item.quantity) {
                lines[index].inPersonOnly = schedule
            }
            let line = lines[index]
            if !demoPriced.contains(item.id) {
                if let offer = data.catalogueOffer(brand: item.name, strength: item.strength, quantity: item.quantity) {
                    offers[item.id] = offer
                } else {
                    misses.append(item.id)
                }
            }
            if line.inPersonOnly == nil,
               let eq = data.janAushadhiEquivalent(brand: item.name, strength: item.strength, quantity: item.quantity) {
                asks[item.id] = eq
            }
        }
        catalogueOffers = offers
        catalogueMisses = misses
        janAushadhiAsks = asks
    }

    /// Short reason a medicine has no catalogue price ("pack size unclear"), for the screen; nil when it has one or none is known.
    func catalogueMissReason(itemID: String) -> String? {
        guard let item = lines.first(where: { $0.id == itemID })?.item else { return nil }
        return data.catalogueMiss(brand: item.name, strength: item.strength, quantity: item.quantity)?.reason
    }

    /// Planner offers made from the catalogue: the whole line (packs x MRP) at the doctor's shop.
    var catalogueMRPOffers: [Offer] {
        catalogueOffers.keys.sorted().compactMap { id in
            catalogueOffers[id].map { Offer(itemID: id, sellerID: Self.catalogueSellerID, price: $0.price.totalPaise) }
        }
    }

    /// The chip for one price line in the plan: catalogue MRP for a catalogue line, else the seller's usual source.
    func priceSource(sellerID: String, itemID: String) -> PriceSource {
        if let reply = shopReplySource, shopReplyOffers.contains(where: { $0.sellerID == sellerID && $0.itemID == itemID }) { return reply }
        if sellerID == Self.catalogueSellerID, let offer = catalogueOffers[itemID] {
            return PriceSource.catalogueMRP(dateSeen: Self.catalogueSeen, packSizeKnown: offer.price.packSizeKnown)
        }
        return priceSource(sellerID: sellerID)
    }

    /// "2 x strip of 10 tablets at ₹120.50 a pack" under a catalogue price, so the patient can check it against the pack in the shop.
    func cataloguePackText(itemID: String) -> String? {
        guard let price = catalogueOffers[itemID]?.price else { return nil }
        if !price.packSizeKnown { return "\(price.packLabel), \(rupees(price.perPackPaise)) a pack" }
        return "\(price.packs) × \(price.packLabel) at \(rupees(price.perPackPaise)) a pack"
    }

    /// The grey line under a medicine: "Ask your doctor: same salt at Jan Aushadhi ₹X (list of 23 Oct)". nil when there is none.
    /// Never applied to the plan, never worded as a switch.
    func janAushadhiLine(itemID: String) -> String? {
        guard let eq = janAushadhiAsks[itemID] else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Kolkata")
        formatter.dateFormat = "d MMM"
        let date = formatter.string(from: data.janAushadhiListDate)
        let price = eq.packSizeKnown ? rupees(eq.totalPaise) : "\(rupees(eq.totalPaise)) a pack"
        return "Ask your doctor: same salt at Jan Aushadhi \(price) (list of \(date))"
    }

    /// Offers the planner may use: H1/X medicines only from shops you walk into (never delivery), and nothing from skipped sellers.
    private var plannerOffers: [Offer] {
        let inPerson = Set(lines.filter { $0.inPersonOnly != nil }.map(\.id))
        let delivery = Set(scenario.sellers.filter { $0.channel == .onlinePharmacy || $0.channel == .quickCommerce }.map(\.id))
        // A price a shop quoted through "Ask nearby shops" replaces our bundled price for the same item at that shop.
        let quoted = Set(shopReplyOffers.map { OfferKey(itemID: $0.itemID, sellerID: $0.sellerID) })
        let base = (scenario.offers + catalogueMRPOffers).filter { !quoted.contains(OfferKey(itemID: $0.itemID, sellerID: $0.sellerID)) }
        return (base + shopReplyOffers).filter { offer in
            !skippedSellers.contains(offer.sellerID) && !deliveredSellers.contains(offer.sellerID) && !inactiveSellers.contains(offer.sellerID)
                && !(inPerson.contains(offer.itemID) && delivery.contains(offer.sellerID))
        }
    }

    /// Checkout Assistant "Skip this seller": plan again without them. If nothing complete is left, the plan stays as it was.
    func skipSeller(_ sellerID: String) {
        let before = skippedSellers
        skippedSellers.insert(sellerID)
        if planner.best() == nil { skippedSellers = before; return }
        replan()
    }

    /// "Buy in person with the original parchi" for an H1/X medicine, else nil.
    func inPersonMessage(itemID: String) -> String? {
        lines.first { $0.id == itemID }?.inPersonOnly?.inPersonMessage
    }

    // MARK: Price sources (every price on screen says where and when)

    /// Date the bundled scenario prices were captured (see scenario title and the plan footnote).
    static let scenarioPricesSeen = PriceSource.date(fromISO: "2026-10-23") ?? Date()

    /// Where the price for this seller came from. A shop that replied to "Ask nearby shops" wins with its reply time.
    func priceSource(sellerID: String) -> PriceSource {
        if let reply = shopReplySource, shopReplyOffers.contains(where: { $0.sellerID == sellerID }) { return reply }
        if sellerID == Self.catalogueSellerID, let plan, plan.lines.contains(where: { $0.sellerID == sellerID && catalogueOffers[$0.itemID] != nil }) {
            let known = plan.lines.filter { $0.sellerID == sellerID }.allSatisfy { catalogueOffers[$0.itemID]?.price.packSizeKnown ?? true }
            return PriceSource.catalogueMRP(dateSeen: Self.catalogueSeen, packSizeKnown: known)
        }
        let date = Self.scenarioPricesSeen
        switch seller(sellerID)?.channel {
        case .localChemist where sellerID == "doctorshop": return PriceSource(kind: .mrp, dateSeen: date)
        case .janAushadhi: return PriceSource(kind: .mrp, dateSeen: date)   // PMBI list price = the kendra's MRP
        default: return PriceSource(kind: .online, dateSeen: date)
        }
    }

    /// The seller's own product page for a plan item, if we have one (bundled product_links.json).
    func productLink(itemID: String, sellerID: String) -> ProductLink? {
        guard let rx = scenario.items.first(where: { $0.id == itemID }), rx.kind == .medicine,
              let linkKey = SellerSites.site(id: sellerID)?.linkKey else { return nil }
        let base = rx.name.lowercased().map { $0.isLetter || $0.isNumber ? String($0) : "_" }.joined()
            .split(separator: "_").joined(separator: "_")
        for key in [rx.strength.map { "\(base)_\($0)" }, base].compactMap({ $0 }) {
            if let link = data.productLink(medicine: key, seller: linkKey) { return link }
        }
        return nil
    }

    func replan() {
        guard !lines.isEmpty else { return }
        plan = planner.best()
    }

    var unavailable: [String] { planner.unavailableItems() }

    /// Tests on the parchi that are priced lab by lab below the plan instead of inside its total.
    var testsOutsidePlan: [ReadLine] {
        let planned = Set(scenario.items.map(\.id))
        return lines.filter { $0.item.kind == .test && !$0.askDoctor && !planned.contains($0.id) }
    }

    /// What the medicines cost at MRP at the doctor's shop (the patient's default today).
    var medicinesAtMRP: Paise {
        let medicineIDs = Set(scenario.items.filter { $0.kind == .medicine }.map(\.id))
        return (scenario.offers + catalogueMRPOffers).filter { $0.sellerID == Self.catalogueSellerID && medicineIDs.contains($0.itemID) }.map(\.price).reduce(0, +)
    }

    var planMedicinesTotal: Paise {
        guard let plan else { return 0 }
        let medicineIDs = Set(scenario.items.filter { $0.kind == .medicine }.map(\.id))
        return plan.lines.filter { medicineIDs.contains($0.itemID) }.map(\.price).reduce(0, +)
    }

    /// Same-salt Jan Aushadhi total, shown only as "ask your doctor" (never applied automatically).
    /// Only the medicines of THIS parchi that have an equivalent are counted (the demo's bundled Jan Aushadhi offers for its own six
    /// items, the catalogue's equivalent for any other), and `janAushadhiComparedMRP` is the MRP of exactly those same medicines.
    var janAushadhiMedicines: Paise { janAushadhiComparison.janAushadhi }
    var janAushadhiComparedMRP: Paise { janAushadhiComparison.mrp }

    private var janAushadhiComparison: (janAushadhi: Paise, mrp: Paise) {
        let ids = Set(scenario.items.filter { $0.kind == .medicine }.map(\.id))
        var ja: [String: Paise] = [:]
        for offer in scenario.offers where offer.sellerID == "janaushadhi" && offer.isSubstitute && ids.contains(offer.itemID) {
            ja[offer.itemID, default: 0] += offer.price
        }
        for (id, eq) in janAushadhiAsks where ids.contains(id) && ja[id] == nil && eq.packSizeKnown { ja[id] = eq.totalPaise }
        let mrp = (scenario.offers + catalogueMRPOffers)
            .filter { $0.sellerID == Self.catalogueSellerID && ja.keys.contains($0.itemID) }.map(\.price).reduce(0, +)
        return (ja.values.reduce(0, +), mrp)
    }

    // MARK: Orders + Plan B (sandbox)

    func placeTestOrders() {
        approvedPlan = plan
        if let plan {
            // The demo parchi carries its written schedules; a real reader will supply them per line (nil = Care says "Can't tell").
            let saved = lines.filter { !$0.askDoctor }.map { SavedItem(item: $0.item, schedule: Self.demoSchedules[$0.item.id]) }
            HistoryStore.shared.saveApproved(title: scenario.title, items: saved, plan: plan, sellers: scenario.sellers)
            if backend.mode == .live {
                let watch = saved.compactMap { s in s.schedule.map { (name: s.item.name, quantity: s.item.quantity, schedule: $0) } }
                Task { await registerRefillWatch(items: watch) }
            }
        }
        statuses = Dictionary(uniqueKeysWithValues: (plan?.sellerIDs ?? []).map { ($0, OrderStatus.placed) })
        if backend.mode == .live { startLiveOrder() }
    }

    func simulateCancel(sellerID: String) {
        guard let approved = approvedPlan else { return }
        statuses[sellerID] = .cancelled
        planB = PlanB(planner: planner).reroute(approved: approved, failedSellerID: sellerID, failure: .cancelled)
    }

    func approvePlanB() {
        guard let proposal = planB else { return }
        guard backend.mode == .live, let orderID = liveOrderID, let version = postedProposalVersion, let client = backend.makeClient() else {
            applyApproval(proposal)   // Mock mode, or the local-only "Simulate cancel": nothing on a server to wait for
            return
        }
        // Live: the server must accept first. If it does not (offline, rate limit), the sheet comes back and the patient can tap again.
        Task {
            do {
                try await client.approve(orderID: orderID, planVersion: version)
                postedProposalVersion = nil
                applyApproval(proposal)
            } catch {
                backendError = (error as? LiveError)?.message ?? LiveError.unreachable.message
                planB = proposal
            }
        }
    }

    private func applyApproval(_ proposal: PlanBProposal) {
        approvedPlan = proposal.newPlan
        plan = proposal.newPlan
        for line in proposal.rerouted { statuses[line.sellerID] = .rerouted }
        planB = nil
    }

    /// Live only: tells the server the patient chose not to take the proposal. (The sheet's "Choose myself" does not call this yet.)
    func rejectPlanB() {
        guard let proposal = planB else { return }
        planB = nil
        if backend.mode == .live { sendDecision(approve: false, proposal: proposal) }
    }

    // MARK: Live backend

    /// Called by RootView when the Track screen appears/disappears; polling only runs while it is on screen.
    func trackVisibilityChanged(_ visible: Bool) {
        trackVisible = visible
        if visible { startPollingIfNeeded() } else { stopPolling() }
    }

    func testConnection() async -> Bool {
        guard let client = backend.makeClient() else { backendError = LiveError.badURL.message; return false }
        do {
            let health = try await client.health()
            if health.ok { backendError = nil }
            return health.ok
        } catch {
            backendError = (error as? LiveError)?.message
            return false
        }
    }

    private func resetLiveOrder() {
        stopPolling()
        liveOrderID = nil
        serverPlanVersion = 1
        proposalKey = nil
        postedProposalVersion = nil
        replacementSellers = []
        deliveredSellers = []
        inactiveSellers = []
    }

    private func startLiveOrder() {
        guard let approved = approvedPlan else { return }
        guard let client = backend.makeClient() else { backendError = LiveError.badURL.message; return }
        let key = idempotencyKeys[approved] ?? UUID().uuidString
        idempotencyKeys[approved] = key
        let sellers = scenario.sellers
        // Settings "Plan B" stepper: 0 = always ask me first (sent as nil).
        let cap = UserDefaults.standard.integer(forKey: "parchi.autoApproveCapPaise")
        let autoApproveCap: Int? = cap > 0 ? cap : nil
        Task {
            do {
                let id = try await client.placeOrder(plan: approved, sellers: sellers, autoApproveCapPaise: autoApproveCap, idempotencyKey: key)
                guard approvedPlan == approved else { return }   // the user moved on while we waited
                liveOrderID = id
                BackendUsage.markUsedLive()   // the server now holds an order for this install
                backendError = nil
                startPollingIfNeeded()
            } catch {
                // Never block the UI: the local (Mock) statuses already set above keep working.
                backendError = (error as? LiveError)?.message ?? LiveError.unreachable.message
            }
        }
    }

    private func startPollingIfNeeded() {
        guard backend.mode == .live, trackVisible, liveOrderID != nil, pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let id = self.liveOrderID, let client = self.backend.makeClient() else { break }
                if await self.pollOnce(client: client, orderID: id) { break }
                try? await Task.sleep(for: .seconds(2))
            }
            if !Task.isCancelled { self?.pollTask = nil }
        }
    }

    private func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    /// Returns true when polling should stop (order done).
    private func pollOnce(client: LiveClient, orderID: String) async -> Bool {
        do {
            let status = try await client.status(orderID: orderID)
            if Task.isCancelled || orderID != liveOrderID { return true }
            backendError = nil
            await apply(status, client: client)
            return status.state == "done"
        } catch is CancellationError {
            return true
        } catch {
            backendError = (error as? LiveError)?.message ?? LiveError.unreachable.message
            return false   // keep the demo state on screen and try again at the next tick
        }
    }

    private func apply(_ status: ServerStatus, client: LiveClient) async {
        serverPlanVersion = status.planVersion
        for seller in status.sellers {
            // The server rejects a Plan B that sends items to a seller who already delivered, so never propose one.
            if seller.status == "delivered" { deliveredSellers.insert(seller.id) }
            if ["failed", "cancelled", "rerouted"].contains(seller.status) { inactiveSellers.insert(seller.id) }
            switch seller.status {
            case "failed", "cancelled": statuses[seller.id] = .cancelled
            case "rerouted": statuses[seller.id] = .rerouted
            default: statuses[seller.id] = replacementSellers.contains(seller.id) ? .rerouted : .placed
            }
        }
        // The server already approved this proposal itself (the patient's auto-approve cap): follow it instead of leaving a stale sheet.
        if let shown = planB, let posted = postedProposalVersion, status.planVersion > posted {
            postedProposalVersion = nil
            applyApproval(shown)
        }
        guard let approved = approvedPlan, let orderID = liveOrderID else { return }

        if status.state == "needs_proposal", let pending = status.pending {
            let key = "\(pending.sellerID)|\(status.planVersion)"
            guard proposalKey != key else { return }
            proposalKey = key
            let failure = Failure(rawValue: pending.failure) ?? .cancelled
            // The re-routing maths stays on the phone, using the existing Plan B engine.
            let proposal = PlanB(planner: planner).reroute(approved: approved, failedSellerID: pending.sellerID, failure: failure)
            do {
                try await client.postProposal(orderID: orderID, planVersion: status.planVersion, proposal: proposal)
                postedProposalVersion = status.planVersion
                replacementSellers = Set(proposal.rerouted.map(\.sellerID))
                planB = proposal
            } catch {
                proposalKey = nil   // try again next tick
                backendError = (error as? LiveError)?.message
            }
        } else if status.state == "awaiting_approval", planB == nil, let proposal = status.proposal,
                  let pending = status.pending, proposalKey != "\(pending.sellerID)|\(status.planVersion)" {
            // Proposal already on the server (e.g. the app was reopened): show it once.
            proposalKey = "\(pending.sellerID)|\(status.planVersion)"
            postedProposalVersion = status.planVersion
            replacementSellers = Set(proposal.rerouted.map(\.sellerID))
            planB = proposal
        }
    }

    private func sendDecision(approve: Bool, proposal: PlanBProposal) {
        // Only when the server actually holds this proposal (not for the local-only "Simulate cancel").
        guard let orderID = liveOrderID, let version = postedProposalVersion, let client = backend.makeClient() else { return }
        postedProposalVersion = nil
        Task {
            do {
                if approve { try await client.approve(orderID: orderID, planVersion: version) }
                else { try await client.reject(orderID: orderID, planVersion: version) }
            } catch {
                backendError = (error as? LiveError)?.message
            }
        }
    }

    // MARK: Names

    func sellerName(_ id: String) -> String { scenario.sellers.first { $0.id == id }?.name ?? id }
    func seller(_ id: String) -> Seller? { scenario.sellers.first { $0.id == id } }
    func itemName(_ id: String) -> String {
        guard let item = scenario.items.first(where: { $0.id == id }) else { return id }
        return [item.name, item.strength].compactMap { $0 }.joined(separator: " ")
    }

    // MARK: Loading

    private static func load(_ name: String) -> Scenario {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let scenario = try? JSONDecoder().decode(Scenario.self, from: data) else {
            fatalError("Missing or invalid \(name).json in the app bundle")
        }
        return scenario
    }

    private static func loadCatalogue() -> Catalogue {
        guard let url = Bundle.main.url(forResource: "brand_strengths", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let map = try? JSONDecoder().decode([String: [String]].self, from: data) else {
            return Catalogue(strengths: [:])
        }
        return Catalogue(strengths: map.mapValues(Set.init))
    }
}
