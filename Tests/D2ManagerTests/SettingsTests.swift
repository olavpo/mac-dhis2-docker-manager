import Testing
import Foundation
@testable import D2Manager

@Suite struct SettingsTests {
    @Test func defaultsAreSensible() {
        let s = Settings()
        #expect(s.baseURL == URL(string: "http://localhost:9300")!)
        #expect(s.dhis2BasePath == nil)
        #expect(s.tokenOverride == nil)
    }

    @Test func roundTripsThroughUserDefaults() {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        var s = Settings()
        s.baseURL = URL(string: "http://localhost:9999")!
        s.dhis2BasePath = "/Users/x/dhis2"
        s.tokenOverride = "abc"
        s.save(to: defaults)

        let loaded = Settings.load(from: defaults)
        #expect(loaded.baseURL == URL(string: "http://localhost:9999")!)
        #expect(loaded.dhis2BasePath == "/Users/x/dhis2")
        #expect(loaded.tokenOverride == "abc")
    }
}
