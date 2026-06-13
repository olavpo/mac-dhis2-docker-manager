struct Instance: Codable, Sendable, Identifiable, Equatable {
    var name: String
    var status: InstanceStatus
    var httpPort: Int?
    var pgPort: Int?
    var localhostUrl: String?
    var devnetUrl: String?
    var devnetDb: String?
    var agentManaged: Bool
    var dhis2MajorVersion: String?

    var id: String { name }
}
