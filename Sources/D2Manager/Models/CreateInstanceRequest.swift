struct CreateInstanceRequest: Codable, Sendable, Equatable {
    var name: String
    var version: String?
    var seed: String?
    var tomcat: String?
    var warUrl: String?
    var warFile: String?

    init(
        name: String,
        version: String? = nil,
        seed: String? = nil,
        tomcat: String? = nil,
        warUrl: String? = nil,
        warFile: String? = nil
    ) {
        self.name = name
        self.version = version
        self.seed = seed
        self.tomcat = tomcat
        self.warUrl = warUrl
        self.warFile = warFile
    }
}
