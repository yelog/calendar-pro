import XCTest
@testable import CalendarPro

@MainActor
final class UpdateCheckerTests: XCTestCase {
    func testSelectedUpdateChannelDefaultsToStableForStableVersion() {
        let userDefaults = makeIsolatedUserDefaults(name: #function)

        XCTAssertEqual(
            UpdateChecker.selectedUpdateChannel(userDefaults: userDefaults, bundleVersion: "0.1.0"),
            .stable
        )
    }

    func testSelectedUpdateChannelDefaultsToStableForBetaVersion() {
        let userDefaults = makeIsolatedUserDefaults(name: #function)

        XCTAssertEqual(
            UpdateChecker.selectedUpdateChannel(userDefaults: userDefaults, bundleVersion: "0.1.1-beta.1"),
            .stable
        )
    }

    func testSelectedUpdateChannelPrefersStoredStableOverride() {
        let userDefaults = makeIsolatedUserDefaults(name: #function)
        userDefaults.set(UpdateChannel.stable.rawValue, forKey: UpdateChecker.updateChannelDefaultsKey)

        XCTAssertEqual(
            UpdateChecker.selectedUpdateChannel(userDefaults: userDefaults, bundleVersion: "0.1.1-beta.1"),
            .stable
        )
    }

    func testSelectedUpdateChannelPrefersStoredBetaOverride() {
        let userDefaults = makeIsolatedUserDefaults(name: #function)
        userDefaults.set(UpdateChannel.beta.rawValue, forKey: UpdateChecker.updateChannelDefaultsKey)

        XCTAssertEqual(
            UpdateChecker.selectedUpdateChannel(userDefaults: userDefaults, bundleVersion: "0.1.0"),
            .beta
        )
    }

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

    private func makeIsolatedUserDefaults(name: String) -> UserDefaults {
        let userDefaults = UserDefaults(suiteName: name)!
        userDefaults.removePersistentDomain(forName: name)
        return userDefaults
    }
}
