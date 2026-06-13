struct Seed: Codable, Sendable, Identifiable, Equatable {
    var path: String
    var source: SeedSource
    var sizeBytes: Int
    var modified: String

    var id: String { path }
}
