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
