# DHIS2 Menu Bar Manager — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS menu bar app (`MenuBarExtra`) that manages local DHIS2 Docker instances through the `d2-broker` HTTP API — list / start / stop / reset / delete / create — with live job progress.

**Architecture:** A layered SwiftUI app. Pure `Codable` models decode the broker's JSON. A stateless `BrokerClient` wraps the HTTP API behind a `BrokerClientProtocol` (so it can be faked in tests). A `JobPoller` turns a job id into an `AsyncThrowingStream<Job>` that emits until a terminal status. A `@MainActor @Observable AppModel` is the single source of truth the SwiftUI views read; it drives mutations and consumes the poller stream. `Settings` (in `UserDefaults`) + `TokenResolver` (reads `$DHIS2_BASE/_broker/tokens.json`) supply the base URL and admin token.

**Tech Stack:** Swift 6, Swift Package Manager executable target, SwiftUI `MenuBarExtra` (macOS 14+), Swift Testing (`import Testing`) for unit tests, `URLProtocol` mocking for the HTTP client.

---

## Conventions used throughout

- **JSON decoding:** `JSONDecoder` with `keyDecodingStrategy = .convertFromSnakeCase`. This maps `http_port → httpPort`, `localhost_url → localhostUrl`, `dhis2_major_version → dhis2MajorVersion`, `log_tail → logTail`, etc. Property names below follow that convention exactly (note: `localhostUrl`/`devnetUrl`, lower-case `rl`).
- **JSON encoding** (create request): `JSONEncoder` with `keyEncodingStrategy = .convertToSnakeCase`. Optionals that are `nil` are omitted (Swift's synthesized `encode` uses `encodeIfPresent` for optionals).
- **Timestamps** are decoded as `String` (not `Date`) to avoid date-format fragility; the UI shows them as-is or relatively.
- **Concurrency:** `BrokerClient`, models, and `JobPoller` are `Sendable`. `AppModel` is `@MainActor`. Polling delays go through an injected `sleep` closure so tests never actually wait.
- **Commits:** one per task (or per logical step where noted). Conventional-commit style messages.

## File structure

```
Package.swift
Sources/D2Manager/
  App.swift                       // @main, MenuBarExtra, .accessory policy, live wiring
  Models/
    InstanceStatus.swift          // enum
    JobStatus.swift               // enum + isTerminal
    JobOp.swift                   // enum
    SeedSource.swift              // enum
    Instance.swift
    Seed.swift
    Job.swift
    CreateInstanceRequest.swift
    BrokerError.swift
  Networking/
    BrokerClientProtocol.swift    // protocol both real + fake conform to
    BrokerClient.swift            // URLSession implementation
    JSONCoders.swift              // shared configured encoder/decoder
  Services/
    JobPoller.swift
    TokenResolver.swift
  State/
    Settings.swift
    AppModel.swift
  Views/
    MenuContentView.swift
    InstanceRowView.swift
    ActiveOperationView.swift
    CreateInstanceView.swift
    ResetView.swift
    JobLogView.swift
    SettingsView.swift
Tests/D2ManagerTests/
  Support/
    MockURLProtocol.swift
    FakeBrokerClient.swift
    Fixtures.swift                // sample JSON from the API doc
  ModelDecodingTests.swift
  BrokerClientTests.swift
  JobPollerTests.swift
  TokenResolverTests.swift
  SettingsTests.swift
  AppModelTests.swift
make-app.sh                       // optional .app bundling
```

Each task below is bite-sized (write test → run red → implement → run green → commit). Implement in order; later tasks depend on types defined earlier.

---

## Task 1: Package scaffolding

**Files:**
- Create: `Package.swift`
- Create: `Sources/D2Manager/Placeholder.swift`
- Create: `Tests/D2ManagerTests/SmokeTest.swift`

- [ ] **Step 1: Create `Package.swift`**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "D2Manager",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "D2Manager",
            path: "Sources/D2Manager"
        ),
        .testTarget(
            name: "D2ManagerTests",
            dependencies: ["D2Manager"],
            path: "Tests/D2ManagerTests"
        ),
    ]
)
```

- [ ] **Step 2: Add a temporary placeholder so the target compiles**

`Sources/D2Manager/Placeholder.swift`:

```swift
// Temporary: replaced by App.swift in Task 11.
enum BuildPlaceholder {
    static let ok = true
}
```

- [ ] **Step 3: Write a smoke test**

`Tests/D2ManagerTests/SmokeTest.swift`:

```swift
import Testing
@testable import D2Manager

@Test func packageBuilds() {
    #expect(BuildPlaceholder.ok)
}
```

- [ ] **Step 4: Build and test**

Run: `swift test`
Expected: builds and the single test passes.

- [ ] **Step 5: Commit**

```bash
git add Package.swift Sources Tests
git commit -m "chore: scaffold SwiftPM package for D2Manager"
```

---

## Task 2: Enum models (InstanceStatus, JobStatus, JobOp, SeedSource)

**Files:**
- Create: `Sources/D2Manager/Models/InstanceStatus.swift`
- Create: `Sources/D2Manager/Models/JobStatus.swift`
- Create: `Sources/D2Manager/Models/JobOp.swift`
- Create: `Sources/D2Manager/Models/SeedSource.swift`
- Test: `Tests/D2ManagerTests/ModelDecodingTests.swift`

- [ ] **Step 1: Write failing tests for the enums**

`Tests/D2ManagerTests/ModelDecodingTests.swift`:

```swift
import Testing
import Foundation
@testable import D2Manager

@Suite struct EnumTests {
    @Test func instanceStatusDecodes() throws {
        #expect(try decodeRaw(InstanceStatus.self, "\"running\"") == .running)
        #expect(try decodeRaw(InstanceStatus.self, "\"partial\"") == .partial)
        #expect(try decodeRaw(InstanceStatus.self, "\"stopped\"") == .stopped)
    }

    @Test func jobStatusTerminality() {
        #expect(JobStatus.succeeded.isTerminal)
        #expect(JobStatus.failed.isTerminal)
        #expect(JobStatus.interrupted.isTerminal)
        #expect(!JobStatus.queued.isTerminal)
        #expect(!JobStatus.running.isTerminal)
    }

    @Test func jobOpDecodes() throws {
        #expect(try decodeRaw(JobOp.self, "\"create\"") == .create)
        #expect(try decodeRaw(JobOp.self, "\"delete\"") == .delete)
    }
}

/// Decodes a JSON fragment that is itself a single value (e.g. a quoted string).
func decodeRaw<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
    let wrapped = "[\(json)]"
    return try JSONDecoder().decode([T].self, from: Data(wrapped.utf8))[0]
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter EnumTests`
Expected: FAIL — `InstanceStatus`/`JobStatus`/`JobOp` not defined.

- [ ] **Step 3: Implement the enums**

`Sources/D2Manager/Models/InstanceStatus.swift`:

```swift
enum InstanceStatus: String, Codable, Sendable, CaseIterable {
    case running, partial, stopped
}
```

`Sources/D2Manager/Models/JobStatus.swift`:

```swift
enum JobStatus: String, Codable, Sendable {
    case queued, running, succeeded, failed, interrupted

    var isTerminal: Bool {
        switch self {
        case .succeeded, .failed, .interrupted: return true
        case .queued, .running: return false
        }
    }
}
```

`Sources/D2Manager/Models/JobOp.swift`:

```swift
enum JobOp: String, Codable, Sendable {
    case create, reset, start, stop, delete
}
```

`Sources/D2Manager/Models/SeedSource.swift`:

```swift
enum SeedSource: String, Codable, Sendable {
    case seeds, backups
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter EnumTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/D2Manager/Models Tests/D2ManagerTests/ModelDecodingTests.swift
git commit -m "feat: add enum models (status, op, seed source)"
```

---

## Task 3: Shared JSON coders + Instance/Seed models

**Files:**
- Create: `Sources/D2Manager/Networking/JSONCoders.swift`
- Create: `Sources/D2Manager/Models/Instance.swift`
- Create: `Sources/D2Manager/Models/Seed.swift`
- Create: `Tests/D2ManagerTests/Support/Fixtures.swift`
- Modify: `Tests/D2ManagerTests/ModelDecodingTests.swift`

- [ ] **Step 1: Add the JSON fixtures from the API doc**

`Tests/D2ManagerTests/Support/Fixtures.swift`:

```swift
import Foundation

enum Fixtures {
    static let instanceJSON = """
    {
      "name": "school-ind-test",
      "status": "running",
      "http_port": 9010,
      "pg_port": 5433,
      "localhost_url": "http://localhost:9010",
      "devnet_url": "http://dhis2-school-ind-test:8080",
      "devnet_db": "dhis2-school-ind-test-db:5432",
      "agent_managed": false,
      "dhis2_major_version": "42"
    }
    """

    static let instanceMinimalJSON = """
    {
      "name": "agent-test1",
      "status": "stopped",
      "http_port": null,
      "pg_port": null,
      "localhost_url": null,
      "devnet_url": null,
      "devnet_db": null,
      "agent_managed": true
    }
    """

    static let seedJSON = """
    {
      "path": "sl-demo-v42.sql.gz",
      "source": "seeds",
      "size_bytes": 184729281,
      "modified": "2026-04-01T13:22:08+00:00"
    }
    """

    static let jobRunningJSON = """
    {
      "id": "j-1a2b3c4d",
      "op": "create",
      "instance": "agent-test1",
      "status": "running",
      "created_at": "2026-06-13T09:14:01+00:00",
      "started_at": "2026-06-13T09:14:02+00:00",
      "finished_at": null,
      "exit_code": null,
      "error": null,
      "result": null,
      "log_tail": "...last 20 lines..."
    }
    """

    static let jobSucceededJSON = """
    {
      "id": "j-1a2b3c4d",
      "op": "create",
      "instance": "agent-test1",
      "status": "succeeded",
      "created_at": "2026-06-13T09:14:01+00:00",
      "started_at": "2026-06-13T09:14:02+00:00",
      "finished_at": "2026-06-13T09:15:30+00:00",
      "exit_code": 0,
      "error": null,
      "result": {
        "name": "agent-test1",
        "status": "running",
        "http_port": 9011,
        "pg_port": 5434,
        "localhost_url": "http://localhost:9011",
        "devnet_url": "http://dhis2-agent-test1:8080",
        "devnet_db": "dhis2-agent-test1-db:5432",
        "agent_managed": true
      }
    }
    """

    static func data(_ s: String) -> Data { Data(s.utf8) }
}
```

- [ ] **Step 2: Add failing tests for Instance and Seed decoding**

Append to `Tests/D2ManagerTests/ModelDecodingTests.swift`:

```swift
@Suite struct InstanceSeedTests {
    @Test func instanceFullDecodes() throws {
        let i = try BrokerCoders.decoder.decode(Instance.self, from: Fixtures.data(Fixtures.instanceJSON))
        #expect(i.name == "school-ind-test")
        #expect(i.status == .running)
        #expect(i.httpPort == 9010)
        #expect(i.pgPort == 5433)
        #expect(i.localhostUrl == "http://localhost:9010")
        #expect(i.devnetUrl == "http://dhis2-school-ind-test:8080")
        #expect(i.devnetDb == "dhis2-school-ind-test-db:5432")
        #expect(i.agentManaged == false)
        #expect(i.dhis2MajorVersion == "42")
        #expect(i.id == "school-ind-test")
    }

    @Test func instanceMinimalDecodes() throws {
        let i = try BrokerCoders.decoder.decode(Instance.self, from: Fixtures.data(Fixtures.instanceMinimalJSON))
        #expect(i.httpPort == nil)
        #expect(i.localhostUrl == nil)
        #expect(i.dhis2MajorVersion == nil)
        #expect(i.agentManaged == true)
    }

    @Test func seedDecodes() throws {
        let s = try BrokerCoders.decoder.decode(Seed.self, from: Fixtures.data(Fixtures.seedJSON))
        #expect(s.path == "sl-demo-v42.sql.gz")
        #expect(s.source == .seeds)
        #expect(s.sizeBytes == 184729281)
        #expect(s.modified == "2026-04-01T13:22:08+00:00")
        #expect(s.id == "sl-demo-v42.sql.gz")
    }
}
```

- [ ] **Step 3: Run to verify failure**

Run: `swift test --filter InstanceSeedTests`
Expected: FAIL — `BrokerCoders`, `Instance`, `Seed` not defined.

- [ ] **Step 4: Implement the shared coders**

`Sources/D2Manager/Networking/JSONCoders.swift`:

```swift
import Foundation

enum BrokerCoders {
    static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }
}
```

- [ ] **Step 5: Implement Instance and Seed**

`Sources/D2Manager/Models/Instance.swift`:

```swift
struct Instance: Codable, Sendable, Identifiable, Equatable {
    var name: String
    var status: InstanceStatus
    var httpPort: Int?
    var pgPort: Int?
    var localhostUrl: String?
    var devnetUrl: String?
    var devnetDb: String?
    var agentManaged: Bool
    var dhis2MajorVersion: String?

    var id: String { name }
}
```

`Sources/D2Manager/Models/Seed.swift`:

```swift
struct Seed: Codable, Sendable, Identifiable, Equatable {
    var path: String
    var source: SeedSource
    var sizeBytes: Int
    var modified: String

    var id: String { path }
}
```

- [ ] **Step 6: Run to verify pass**

Run: `swift test --filter InstanceSeedTests`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Sources/D2Manager Tests/D2ManagerTests
git commit -m "feat: add Instance and Seed models with shared JSON coders"
```

---

## Task 4: Job model + CreateInstanceRequest

**Files:**
- Create: `Sources/D2Manager/Models/Job.swift`
- Create: `Sources/D2Manager/Models/CreateInstanceRequest.swift`
- Modify: `Tests/D2ManagerTests/ModelDecodingTests.swift`

- [ ] **Step 1: Add failing tests**

Append to `Tests/D2ManagerTests/ModelDecodingTests.swift`:

```swift
@Suite struct JobTests {
    @Test func runningJobDecodes() throws {
        let j = try BrokerCoders.decoder.decode(Job.self, from: Fixtures.data(Fixtures.jobRunningJSON))
        #expect(j.id == "j-1a2b3c4d")
        #expect(j.op == .create)
        #expect(j.instance == "agent-test1")
        #expect(j.status == .running)
        #expect(j.startedAt == "2026-06-13T09:14:02+00:00")
        #expect(j.finishedAt == nil)
        #expect(j.exitCode == nil)
        #expect(j.result == nil)
        #expect(j.logTail == "...last 20 lines...")
    }

    @Test func succeededJobCarriesResultInstance() throws {
        let j = try BrokerCoders.decoder.decode(Job.self, from: Fixtures.data(Fixtures.jobSucceededJSON))
        #expect(j.status == .succeeded)
        #expect(j.exitCode == 0)
        #expect(j.result?.name == "agent-test1")
        #expect(j.result?.httpPort == 9011)
        #expect(j.result?.status == .running)
    }

    @Test func createRequestOmitsNilsAndSnakeCases() throws {
        let req = CreateInstanceRequest(name: "demo1", version: "2.42", warUrl: "https://x/y.war")
        let data = try BrokerCoders.encoder.encode(req)
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(obj["name"] as? String == "demo1")
        #expect(obj["version"] as? String == "2.42")
        #expect(obj["war_url"] as? String == "https://x/y.war")
        #expect(obj["seed"] == nil)        // nil omitted
        #expect(obj["tomcat"] == nil)      // nil omitted
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter JobTests`
Expected: FAIL — `Job`, `CreateInstanceRequest` not defined.

- [ ] **Step 3: Implement Job**

`Sources/D2Manager/Models/Job.swift`:

```swift
struct Job: Codable, Sendable, Identifiable, Equatable {
    var id: String
    var op: JobOp
    var instance: String
    var status: JobStatus
    var createdAt: String
    var startedAt: String?
    var finishedAt: String?
    var exitCode: Int?
    var error: String?
    var result: Instance?
    var logTail: String?
}
```

- [ ] **Step 4: Implement CreateInstanceRequest**

`Sources/D2Manager/Models/CreateInstanceRequest.swift`:

```swift
struct CreateInstanceRequest: Codable, Sendable, Equatable {
    var name: String
    var version: String?
    var seed: String?
    var tomcat: String?
    var warUrl: String?
    var warFile: String?

    init(
        name: String,
        version: String? = nil,
        seed: String? = nil,
        tomcat: String? = nil,
        warUrl: String? = nil,
        warFile: String? = nil
    ) {
        self.name = name
        self.version = version
        self.seed = seed
        self.tomcat = tomcat
        self.warUrl = warUrl
        self.warFile = warFile
    }
}
```

- [ ] **Step 5: Run to verify pass**

Run: `swift test --filter JobTests`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/D2Manager Tests/D2ManagerTests
git commit -m "feat: add Job model and CreateInstanceRequest"
```

---

## Task 5: BrokerError

**Files:**
- Create: `Sources/D2Manager/Models/BrokerError.swift`
- Create: `Tests/D2ManagerTests/BrokerClientTests.swift` (starts with error tests)

- [ ] **Step 1: Write failing tests for error construction and messages**

`Tests/D2ManagerTests/BrokerClientTests.swift`:

```swift
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
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter BrokerErrorTests`
Expected: FAIL — `BrokerError` not defined.

- [ ] **Step 3: Implement BrokerError**

`Sources/D2Manager/Models/BrokerError.swift`:

```swift
import Foundation

enum BrokerError: Error, Equatable, Sendable {
    /// Non-2xx HTTP response. `message` is the broker's verbatim `{"error":...}` text when present.
    case http(status: Int, message: String?)
    /// Could not reach the broker (connection refused, timeout, etc.).
    case transport(String)
    /// Response body could not be decoded into the expected type.
    case decoding(String)

    /// Build from an HTTP status and raw body, decoding the `{"error": "..."}` envelope if present.
    static func from(status: Int, data: Data) -> BrokerError {
        struct Envelope: Decodable { let error: String }
        let message = try? JSONDecoder().decode(Envelope.self, from: data)
        return .http(status: status, message: message?.error)
    }

    /// User-facing string. Broker messages are already user-facing and shown verbatim;
    /// a few status codes get an extra hint.
    var userMessage: String {
        switch self {
        case .http(let status, let message):
            switch status {
            case 401:
                return "Token missing or invalid — check Settings."
            case 409:
                return message ?? "That instance already has an operation in progress."
            default:
                if let message { return message }
                return "Broker returned HTTP \(status)."
            }
        case .transport(let detail):
            return "Can't reach d2-broker. \(detail)"
        case .decoding(let detail):
            return "Unexpected response from d2-broker. \(detail)"
        }
    }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --filter BrokerErrorTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/D2Manager/Models/BrokerError.swift Tests/D2ManagerTests/BrokerClientTests.swift
git commit -m "feat: add BrokerError with status-code mapping and user messages"
```

---

## Task 6: BrokerClientProtocol + MockURLProtocol test harness

**Files:**
- Create: `Sources/D2Manager/Networking/BrokerClientProtocol.swift`
- Create: `Tests/D2ManagerTests/Support/MockURLProtocol.swift`

- [ ] **Step 1: Define the protocol**

`Sources/D2Manager/Networking/BrokerClientProtocol.swift`:

```swift
protocol BrokerClientProtocol: Sendable {
    func health() async -> Bool
    func instances(full: Bool) async throws -> [Instance]
    func seeds() async throws -> [Seed]
    func jobs() async throws -> [Job]
    func job(id: String) async throws -> Job
    func jobLog(id: String) async throws -> String
    func create(_ request: CreateInstanceRequest) async throws -> Job
    func reset(name: String, seed: String) async throws -> Job
    func start(name: String) async throws -> Job
    func stop(name: String) async throws -> Job
    func delete(name: String) async throws -> Job
}
```

- [ ] **Step 2: Implement the URLProtocol mock**

`Tests/D2ManagerTests/Support/MockURLProtocol.swift`:

```swift
import Foundation

/// A URLProtocol that returns a canned response decided by a per-test handler.
/// Set `MockURLProtocol.handler` before each test; it receives the outgoing
/// request and returns (statusCode, body).
final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> (Int, Data))?
    /// Captures the most recent request so tests can assert method/path/headers/body.
    nonisolated(unsafe) static var lastRequest: URLRequest?
    nonisolated(unsafe) static var lastBody: Data?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        // URLSession strips httpBody into a stream; capture it for assertions.
        Self.lastRequest = request
        Self.lastBody = request.httpBody ?? request.bodyStreamData()

        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let (status, data) = handler(request)
        let response = HTTPURLResponse(
            url: request.url!, statusCode: status,
            httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    /// Build a URLSession wired to this mock.
    static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }
}

private extension URLRequest {
    func bodyStreamData() -> Data? {
        guard let stream = httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data.isEmpty ? nil : data
    }
}
```

- [ ] **Step 3: Build to confirm it compiles**

Run: `swift build`
Expected: builds (no tests reference these yet beyond compilation).

- [ ] **Step 4: Commit**

```bash
git add Sources/D2Manager/Networking/BrokerClientProtocol.swift Tests/D2ManagerTests/Support/MockURLProtocol.swift
git commit -m "feat: add BrokerClientProtocol and URLProtocol mock harness"
```

---

## Task 7: BrokerClient — GET endpoints

**Files:**
- Create: `Sources/D2Manager/Networking/BrokerClient.swift`
- Modify: `Tests/D2ManagerTests/BrokerClientTests.swift`

- [ ] **Step 1: Write failing tests for GETs (health, instances, seeds, job, jobLog) and error mapping**

Append to `Tests/D2ManagerTests/BrokerClientTests.swift`:

```swift
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
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter BrokerClientGetTests`
Expected: FAIL — `BrokerClient` not defined.

- [ ] **Step 3: Implement BrokerClient with GET support**

`Sources/D2Manager/Networking/BrokerClient.swift`:

```swift
import Foundation

struct BrokerClient: BrokerClientProtocol {
    let baseURL: URL
    let token: String?
    let session: URLSession

    init(baseURL: URL, token: String?, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.token = token
        self.session = session
    }

    // MARK: Request plumbing

    private func makeRequest(_ method: String, path: String, query: [URLQueryItem] = [], body: Data? = nil) -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query }
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    /// Perform a request, returning the raw body on 2xx or throwing a BrokerError.
    private func perform(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw BrokerError.transport((error as NSError).localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw BrokerError.transport("No HTTP response.")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw BrokerError.from(status: http.statusCode, data: data)
        }
        return data
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do { return try BrokerCoders.decoder.decode(T.self, from: data) }
        catch { throw BrokerError.decoding(String(describing: error)) }
    }

    // MARK: GET endpoints

    func health() async -> Bool {
        let request = makeRequest("GET", path: "health")
        guard let data = try? await perform(request) else { return false }
        struct H: Decodable { let status: String }
        return (try? BrokerCoders.decoder.decode(H.self, from: data))?.status == "ok"
    }

    func instances(full: Bool) async throws -> [Instance] {
        let request = makeRequest("GET", path: "instances", query: [.init(name: "full", value: full ? "1" : "0")])
        struct Wrapper: Decodable { let instances: [Instance] }
        return try decode(Wrapper.self, from: try await perform(request)).instances
    }

    func seeds() async throws -> [Seed] {
        let request = makeRequest("GET", path: "seeds")
        struct Wrapper: Decodable { let seeds: [Seed] }
        return try decode(Wrapper.self, from: try await perform(request)).seeds
    }

    func jobs() async throws -> [Job] {
        let request = makeRequest("GET", path: "jobs")
        struct Wrapper: Decodable { let jobs: [Job] }
        return try decode(Wrapper.self, from: try await perform(request)).jobs
    }

    func job(id: String) async throws -> Job {
        let request = makeRequest("GET", path: "jobs/\(id)")
        return try decode(Job.self, from: try await perform(request))
    }

    func jobLog(id: String) async throws -> String {
        let request = makeRequest("GET", path: "jobs/\(id)/log")
        let data = try await perform(request)
        return String(decoding: data, as: UTF8.self)
    }

    // MARK: Mutations (implemented in Task 8)

    func create(_ request: CreateInstanceRequest) async throws -> Job { try await postJob(path: "instances", body: request) }
    func reset(name: String, seed: String) async throws -> Job { fatalError("implemented in Task 8") }
    func start(name: String) async throws -> Job { fatalError("implemented in Task 8") }
    func stop(name: String) async throws -> Job { fatalError("implemented in Task 8") }
    func delete(name: String) async throws -> Job { fatalError("implemented in Task 8") }

    private func postJob<B: Encodable>(path: String, body: B?) async throws -> Job {
        fatalError("implemented in Task 8")
    }
}
```

> Note: the mutation stubs use `fatalError` only so the type conforms to the protocol now; Task 8 replaces them and adds their tests. No test in this task exercises them.

- [ ] **Step 4: Run to verify pass**

Run: `swift test --filter BrokerClientGetTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/D2Manager/Networking/BrokerClient.swift Tests/D2ManagerTests/BrokerClientTests.swift
git commit -m "feat: implement BrokerClient GET endpoints"
```

---

## Task 8: BrokerClient — mutations (create/reset/start/stop/delete)

**Files:**
- Modify: `Sources/D2Manager/Networking/BrokerClient.swift`
- Modify: `Tests/D2ManagerTests/BrokerClientTests.swift`

- [ ] **Step 1: Write failing tests for the mutations**

Append to `Tests/D2ManagerTests/BrokerClientTests.swift`:

```swift
@Suite struct BrokerClientMutationTests {
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
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter BrokerClientMutationTests`
Expected: FAIL — current stubs `fatalError`, so tests crash/fail.

- [ ] **Step 3: Replace the mutation stubs in `BrokerClient.swift`**

Replace the `// MARK: Mutations (implemented in Task 8)` block with:

```swift
    // MARK: Mutations

    func create(_ request: CreateInstanceRequest) async throws -> Job {
        try await postJob(path: "instances", body: request)
    }

    func reset(name: String, seed: String) async throws -> Job {
        struct Body: Encodable { let seed: String }
        return try await postJob(path: "instances/\(name)/reset", body: Body(seed: seed))
    }

    func start(name: String) async throws -> Job {
        try await postJob(path: "instances/\(name)/start", body: Optional<CreateInstanceRequest>.none)
    }

    func stop(name: String) async throws -> Job {
        try await postJob(path: "instances/\(name)/stop", body: Optional<CreateInstanceRequest>.none)
    }

    func delete(name: String) async throws -> Job {
        let request = makeRequest("DELETE", path: "instances/\(name)")
        return try decodeJobEnvelope(from: try await perform(request))
    }

    /// POST a JSON body (or none) and decode the `{ "job": {...} }` envelope into a Job.
    private func postJob<B: Encodable>(path: String, body: B?) async throws -> Job {
        let data: Data? = try body.map { try BrokerCoders.encoder.encode($0) }
        let request = makeRequest("POST", path: path, body: data)
        return try decodeJobEnvelope(from: try await perform(request))
    }

    private func decodeJobEnvelope(from data: Data) throws -> Job {
        struct Envelope: Decodable { let job: Job }
        return try decode(Envelope.self, from: data).job
    }
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --filter BrokerClientMutationTests`
Expected: PASS. Also run the full suite: `swift test` → all green.

- [ ] **Step 5: Commit**

```bash
git add Sources/D2Manager/Networking/BrokerClient.swift Tests/D2ManagerTests/BrokerClientTests.swift
git commit -m "feat: implement BrokerClient mutations with job-envelope decoding"
```

---

## Task 9: JobPoller + FakeBrokerClient

**Files:**
- Create: `Sources/D2Manager/Services/JobPoller.swift`
- Create: `Tests/D2ManagerTests/Support/FakeBrokerClient.swift`
- Create: `Tests/D2ManagerTests/JobPollerTests.swift`

- [ ] **Step 1: Implement a reusable FakeBrokerClient for tests**

`Tests/D2ManagerTests/Support/FakeBrokerClient.swift`:

```swift
import Foundation
@testable import D2Manager

/// Configurable fake. `jobScript` returns successive Job values on each
/// `job(id:)` call (by call index). Other methods return stored values or throw `error`.
final class FakeBrokerClient: BrokerClientProtocol, @unchecked Sendable {
    var jobScript: [Job] = []
    private var jobCallCount = 0

    var instancesResult: [Instance] = []
    var seedsResult: [Seed] = []
    var jobsResult: [Job] = []
    var jobLogResult = ""
    var mutationResult: Job?
    var error: BrokerError?

    private(set) var startedNames: [String] = []
    private(set) var stoppedNames: [String] = []
    private(set) var deletedNames: [String] = []
    private(set) var resetCalls: [(String, String)] = []
    private(set) var createRequests: [CreateInstanceRequest] = []

    func health() async -> Bool { error == nil }

    func instances(full: Bool) async throws -> [Instance] {
        if let error { throw error }
        return instancesResult
    }
    func seeds() async throws -> [Seed] { if let error { throw error }; return seedsResult }
    func jobs() async throws -> [Job] { if let error { throw error }; return jobsResult }
    func jobLog(id: String) async throws -> String { if let error { throw error }; return jobLogResult }

    func job(id: String) async throws -> Job {
        if let error { throw error }
        defer { jobCallCount += 1 }
        let index = min(jobCallCount, jobScript.count - 1)
        return jobScript[index]
    }

    func create(_ request: CreateInstanceRequest) async throws -> Job { createRequests.append(request); return try mutationOrThrow() }
    func reset(name: String, seed: String) async throws -> Job { resetCalls.append((name, seed)); return try mutationOrThrow() }
    func start(name: String) async throws -> Job { startedNames.append(name); return try mutationOrThrow() }
    func stop(name: String) async throws -> Job { stoppedNames.append(name); return try mutationOrThrow() }
    func delete(name: String) async throws -> Job { deletedNames.append(name); return try mutationOrThrow() }

    private func mutationOrThrow() throws -> Job {
        if let error { throw error }
        return mutationResult ?? jobScript.first ?? TestJobs.queued
    }
}

/// Convenience job builders for tests.
enum TestJobs {
    static func job(id: String = "j-1", op: JobOp = .start, status: JobStatus) -> Job {
        Job(id: id, op: op, instance: "demo1", status: status,
            createdAt: "t0", startedAt: nil, finishedAt: nil,
            exitCode: status == .succeeded ? 0 : nil,
            error: status == .failed ? "boom" : nil,
            result: nil, logTail: "tail")
    }
    static let queued = job(status: .queued)
    static let running = job(status: .running)
    static let succeeded = job(status: .succeeded)
    static let failed = job(status: .failed)
}
```

- [ ] **Step 2: Write failing tests for JobPoller**

`Tests/D2ManagerTests/JobPollerTests.swift`:

```swift
import Testing
import Foundation
@testable import D2Manager

@Suite struct JobPollerTests {
    func makePoller(_ fake: FakeBrokerClient) -> JobPoller {
        // No-op sleep so tests don't wait.
        JobPoller(client: fake, interval: .zero, sleep: { _ in })
    }

    @Test func emitsUntilSucceeded() async throws {
        let fake = FakeBrokerClient()
        fake.jobScript = [TestJobs.queued, TestJobs.running, TestJobs.succeeded]
        var seen: [JobStatus] = []
        for try await job in makePoller(fake).updates(forJobID: "j-1") {
            seen.append(job.status)
        }
        #expect(seen == [.queued, .running, .succeeded])
    }

    @Test func stopsOnFailed() async throws {
        let fake = FakeBrokerClient()
        fake.jobScript = [TestJobs.running, TestJobs.failed, TestJobs.succeeded]
        var count = 0
        var last: JobStatus?
        for try await job in makePoller(fake).updates(forJobID: "j-1") {
            count += 1; last = job.status
        }
        #expect(count == 2)         // running, failed — never reaches the succeeded entry
        #expect(last == .failed)
    }

    @Test func propagatesClientError() async {
        let fake = FakeBrokerClient()
        fake.error = .transport("down")
        await #expect(throws: BrokerError.self) {
            for try await _ in makePoller(fake).updates(forJobID: "j-1") {}
        }
    }
}
```

- [ ] **Step 3: Run to verify failure**

Run: `swift test --filter JobPollerTests`
Expected: FAIL — `JobPoller` not defined.

- [ ] **Step 4: Implement JobPoller**

`Sources/D2Manager/Services/JobPoller.swift`:

```swift
import Foundation

/// Polls `GET /jobs/<id>` until the job reaches a terminal status, emitting each
/// fetched Job. The poll delay goes through `sleep` so tests can inject a no-op.
struct JobPoller: Sendable {
    let client: BrokerClientProtocol
    var interval: Duration = .milliseconds(1500)
    var sleep: @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }

    func updates(forJobID id: String) -> AsyncThrowingStream<Job, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    while true {
                        let job = try await client.job(id: id)
                        continuation.yield(job)
                        if job.status.isTerminal { break }
                        try await sleep(interval)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
```

- [ ] **Step 5: Run to verify pass**

Run: `swift test --filter JobPollerTests`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/D2Manager/Services/JobPoller.swift Tests/D2ManagerTests/Support/FakeBrokerClient.swift Tests/D2ManagerTests/JobPollerTests.swift
git commit -m "feat: add JobPoller streaming poll-until-terminal + fake client"
```

---

## Task 10: Settings + TokenResolver

**Files:**
- Create: `Sources/D2Manager/State/Settings.swift`
- Create: `Sources/D2Manager/Services/TokenResolver.swift`
- Create: `Tests/D2ManagerTests/SettingsTests.swift`
- Create: `Tests/D2ManagerTests/TokenResolverTests.swift`

- [ ] **Step 1: Write failing tests for Settings round-trip**

`Tests/D2ManagerTests/SettingsTests.swift`:

```swift
import Testing
import Foundation
@testable import D2Manager

@Suite struct SettingsTests {
    @Test func defaultsAreSensible() {
        let s = Settings()
        #expect(s.baseURL == URL(string: "http://localhost:9300")!)
        #expect(s.dhis2BasePath == nil)
        #expect(s.tokenOverride == nil)
    }

    @Test func roundTripsThroughUserDefaults() {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        var s = Settings()
        s.baseURL = URL(string: "http://localhost:9999")!
        s.dhis2BasePath = "/Users/x/dhis2"
        s.tokenOverride = "abc"
        s.save(to: defaults)

        let loaded = Settings.load(from: defaults)
        #expect(loaded.baseURL == URL(string: "http://localhost:9999")!)
        #expect(loaded.dhis2BasePath == "/Users/x/dhis2")
        #expect(loaded.tokenOverride == "abc")
    }
}
```

- [ ] **Step 2: Write failing tests for TokenResolver**

`Tests/D2ManagerTests/TokenResolverTests.swift`:

```swift
import Testing
import Foundation
@testable import D2Manager

@Suite struct TokenResolverTests {
    let tokensJSON = #"{"admin":{"token":"ADMIN123"},"agent":{"token":"AGENT456"}}"#

    @Test func overrideWins() throws {
        var s = Settings(); s.tokenOverride = "OVERRIDE"
        let resolver = TokenResolver(environment: [:], fileReader: { _ in Data() })
        #expect(try resolver.resolve(settings: s) == "OVERRIDE")
    }

    @Test func readsAdminTokenFromConfiguredBasePath() throws {
        var s = Settings(); s.dhis2BasePath = "/base"
        let resolver = TokenResolver(environment: [:], fileReader: { url in
            #expect(url.path == "/base/_broker/tokens.json")
            return Data(self.tokensJSON.utf8)
        })
        #expect(try resolver.resolve(settings: s) == "ADMIN123")
    }

    @Test func fallsBackToEnvironmentDHIS2Base() throws {
        let s = Settings()  // no dhis2BasePath
        let resolver = TokenResolver(environment: ["DHIS2_BASE": "/envbase"], fileReader: { url in
            #expect(url.path == "/envbase/_broker/tokens.json")
            return Data(self.tokensJSON.utf8)
        })
        #expect(try resolver.resolve(settings: s) == "ADMIN123")
    }

    @Test func returnsNilWhenNoSourceAvailable() throws {
        let s = Settings()
        let resolver = TokenResolver(environment: [:], fileReader: { _ in Data() })
        #expect(try resolver.resolve(settings: s) == nil)
    }
}
```

- [ ] **Step 3: Run to verify failure**

Run: `swift test --filter SettingsTests` then `swift test --filter TokenResolverTests`
Expected: FAIL — `Settings`, `TokenResolver` not defined.

- [ ] **Step 4: Implement Settings**

`Sources/D2Manager/State/Settings.swift`:

```swift
import Foundation

struct Settings: Equatable, Sendable {
    var baseURL: URL = URL(string: "http://localhost:9300")!
    var dhis2BasePath: String?
    var tokenOverride: String?

    private enum Key {
        static let baseURL = "baseURL"
        static let dhis2BasePath = "dhis2BasePath"
        static let tokenOverride = "tokenOverride"
    }

    func save(to defaults: UserDefaults) {
        defaults.set(baseURL.absoluteString, forKey: Key.baseURL)
        defaults.set(dhis2BasePath, forKey: Key.dhis2BasePath)
        defaults.set(tokenOverride, forKey: Key.tokenOverride)
    }

    static func load(from defaults: UserDefaults) -> Settings {
        var s = Settings()
        if let raw = defaults.string(forKey: Key.baseURL), let url = URL(string: raw) {
            s.baseURL = url
        }
        s.dhis2BasePath = defaults.string(forKey: Key.dhis2BasePath)
        s.tokenOverride = defaults.string(forKey: Key.tokenOverride)
        return s
    }
}
```

- [ ] **Step 5: Implement TokenResolver**

`Sources/D2Manager/Services/TokenResolver.swift`:

```swift
import Foundation

struct TokenResolver {
    var environment: [String: String] = ProcessInfo.processInfo.environment
    var fileReader: (URL) throws -> Data = { try Data(contentsOf: $0) }

    /// Resolve the admin token. Precedence: manual override → tokens.json under
    /// `dhis2BasePath` → tokens.json under `$DHIS2_BASE`. Returns nil if none resolve.
    func resolve(settings: Settings) throws -> String? {
        if let override = settings.tokenOverride, !override.isEmpty {
            return override
        }
        guard let base = settings.dhis2BasePath ?? environment["DHIS2_BASE"], !base.isEmpty else {
            return nil
        }
        let url = URL(fileURLWithPath: base)
            .appendingPathComponent("_broker")
            .appendingPathComponent("tokens.json")
        let data = try fileReader(url)
        struct TokensFile: Decodable {
            struct Entry: Decodable { let token: String }
            let admin: Entry
        }
        return try JSONDecoder().decode(TokensFile.self, from: data).admin.token
    }
}
```

- [ ] **Step 6: Run to verify pass**

Run: `swift test --filter SettingsTests` then `swift test --filter TokenResolverTests`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Sources/D2Manager/State/Settings.swift Sources/D2Manager/Services/TokenResolver.swift Tests/D2ManagerTests/SettingsTests.swift Tests/D2ManagerTests/TokenResolverTests.swift
git commit -m "feat: add Settings persistence and TokenResolver"
```

---

## Task 11: AppModel

**Files:**
- Create: `Sources/D2Manager/State/AppModel.swift`
- Create: `Tests/D2ManagerTests/AppModelTests.swift`

- [ ] **Step 1: Write failing tests for AppModel behavior**

`Tests/D2ManagerTests/AppModelTests.swift`:

```swift
import Testing
import Foundation
@testable import D2Manager

@MainActor
@Suite struct AppModelTests {
    func makeModel(_ fake: FakeBrokerClient) -> AppModel {
        let poller = JobPoller(client: fake, interval: .zero, sleep: { _ in })
        return AppModel(client: fake, poller: poller)
    }

    @Test func refreshLoadsInstances() async {
        let fake = FakeBrokerClient()
        fake.instancesResult = [TestInstances.running]
        let model = makeModel(fake)
        await model.refresh()
        #expect(model.instances.count == 1)
        #expect(model.lastError == nil)
    }

    @Test func refreshStoresErrorMessage() async {
        let fake = FakeBrokerClient()
        fake.error = .transport("connection refused")
        let model = makeModel(fake)
        await model.refresh()
        #expect(model.instances.isEmpty)
        #expect(model.lastError?.contains("d2-broker") == true)
    }

    @Test func startRunsJobToTerminalThenRefreshes() async {
        let fake = FakeBrokerClient()
        fake.mutationResult = TestJobs.job(op: .start, status: .queued)
        fake.jobScript = [TestJobs.job(op: .start, status: .running),
                          TestJobs.job(op: .start, status: .succeeded)]
        fake.instancesResult = [TestInstances.running]
        let model = makeModel(fake)

        await model.start(name: "demo1")

        #expect(fake.startedNames == ["demo1"])
        #expect(model.activeJob == nil)               // cleared after terminal
        #expect(model.recentJobs.first?.status == .succeeded)
        #expect(model.instances.count == 1)           // refreshed afterwards
    }

    @Test func failedJobSurfacesErrorButStillRecorded() async {
        let fake = FakeBrokerClient()
        fake.mutationResult = TestJobs.job(op: .delete, status: .queued)
        fake.jobScript = [TestJobs.job(op: .delete, status: .failed)]
        let model = makeModel(fake)

        await model.delete(name: "demo1")

        #expect(model.activeJob == nil)
        #expect(model.recentJobs.first?.status == .failed)
        #expect(model.lastError?.isEmpty == false)
    }

    @Test func mutationErrorIsCaught() async {
        let fake = FakeBrokerClient()
        fake.error = .http(status: 409, message: "busy")
        let model = makeModel(fake)
        await model.stop(name: "demo1")
        #expect(model.activeJob == nil)
        #expect(model.lastError != nil)
    }
}

enum TestInstances {
    static let running = Instance(
        name: "demo1", status: .running, httpPort: 9010, pgPort: 5433,
        localhostUrl: "http://localhost:9010", devnetUrl: nil, devnetDb: nil,
        agentManaged: false, dhis2MajorVersion: nil
    )
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter AppModelTests`
Expected: FAIL — `AppModel` not defined.

- [ ] **Step 3: Implement AppModel**

`Sources/D2Manager/State/AppModel.swift`:

```swift
import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    private(set) var instances: [Instance] = []
    private(set) var seeds: [Seed] = []
    private(set) var activeJob: Job?
    private(set) var recentJobs: [Job] = []
    var lastError: String?

    private let client: BrokerClientProtocol
    private let poller: JobPoller

    init(client: BrokerClientProtocol, poller: JobPoller) {
        self.client = client
        self.poller = poller
    }

    var isBusy: Bool { activeJob != nil }

    // MARK: Reads

    func refresh() async {
        do {
            instances = try await client.instances(full: false)
            lastError = nil
        } catch {
            lastError = message(for: error)
        }
    }

    func loadSeeds() async {
        do { seeds = try await client.seeds() }
        catch { lastError = message(for: error) }
    }

    func fullLog(for jobID: String) async -> String {
        (try? await client.jobLog(id: jobID)) ?? ""
    }

    // MARK: Mutations

    func start(name: String) async { await run { try await self.client.start(name: name) } }
    func stop(name: String) async { await run { try await self.client.stop(name: name) } }
    func delete(name: String) async { await run { try await self.client.delete(name: name) } }
    func reset(name: String, seed: String) async { await run { try await self.client.reset(name: name, seed: seed) } }
    func create(_ request: CreateInstanceRequest) async { await run { try await self.client.create(request) } }

    /// Shared mutation flow: kick off the op, then poll its job to terminal,
    /// reflecting progress in `activeJob`, recording the final job, and refreshing.
    private func run(_ op: @escaping () async throws -> Job) async {
        guard !isBusy else {
            lastError = "An operation is already in progress."
            return
        }
        do {
            let job = try await op()
            activeJob = job
            var finalJob = job
            for try await update in poller.updates(forJobID: job.id) {
                activeJob = update
                finalJob = update
            }
            activeJob = nil
            recentJobs.insert(finalJob, at: 0)
            if finalJob.status != .succeeded {
                lastError = finalJob.error ?? "Operation \(finalJob.op.rawValue) \(finalJob.status.rawValue)."
            } else {
                lastError = nil
            }
            await refresh()
        } catch {
            activeJob = nil
            lastError = message(for: error)
        }
    }

    private func message(for error: Error) -> String {
        if let brokerError = error as? BrokerError { return brokerError.userMessage }
        return error.localizedDescription
    }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --filter AppModelTests`
Expected: PASS. Then full suite: `swift test` → all green.

- [ ] **Step 5: Commit**

```bash
git add Sources/D2Manager/State/AppModel.swift Tests/D2ManagerTests/AppModelTests.swift
git commit -m "feat: add AppModel orchestrating reads, mutations, and polling"
```

---

## Task 12: App entry point + live wiring

**Files:**
- Create: `Sources/D2Manager/App.swift`
- Delete: `Sources/D2Manager/Placeholder.swift`
- Modify: `Tests/D2ManagerTests/SmokeTest.swift` (remove the placeholder reference)

> Views are built in Tasks 13–15. This task wires a minimal `MenuBarExtra` that lists instances, so the app runs end-to-end early. It is verified by building + a manual launch, not unit tests (SwiftUI scene code isn't unit-tested here).

- [ ] **Step 1: Replace the smoke test so it no longer references the placeholder**

`Tests/D2ManagerTests/SmokeTest.swift`:

```swift
import Testing
@testable import D2Manager

@Test func enumsAreWired() {
    #expect(JobStatus.succeeded.isTerminal)
}
```

- [ ] **Step 2: Delete the placeholder**

Run: `rm Sources/D2Manager/Placeholder.swift`

- [ ] **Step 3: Add a live AppModel factory to `AppModel.swift`**

Append to `Sources/D2Manager/State/AppModel.swift`:

```swift
extension AppModel {
    /// Build an AppModel from persisted settings + the resolved admin token.
    static func live(defaults: UserDefaults = .standard) -> AppModel {
        let settings = Settings.load(from: defaults)
        let token = try? TokenResolver().resolve(settings: settings)
        let client = BrokerClient(baseURL: settings.baseURL, token: token)
        let poller = JobPoller(client: client)
        return AppModel(client: client, poller: poller)
    }
}
```

- [ ] **Step 4: Implement the app entry point**

`Sources/D2Manager/App.swift`:

```swift
import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar only — no Dock icon, no main window.
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct D2ManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel.live()

    var body: some Scene {
        MenuBarExtra("DHIS2", systemImage: model.isBusy ? "shippingbox.circle.fill" : "shippingbox") {
            MenuContentView()
                .environment(model)
                .frame(width: 360)
        }
        .menuBarExtraStyle(.window)
    }
}
```

- [ ] **Step 5: Add a temporary minimal MenuContentView so the app compiles and runs**

`Sources/D2Manager/Views/MenuContentView.swift` (replaced fully in Task 13):

```swift
import SwiftUI

struct MenuContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DHIS2 Instances").font(.headline)
            if let error = model.lastError {
                Text(error).font(.caption).foregroundStyle(.red)
            }
            ForEach(model.instances) { instance in
                Text("\(instance.name) — \(instance.status.rawValue)")
            }
            Divider()
            Button("Refresh") { Task { await model.refresh() } }
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .padding(12)
        .task { await model.refresh() }
    }
}
```

- [ ] **Step 6: Build and run manually**

Run: `swift build` → expected: builds.
Run: `swift run` → expected: a menu bar icon appears (top-right). Click it; if `d2-broker` is running and a token resolves, instances list. If not, the error line shows the broker message. Verify, then quit via the menu.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: wire MenuBarExtra app entry point with live AppModel"
```

---

## Task 13: Instance list UI (rows, status pills, actions)

**Files:**
- Create: `Sources/D2Manager/Views/InstanceRowView.swift`
- Create: `Sources/D2Manager/Views/ActiveOperationView.swift`
- Modify: `Sources/D2Manager/Views/MenuContentView.swift`

> UI tasks are verified by build + manual interaction (no unit tests for SwiftUI views — logic lives in the tested AppModel).

- [ ] **Step 1: Implement the active-operation banner**

`Sources/D2Manager/Views/ActiveOperationView.swift`:

```swift
import SwiftUI

struct ActiveOperationView: View {
    let job: Job

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("\(job.op.rawValue.capitalized) \(job.instance)…")
                    .font(.subheadline).bold()
            }
            if let tail = job.logTail, !tail.isEmpty {
                Text(tail)
                    .font(.system(.caption2, design: .monospaced))
                    .lineLimit(3)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
}
```

- [ ] **Step 2: Implement the instance row**

`Sources/D2Manager/Views/InstanceRowView.swift`:

```swift
import SwiftUI

struct InstanceRowView: View {
    let instance: Instance
    let isBusy: Bool
    let onStart: () -> Void
    let onStop: () -> Void
    let onReset: () -> Void
    let onDelete: () -> Void

    private var pillColor: Color {
        switch instance.status {
        case .running: return .green
        case .partial: return .orange
        case .stopped: return .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle().fill(pillColor).frame(width: 8, height: 8)
                Text(instance.name).bold()
                if instance.agentManaged {
                    Text("agent").font(.caption2).padding(.horizontal, 4)
                        .background(.tertiary, in: Capsule())
                }
                if let v = instance.dhis2MajorVersion {
                    Text("v\(v)").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                if let urlString = instance.localhostUrl, let url = URL(string: urlString) {
                    Link(destination: url) { Image(systemName: "safari") }
                        .help("Open \(urlString)")
                }
            }
            HStack(spacing: 8) {
                if instance.status == .stopped {
                    Button("Start", action: onStart)
                } else {
                    Button("Stop", action: onStop)
                }
                Button("Reset", action: onReset)
                Button("Delete", role: .destructive, action: onDelete)
            }
            .controlSize(.small)
            .disabled(isBusy)
        }
        .padding(.vertical, 4)
    }
}
```

- [ ] **Step 3: Rebuild MenuContentView to use the row + banner**

Replace `Sources/D2Manager/Views/MenuContentView.swift`:

```swift
import SwiftUI

struct MenuContentView: View {
    @Environment(AppModel.self) private var model
    @State private var resetTarget: Instance?
    @State private var deleteTarget: Instance?
    @State private var showCreate = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if let job = model.activeJob {
                ActiveOperationView(job: job)
            }
            if let error = model.lastError, model.activeJob == nil {
                Text(error).font(.caption).foregroundStyle(.red)
            }
            if model.instances.isEmpty {
                Text("No instances.").font(.caption).foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(model.instances) { instance in
                            InstanceRowView(
                                instance: instance,
                                isBusy: model.isBusy,
                                onStart: { Task { await model.start(name: instance.name) } },
                                onStop: { Task { await model.stop(name: instance.name) } },
                                onReset: { resetTarget = instance },
                                onDelete: { deleteTarget = instance }
                            )
                            Divider()
                        }
                    }
                }
                .frame(maxHeight: 320)
            }
            footer
        }
        .padding(12)
        .task { await model.refresh() }
        .sheet(isPresented: $showCreate) { CreateInstanceView() }
        .sheet(item: $resetTarget) { ResetView(instance: $0) }
        .confirmationDialog(
            "Delete \(deleteTarget?.name ?? "")? This is irreversible.",
            isPresented: Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } }),
            presenting: deleteTarget
        ) { instance in
            Button("Delete \(instance.name)", role: .destructive) {
                Task { await model.delete(name: instance.name) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var header: some View {
        HStack {
            Text("DHIS2 Instances").font(.headline)
            Spacer()
            Button { Task { await model.refresh() } } label: { Image(systemName: "arrow.clockwise") }
                .buttonStyle(.plain)
                .disabled(model.isBusy)
        }
    }

    private var footer: some View {
        HStack {
            Button("New instance…") { showCreate = true }.disabled(model.isBusy)
            Spacer()
            Button("Settings") { openSettings() }
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .controlSize(.small)
    }

    private func openSettings() {
        SettingsWindow.shared.show(model: model)
    }
}
```

> `CreateInstanceView`, `ResetView`, and `SettingsWindow` are added in Tasks 14–15. Until then, comment out the `.sheet`/`openSettings` references if you want to build mid-task; otherwise implement Tasks 14–15 before building this one. To keep tasks independently buildable, **implement Task 14 and 15 in the same session before running `swift build` for Task 13**, or temporarily stub them.

- [ ] **Step 4: Build (after Tasks 14–15 stubs exist) and manually verify**

Run: `swift build` → expected: builds once Tasks 14–15 types exist.
Manual: launch with `swift run`, confirm rows show status colors, Start/Stop trigger jobs (banner appears, then list refreshes), agent badge shows for `agent-*`.

- [ ] **Step 5: Commit**

```bash
git add Sources/D2Manager/Views
git commit -m "feat: instance list UI with status pills, actions, active-op banner"
```

---

## Task 14: Create + Reset + JobLog views

**Files:**
- Create: `Sources/D2Manager/Views/CreateInstanceView.swift`
- Create: `Sources/D2Manager/Views/ResetView.swift`
- Create: `Sources/D2Manager/Views/JobLogView.swift`

- [ ] **Step 1: Implement the Create form**

`Sources/D2Manager/Views/CreateInstanceView.swift`:

```swift
import SwiftUI

struct CreateInstanceView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var version = ""
    @State private var selectedSeed: String = ""   // "" = no seed
    @State private var tomcat = "10"
    @State private var showAdvanced = false
    @State private var warUrl = ""
    @State private var warFile = ""

    private let namePattern = #"^[a-z][a-z0-9_-]{1,29}$"#

    private var nameValid: Bool {
        name.range(of: namePattern, options: .regularExpression) != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New instance").font(.headline)

            TextField("name (lower-case, 2–30 chars)", text: $name)
            if !name.isEmpty && !nameValid {
                Text("Must match ^[a-z][a-z0-9_-]{1,29}$")
                    .font(.caption).foregroundStyle(.red)
            }

            TextField("version (e.g. 42, 2.42, 2.42.4 — blank = latest)", text: $version)

            Picker("Seed", selection: $selectedSeed) {
                Text("No seed (empty database)").tag("")
                ForEach(model.seeds) { seed in
                    Text(seed.path).tag(seed.path)
                }
            }

            Picker("Tomcat", selection: $tomcat) {
                Text("10").tag("10")
                Text("9").tag("9")
            }.pickerStyle(.segmented)

            DisclosureGroup("Advanced", isExpanded: $showAdvanced) {
                TextField("war_url (https://…)", text: $warUrl)
                TextField("war_file (/abs/path.war)", text: $warFile)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Create") {
                    Task {
                        await model.create(makeRequest())
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!nameValid)
            }
        }
        .padding(16)
        .frame(width: 380)
        .task { await model.loadSeeds() }
    }

    private func makeRequest() -> CreateInstanceRequest {
        CreateInstanceRequest(
            name: name,
            version: version.isEmpty ? nil : version,
            seed: selectedSeed.isEmpty ? nil : selectedSeed,
            tomcat: tomcat,
            warUrl: warUrl.isEmpty ? nil : warUrl,
            warFile: warFile.isEmpty ? nil : warFile
        )
    }
}
```

- [ ] **Step 2: Implement the Reset seed-picker**

`Sources/D2Manager/Views/ResetView.swift`:

```swift
import SwiftUI

struct ResetView: View {
    let instance: Instance
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSeed: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reset \(instance.name)").font(.headline)
            Text("Restores the database from a seed. Existing data is replaced.")
                .font(.caption).foregroundStyle(.secondary)

            Picker("Seed", selection: $selectedSeed) {
                Text("Choose a seed…").tag("")
                ForEach(model.seeds) { seed in
                    Text(seed.path).tag(seed.path)
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Reset", role: .destructive) {
                    Task {
                        await model.reset(name: instance.name, seed: selectedSeed)
                        dismiss()
                    }
                }
                .disabled(selectedSeed.isEmpty)
            }
        }
        .padding(16)
        .frame(width: 360)
        .task { await model.loadSeeds() }
    }
}
```

- [ ] **Step 3: Implement the full-log viewer**

`Sources/D2Manager/Views/JobLogView.swift`:

```swift
import SwiftUI

struct JobLogView: View {
    let jobID: String
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var log = "Loading…"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Log — \(jobID)").font(.headline)
            ScrollView {
                Text(log)
                    .font(.system(.caption2, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack { Spacer(); Button("Close") { dismiss() } }
        }
        .padding(16)
        .frame(width: 520, height: 360)
        .task { log = await model.fullLog(for: jobID) }
    }
}
```

- [ ] **Step 4: Build**

Run: `swift build`
Expected: builds (these views only depend on AppModel + models). Note: `SettingsWindow` referenced by Task 13 is added in Task 15 — build the whole set together at the end of Task 15.

- [ ] **Step 5: Commit**

```bash
git add Sources/D2Manager/Views/CreateInstanceView.swift Sources/D2Manager/Views/ResetView.swift Sources/D2Manager/Views/JobLogView.swift
git commit -m "feat: add create, reset, and job-log views"
```

---

## Task 15: Settings view + recent activity, final wiring

**Files:**
- Create: `Sources/D2Manager/Views/SettingsView.swift`
- Modify: `Sources/D2Manager/State/AppModel.swift` (expose settings editing + connection test)
- Modify: `Sources/D2Manager/Views/MenuContentView.swift` (recent activity + log sheet)

- [ ] **Step 1: Add settings handling to AppModel**

Append to `Sources/D2Manager/State/AppModel.swift`:

```swift
extension AppModel {
    /// Persist new settings, rebuild nothing yet — caller restarts/recreates the
    /// live model on next launch. For an in-session apply, the app recreates AppModel.
    @MainActor
    func testConnection(baseURL: URL, dhis2BasePath: String?, tokenOverride: String?) async -> String {
        var settings = Settings()
        settings.baseURL = baseURL
        settings.dhis2BasePath = dhis2BasePath?.isEmpty == true ? nil : dhis2BasePath
        settings.tokenOverride = tokenOverride?.isEmpty == true ? nil : tokenOverride
        let token = try? TokenResolver().resolve(settings: settings)
        let probe = BrokerClient(baseURL: baseURL, token: token)
        guard await probe.health() else { return "No broker at \(baseURL.absoluteString)." }
        if token == nil { return "Broker is up, but no admin token resolved." }
        do {
            _ = try await probe.instances(full: false)
            return "Connected. Token works."
        } catch {
            return (error as? BrokerError)?.userMessage ?? error.localizedDescription
        }
    }

    func persist(settings: Settings, to defaults: UserDefaults = .standard) {
        settings.save(to: defaults)
    }
}
```

- [ ] **Step 2: Implement SettingsView and a small window host**

`Sources/D2Manager/Views/SettingsView.swift`:

```swift
import SwiftUI
import AppKit

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var baseURLString = Settings.load(from: .standard).baseURL.absoluteString
    @State private var dhis2BasePath = Settings.load(from: .standard).dhis2BasePath ?? ""
    @State private var tokenOverride = Settings.load(from: .standard).tokenOverride ?? ""
    @State private var testResult = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings").font(.headline)
            Form {
                TextField("Broker base URL", text: $baseURLString)
                TextField("DHIS2_BASE path (for tokens.json)", text: $dhis2BasePath)
                SecureField("Admin token override (optional)", text: $tokenOverride)
            }
            HStack {
                Button("Test connection") {
                    Task {
                        guard let url = URL(string: baseURLString) else { testResult = "Invalid URL."; return }
                        testResult = await model.testConnection(
                            baseURL: url, dhis2BasePath: dhis2BasePath, tokenOverride: tokenOverride)
                    }
                }
                Text(testResult).font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                Button("Save") { save() }.keyboardShortcut(.defaultAction)
            }
            Text("Changes apply after relaunch.").font(.caption2).foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 420)
    }

    private func save() {
        var settings = Settings()
        if let url = URL(string: baseURLString) { settings.baseURL = url }
        settings.dhis2BasePath = dhis2BasePath.isEmpty ? nil : dhis2BasePath
        settings.tokenOverride = tokenOverride.isEmpty ? nil : tokenOverride
        model.persist(settings: settings)
    }
}

/// Hosts SettingsView in a standalone NSWindow (MenuBarExtra popovers can't push
/// a separate Settings scene cleanly in an accessory app).
@MainActor
final class SettingsWindow {
    static let shared = SettingsWindow()
    private var window: NSWindow?

    func show(model: AppModel) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let hosting = NSHostingController(rootView: SettingsView().environment(model))
        let window = NSWindow(contentViewController: hosting)
        window.title = "D2 Manager Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        self.window = window
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
```

- [ ] **Step 3: Add recent-activity + log sheet to MenuContentView**

In `Sources/D2Manager/Views/MenuContentView.swift`, add state and a section. Add near the other `@State`:

```swift
    @State private var logJobID: String?
```

Insert this section into the `VStack`, just above `footer`:

```swift
            if !model.recentJobs.isEmpty {
                Divider()
                Text("Recent activity").font(.caption).foregroundStyle(.secondary)
                ForEach(model.recentJobs.prefix(5)) { job in
                    HStack {
                        Image(systemName: job.status == .succeeded ? "checkmark.circle" : "exclamationmark.triangle")
                            .foregroundStyle(job.status == .succeeded ? .green : .red)
                        Text("\(job.op.rawValue.capitalized) \(job.instance)")
                            .font(.caption)
                        Spacer()
                        if job.status != .succeeded {
                            Button("Log") { logJobID = job.id }
                                .controlSize(.mini)
                        }
                    }
                }
            }
```

Add this modifier alongside the other `.sheet`s:

```swift
        .sheet(item: Binding(get: { logJobID.map { LogID(id: $0) } },
                             set: { logJobID = $0?.id })) { wrapper in
            JobLogView(jobID: wrapper.id)
        }
```

And add this small Identifiable wrapper at file scope (bottom of `MenuContentView.swift`):

```swift
private struct LogID: Identifiable { let id: String }
```

- [ ] **Step 4: Build the whole app and run**

Run: `swift build` → expected: builds, all view references resolved.
Run: `swift test` → expected: all unit tests still pass.
Run: `swift run` → manual end-to-end:
  - List shows instances; Start/Stop/Reset/Delete work with the banner + refresh.
  - "New instance…" creates one (watch the banner, then it appears in the list).
  - Failed jobs show in Recent activity with a working "Log" button.
  - Settings window opens, "Test connection" reports status, Save persists.

- [ ] **Step 5: Commit**

```bash
git add Sources/D2Manager
git commit -m "feat: add settings window, connection test, and recent-activity feed"
```

---

## Task 16: Optional .app bundling script

**Files:**
- Create: `make-app.sh`

- [ ] **Step 1: Write the bundling script**

`make-app.sh`:

```bash
#!/usr/bin/env bash
# Build a release binary and assemble a minimal D2Manager.app bundle (LSUIElement).
set -euo pipefail

APP_NAME="D2Manager"
BUILD_DIR=".build/release"
APP_DIR="$APP_NAME.app/Contents"

swift build -c release

rm -rf "$APP_NAME.app"
mkdir -p "$APP_DIR/MacOS" "$APP_DIR/Resources"
cp "$BUILD_DIR/$APP_NAME" "$APP_DIR/MacOS/$APP_NAME"

cat > "$APP_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>org.dhis2.d2manager</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

echo "Built $APP_NAME.app — move it to /Applications or add to Login Items."
```

- [ ] **Step 2: Make it executable and run it**

Run: `chmod +x make-app.sh && ./make-app.sh`
Expected: produces `D2Manager.app`. Double-click it; the menu bar icon appears with no Dock icon.

- [ ] **Step 3: Commit**

```bash
git add make-app.sh
git commit -m "chore: add optional .app bundling script"
```

---

## Self-review notes (addressed)

- **Spec coverage:** every spec section maps to a task — models (T2–T5), `BrokerClient` GET+mutations (T7–T8), `JobPoller` (T9), `Settings`+`TokenResolver` (T10), `AppModel` (T11), full UI incl. create/reset/delete/log/settings/recent-activity (T12–T15), `.accessory`/no-Dock + optional bundle (T12, T16), error handling verbatim + 401/409/transport hints (T5, T11), TDD across all logic layers.
- **Type consistency:** property names use the `.convertFromSnakeCase` forms (`localhostUrl`, `devnetUrl`, `devnetDb`, `dhis2MajorVersion`, `logTail`) consistently across models, fixtures, and views. `BrokerClientProtocol` signatures match `BrokerClient`, `FakeBrokerClient`, and `AppModel` call sites.
- **Build-order caveat:** Task 13's `MenuContentView` references types from Tasks 14–15 (`CreateInstanceView`, `ResetView`, `SettingsWindow`, `JobLogView`). Implement Tasks 13–15 together (or stub the referenced types) before running `swift build` for Task 13 — this is called out inline in Task 13.
- **No real sleeps in tests:** `JobPoller` and `AppModel` take an injected `sleep`/zero-interval poller in tests.
```
