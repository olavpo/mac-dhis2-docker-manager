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

    private enum CodingKeys: String, CodingKey {
        case id, op, instance, status, createdAt, startedAt, finishedAt
        case exitCode, error, result, logTail
    }
}

extension Job {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        op = try c.decode(JobOp.self, forKey: .op)
        instance = try c.decode(String.self, forKey: .instance)
        status = try c.decode(JobStatus.self, forKey: .status)
        createdAt = try c.decode(String.self, forKey: .createdAt)
        startedAt = try c.decodeIfPresent(String.self, forKey: .startedAt)
        finishedAt = try c.decodeIfPresent(String.self, forKey: .finishedAt)
        exitCode = try c.decodeIfPresent(Int.self, forKey: .exitCode)
        error = try c.decodeIfPresent(String.self, forKey: .error)
        // `result` is a GET /instances element for create/reset/start/upgrade/
        // memory, but a GET /seeds element for backup. Decode leniently so a
        // non-instance shape doesn't fail the whole job (the app re-lists
        // instances after a job instead of patching from `result`).
        result = try? c.decodeIfPresent(Instance.self, forKey: .result)
        logTail = try c.decodeIfPresent(String.self, forKey: .logTail)
    }
}
