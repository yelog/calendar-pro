import XCTest
@testable import CalendarPro

@MainActor
final class UpdateCheckerTests: XCTestCase {
    func testAppcastFeedURLStringUsesStableChannelForStableVersion() {
        XCTAssertEqual(
            UpdateChecker.appcastFeedURLString(forVersion: "0.1.0"),
            UpdateChecker.stableFeedURLString
        )
    }

    func testAppcastFeedURLStringUsesBetaChannelForBetaVersion() {
        XCTAssertEqual(
            UpdateChecker.appcastFeedURLString(forVersion: "0.1.1-beta.1"),
            UpdateChecker.betaFeedURLString
        )
    }

    func testAppcastFeedURLStringUsesBetaChannelForReleaseCandidateVersion() {
        XCTAssertEqual(
            UpdateChecker.appcastFeedURLString(forVersion: "0.1.1-rc.2"),
            UpdateChecker.betaFeedURLString
        )
    }
}
