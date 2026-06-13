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
