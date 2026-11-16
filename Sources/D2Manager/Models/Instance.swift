struct Instance: Codable, Sendable, Identifiable, Equatable {
    var name: String
    var status: InstanceStatus
    var httpPort: Int?
    var pgPort: Int?
    var localhostUrl: String?
    var devnetUrl: String?
    var devnetDb: String?
    var agentManaged: Bool
    /// `"doris"` if the instance was created with a dedicated analytics DB.
    var analytics: String?
    /// Free-text label passed on create; nil if none.
    var label: String?
    /// IANA time zone passed on create; nil means the default, Etc/UTC.
    var timezone: String?
    var createdAt: String?
    var dhis2MajorVersion: String?
    /// `deploying` / `migrating` / `ready`. Only present with `full=1`, and
    /// nil when the instance isn't running.
    var readiness: String?

    var id: String { name }
}
