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
}
