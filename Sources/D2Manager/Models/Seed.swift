struct Seed: Codable, Sendable, Identifiable, Equatable {
    var path: String
    var source: SeedSource
    var sizeBytes: Int
    var modified: String
    /// DHIS2 major from the `_vNN` filename token; nil if absent.
    var dhis2Version: Int?
    /// Hand-written sidecar (`<file>.json`); nil if absent.
    var notes: SeedNotes?

    var id: String { path }
}

extension Seed {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        path = try c.decode(String.self, forKey: .path)
        source = try c.decode(SeedSource.self, forKey: .source)
        sizeBytes = try c.decode(Int.self, forKey: .sizeBytes)
        modified = try c.decode(String.self, forKey: .modified)
        dhis2Version = try? c.decodeIfPresent(Int.self, forKey: .dhis2Version)
        // The sidecar is hand-written and returned as-is; a malformed one must
        // not fail the whole seeds list.
        notes = try? c.decodeIfPresent(SeedNotes.self, forKey: .notes)
    }
}

/// Conventional keys of a seed's notes sidecar. All optional.
struct SeedNotes: Codable, Sendable, Equatable {
    var description: String?
    var dataUntil: String?
    var adminUser: String?
    var analyticsOk: Bool?
    var knownIssues: [String]?

    init(description: String? = nil, dataUntil: String? = nil, adminUser: String? = nil,
         analyticsOk: Bool? = nil, knownIssues: [String]? = nil) {
        self.description = description
        self.dataUntil = dataUntil
        self.adminUser = adminUser
        self.analyticsOk = analyticsOk
        self.knownIssues = knownIssues
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        description = try? c.decodeIfPresent(String.self, forKey: .description)
        dataUntil = try? c.decodeIfPresent(String.self, forKey: .dataUntil)
        adminUser = try? c.decodeIfPresent(String.self, forKey: .adminUser)
        analyticsOk = try? c.decodeIfPresent(Bool.self, forKey: .analyticsOk)
        knownIssues = try? c.decodeIfPresent([String].self, forKey: .knownIssues)
    }
}
