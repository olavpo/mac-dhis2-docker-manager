import Testing
@testable import D2Manager

@Test func enumsAreWired() {
    #expect(JobStatus.succeeded.isTerminal)
}
