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

    /// Cache of major versions keyed by instance name, populated by the expensive
    /// `full=1` fetch (`refreshVersions`) and merged into light refreshes so the
    /// version badge stays populated without re-querying flyway every refresh.
    private var versionsByName: [String: String] = [:]

    init(client: BrokerClientProtocol, poller: JobPoller) {
        self.client = client
        self.poller = poller
    }

    var isBusy: Bool { activeJob != nil }

    // MARK: Reads

    func refresh() async {
        do {
            let fetched = try await client.instances(full: false)
            instances = merging(versions: versionsByName, into: fetched)
            lastError = nil
        } catch is CancellationError {
            // Request abandoned (view task torn down) — keep current state, no error.
        } catch {
            lastError = message(for: error)
        }
    }

    /// Expensive `full=1` fetch (queries flyway on each running DB) used only to
    /// enrich version badges. Caches discovered versions and re-applies them to the
    /// current list. Best-effort: failures are swallowed (no `lastError`).
    func refreshVersions() async {
        guard let full = try? await client.instances(full: true) else { return }
        for instance in full where instance.dhis2MajorVersion != nil {
            versionsByName[instance.name] = instance.dhis2MajorVersion
        }
        instances = merging(versions: versionsByName, into: instances)
    }

    /// Light list refresh plus a version enrichment pass.
    func refreshAll() async {
        await refresh()
        await refreshVersions()
    }

    /// Seed "Recent activity" from the broker's job history. Best-effort: keeps the
    /// existing list on error.
    func loadRecentJobs() async {
        recentJobs = (try? await client.jobs()) ?? recentJobs
    }

    /// Fill in `dhis2MajorVersion` from the cache for any instance still missing it.
    private func merging(versions: [String: String], into list: [Instance]) -> [Instance] {
        list.map { instance in
            guard instance.dhis2MajorVersion == nil, let version = versions[instance.name]
            else { return instance }
            var copy = instance
            copy.dhis2MajorVersion = version
            return copy
        }
    }

    func loadSeeds() async {
        do { seeds = try await client.seeds() }
        catch is CancellationError { /* abandoned — ignore */ }
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
            // Dedupe by id so a locally-tracked job doesn't duplicate one already
            // seeded from `jobs()` (loadRecentJobs).
            recentJobs.removeAll { $0.id == finalJob.id }
            recentJobs.insert(finalJob, at: 0)
            // Re-list instances (full=0) to reflect the mutation; cached versions
            // are merged back in by refresh(). We deliberately re-list rather than
            // patch from job.result, as the broker list is the source of truth.
            await refresh()  // sets lastError = nil on success, or a message on failure
            // Set the job-failure error only for non-succeeded jobs. On success,
            // refresh has already managed lastError (including a failed refresh).
            if finalJob.status != .succeeded {
                lastError = finalJob.error ?? "Operation \(finalJob.op.rawValue) \(finalJob.status.rawValue)."
            }
        } catch is CancellationError {
            activeJob = nil
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
