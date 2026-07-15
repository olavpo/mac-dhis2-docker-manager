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
        #expect(try decodeRaw(JobOp.self, "\"backup\"") == .backup)
        #expect(try decodeRaw(JobOp.self, "\"upgrade\"") == .upgrade)
        #expect(try decodeRaw(JobOp.self, "\"memory\"") == .memory)
    }

    @Test func upgradeRequestOmitsNilsAndSnakeCases() throws {
        let req = UpgradeRequest(version: "2.42", warUrl: "https://x/y.war", backupFirst: true)
        let obj = try JSONSerialization.jsonObject(
            with: BrokerCoders.encoder.encode(req)) as! [String: Any]
        #expect(obj["version"] as? String == "2.42")
        #expect(obj["war_url"] as? String == "https://x/y.war")
        #expect(obj["backup_first"] as? Bool == true)
        #expect(obj["war_file"] == nil)   // nil omitted
        #expect(obj["tomcat"] == nil)     // nil omitted
    }
}

/// Decodes a JSON fragment that is itself a single value (e.g. a quoted string).
func decodeRaw<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
    let wrapped = "[\(json)]"
    return try JSONDecoder().decode([T].self, from: Data(wrapped.utf8))[0]
}

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
        #expect(i.analytics == "doris")
        #expect(i.dhis2MajorVersion == "42")
        #expect(i.id == "school-ind-test")
    }

    @Test func instanceMinimalDecodes() throws {
        let i = try BrokerCoders.decoder.decode(Instance.self, from: Fixtures.data(Fixtures.instanceMinimalJSON))
        #expect(i.httpPort == nil)
        #expect(i.localhostUrl == nil)
        #expect(i.dhis2MajorVersion == nil)
        #expect(i.analytics == nil)
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

    // A backup job's `result` is a GET /seeds element. It must not fail Job
    // decoding (which would break the whole jobs list and job polling) — the
    // non-instance result decodes leniently to nil.
    @Test func backupJobWithSeedResultDecodes() throws {
        let j = try BrokerCoders.decoder.decode(Job.self, from: Fixtures.data(Fixtures.jobBackupSucceededJSON))
        #expect(j.op == .backup)
        #expect(j.status == .succeeded)
        #expect(j.result == nil)
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
        #expect(obj["memory"] == nil)      // nil omitted
        #expect(obj["analytics"] == nil)   // nil omitted
    }

    @Test func createRequestEncodesNewOptions() throws {
        let req = CreateInstanceRequest(
            name: "demo1", version: "42", memory: "2g",
            httpPort: 9010, pgPort: 5433, analytics: "doris")
        let obj = try JSONSerialization.jsonObject(
            with: BrokerCoders.encoder.encode(req)) as! [String: Any]
        #expect(obj["memory"] as? String == "2g")
        #expect(obj["http_port"] as? Int == 9010)
        #expect(obj["pg_port"] as? Int == 5433)
        #expect(obj["analytics"] as? String == "doris")
    }
}
