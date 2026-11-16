struct CreateInstanceRequest: Codable, Sendable, Equatable {
    var name: String
    var version: String?
    var seed: String?
    /// "9" or "10". Leave nil to let the broker auto-select from `version`.
    var tomcat: String?
    /// Tomcat max heap (-Xmx), e.g. "512m", "4g". Broker default: 4g.
    var memory: String?
    /// Host ports; the broker auto-selects free ones when nil.
    var httpPort: Int?
    var pgPort: Int?
    var warUrl: String?
    var warFile: String?
    /// "doris" for a dedicated analytics DB (requires DHIS2 >= 42 or a custom WAR).
    var analytics: String?
    /// IANA time zone, e.g. "Africa/Lagos". Broker default: Etc/UTC.
    var timezone: String?
    /// Extra CORS origins (≤ 20); localhost:3000 and :8080 are always added.
    var corsOrigins: [String]?
    /// Free text (≤ 100 chars), echoed back in GET /instances.
    var label: String?

    init(
        name: String,
        version: String? = nil,
        seed: String? = nil,
        tomcat: String? = nil,
        memory: String? = nil,
        httpPort: Int? = nil,
        pgPort: Int? = nil,
        warUrl: String? = nil,
        warFile: String? = nil,
        analytics: String? = nil,
        timezone: String? = nil,
        corsOrigins: [String]? = nil,
        label: String? = nil
    ) {
        self.name = name
        self.version = version
        self.seed = seed
        self.tomcat = tomcat
        self.memory = memory
        self.httpPort = httpPort
        self.pgPort = pgPort
        self.warUrl = warUrl
        self.warFile = warFile
        self.analytics = analytics
        self.timezone = timezone
        self.corsOrigins = corsOrigins
        self.label = label
    }
}
