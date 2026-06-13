import Foundation

struct Settings: Equatable, Sendable {
    var baseURL: URL = URL(string: "http://localhost:9300")!
    var dhis2BasePath: String?
    var tokenOverride: String?

    private enum Key {
        static let baseURL = "baseURL"
        static let dhis2BasePath = "dhis2BasePath"
        static let tokenOverride = "tokenOverride"
    }

    func save(to defaults: UserDefaults) {
        defaults.set(baseURL.absoluteString, forKey: Key.baseURL)
        defaults.set(dhis2BasePath, forKey: Key.dhis2BasePath)
        defaults.set(tokenOverride, forKey: Key.tokenOverride)
    }

    static func load(from defaults: UserDefaults) -> Settings {
        var s = Settings()
        if let raw = defaults.string(forKey: Key.baseURL), let url = URL(string: raw) {
            s.baseURL = url
        }
        s.dhis2BasePath = defaults.string(forKey: Key.dhis2BasePath)
        s.tokenOverride = defaults.string(forKey: Key.tokenOverride)
        return s
    }
}
