import Testing
import Foundation
@testable import D2Manager

@Suite struct BrokerErrorTests {
    @Test func httpErrorParsesBrokerMessage() {
        let body = Fixtures.data(#"{"error":"name already exists"}"#)
        let err = BrokerError.from(status: 409, data: body)
        #expect(err == .http(status: 409, message: "name already exists"))
        #expect(err.userMessage.contains("already has an operation") || err.userMessage.contains("already exists"))
    }

    @Test func unauthorizedHasFriendlyMessage() {
        let err = BrokerError.http(status: 401, message: nil)
        #expect(err.userMessage.localizedCaseInsensitiveContains("token"))
    }

    @Test func transportErrorKeepsDescription() {
        let err = BrokerError.transport("Could not connect to the server.")
        #expect(err.userMessage.contains("d2-broker") || err.userMessage.contains("connect"))
    }

    @Test func malformedBodyStillYieldsError() {
        let err = BrokerError.from(status: 500, data: Fixtures.data("not json"))
        #expect(err == .http(status: 500, message: nil))
    }
}

// Serialized parent: the MockURLProtocol harness uses shared static state
// (handler/lastRequest/lastBody). A per-suite `.serialized` trait only serializes
// tests *within* one suite — separate suites still run in parallel and would race
// on that static state. Nesting both HTTP suites under one serialized parent
// serializes all of their tests against each other. Test-only; does not affect
// the BrokerClient API.
@Suite(.serialized) struct BrokerClientHTTPTests {
    @Suite struct BrokerClientGetTests {
    func makeClient() -> BrokerClient {
        BrokerClient(
            baseURL: URL(string: "http://localhost:9300")!,
            token: "admin-token",
            session: MockURLProtocol.session()
        )
    }

    @Test func healthReturnsTrueOn200() async {
        MockURLProtocol.handler = { _ in (200, Fixtures.data(#"{"status":"ok","service":"d2-broker"}"#)) }
        #expect(await makeClient().health() == true)
    }

    @Test func instancesSendsBearerAndParsesList() async throws {
        MockURLProtocol.handler = { _ in
            (200, Fixtures.data("{\"instances\":[\(Fixtures.instanceJSON)]}"))
        }
        let list = try await makeClient().instances(full: true)
        #expect(list.count == 1)
        #expect(list[0].name == "school-ind-test")
        // Assert request shape:
        let req = MockURLProtocol.lastRequest!
        #expect(req.httpMethod == "GET")
        #expect(req.url?.path == "/instances")
        #expect(req.url?.query?.contains("full=1") == true)
        #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer admin-token")
    }

    @Test func instancesFullFalseSendsFullZero() async throws {
        MockURLProtocol.handler = { _ in (200, Fixtures.data(#"{"instances":[]}"#)) }
        _ = try await makeClient().instances(full: false)
        #expect(MockURLProtocol.lastRequest?.url?.query?.contains("full=0") == true)
    }

    @Test func seedsParsesList() async throws {
        MockURLProtocol.handler = { _ in
            (200, Fixtures.data("{\"seeds_dir\":\"/x\",\"seeds\":[\(Fixtures.seedJSON)]}"))
        }
        let seeds = try await makeClient().seeds()
        #expect(seeds.count == 1)
        #expect(seeds[0].source == .seeds)
    }

    @Test func jobParsesSingleJob() async throws {
        MockURLProtocol.handler = { _ in (200, Fixtures.data(Fixtures.jobRunningJSON)) }
        let job = try await makeClient().job(id: "j-1a2b3c4d")
        #expect(job.status == .running)
        #expect(MockURLProtocol.lastRequest?.url?.path == "/jobs/j-1a2b3c4d")
    }

    @Test func jobLogReturnsPlainText() async throws {
        MockURLProtocol.handler = { _ in (200, Fixtures.data("line1\nline2")) }
        let log = try await makeClient().jobLog(id: "j-1")
        #expect(log == "line1\nline2")
        #expect(MockURLProtocol.lastRequest?.url?.path == "/jobs/j-1/log")
    }

    @Test func non2xxThrowsBrokerError() async {
        MockURLProtocol.handler = { _ in (409, Fixtures.data(#"{"error":"instance exists"}"#)) }
        await #expect(throws: BrokerError.http(status: 409, message: "instance exists")) {
            _ = try await makeClient().instances(full: false)
        }
    }

    // A cancelled URL request must surface as CancellationError, NOT as a
    // BrokerError.transport "can't reach broker" — cancellation is normal when a
    // SwiftUI .task is torn down, and must not be reported as the broker being down.
    @Test func cancelledRequestThrowsCancellationNotTransport() async {
        MockURLProtocol.handler = nil
        MockURLProtocol.failure = { URLError(.cancelled) }
        defer { MockURLProtocol.failure = nil }
        await #expect(throws: CancellationError.self) {
            _ = try await makeClient().instances(full: false)
        }
    }
}

// Serialized for the same reason as BrokerClientGetTests (shared mock static state).
    @Suite struct BrokerClientMutationTests {  // nested under serialized BrokerClientHTTPTests parent
    func makeClient() -> BrokerClient {
        BrokerClient(baseURL: URL(string: "http://localhost:9300")!,
                     token: "admin-token", session: MockURLProtocol.session())
    }

    /// The broker returns 202 + { "job": {...}, "poll": ..., "log": ... }.
    func jobEnvelope() -> Data {
        Fixtures.data("{\"job\":\(Fixtures.jobRunningJSON),\"poll\":\"/jobs/j-1a2b3c4d\",\"log\":\"/jobs/j-1a2b3c4d/log\"}")
    }

    @Test func createPostsBodyAndReturnsJob() async throws {
        MockURLProtocol.handler = { _ in (202, self.jobEnvelope()) }
        let job = try await makeClient().create(.init(name: "demo1", version: "2.42"))
        #expect(job.id == "j-1a2b3c4d")
        let req = MockURLProtocol.lastRequest!
        #expect(req.httpMethod == "POST")
        #expect(req.url?.path == "/instances")
        let body = try JSONSerialization.jsonObject(with: MockURLProtocol.lastBody!) as! [String: Any]
        #expect(body["name"] as? String == "demo1")
        #expect(body["version"] as? String == "2.42")
    }

    @Test func resetPostsSeed() async throws {
        MockURLProtocol.handler = { _ in (202, self.jobEnvelope()) }
        _ = try await makeClient().reset(name: "demo1", seed: "sl-demo-v42.sql.gz")
        let req = MockURLProtocol.lastRequest!
        #expect(req.url?.path == "/instances/demo1/reset")
        let body = try JSONSerialization.jsonObject(with: MockURLProtocol.lastBody!) as! [String: Any]
        #expect(body["seed"] as? String == "sl-demo-v42.sql.gz")
    }

    @Test func startStopPostNoBody() async throws {
        MockURLProtocol.handler = { _ in (202, self.jobEnvelope()) }
        _ = try await makeClient().start(name: "demo1")
        #expect(MockURLProtocol.lastRequest?.url?.path == "/instances/demo1/start")
        #expect(MockURLProtocol.lastRequest?.httpMethod == "POST")

        _ = try await makeClient().stop(name: "demo1")
        #expect(MockURLProtocol.lastRequest?.url?.path == "/instances/demo1/stop")
    }

    @Test func deleteUsesDeleteMethod() async throws {
        MockURLProtocol.handler = { _ in (202, self.jobEnvelope()) }
        _ = try await makeClient().delete(name: "demo1")
        #expect(MockURLProtocol.lastRequest?.httpMethod == "DELETE")
        #expect(MockURLProtocol.lastRequest?.url?.path == "/instances/demo1")
    }
}
}
