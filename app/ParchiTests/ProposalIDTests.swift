import XCTest
@testable import Parchi

/// K31: the app reads the server's proposalID from /status and sends it back on approve / reject.
/// An old server (no id) and an old call (no id) keep working: the field is simply left out of the request.
final class ProposalIDTests: XCTestCase {
    private final class Stub: URLProtocol {
        nonisolated(unsafe) static var lastPath = ""
        nonisolated(unsafe) static var lastBody: [String: Any] = [:]
        nonisolated(unsafe) static var status = 200

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        override func startLoading() {
            Stub.lastPath = request.url?.path ?? ""
            var data = request.httpBody ?? Data()
            if data.isEmpty, let stream = request.httpBodyStream {
                stream.open()
                var buffer = [UInt8](repeating: 0, count: 4096)
                while stream.hasBytesAvailable {
                    let n = stream.read(&buffer, maxLength: buffer.count)
                    if n <= 0 { break }
                    data.append(buffer, count: n)
                }
                stream.close()
            }
            Stub.lastBody = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            let body = Stub.status == 200 ? Data("{\"ok\":true}".utf8) : Data("{\"detail\":\"stale proposal\"}".utf8)
            let response = HTTPURLResponse(url: request.url!, statusCode: Stub.status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        }
        override func stopLoading() {}
    }

    private func client() throws -> LiveClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [Stub.self]
        Stub.status = 200
        return try XCTUnwrap(LiveClient(baseURLString: "http://stub.test", installKey: "k", session: URLSession(configuration: config)))
    }

    private func status(_ proposal: String) throws -> ServerStatus {
        let json = """
        {"orderID":"o1","state":"awaiting_approval","planVersion":1,"sellers":[],"pending":null,"proposal":\(proposal),
         "nothingAvailable":false,"needsCheck":[],"waitingSince":null,"audit":[]}
        """
        return try JSONDecoder().decode(ServerStatus.self, from: Data(json.utf8))
    }

    func testStatusExposesTheProposalID() throws {
        XCTAssertEqual(try status("{\"proposalID\":\"1-3\"}").proposalID, "1-3")
    }

    func testStatusWithoutAnIdOrWithoutAProposalHasNoID() throws {
        XCTAssertNil(try status("{}").proposalID)
        XCTAssertNil(try status("null").proposalID)
        XCTAssertNil(try status("{\"proposalID\":5}").proposalID, "a malformed id is ignored, never a crash")
    }

    func testApproveAndRejectSendTheIDBack() async throws {
        let live = try client()
        try await live.approve(orderID: "o1", planVersion: 1, proposalID: "1-3")
        XCTAssertEqual(Stub.lastPath, "/order/o1/approve")
        XCTAssertEqual(Stub.lastBody["proposalID"] as? String, "1-3")
        XCTAssertEqual(Stub.lastBody["planVersion"] as? Int, 1)
        try await live.reject(orderID: "o1", planVersion: 1, proposalID: "1-4")
        XCTAssertEqual(Stub.lastPath, "/order/o1/reject")
        XCTAssertEqual(Stub.lastBody["proposalID"] as? String, "1-4")
    }

    func testWithoutAnIDTheOldBodyIsSent() async throws {
        let live = try client()
        try await live.approve(orderID: "o1", planVersion: 2)
        XCTAssertEqual(Array(Stub.lastBody.keys), ["planVersion"], "no proposalID key at all")
        try await live.reject(orderID: "o1", planVersion: 2, proposalID: nil)
        XCTAssertEqual(Array(Stub.lastBody.keys), ["planVersion"])
    }

    func testAStaleProposalAnswerIsAConflict() async throws {
        let live = try client()
        Stub.status = 409
        do {
            try await live.approve(orderID: "o1", planVersion: 1, proposalID: "1-1")
            XCTFail("a 409 must throw")
        } catch let error as LiveError {
            XCTAssertEqual(error.message, LiveError.conflict.message)
        }
    }
}
