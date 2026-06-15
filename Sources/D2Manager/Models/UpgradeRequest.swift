/// Body for `POST /instances/<name>/upgrade`. Exactly one of `version` /
/// `warUrl` / `warFile` must be set; `warUrl`/`warFile` are admin-only.
struct UpgradeRequest: Codable, Sendable, Equatable {
    var version: String?
    var warUrl: String?
    var warFile: String?
    var tomcat: String?
    var backupFirst: Bool?

    init(
        version: String? = nil,
        warUrl: String? = nil,
        warFile: String? = nil,
        tomcat: String? = nil,
        backupFirst: Bool? = nil
    ) {
        self.version = version
        self.warUrl = warUrl
        self.warFile = warFile
        self.tomcat = tomcat
        self.backupFirst = backupFirst
    }
}
