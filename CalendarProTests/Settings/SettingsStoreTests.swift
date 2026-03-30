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

    func testSetShowEvents() {
        let userDefaults = makeIsolatedUserDefaults()
        let store = SettingsStore(userDefaults: userDefaults)
        store.setShowEvents(false)
        XCTAssertFalse(store.menuBarPreferences.showEvents)

        store.setShowEvents(true)
        XCTAssertTrue(store.menuBarPreferences.showEvents)
    }

    func testSetCalendarEnabled() {
        let userDefaults = makeIsolatedUserDefaults()
        let store = SettingsStore(userDefaults: userDefaults)
        store.setCalendarEnabled(true, calendarID: "calendar-1")
        XCTAssertTrue(store.menuBarPreferences.enabledCalendarIDs.contains("calendar-1"))

        store.setCalendarEnabled(false, calendarID: "calendar-1")
        XCTAssertFalse(store.menuBarPreferences.enabledCalendarIDs.contains("calendar-1"))
    }

    func testTokenStylePersistsForChineseFormats() {
        let suiteName = #function
        let userDefaults = makeIsolatedUserDefaults(name: suiteName)
        let store = SettingsStore(userDefaults: userDefaults)

        store.setTokenStyle(.chineseMonthDay, for: .date)
        store.setTokenStyle(.chineseWeekday, for: .weekday)

        let reloaded = SettingsStore(userDefaults: userDefaults)
        XCTAssertEqual(reloaded.menuBarPreferences.tokens.first(where: { $0.token == .date })?.style, .chineseMonthDay)
        XCTAssertEqual(reloaded.menuBarPreferences.tokens.first(where: { $0.token == .weekday })?.style, .chineseWeekday)
    }

    private func makeIsolatedUserDefaults(name: String = #function) -> UserDefaults {
        let userDefaults = UserDefaults(suiteName: name)!
        userDefaults.removePersistentDomain(forName: name)
        return userDefaults
    }
}
