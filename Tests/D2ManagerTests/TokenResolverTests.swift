import Testing
import Foundation
@testable import D2Manager

@Suite struct TokenResolverTests {
    let tokensJSON = #"{"admin":{"token":"ADMIN123"},"agent":{"token":"AGENT456"}}"#

    @Test func overrideWins() throws {
        var s = Settings(); s.tokenOverride = "OVERRIDE"
        let resolver = TokenResolver(environment: [:], fileReader: { _ in Data() })
        #expect(try resolver.resolve(settings: s) == "OVERRIDE")
    }

    @Test func readsAdminTokenFromConfiguredBasePath() throws {
        var s = Settings(); s.dhis2BasePath = "/base"
        let resolver = TokenResolver(environment: [:], fileReader: { url in
            #expect(url.path == "/base/_broker/tokens.json")
            return Data(self.tokensJSON.utf8)
        })
        #expect(try resolver.resolve(settings: s) == "ADMIN123")
    }

    @Test func fallsBackToEnvironmentDHIS2Base() throws {
        let s = Settings()  // no dhis2BasePath
        let resolver = TokenResolver(environment: ["DHIS2_BASE": "/envbase"], fileReader: { url in
            #expect(url.path == "/envbase/_broker/tokens.json")
            return Data(self.tokensJSON.utf8)
        })
        #expect(try resolver.resolve(settings: s) == "ADMIN123")
    }

    @Test func returnsNilWhenNoSourceAvailable() throws {
        let s = Settings()
        let resolver = TokenResolver(environment: [:], fileReader: { _ in Data() })
        #expect(try resolver.resolve(settings: s) == nil)
    }
}
