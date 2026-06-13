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
