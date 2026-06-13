import Foundation

struct TokenResolver {
    var environment: [String: String] = ProcessInfo.processInfo.environment
    var fileReader: (URL) throws -> Data = { try Data(contentsOf: $0) }

    /// Resolve the admin token. Precedence: manual override → tokens.json under
    /// `dhis2BasePath` → tokens.json under `$DHIS2_BASE`. Returns nil if none resolve.
    func resolve(settings: Settings) throws -> String? {
        if let override = settings.tokenOverride, !override.isEmpty {
            return override
        }
        guard let base = settings.dhis2BasePath ?? environment["DHIS2_BASE"], !base.isEmpty else {
            return nil
        }
        let url = URL(fileURLWithPath: base)
            .appendingPathComponent("_broker")
            .appendingPathComponent("tokens.json")
        let data = try fileReader(url)
        struct TokensFile: Decodable {
            struct Entry: Decodable { let token: String }
            let admin: Entry
        }
        return try JSONDecoder().decode(TokensFile.self, from: data).admin.token
    }
}
