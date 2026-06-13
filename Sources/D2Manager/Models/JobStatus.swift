enum JobStatus: String, Codable, Sendable {
    case queued, running, succeeded, failed, interrupted

    var isTerminal: Bool {
        switch self {
        case .succeeded, .failed, .interrupted: return true
        case .queued, .running: return false
        }
    }
}
