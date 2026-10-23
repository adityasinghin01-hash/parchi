import ParchiCore
import XCTest
@testable import Parchi

/// KR contract: where the lines came from (readSource), quantities that were not read, editing a line, reader failures,
/// and the ReaderClient code mapping (URLProtocol stub, no network).
@MainActor
final class ReaderContractTests: XCTestCase {
    private func med(_ name: String, _ strength: String?, _ quantity: Int?) -> ReaderLine {
        ReaderLine(kind: "medicine", name: name, strength: strength, quantity: quantity, schedule: nil)
    }

    // MARK: readSource / readNote

    func testDefaultSourceIsManualWithNoNote() {
        let model = AppModel()
        XCTAssertEqual(model.readSource, .manual)
        XCTAssertNil(model.readNote)
    }

    func testReaderAndOnPhoneSources() {
        let model = AppModel()
        model.loadReaderLines([med("Dolo", "650", 15)])
        XCTAssertEqual(model.readSource, .reader)
        XCTAssertNil(model.readNote)
        model.loadReaderLines([med("Dolo", "650", 15)], source: .onPhone)
        XCTAssertEqual(model.readSource, .onPhone)
    }

    func testSampleIsLabelledAndEraseResets() {
        let model = AppModel()
        model.readDemoParchi()
        XCTAssertEqual(model.readSource, .sample)
        XCTAssertEqual(model.readNote, "Sample parchi, not your photo")
        model.eraseAll()
        XCTAssertEqual(model.readSource, .manual)
        XCTAssertNil(model.readNote)
        XCTAssertTrue(model.quantityAssumed.isEmpty)
    }

    func testManualAddAndRemoveKeepTheSource() {
        let model = AppModel()
        model.loadReaderLines([med("Dolo", "650", 15), med("Pantop", "40", nil)])
        model.addManualMedicine(name: "Augmentin", strength: "625", quantity: 10)
        XCTAssertEqual(model.readSource, .reader)
        XCTAssertEqual(model.quantityAssumed, ["r2"], "the Pantop line is still assumed after a rebuild")
        model.removeManualLine("r1")
        XCTAssertEqual(model.readSource, .reader)
        XCTAssertEqual(model.quantityAssumed, ["r1"], "Pantop moved to r1 and is still assumed")
        model.readDemoParchi()
        model.addManualMedicine(name: "Augmentin", strength: "625", quantity: 10)
        XCTAssertEqual(model.readSource, .sample)
        XCTAssertEqual(model.readNote, "Sample parchi, not your photo")
    }

    func testStartManualListIsEmptyAndManual() {
        let model = AppModel()
        model.readDemoParchi()
        model.startManualList()
        XCTAssertTrue(model.lines.isEmpty)
        XCTAssertEqual(model.readSource, .manual)
        XCTAssertNil(model.readNote)
    }

    // MARK: quantities

    func testMissingQuantityIsAssumedOneAndSetQuantityClears() throws {
        let model = AppModel()
        model.loadReaderLines([med("Dolo", "650", nil), med("Pantop", "40", 15),
                               ReaderLine(kind: "test", name: "CBC", strength: nil, quantity: nil, schedule: nil)])
        XCTAssertEqual(model.quantityAssumed, ["r1"], "tests never count as an assumed quantity")
        XCTAssertEqual(model.lines[0].item.quantity, 1)
        model.setQuantity("r1", 20)
        XCTAssertEqual(model.lines[0].item.quantity, 20)
        XCTAssertTrue(model.quantityAssumed.isEmpty)
        model.setQuantity("r2", 0)
        XCTAssertEqual(model.lines[1].item.quantity, 1)
        model.setQuantity("r2", 5000)
        XCTAssertEqual(model.lines[1].item.quantity, AppModel.maxEditQuantity)
        XCTAssertEqual(AppModel.maxEditQuantity, 99)
    }

    func testSetQuantityInvalidatesThePlan() {
        let model = AppModel()
        model.loadReaderLines([med("Dolo", "650", 15)])
        model.confirmList()
        XCTAssertNotNil(model.plan)
        model.setQuantity("r1", 30)
        XCTAssertNil(model.plan)
    }

    func testChangedDemoLineLeavesTheDemoPriceButUnchangedDemoKeepsTheTotal() throws {
        let model = AppModel()
        model.readDemoParchi()
        model.editLine("telma", name: "Telma", strength: "40")   // the deliberate misread corrected through editLine
        XCTAssertNotNil(model.lines.first { $0.id == "telma" }, "back to the bundled item: keeps its demo id and prices")
        model.confirmList()
        XCTAssertEqual(try XCTUnwrap(model.plan).payable, 269_677, "Rs 2,696.77")

        let dolo = try XCTUnwrap(model.lines.first { $0.id == "dolo" })
        let count = model.lines.count
        model.setQuantity("dolo", dolo.item.quantity + 1)
        XCTAssertNil(model.lines.first { $0.id == "dolo" }, "a different amount must not keep the demo price")
        XCTAssertEqual(model.lines.count, count)
        XCTAssertEqual(model.readSource, .sample)
    }

    // MARK: editLine

    func testEditLineRerunsTheCatalogueCheck() throws {
        let model = AppModel()
        model.loadReaderLines([med("Telma", "41", 10)])
        guard case .strengthMismatch? = model.lines[0].check else { return XCTFail("41 is not a Telma strength") }
        model.editLine("r1", name: "Telma", strength: "40")
        XCTAssertEqual(model.lines[0].item.strength, "40")
        XCTAssertFalse(model.lines[0].needsAnswer)
        XCTAssertEqual(model.lines[0].item.quantity, 10, "quantity is kept")
        model.editLine("r1", name: "Xyzzyqq", strength: nil)
        guard case .unknownBrand? = model.lines[0].check else { return XCTFail("unknown brand must be flagged") }
        XCTAssertNil(model.lines[0].item.strength)
        model.editLine("r1", name: "   ", strength: "40")
        XCTAssertEqual(model.lines[0].item.name, "Xyzzyqq", "an empty name is ignored")
    }

    // MARK: ReaderFailure

    func testEveryFailureHasItsOwnHonestMessage() {
        let all: [ReaderFailure] = [.notConfigured, .capReached, .badKey, .readerError, .offline, .timeout, .empty, .noReaderInMock, .slowDown]
        XCTAssertEqual(Set(all.map(\.message)).count, all.count, "distinct text for each")
        for failure in all where failure != .offline {
            XCTAssertFalse(failure.message.localizedCaseInsensitiveContains("can't reach"), "\(failure) must not blame the network")
        }
        XCTAssertTrue(ReaderFailure.offline.message.contains("Can't reach"))
        XCTAssertFalse(ReaderFailure.capReached.canRetry)
        XCTAssertFalse(ReaderFailure.notConfigured.canRetry)
        XCTAssertFalse(ReaderFailure.badKey.canRetry)
        XCTAssertTrue(ReaderFailure.readerError.canRetry)
        XCTAssertTrue(ReaderFailure.offline.canRetry)
        XCTAssertTrue(ReaderFailure.timeout.canRetry)
        for failure in all { XCTAssertFalse(failure.message.contains("sample parchi is shown")) }
    }

    func testCodesMapOneToOne() {
        XCTAssertEqual(ReaderFailure(code: "not_configured"), .notConfigured)
        XCTAssertEqual(ReaderFailure(code: "cap_reached"), .capReached)
        XCTAssertEqual(ReaderFailure(code: "bad_key"), .badKey)
        XCTAssertEqual(ReaderFailure(code: "reader_error"), .readerError)
        XCTAssertEqual(ReaderFailure(code: "timeout"), .timeout)
        XCTAssertEqual(ReaderFailure(code: "slow_down"), .slowDown)
        XCTAssertNil(ReaderFailure(code: "nope"))
    }

    func testLiveNoteNamesAnthropicAndMakesNoRetentionClaim() {
        XCTAssertTrue(ReaderCopy.liveUploadNote.contains("Anthropic's Claude service"))
        XCTAssertTrue(ReaderCopy.liveUploadNote.contains("Anthropic's own terms apply"))
        XCTAssertFalse(ReaderCopy.liveUploadNote.localizedCaseInsensitiveContains("never leaves"))
        XCTAssertFalse(ReaderCopy.liveUploadNote.localizedCaseInsensitiveContains("days"))
    }

    // MARK: ReaderClient (stubbed HTTP)

    private func client() throws -> ReaderClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubReaderProtocol.self]
        let live = try XCTUnwrap(LiveClient(baseURLString: "http://stub.local", installKey: "k", session: URLSession(configuration: config)))
        return ReaderClient(live: live)
    }

    private func failure(status: Int, body: String) async throws -> ReaderFailure? {
        StubReaderProtocol.reply = .http(status, Data(body.utf8))
        do { _ = try await client().read(jpeg: Data([0xFF, 0xD8, 0xFF])); return nil } catch let f as ReaderFailure { return f }
    }

    func testClientMapsServerCodes() async throws {
        let cases: [(Int, String, ReaderFailure)] = [
            (503, #"{"detail":"x","code":"not_configured"}"#, .notConfigured),
            (503, #"{"detail":"x","code":"cap_reached"}"#, .capReached),
            (502, #"{"detail":"x","code":"bad_key"}"#, .badKey),
            (502, #"{"detail":"x","code":"reader_error"}"#, .readerError),
            (504, #"{"detail":"x","code":"timeout"}"#, .timeout),
            (429, #"{"detail":"x","code":"slow_down"}"#, .slowDown),
            (503, #"{"detail":"reader not connected"}"#, .notConfigured),
            (500, "oops", .readerError),
            (429, "", .slowDown),
        ]
        for (status, body, expected) in cases {
            let got = try await failure(status: status, body: body)
            XCTAssertEqual(got, expected, "HTTP \(status) \(body)")
        }
    }

    func testClientReturnsLinesAndMapsNetworkFailures() async throws {
        StubReaderProtocol.reply = .http(200, Data(#"{"lines":[{"kind":"medicine","name":"Dolo","strength":"650","quantity":null}]}"#.utf8))
        let lines = try await client().read(jpeg: Data([1]))
        XCTAssertEqual(lines, [ReaderLine(kind: "medicine", name: "Dolo", strength: "650", quantity: nil, schedule: nil)])

        StubReaderProtocol.reply = .error(URLError(.notConnectedToInternet))
        do { _ = try await client().read(jpeg: Data([1])); XCTFail() } catch let f as ReaderFailure { XCTAssertEqual(f, .offline) }
        StubReaderProtocol.reply = .error(URLError(.timedOut))
        do { _ = try await client().read(jpeg: Data([1])); XCTFail() } catch let f as ReaderFailure { XCTAssertEqual(f, .timeout) }
        StubReaderProtocol.reply = .http(200, Data("not json".utf8))
        do { _ = try await client().read(jpeg: Data([1])); XCTFail() } catch let f as ReaderFailure { XCTAssertEqual(f, .readerError) }
    }
}

/// Answers every request with `reply`. Tests only.
final class StubReaderProtocol: URLProtocol {
    enum Reply { case http(Int, Data), error(URLError) }
    nonisolated(unsafe) static var reply: Reply = .http(500, Data())

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        switch Self.reply {
        case .http(let status, let data):
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        case .error(let error):
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    override func stopLoading() {}
}
