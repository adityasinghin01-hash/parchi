import Foundation
import Observation
import ParchiCore
import UIKit

/// A local shop the user can ask. `id` is the Seller id from the plan data, so replies map straight back to planner offers.
/// For a shop found on Apple Maps `id` is an opaque random code (`ShopAskModel.opaqueID(forMapShop:)`) and `appleDerived` is true:
/// its real `name` and `distanceM` stay on the phone and are never sent to the server.
struct ShopCandidate: Identifiable, Equatable {
    let id: String
    let name: String
    var distanceM: Int?
    var appleDerived = false
    var janAushadhi = false

    var distanceText: String? {
        guard let distanceM else { return nil }
        return distanceM < 1000 ? "\(distanceM) m" : String(format: "%.1f km", Double(distanceM) / 1000)
    }
}

/// One shop's line in the status list.
struct ShopRow: Identifiable, Equatable {
    enum State: Equatable { case notAsked, waiting, replied, notNeeded, noReply }

    let id: String
    var name: String
    var state: State = .notAsked
    var askedAt: Date?
    var repliedAt: Date?
    var items: [ShopStatusItem] = []
    var totalPaise: Int?
    var readyBy: Date?
    var link: String?
    var isDemo = false
}

/// "Ask nearby shops" (automation A3): pick up to 3 shops + a pickup time, send the typed list by WhatsApp/SMS with a reply link,
/// watch the answers arrive, and expose the winner's prices as `shopReplyOffers` (Claude merges them into the planner later).
@MainActor
@Observable
final class ShopAskModel {
    static let maxPick = 3
    /// The server rejects a quantity above 999 in an ask (422); the Add-medicine sheet uses the same number.
    static let maxQuantity = AppModel.maxManualQuantity
    static let demoReplyDelay: Duration = .seconds(5)

    enum Phase { case composing, asking, asked }

    // Inputs
    private(set) var candidates: [ShopCandidate] = []
    var selected: Set<String> = []
    var pickupTime: Date = ShopAskModel.defaultPickup()
    var language: MessageLanguage = .saved { didSet { MessageLanguage.saved = language } }
    /// Typed shop phone numbers, by shop id. Numbers for Apple Maps shops (keyed by their opaque id) live in memory only.
    var phones: [String: String] { didSet { UserDefaults.standard.set(phones.filter { genericNames[$0.key] == nil }, forKey: Self.phonesKey) } }

    // Output
    private(set) var phase: Phase = .composing
    private(set) var rows: [ShopRow] = []
    private(set) var round = 1
    private(set) var noReply = false
    private(set) var nextGroup: [String] = []
    private(set) var winnerShopID: String?
    private(set) var shopReplyOffers: [Offer] = [] { didSet { onQuotesChanged?() } }
    /// Quoted Apple Maps shops, in memory only (key = opaque id). They are `mapSellers` only while their reply is in `shopReplyOffers`.
    @ObservationIgnored private var quotedMapSellers: [String: Seller] = [:]
    /// Map shop id (has the coordinates in it) -> opaque id (`map-` + 12 random hex), for this session only.
    @ObservationIgnored private var opaqueIDs: [String: String] = [:]
    /// Opaque id -> "Shop near you N", the only name the server ever sees for an Apple Maps shop.
    @ObservationIgnored private(set) var genericNames: [String: String] = [:]
    /// AppModel re-plans when quotes arrive or are cleared.
    var onQuotesChanged: (() -> Void)?
    private(set) var winnerSource: PriceSource?
    private(set) var notice: String?
    private(set) var error: String?
    private(set) var isDemo = false
    private(set) var askedAtLocal: Date?

    // Context given by AppModel when the sheet opens
    private var items: [RxItem] = []
    private var demoOffers: [Offer] = []
    private var live: LiveClient?
    private var liveRequested = false
    private var orderID: String?
    private var askID: String?
    private var links: [String: String] = [:]
    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private var demoTask: Task<Void, Never>?
    @ObservationIgnored private var templates = MessageTemplates.shared

    private static let phonesKey = "parchi.shopask.phones"

    init() {
        // Older builds saved phone numbers for Apple Maps shops under an id that contains the shop's name and coordinates: drop those.
        let saved = ((UserDefaults.standard.dictionary(forKey: Self.phonesKey) as? [String: String]) ?? [:]).filter { !$0.key.hasPrefix("map-") }
        UserDefaults.standard.set(saved, forKey: Self.phonesKey)
        phones = saved
        NotificationCenter.default.addObserver(forName: .parchiErased, object: nil, queue: nil) { [weak self] _ in
            MainActor.assumeIsolated { self?.eraseAll() }   // "Delete everything" must not leave rows, offers or phone numbers in memory or storage
        }
    }

    /// Back to a blank model: polling and the scripted demo stopped, rows, replies, offers, phones and context forgotten.
    func eraseAll() {
        startOver()
        selected = []
        candidates = []
        items = []
        demoOffers = []
        live = nil
        liveRequested = false
        orderID = nil
        pickupTime = Self.defaultPickup()
        opaqueIDs = [:]; genericNames = [:]; quotedMapSellers = [:]
        phones = [:]
        UserDefaults.standard.removeObject(forKey: Self.phonesKey)
    }

    // MARK: Apple Maps shops (Apple-derived fields never leave the phone)

    /// The ask-list id for an Apple Maps shop: `map-` + 12 random hex, made on first use and kept in memory for the session.
    func opaqueID(forMapShop mapID: String) -> String {
        if let known = opaqueIDs[mapID] { return known }
        var opaque: String
        repeat { opaque = "map-" + String((0..<12).map { _ in "0123456789abcdef".randomElement() ?? "0" }) } while genericNames[opaque] != nil
        opaqueIDs[mapID] = opaque
        genericNames[opaque] = "Shop near you \(genericNames.count + 1)"
        return opaque
    }

    /// The id this model uses for a shop: the opaque id for an Apple Maps shop that has one, else the id itself.
    func key(for id: String) -> String { opaqueIDs[id] ?? id }

    /// Quoted Apple Maps shops as in-memory local sellers (real name, for the screen), so the planner can use their reply.
    /// Gone as soon as their reply is cleared (new ask, edited list, Delete everything).
    var mapSellers: [Seller] {
        let quoted = Set(shopReplyOffers.map(\.sellerID))
        return quotedMapSellers.values.filter { quoted.contains($0.id) }.sorted { $0.id < $1.id }
    }

    /// The same sellers as the server and the saved history may see them: generic name, no distance.
    var mapSellersForServer: [Seller] {
        mapSellers.map { seller in
            var copy = seller
            copy.name = genericNames[seller.id] ?? "Shop near you"
            copy.distanceMeters = nil
            return copy
        }
    }

    // MARK: Setup

    /// Called each time the sheet opens. An ask already in progress is kept (reopening the sheet shows its live status).
    func prepare(items: [RxItem], candidates: [ShopCandidate], demoOffers: [Offer], liveRequested: Bool, live: LiveClient?, orderID: String?) {
        self.live = live
        self.liveRequested = liveRequested
        self.orderID = orderID
        guard phase == .composing else { return }
        self.items = items
        self.candidates = candidates
        self.demoOffers = demoOffers
        selected = Set(candidates.prefix(Self.maxPick).map(\.id))
        error = nil
        notice = nil
    }

    /// Forget the finished ask and start a new one.
    func startOver() {
        pollTask?.cancel(); pollTask = nil
        demoTask?.cancel(); demoTask = nil
        phase = .composing
        rows = []; round = 1; noReply = false; nextGroup = []; winnerShopID = nil
        shopReplyOffers = []; winnerSource = nil; askID = nil; links = [:]
        quotedMapSellers = [:]
        notice = nil; error = nil; isDemo = false; askedAtLocal = nil
    }

    func toggle(_ id: String) {
        if selected.contains(id) { selected.remove(id) }
        else if selected.count < Self.maxPick { selected.insert(id) }
    }

    func selectNearest() { selected = Set(candidates.prefix(Self.maxPick).map(\.id)) }

    var canSend: Bool { !selected.isEmpty && !items.isEmpty && phase == .composing }

    private static func defaultPickup() -> Date {
        let calendar = ISOTime.calendar
        let now = Date()
        if let evening = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: now), evening.timeIntervalSince(now) > 3600 { return evening }
        let later = now.addingTimeInterval(2 * 3600)
        let comps = calendar.dateComponents([.year, .month, .day, .hour], from: later)
        if let rounded = calendar.date(from: comps).map({ $0.addingTimeInterval(3600) }),
           calendar.isDate(rounded, inSameDayAs: now), calendar.component(.hour, from: rounded) <= 21 { return rounded }
        // Too late today: tomorrow 10:00 am.
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        return calendar.date(bySettingHour: 10, minute: 0, second: 0, of: tomorrow) ?? later
    }

    /// Today at the chosen clock time, or tomorrow if that time has passed.
    var pickupBy: Date {
        let calendar = ISOTime.calendar
        let parts = calendar.dateComponents([.hour, .minute], from: pickupTime)
        let today = calendar.date(bySettingHour: parts.hour ?? 18, minute: parts.minute ?? 0, second: 0, of: Date()) ?? pickupTime
        return today > Date() ? today : (calendar.date(byAdding: .day, value: 1, to: today) ?? today)
    }

    var pickupHint: String { ISOTime.clock(pickupBy) }

    // MARK: Phones / actions

    func phone(for id: String) -> String? {
        let text = phones[key(for: id)]?.trimmingCharacters(in: .whitespaces)
        return (text?.isEmpty ?? true) ? nil : text
    }

    func callURL(for id: String) -> URL? {
        guard let phone = phone(for: id) else { return nil }
        let dialable = phone.filter { $0.isNumber || $0 == "+" }
        return dialable.isEmpty ? nil : URL(string: "tel:\(dialable)")
    }

    func directionsURL(for shop: ShopCandidate) -> URL? {
        URL(string: "https://maps.apple.com/?q=\(shop.name.urlQueryValue)")
    }

    // MARK: Message

    private var itemLines: String {
        items.filter { $0.kind == .medicine }.map { item in
            [item.name, item.strength].compactMap { $0 }.joined(separator: " ") + " x\(min(item.quantity, Self.maxQuantity))"
        }.joined(separator: "\n")
    }

    /// The text for one shop. WhatsApp template when we have a phone number, otherwise the SMS template.
    func message(for shopID: String) -> FilledMessage? {
        let shopID = key(for: shopID)
        let channel: MessageChannel = phone(for: shopID).flatMap(PhoneNumber.digits) == nil ? .sms : .whatsapp
        let link = links[shopID] ?? "https://parchi-demo.invalid/r/\(shopID)"
        return templates.fill(purpose: "shop_ask", language: language, channel: channel,
                              values: ["items": itemLines, "pickup_hint": pickupHint, "reply_link": link])
    }

    /// Where the message goes: wa.me with the text (user presses send), or `sms:` when there is no usable number.
    func messageURL(for shopID: String) -> URL? {
        guard let filled = message(for: shopID) else { return nil }
        if let digits = phone(for: shopID).flatMap(PhoneNumber.digits) {
            return URL(string: "https://wa.me/\(digits)?text=\(filled.text.urlQueryValue)")
        }
        return URL(string: "sms:?&body=\(filled.text.urlQueryValue)")
    }

    private var canOpenMessages: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return !isDemo
        #endif
    }

    /// Opens WhatsApp/SMS with the text filled in. In the Simulator or Mock mode it copies the text instead (nothing is sent).
    func sendMessage(to shopID: String) {
        guard let filled = message(for: shopID) else { error = "The message template is missing."; return }
        let name = candidates.first { $0.id == shopID }?.name ?? "the shop"
        if canOpenMessages, let url = messageURL(for: shopID) {
            if phone(for: shopID).flatMap(PhoneNumber.digits) == nil { ClipboardTracker.shared.copy(filled.text) }
            UIApplication.shared.open(url)
            notice = "Press send in the message app to ask \(name)."
        } else {
            ClipboardTracker.shared.copy(filled.text)
            #if targetEnvironment(simulator)
            notice = "Simulator: message for \(name) copied to the clipboard instead of opening WhatsApp. Nothing was sent."
            #else
            notice = "Demo mode: message for \(name) copied to the clipboard. Nothing was sent."
            #endif
        }
    }

    // MARK: Ask

    func send() {
        guard canSend else { return }
        error = nil
        notice = nil
        let ordered = candidates.filter { selected.contains($0.id) }
        askedAtLocal = Date()
        if liveRequested {
            // Live mode never falls back to the scripted demo: a bad address is an error the user can see.
            guard let live else { error = LiveError.badURL.message; return }
            let client = ShopAskClient(live: live)
            phase = .asking
            // Selected shops first (they form round 1), then the others, so "ask next 3" has someone to open.
            let request = makeRequest(ordered: ordered)
            Task { [weak self] in
                do {
                    let reply = try await client.ask(request)
                    guard let self else { return }
                    BackendUsage.markUsedLive()   // the server now holds this ask
                    self.askID = reply.askID
                    self.round = reply.round
                    for link in reply.replyLinks { self.links[link.shopID] = link.url }
                    self.rows = ordered.map { ShopRow(id: $0.id, name: $0.name, state: .waiting, askedAt: self.askedAtLocal, link: self.links[$0.id]) }
                    self.phase = .asked
                    if let first = ordered.first(where: { self.links[$0.id] != nil }) { self.sendMessage(to: first.id) }
                    self.startPolling(client: client)
                } catch {
                    guard let self else { return }
                    self.phase = .composing
                    self.error = (error as? LiveError)?.message ?? LiveError.unreachable.message
                }
            }
        } else {
            // Mock: no network. A scripted reply arrives after 5 s so the flow can be demoed offline.
            isDemo = true
            askID = "demo"
            phase = .asked
            rows = ordered.map { ShopRow(id: $0.id, name: $0.name, state: .waiting, askedAt: askedAtLocal, isDemo: true) }
            demoTask = Task { [weak self] in
                try? await Task.sleep(for: Self.demoReplyDelay)
                guard !Task.isCancelled else { return }
                self?.applyDemoReply()
            }
        }
    }

    /// The body of POST /shop/ask. An Apple Maps shop goes out as its opaque id and a generic name, with no distance:
    /// its real name, place and distance stay on the phone.
    func makeRequest(ordered: [ShopCandidate]) -> ShopAskRequest {
        // Selected shops first (they form round 1), then the others, so "ask next 3" has someone to open.
        let rest = candidates.filter { !selected.contains($0.id) }
        return ShopAskRequest(
            items: items.filter { $0.kind == .medicine }.map {
                AskItemBody(itemID: $0.id, name: $0.name, strength: $0.strength, quantity: min($0.quantity, Self.maxQuantity))
            },
            shops: (ordered + rest).prefix(9).map { shop in
                shop.appleDerived
                    ? AskShopBody(shopID: shop.id, name: genericNames[shop.id] ?? "Shop near you", phone: phone(for: shop.id), distanceM: nil)
                    : AskShopBody(shopID: shop.id, name: shop.name, phone: phone(for: shop.id), distanceM: shop.distanceM)
            },
            pickupBy: ISOTime.string(pickupBy),
            groupSize: min(Self.maxPick, ordered.count),
            waitMinutes: 10,
            orderID: orderID)
    }

    func applyDemoReply() {
        guard phase == .asked, isDemo else { return }
        let sellerWithStock = rows.first { row in
            demoOffers.contains { $0.sellerID == row.id && $0.inStock && !$0.isSubstitute }
        } ?? rows.first
        guard let winner = sellerWithStock else { return }
        let now = Date()
        let statusItems = items.filter { $0.kind == .medicine }.map { item -> ShopStatusItem in
            let offer = demoOffers.first { $0.itemID == item.id && $0.sellerID == winner.id && $0.inStock && !$0.isSubstitute }
            return ShopStatusItem(itemID: item.id, available: offer != nil, pricePaise: offer?.price)
        }
        for i in rows.indices {
            if rows[i].id == winner.id {
                rows[i].state = .replied
                rows[i].repliedAt = now
                rows[i].items = statusItems
                rows[i].totalPaise = statusItems.compactMap(\.pricePaise).reduce(0, +)
                rows[i].readyBy = pickupBy
            } else {
                rows[i].state = .notNeeded
            }
        }
        if let won = rows.first(where: { $0.id == winner.id }) { setWinner(won) }
    }

    // MARK: Live polling (every 3 s)

    private func startPolling(client: ShopAskClient) {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled, let self, let id = self.askID else { return }
                do {
                    let status = try await client.status(askID: id)
                    if Task.isCancelled { return }
                    self.error = nil
                    self.apply(status)
                    if status.state == "closed" || status.winnerShopID != nil { return }
                } catch is CancellationError {
                    return
                } catch {
                    let live = error as? LiveError
                    self.error = live?.message ?? LiveError.unreachable.message   // keep what is on screen, retry
                    switch live {
                    case .unauthorized?, .rejected?: self.pollTask = nil; return   // permanent (bad key, deleted ask): stop hammering the server
                    case .rateLimited?: try? await Task.sleep(for: .seconds(15))
                    default: break
                    }
                }
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel(); pollTask = nil
    }

    func resumePolling() {
        guard phase == .asked, !isDemo, let live, pollTask == nil, winnerShopID == nil else { return }
        startPolling(client: ShopAskClient(live: live))
    }

    private func apply(_ status: ShopStatus) {
        round = status.round
        noReply = status.noReply
        nextGroup = status.nextGroup
        let nameByID = Dictionary(uniqueKeysWithValues: candidates.map { ($0.id, $0.name) })
        var updated: [ShopRow] = []
        for shop in status.shops where shop.state != "not_asked" {
            var row = ShopRow(id: shop.shopID, name: nameByID[shop.shopID] ?? shop.shopID)
            switch shop.state {
            case "replied": row.state = .replied
            case "not_needed": row.state = .notNeeded
            case "no_reply": row.state = .noReply
            default: row.state = .waiting
            }
            row.askedAt = ISOTime.parse(shop.askedAt) ?? askedAtLocal
            row.repliedAt = ISOTime.parse(shop.repliedAt)
            row.items = shop.items
            row.totalPaise = shop.totalPaise
            row.readyBy = ISOTime.parse(shop.readyBy)
            row.link = links[shop.shopID]
            updated.append(row)
        }
        if !updated.isEmpty { rows = updated }
        let winnerID = status.winnerShopID ?? rows.first { $0.state == .replied }?.id
        if let winnerID, let row = rows.first(where: { $0.id == winnerID }), row.state == .replied { setWinner(row) }
    }

    private func setWinner(_ row: ShopRow) {
        winnerShopID = row.id
        winnerSource = PriceSource(kind: .shopReply, dateSeen: row.repliedAt ?? Date())
        // A quoted shop from Apple Maps is not in the plan data: register it as an in-memory local seller BEFORE the offers change
        // (which re-plans), so the planner can actually use its price.
        if let shop = candidates.first(where: { $0.id == row.id }), shop.appleDerived {
            quotedMapSellers[shop.id] = Seller(id: shop.id, name: shop.name, channel: shop.janAushadhi ? .janAushadhi : .localChemist,
                                               etaMinutes: 30, requiresVisit: true, distanceMeters: shop.distanceM)
        }
        // Treated as the price for the whole line (the quantity we asked about). See report: assumption on "per pack".
        shopReplyOffers = row.items.compactMap { item in
            guard item.available, let price = item.pricePaise else { return nil }
            return Offer(itemID: item.itemID, sellerID: row.id, price: price, inStock: true, exactMatch: true, isSubstitute: false)
        }
    }

    /// No reply in 10 min: open the next group (the user taps once). The new links show up as "Send message" buttons.
    func askNext() {
        guard let live, let id = askID, !isDemo else { return }
        let client = ShopAskClient(live: live)
        Task { [weak self] in
            do {
                let reply = try await client.next(askID: id)
                guard let self else { return }
                self.round = reply.round
                for link in reply.replyLinks { self.links[link.shopID] = link.url }
                self.noReply = false
                self.notice = "Next shops opened. Tap Send message on each."
                self.resumePolling()
            } catch {
                guard let self else { return }
                self.error = (error as? LiveError) == .conflict ? "There is no one left to ask." : ((error as? LiveError)?.message ?? LiveError.unreachable.message)
            }
        }
    }

    // MARK: Display

    func waitingText(for row: ShopRow, now: Date) -> String {
        guard let asked = row.askedAt else { return "Waiting for a reply" }
        let minutes = max(0, Int(now.timeIntervalSince(asked) / 60))
        return minutes == 0 ? "Waiting · asked just now" : "Waiting · asked \(minutes) min ago"
    }
}
