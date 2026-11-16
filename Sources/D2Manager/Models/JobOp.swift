enum JobOp: String, Codable, Sendable {
    case create, reset, start, stop, delete, backup, upgrade, memory, analytics
    case restartDb = "restart-db"
    /// An op this app version doesn't know. The broker adds ops over time; an
    /// unknown one must not fail decoding of the whole jobs list.
    case unknown

    /// Short name for the recent-activity list.
    var title: String {
        switch self {
        case .restartDb: "Restart DB"
        default: rawValue.capitalized
        }
    }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = JobOp(rawValue: raw) ?? .unknown
    }
}
