import Foundation
@testable import D2Manager

/// Configurable fake. `jobScript` returns successive Job values on each
/// `job(id:)` call (by call index). Other methods return stored values or throw `error`.
final class FakeBrokerClient: BrokerClientProtocol, @unchecked Sendable {
    var jobScript: [Job] = []
    private var jobCallCount = 0

    var instancesResult: [Instance] = []
    var instancesFullResult: [Instance]?
    var seedsResult: [Seed] = []
    var jobsResult: [Job] = []
    var jobLogResult = ""
    var mutationResult: Job?
    var error: BrokerError?
    var instancesError: BrokerError?
    var instancesFullError: BrokerError?
    /// Any error to throw from `instances(full:)` regardless of `full` — used to
    /// simulate a cancelled request (CancellationError).
    var instancesThrowable: Error?

    private(set) var startedNames: [String] = []
    private(set) var stoppedNames: [String] = []
    private(set) var deletedNames: [String] = []
    private(set) var resetCalls: [(String, String)] = []
    private(set) var createRequests: [CreateInstanceRequest] = []

    func health() async -> Bool { error == nil }

    func instances(full: Bool) async throws -> [Instance] {
        if let instancesThrowable { throw instancesThrowable }
        if full, let instancesFullError { throw instancesFullError }
        if let instancesError { throw instancesError }
        if let error { throw error }
        if full, let instancesFullResult { return instancesFullResult }
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
