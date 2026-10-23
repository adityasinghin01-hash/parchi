import MapKit
import ParchiCore
import XCTest
@testable import Parchi

/// K29 (Codex R7 rows 5, 6, 7, 8, 11): map-only shop quotes in the plan, Apple data staying on the phone, "not available" replies,
/// city change while searching, and the 999 quantity ceiling.
@MainActor
final class MapShopK29Tests: XCTestCase {
    private let mapShop = MapShop(id: "map-testchemistz-287500-775000", name: "Test Chemist Z", distanceM: 420,
                                  latitude: 28.75, longitude: 77.5, kind: .chemist)

    /// A typed parchi (Dolo 650 x150, line r1): the plan starts at the catalogue MRP at the doctor's shop. The basket is big enough
    /// that a shop quoting half of it still wins after the planner's Rs 50 "walk to the shop" cost.
    private func doloModel(quantity: Int = 150) -> AppModel {
        let model = AppModel()
        model.loadReaderLines([ReaderLine(kind: "medicine", name: "Dolo", strength: "650", quantity: quantity, schedule: nil)])
        model.confirmList()
        return model
    }

    /// Opens the ask for `mapShop`, scripts its reply with `offers` (priced by the opaque id) and delivers it. Returns the opaque id.
    @discardableResult
    private func askMapShop(_ model: AppModel, _ shop: MapShop, offers: (String) -> [Offer]) -> String {
        model.prepareShopAsk(preselecting: shop)
        let askID = model.shopAsk.opaqueID(forMapShop: shop.id)
        model.shopAsk.prepare(items: model.scenario.items, candidates: model.shopAsk.candidates, demoOffers: offers(askID),
                              liveRequested: false, live: nil, orderID: nil)
        model.shopAsk.selected = [askID]
        model.shopAsk.send()
        model.shopAsk.applyDemoReply()
        return askID
    }

    // MARK: Row 5: a map-only shop's complete quote can enter the plan

    func testMapOnlyShopQuoteEntersThePlanWithShopRepliedChipAndItsRealPrice() throws {
        let model = doloModel()
        XCTAssertEqual(model.plan?.lines.map(\.sellerID), ["doctorshop"])
        let mrp = try XCTUnwrap(model.plan?.lines.first?.price)
        XCTAssertGreaterThan(mrp, 10_000, "precondition: Dolo 650 x150 at the catalogue MRP")
        let quote = mrp / 2

        let askID = askMapShop(model, mapShop) { [Offer(itemID: "r1", sellerID: $0, price: quote)] }

        let plan = try XCTUnwrap(model.plan)
        XCTAssertEqual(plan.lines.map(\.sellerID), [askID], "the cheaper complete quote from the map-only shop wins the plan")
        XCTAssertEqual(plan.lines.first?.price, quote, "its real reply price")
        XCTAssertEqual(model.sellerName(askID), "Test Chemist Z", "the plan shows the shop's real name (in memory)")
        XCTAssertEqual(model.seller(askID)?.channel, .localChemist)
        XCTAssertEqual(model.priceSource(sellerID: askID, itemID: "r1").kind, .shopReply, "the \"Shop replied\" chip")
        XCTAssertTrue(model.priceSource(sellerID: askID, itemID: "r1").label.hasPrefix("Shop replied"))
        XCTAssertFalse(model.scenario.sellers.contains { $0.id == askID }, "never written into the scenario, only in memory")
    }

    func testTheRegisteredShopIsDroppedWithItsReplyAndOnDeleteEverything() throws {
        let model = doloModel()
        let askID = askMapShop(model, mapShop) { [Offer(itemID: "r1", sellerID: $0, price: 20_000)] }
        XCTAssertNotNil(model.seller(askID))

        // New ask / edited parchi (resetPlanState calls startOver): the reply and the seller go; the plan is back to the doctor's shop.
        model.shopAsk.startOver()
        XCTAssertNil(model.seller(askID))
        XCTAssertTrue(model.shopAsk.mapSellers.isEmpty)
        XCTAssertEqual(model.plan?.lines.map(\.sellerID), ["doctorshop"])

        // Delete everything.
        askMapShop(model, mapShop) { [Offer(itemID: "r1", sellerID: $0, price: 20_000)] }
        XCTAssertFalse(model.shopAsk.mapSellers.isEmpty)
        NotificationCenter.default.post(name: .parchiErased, object: nil)
        XCTAssertTrue(model.shopAsk.mapSellers.isEmpty)
        XCTAssertNil(model.seller(askID))
        XCTAssertTrue(model.lines.isEmpty)
    }

    func testServerAndHistoryOnlySeeTheGenericNameAndNoDistanceForAQuotedMapShop() {
        let model = doloModel()
        let askID = askMapShop(model, mapShop) { [Offer(itemID: "r1", sellerID: $0, price: 20_000)] }
        let forServer = model.shopAsk.mapSellersForServer
        XCTAssertEqual(forServer.map(\.id), [askID])
        XCTAssertEqual(forServer.first?.name, "Shop near you 1")
        XCTAssertNil(forServer.first?.distanceMeters)
        XCTAssertEqual(model.shopAsk.mapSellers.first?.name, "Test Chemist Z")
        XCTAssertEqual(model.shopAsk.mapSellers.first?.distanceMeters, 420)
    }

    // MARK: Row 6: Apple-derived fields never leave the phone

    func testAskBodyHasOpaqueIDGenericNameAndNoDistanceForAMapShop() throws {
        let model = doloModel()
        model.prepareShopAsk(preselecting: mapShop)
        let askID = model.shopAsk.opaqueID(forMapShop: mapShop.id)
        XCTAssertNotNil(askID.range(of: "^map-[0-9a-f]{12}$", options: .regularExpression), askID)
        XCTAssertEqual(askID, model.shopAsk.opaqueID(forMapShop: mapShop.id), "stable for the session")
        XCTAssertEqual(model.shopAsk.candidates.first?.id, askID)
        XCTAssertEqual(model.shopAsk.candidates.first?.name, "Test Chemist Z", "the phone keeps the real name to show it")
        model.shopAsk.phones[askID] = "9876543210"

        let ordered = model.shopAsk.candidates.filter { model.shopAsk.selected.contains($0.id) }
        let request = model.shopAsk.makeRequest(ordered: ordered)
        let sent = try XCTUnwrap(request.shops.first)
        XCTAssertEqual(sent.shopID, askID)
        XCTAssertEqual(sent.name, "Shop near you 1")
        XCTAssertNil(sent.distanceM)
        XCTAssertEqual(sent.phone, "9876543210", "a number the user typed is theirs to send")
        let json = String(decoding: try JSONEncoder().encode(request), as: UTF8.self)
        for apple in ["Test Chemist Z", "testchemistz", "287500", "775000", "420", mapShop.id] {
            XCTAssertFalse(json.contains(apple), "\(apple) must not be in the ask body: \(json)")
        }
        // Shops from the plan data are unchanged (their name and distance are bundled data, not Apple's).
        let kendra = try XCTUnwrap(request.shops.first { $0.shopID == "janaushadhi" })
        XCTAssertEqual(kendra.name, "Jan Aushadhi Kendra")
        XCTAssertEqual(kendra.distanceM, 3_600)

        // A second map shop gets its own random id and the next generic name.
        let other = MapShop(id: "map-other-1-2", name: "Other Chemist", distanceM: 900, latitude: 28.7, longitude: 77.4, kind: .chemist)
        let otherID = model.shopAsk.opaqueID(forMapShop: other.id)
        XCTAssertNotEqual(otherID, askID)
        XCTAssertEqual(model.shopAsk.genericNames[otherID], "Shop near you 2")
    }

    func testSavedPhoneIsKeyedByTheOpaqueIDAndNotPersistedWithAppleData() {
        let model = AppModel()
        model.readDemoParchi()
        model.prepareShopAsk(preselecting: mapShop)
        let askID = model.shopAsk.opaqueID(forMapShop: mapShop.id)
        model.shopAsk.phones[askID] = "9123456789"
        XCTAssertEqual(model.shopAsk.phone(for: mapShop.id), "9123456789", "the shop sheet finds it by the map id")
        XCTAssertEqual(model.shopAsk.phone(for: askID), "9123456789")
        XCTAssertNil(model.shopAsk.phones[mapShop.id], "never keyed by the coordinate-bearing id")
        let stored = UserDefaults.standard.dictionary(forKey: "parchi.shopask.phones") as? [String: String] ?? [:]
        XCTAssertNil(stored[askID], "a map shop's number stays in memory")
        XCTAssertTrue(stored.keys.allSatisfy { !$0.contains("testchemistz") && !$0.contains("287500") })
        model.shopAsk.phones = [:]
    }

    func testOldSavedPhonesKeyedByAMapIDAreRemovedAtStart() {
        UserDefaults.standard.set(["map-oldshop-287500-775000": "9000000000", "doctorshop": "9111111111"], forKey: "parchi.shopask.phones")
        let model = ShopAskModel()
        XCTAssertEqual(model.phones, ["doctorshop": "9111111111"])
        let stored = UserDefaults.standard.dictionary(forKey: "parchi.shopask.phones") as? [String: String]
        XCTAssertEqual(stored, ["doctorshop": "9111111111"])
        UserDefaults.standard.removeObject(forKey: "parchi.shopask.phones")
    }

    func testDeleteEverythingForgetsTheOpaqueIDs() {
        let model = doloModel()
        model.prepareShopAsk(preselecting: mapShop)
        let first = model.shopAsk.opaqueID(forMapShop: mapShop.id)
        NotificationCenter.default.post(name: .parchiErased, object: nil)
        XCTAssertTrue(model.shopAsk.genericNames.isEmpty)
        let second = model.shopAsk.opaqueID(forMapShop: mapShop.id)
        XCTAssertNotEqual(first, second, "a fresh random id after Delete everything")
        XCTAssertEqual(model.shopAsk.genericNames[second], "Shop near you 1")
    }

    // MARK: Row 7: "not available" for everything is kept, never replaced by the catalogue MRP

    func testShopThatRepliedNotAvailableForEverythingShowsNotAvailableWithTheChip() throws {
        let model = doloModel()
        askMapShop(model, mapShop) { _ in [] }            // the scripted shop has nothing in stock
        XCTAssertEqual(model.shopAsk.rows.first?.state, .replied)

        let quote = ShopPricer(app: model).quote(for: mapShop)
        XCTAssertTrue(quote.price.isAsk, "no number")
        XCTAssertEqual(quote.price.source?.kind, .shopReply, "the \"Shop replied\" chip is still there")
        XCTAssertEqual(quote.items.count, 1)
        XCTAssertNil(quote.items.first?.paise, "not the catalogue MRP")
        XCTAssertEqual(quote.items.first?.note, "Not available")
        XCTAssertNotEqual(quote.footnote, "This is the printed price (MRP), not a quote from this shop. Ask the shop for its price.")
        XCTAssertEqual(model.plan?.lines.map(\.sellerID), ["doctorshop"], "an unavailable reply adds no price to the plan")
    }

    // MARK: Row 8: a new search centre clears the old city's shops

    private func item(_ name: String, _ lat: Double, _ lon: Double) -> MKMapItem {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)))
        item.name = name
        return item
    }

    func testChangingCityClearsTheOldShopsAtOnceAndDropsALateResultFromTheOldCity() async throws {
        let cityA = City(name: "City A", latitude: 28.0, longitude: 77.0)
        let cityB = City(name: "City B", latitude: 29.0, longitude: 78.0)
        let old = item("Old City Chemist", 28.0, 77.0), new = item("New City Chemist", 29.0, 78.0)
        defer { ShopSearchModel.searchOverride = nil }

        // 1. City A loads normally.
        ShopSearchModel.searchOverride = { _, region in region.center.latitude < 28.5 ? [old] : [new] }
        let search = ShopSearchModel()
        await search.load(around: cityA)
        XCTAssertEqual(search.shops.map(\.name), ["Old City Chemist"])

        // 2. The user picks city B while its searches are slow: the old shops are gone immediately and cannot be tapped.
        ShopSearchModel.searchOverride = { _, region in
            try? await Task.sleep(for: .milliseconds(150))
            return region.center.latitude < 28.5 ? [old] : [new]
        }
        let slow = Task { await search.load(around: cityB) }
        try await Task.sleep(for: .milliseconds(40))
        XCTAssertTrue(search.shops.isEmpty, "previous city's shops must not stay under the new city")
        XCTAssertEqual(search.state, .loading)
        await slow.value
        XCTAssertEqual(search.shops.map(\.name), ["New City Chemist"])

        // 3. A slow search for the OLD city that finishes after the new city loaded must not put its shops back.
        let search2 = ShopSearchModel()
        ShopSearchModel.searchOverride = { _, region in
            if region.center.latitude < 28.5 { try? await Task.sleep(for: .milliseconds(150)); return [old] }
            return [new]
        }
        let late = Task { await search2.load(around: cityA) }
        try await Task.sleep(for: .milliseconds(40))
        await search2.load(around: cityB)
        await late.value
        XCTAssertEqual(search2.shops.map(\.name), ["New City Chemist"])
        XCTAssertEqual(search2.state, .loaded)
    }

    func testACancelledSearchLeavesNoShopsAndCanBeStartedAgain() async throws {
        let city = City(name: "City A", latitude: 28.0, longitude: 77.0)
        let chemist = item("Chemist", 28.0, 77.0)
        defer { ShopSearchModel.searchOverride = nil }
        ShopSearchModel.searchOverride = { _, _ in
            try? await Task.sleep(for: .milliseconds(150))
            return [chemist]
        }
        let search = ShopSearchModel()
        let running = Task { await search.load(around: city) }
        try await Task.sleep(for: .milliseconds(40))
        running.cancel()
        await running.value
        XCTAssertTrue(search.shops.isEmpty)
        XCTAssertNotEqual(search.state, .loading, "not stuck on \"Finding shops\"")
        ShopSearchModel.searchOverride = { _, _ in [chemist] }
        await search.load(around: city)
        XCTAssertEqual(search.shops.map(\.name), ["Chemist"])
    }

    // MARK: Row 11: one ceiling, 999

    func testQuantityCeilingIs999InTheAddClampAndTheAskBodyAndMessage() throws {
        XCTAssertEqual(AppModel.maxManualQuantity, 999)
        XCTAssertEqual(ShopAskModel.maxQuantity, 999)

        let typed = AppModel()
        typed.addManualMedicine(name: "Dolo", strength: "650", quantity: 1000)
        XCTAssertEqual(typed.lines.first?.item.quantity, 999)

        // A reader line above 999 is still sent as 999 (the server answers 422 above that).
        let model = doloModel(quantity: 5_000)
        model.prepareShopAsk()
        let request = model.shopAsk.makeRequest(ordered: model.shopAsk.candidates.filter { model.shopAsk.selected.contains($0.id) })
        XCTAssertEqual(request.items.map(\.quantity), [999])
        let message = try XCTUnwrap(model.shopAsk.message(for: try XCTUnwrap(model.shopAsk.candidates.first).id))
        XCTAssertTrue(message.text.contains("x999"), message.text)
        XCTAssertFalse(message.text.contains("x5000"))
    }
}
