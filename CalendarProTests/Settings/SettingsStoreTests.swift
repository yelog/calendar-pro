import XCTest
@testable import CalendarPro

@MainActor
final class SettingsStoreTests: XCTestCase {
    func testDefaultMenuBarPreferencesEnableDateTimeAndWeekday() {
        let userDefaults = makeIsolatedUserDefaults()
        let store = SettingsStore(userDefaults: userDefaults)
        let preferences = store.menuBarPreferences

        XCTAssertTrue(preferences.tokens.contains { $0.token == .date && $0.isEnabled })
        XCTAssertTrue(preferences.tokens.contains { $0.token == .time && $0.isEnabled })
        XCTAssertTrue(preferences.tokens.contains { $0.token == .weekday && $0.isEnabled })
    }

    func testSettingsPersistMenuBarPreferences() {
        let suiteName = #function
        let userDefaults = makeIsolatedUserDefaults(name: suiteName)
        let store = SettingsStore(userDefaults: userDefaults)

        store.setTokenEnabled(false, for: .weekday)

        let reloaded = SettingsStore(userDefaults: userDefaults)
        XCTAssertFalse(reloaded.menuBarPreferences.tokens.first(where: { $0.token == .weekday })?.isEnabled ?? true)
    }

    private func makeIsolatedUserDefaults(name: String = #function) -> UserDefaults {
        let userDefaults = UserDefaults(suiteName: name)!
        userDefaults.removePersistentDomain(forName: name)
        return userDefaults
    }
}
