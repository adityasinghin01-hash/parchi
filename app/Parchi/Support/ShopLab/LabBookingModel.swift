import Foundation
import Observation
import ParchiCore

/// One lab that can do one test, with its price and where/when we saw it.
struct LabChoice: Identifiable, Equatable {
    let id: String                       // labID sent to the server
    let name: String
    let pricePaise: Paise
    let source: PriceSource
    let home: LabOption.HomeCollection   // from AppData's lab list (home collection yes / no / unknown)
    let feePaise: Paise
    let reportMinutes: Int?
    let sellerID: String?                // set when the lab is a seller in the plan data (lets Plan B hear about problems)
    let isScenario: Bool

    var homeText: String {
        switch home {
        case .yes: return "Home collection"
        case .no: return "Visit the lab"
        case .unknown: return "Home collection: ask the lab"
        }
    }
}

struct LabTestRow: Identifiable, Equatable {
    let id: String                       // RxItem id
    let name: String                     // as written on the parchi
    let canonical: String?
    let fasting: CanonicalTest.Fasting
    let choices: [LabChoice]             // cheapest first
}

struct LabBookingState: Identifiable, Equatable {
    let id: String                       // bookingID (or a local demo id)
    var labID: String
    var labName: String
    var testNames: [String]
    var fastingTestNames: [String]
    var homeCollection: Bool
    var requestedSlot: Date
    var address: String?
    var state = "requested"              // requested | confirmed | rejected | collected | report_due | report_chase_due | done
    var noReply = false
    var slot: Date?
    var feePaise: Int?
    var fastingReminderAt: Date?
    var note: String?
    var replyLink: String?
    var isDemo = false
    var calendarResult: String?
    var reminderResult: String?

    var isConfirmed: Bool { ["confirmed", "collected", "report_due", "report_chase_due", "done"].contains(state) }
    var isFinal: Bool { state == "rejected" || state == "done" }
}

/// Lab tests from the plan → options per test (cheapest first) → slot + address → `POST /lab/book` → status → Calendar + fasting reminder.
@MainActor
@Observable
final class LabBookingModel {
    static let demoConfirmDelay: Duration = .seconds(5)
    static let hours = [7, 8, 9, 10, 11, 16, 17]
    static let cities = ["Meerut", "Ghaziabad"]

    private(set) var tests: [LabTestRow] = []
    var chosenLab: [String: String] = [:]          // testID -> labID
    var toldToFast: Set<String> = []                // tests whose fasting need is unknown, but the user was told to fast
    var dayOffset = 1
    var hour = 7
    var wantsHome = true
    var city = "Meerut" { didSet { if city != oldValue, bookings.isEmpty { rebuild() } } }
    let address = AddressStore()

    private(set) var bookings: [LabBookingState] = []
    private(set) var phase: Phase = .choosing
    private(set) var error: String?
    private(set) var isDemo = false

    enum Phase { case choosing, booking, booked }

    private var scenarioItems: [RxItem] = []
    private var sellers: [Seller] = []
    private var offers: [Offer] = []
    private var live: LiveClient?
    private var liveRequested = false
    private var orderID: String?
    private var planSellerIDs: Set<String> = []
    @ObservationIgnored private var pollTasks: [String: Task<Void, Never>] = [:]
    @ObservationIgnored private var demoTask: Task<Void, Never>?
    @ObservationIgnored private var templates = MessageTemplates.shared

    // MARK: Setup

    func prepare(items: [RxItem], sellers: [Seller], offers: [Offer], liveRequested: Bool, live: LiveClient?, orderID: String?, planSellerIDs: Set<String>) {
        self.live = live
        self.liveRequested = liveRequested
        self.orderID = orderID
        self.planSellerIDs = planSellerIDs
        guard bookings.isEmpty else { return }
        scenarioItems = items.filter { $0.kind == .test }
        self.sellers = sellers
        self.offers = offers
        rebuild()
        phase = .choosing
        error = nil
    }

    private func rebuild() {
        let data = AppData.shared
        let reference = PriceSource.date(fromISO: "2026-10-23") ?? Date()
        tests = scenarioItems.map { item in
            var canonical: String?
            if case .exact(let name) = canonicalTest(for: item.name, catalogue: data.testCatalogue) { canonical = name }
            let fasting = canonical.flatMap { name in data.testCatalogue.tests.first { $0.name == name }?.fasting } ?? .unknown

            var choices: [LabChoice] = []
            if let canonical {
                for priced in data.labPrices(city: city, test: canonical) {
                    let option = data.labOptions(city: city).filter { $0.lab == priced.lab || $0.lab.hasPrefix(priced.lab) || priced.lab.hasPrefix($0.lab) }
                        .sorted { $0.homeCollection.rawValue > $1.homeCollection.rawValue }.first   // "yes" sorts first
                    choices.append(LabChoice(id: Self.slug("\(city)-\(priced.lab)"), name: priced.lab, pricePaise: priced.paise, source: priced.source,
                                             home: option?.homeCollection ?? .unknown, feePaise: 0, reportMinutes: nil, sellerID: nil, isScenario: false))
                }
            }
            if choices.isEmpty {
                // No measured price for this test in this city: fall back to the demo basket's lab sellers.
                for offer in offers where offer.itemID == item.id && offer.inStock {
                    guard let seller = sellers.first(where: { $0.id == offer.sellerID && $0.channel == .lab }) else { continue }
                    choices.append(LabChoice(id: seller.id, name: Self.cleanLabName(seller.name), pricePaise: offer.price,
                                             source: PriceSource(kind: .online, dateSeen: reference),
                                             home: seller.name.lowercased().contains("home collection") ? .yes : .unknown,
                                             feePaise: seller.collectionFee, reportMinutes: seller.etaMinutes, sellerID: seller.id, isScenario: true))
                }
            }
            choices.sort { ($0.pricePaise, $0.name) < ($1.pricePaise, $1.name) }
            return LabTestRow(id: item.id, name: item.name, canonical: canonical, fasting: fasting, choices: choices)
        }
        chosenLab = Dictionary(uniqueKeysWithValues: tests.compactMap { row in row.choices.first.map { (row.id, $0.id) } })
        toldToFast = toldToFast.filter { id in tests.contains { $0.id == id } }
    }

    private static func cleanLabName(_ name: String) -> String {
        guard let open = name.firstIndex(of: "(") else { return name }
        return name[..<open].trimmingCharacters(in: .whitespaces)
    }

    private static func slug(_ text: String) -> String {
        text.lowercased().map { $0.isLetter || $0.isNumber ? String($0) : "-" }.joined()
            .split(separator: "-").joined(separator: "-")
    }

    // MARK: Choices

    /// Launch route only (-demoRoute lab): pretend the user ticked 'my lab told me to fast' for one test.
    func demoMarkToldToFast(_ testID: String) { toldToFast.insert(testID) }

    func select(lab: String, for testID: String) { chosenLab[testID] = lab }

    func isFasting(_ row: LabTestRow) -> Bool {
        row.fasting == .required || toldToFast.contains(row.id)
    }

    func setToldToFast(_ on: Bool, for testID: String) {
        if on { toldToFast.insert(testID) } else { toldToFast.remove(testID) }
    }

    func choice(for row: LabTestRow) -> LabChoice? {
        row.choices.first { $0.id == chosenLab[row.id] }
    }

    var selectedTotal: Paise {
        let chosen = tests.compactMap { row in choice(for: row) }
        let fees = Dictionary(grouping: chosen, by: \.id).values.compactMap { $0.first?.feePaise }.reduce(0, +)
        return chosen.map(\.pricePaise).reduce(0, +) + fees
    }

    // MARK: Slot

    /// The next 3 days, starting tomorrow.
    var dayChoices: [Date] {
        let calendar = ISOTime.calendar
        let today = calendar.startOfDay(for: Date())
        return (1...3).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }

    var preferredSlot: Date {
        let calendar = ISOTime.calendar
        let days = dayChoices
        let day = days.indices.contains(dayOffset - 1) ? days[dayOffset - 1] : (days.first ?? Date())
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
    }

    static func hourText(_ hour: Int) -> String {
        let h12 = hour % 12 == 0 ? 12 : hour % 12
        return "\(h12):00 \(hour < 12 ? "am" : "pm")"
    }

    // MARK: Book

    var canBook: Bool { phase == .choosing && tests.contains { choice(for: $0) != nil } }

    func book() {
        guard canBook else { return }
        let groups = Dictionary(grouping: tests.compactMap { row -> (LabTestRow, LabChoice)? in choice(for: row).map { (row, $0) } }, by: { $0.1.id })
        let slot = preferredSlot
        let addressText = address.text.trimmingCharacters(in: .whitespacesAndNewlines)
        error = nil

        var plans: [(LabBookRequest, LabBookingState)] = []
        for (labID, pairs) in groups.sorted(by: { $0.key < $1.key }) {
            guard let lab = pairs.first?.1 else { continue }
            let home = wantsHome && lab.home != .no
            if home && addressText.isEmpty { error = "Add your address for home collection, or switch to visiting the lab."; return }
            let fastingNames = pairs.filter { isFasting($0.0) }.map { $0.0.name }
            let request = LabBookRequest(
                labID: labID, labName: lab.name,
                tests: pairs.map { LabBookTestBody(testID: $0.0.id, name: $0.0.name, fasting: isFasting($0.0)) },
                homeCollection: home, preferredSlot: ISOTime.string(slot),
                addressText: home ? addressText : nil,
                orderID: lab.sellerID != nil && planSellerIDs.contains(lab.sellerID ?? "") ? orderID : nil,
                sellerID: lab.sellerID != nil && planSellerIDs.contains(lab.sellerID ?? "") ? lab.sellerID : nil)
            let state = LabBookingState(id: "pending-\(labID)", labID: labID, labName: lab.name, testNames: pairs.map { $0.0.name },
                                        fastingTestNames: fastingNames, homeCollection: home, requestedSlot: slot, address: home ? addressText : nil)
            plans.append((request, state))
        }
        guard !plans.isEmpty else { return }

        if liveRequested {
            guard let live else { error = LiveError.badURL.message; return }
            phase = .booking
            let client = LabBookingClient(live: live)
            Task { [weak self] in
                var made: [LabBookingState] = []
                for (request, var state) in plans {
                    do {
                        let reply = try await client.book(request)
                        state = LabBookingState(id: reply.bookingID, labID: state.labID, labName: state.labName, testNames: state.testNames,
                                                fastingTestNames: state.fastingTestNames, homeCollection: state.homeCollection,
                                                requestedSlot: state.requestedSlot, address: state.address, replyLink: reply.replyLink)
                        made.append(state)
                    } catch {
                        guard let self else { return }
                        self.error = (error as? LiveError)?.message ?? LiveError.unreachable.message
                        if made.isEmpty { self.phase = .choosing; return }
                    }
                }
                guard let self else { return }
                self.bookings = made
                self.phase = .booked
                for booking in made { self.startPolling(booking.id, client: client) }
            }
        } else {
            // Mock: no network; a scripted confirmation arrives after 5 s so the flow can be demoed offline.
            isDemo = true
            bookings = plans.map { var state = $0.1; state.isDemo = true; return state }
            phase = .booked
            demoTask = Task { [weak self] in
                try? await Task.sleep(for: Self.demoConfirmDelay)
                guard !Task.isCancelled else { return }
                self?.applyDemoConfirmation()
            }
        }
    }

    private func applyDemoConfirmation() {
        for i in bookings.indices where bookings[i].isDemo && bookings[i].state == "requested" {
            bookings[i].state = "confirmed"
            bookings[i].slot = bookings[i].requestedSlot
            bookings[i].note = "Demo confirmation: no lab was contacted."
            if !bookings[i].fastingTestNames.isEmpty, let slot = bookings[i].slot { bookings[i].fastingReminderAt = Self.reminderTime(before: slot) }
        }
    }

    /// 21:00 IST on the evening before the slot (same rule as the server).
    static func reminderTime(before slot: Date) -> Date? {
        let calendar = ISOTime.calendar
        guard let dayBefore = calendar.date(byAdding: .day, value: -1, to: slot) else { return nil }
        return calendar.date(bySettingHour: 21, minute: 0, second: 0, of: dayBefore)
    }

    func startOver() {
        pollTasks.values.forEach { $0.cancel() }
        pollTasks = [:]
        demoTask?.cancel()
        bookings = []
        phase = .choosing
        isDemo = false
        error = nil
        rebuild()
    }

    // MARK: Polling (every 3 s)

    private func startPolling(_ bookingID: String, client: LabBookingClient) {
        pollTasks[bookingID]?.cancel()
        pollTasks[bookingID] = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled, let self else { return }
                do {
                    let status = try await client.status(bookingID: bookingID)
                    if Task.isCancelled { return }
                    self.error = nil
                    self.apply(status)
                    if status.state == "rejected" || status.state == "done" || status.state == "confirmed" { return }
                } catch is CancellationError {
                    return
                } catch {
                    self.error = (error as? LiveError)?.message ?? LiveError.unreachable.message
                }
            }
        }
    }

    func resumePolling() {
        guard !isDemo, let live else { return }
        for booking in bookings where !booking.isFinal && pollTasks[booking.id] == nil {
            startPolling(booking.id, client: LabBookingClient(live: live))
        }
    }

    func stopPolling() {
        pollTasks.values.forEach { $0.cancel() }
        pollTasks = [:]
    }

    /// Manual refresh (also moves a confirmed booking on to collected / report states).
    func refresh() {
        guard let live else { return }
        let client = LabBookingClient(live: live)
        for booking in bookings where !booking.isFinal {
            Task { [weak self] in
                if let status = try? await client.status(bookingID: booking.id) { self?.apply(status) }
            }
        }
    }

    private func apply(_ status: LabStatus) {
        guard let i = bookings.firstIndex(where: { $0.id == status.bookingID }) else { return }
        bookings[i].state = status.state
        bookings[i].noReply = status.noReply
        bookings[i].slot = ISOTime.parse(status.slot)
        bookings[i].feePaise = status.feePaise
        bookings[i].fastingReminderAt = ISOTime.parse(status.fastingReminderAt)
        bookings[i].note = status.note
    }

    // MARK: Messages + Calendar

    /// Text to hand to the lab (the lab_booking_request template plus the reply link), for the share sheet.
    func requestText(for booking: LabBookingState) -> String? {
        let tests = booking.testNames.joined(separator: "\n")
        guard let filled = templates.fill(purpose: "lab_booking_request", language: .saved, channel: .whatsapp,
                                          values: ["lab_name": booking.labName, "slot": ISOTime.slot(booking.requestedSlot), "test_list": tests])
        else { return nil }
        guard let link = booking.replyLink else { return filled.text }
        return filled.text + "\n" + link
    }

    /// Adds the confirmed slot to Calendar and schedules the fasting reminder (when the server/demo gave one).
    func addToCalendarAndRemind(_ bookingID: String) async {
        guard let i = bookings.firstIndex(where: { $0.id == bookingID }), let slot = bookings[i].slot else { return }
        let booking = bookings[i]
        let calendarResult = await LabReminders.addToCalendar(
            title: "Lab tests at \(booking.labName)", start: slot,
            notes: booking.testNames.joined(separator: "\n") + (booking.isDemo ? "\n(Demo booking)" : ""), location: booking.address)
        var reminderResult = "No fasting reminder: none of the tests is marked fasting."
        if let fireAt = booking.fastingReminderAt {
            let list = booking.fastingTestNames.isEmpty ? booking.testNames : booking.fastingTestNames
            let body = templates.fill(purpose: "lab_fasting_reminder", language: .saved, channel: .whatsapp,
                                      values: ["slot": ISOTime.slot(slot), "test_list": list.joined(separator: "\n")])?.text
                ?? "Tomorrow: \(list.joined(separator: ", ")) at \(ISOTime.slot(slot))."
            reminderResult = await LabReminders.scheduleReminder(id: booking.id, body: body, fireAt: fireAt)
        }
        if let j = bookings.firstIndex(where: { $0.id == bookingID }) {
            bookings[j].calendarResult = calendarResult
            bookings[j].reminderResult = reminderResult
        }
    }
}
