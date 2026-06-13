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

    @Test func successfulJobButFailedRefreshSurfacesRefreshError() async {
        let fake = FakeBrokerClient()
        fake.mutationResult = TestJobs.job(op: .start, status: .queued)
        fake.jobScript = [TestJobs.job(op: .start, status: .succeeded)]
        fake.instancesError = .transport("refresh failed")
        let model = makeModel(fake)

        await model.start(name: "demo1")

        #expect(model.activeJob == nil)
        #expect(model.recentJobs.first?.status == .succeeded)
        #expect(model.lastError != nil)        // refresh error is NOT swallowed
    }

    @Test func mutationErrorIsCaught() async {
        let fake = FakeBrokerClient()
        fake.error = .http(status: 409, message: "busy")
        let model = makeModel(fake)
        await model.stop(name: "demo1")
        #expect(model.activeJob == nil)
        #expect(model.lastError != nil)
    }

    @Test func refreshVersionsPopulatesBadgesAndCachePersistsAcrossLightRefresh() async {
        let fake = FakeBrokerClient()
        fake.instancesResult = [TestInstances.running]   // dhis2MajorVersion == nil
        var withVersion = TestInstances.running
        withVersion.dhis2MajorVersion = "42"
        fake.instancesFullResult = [withVersion]
        let model = makeModel(fake)

        await model.refresh()
        #expect(model.instances.first?.dhis2MajorVersion == nil)

        await model.refreshVersions()
        #expect(model.instances.first?.dhis2MajorVersion == "42")

        await model.refresh()   // light refresh, full=0
        #expect(model.instances.first?.dhis2MajorVersion == "42")   // from cache
    }

    @Test func refreshVersionsFailsQuietly() async {
        let fake = FakeBrokerClient()
        fake.instancesResult = [TestInstances.running]
        fake.instancesFullError = .transport("x")   // only full=1 throws
        let model = makeModel(fake)

        await model.refresh()
        await model.refreshVersions()
        #expect(model.lastError == nil)
    }

    @Test func loadRecentJobsPopulatesFromClient() async {
        let fake = FakeBrokerClient()
        let jobs = [TestJobs.job(id: "j-a", status: .succeeded),
                    TestJobs.job(id: "j-b", status: .failed)]
        fake.jobsResult = jobs
        let model = makeModel(fake)

        await model.loadRecentJobs()
        #expect(model.recentJobs == jobs)
    }

    @Test func runDedupesRecentJobsById() async {
        let fake = FakeBrokerClient()
        fake.jobsResult = [TestJobs.job(id: "j-1", op: .start, status: .succeeded)]
        fake.mutationResult = TestJobs.job(id: "j-1", op: .start, status: .queued)
        fake.jobScript = [TestJobs.job(id: "j-1", op: .start, status: .succeeded)]
        fake.instancesResult = [TestInstances.running]
        let model = makeModel(fake)

        await model.loadRecentJobs()
        await model.start(name: "demo1")

        #expect(model.recentJobs.filter { $0.id == "j-1" }.count == 1)
    }
}

enum TestInstances {
    static let running = Instance(
        name: "demo1", status: .running, httpPort: 9010, pgPort: 5433,
        localhostUrl: "http://localhost:9010", devnetUrl: nil, devnetDb: nil,
        agentManaged: false, dhis2MajorVersion: nil
    )
}
