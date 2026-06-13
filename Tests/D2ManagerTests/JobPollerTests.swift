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
