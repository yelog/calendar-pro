import XCTest
@testable import CalendarPro

@MainActor
final class SettingsStoreTests: XCTestCase {
    func testDefaultMenuBarPreferencesEnableDateTimeAndWeekday() {
        let userDefaults = makeIsolatedUserDefaults()
        let store = makeStore(userDefaults: userDefaults)
        let preferences = store.menuBarPreferences

        XCTAssertTrue(preferences.tokens.contains { $0.token == .date && $0.isEnabled })
        XCTAssertTrue(preferences.tokens.contains { $0.token == .time && $0.isEnabled })
        XCTAssertTrue(preferences.tokens.contains { $0.token == .weekday && $0.isEnabled })
    }

    func testSettingsPersistMenuBarPreferences() {
        let suiteName = #function
        let userDefaults = makeIsolatedUserDefaults(name: suiteName)
        let store = makeStore(userDefaults: userDefaults)

        store.setTokenEnabled(false, for: .weekday)

        let reloaded = makeStore(userDefaults: userDefaults)
        XCTAssertFalse(reloaded.menuBarPreferences.tokens.first(where: { $0.token == .weekday })?.isEnabled ?? true)
    }

    func testSetShowEvents() {
        let userDefaults = makeIsolatedUserDefaults()
        let store = makeStore(userDefaults: userDefaults)
        store.setShowEvents(false)
        XCTAssertFalse(store.menuBarPreferences.showEvents)

        store.setShowEvents(true)
        XCTAssertTrue(store.menuBarPreferences.showEvents)
    }

    func testSetShowCalendarEvents() {
        let suiteName = #function
        let userDefaults = makeIsolatedUserDefaults(name: suiteName)
        let store = makeStore(userDefaults: userDefaults)

        store.setShowCalendarEvents(false)
        XCTAssertFalse(store.menuBarPreferences.showCalendarEvents)

        let reloaded = makeStore(userDefaults: userDefaults)
        XCTAssertFalse(reloaded.menuBarPreferences.showCalendarEvents)
    }

    func testSetCalendarEnabled() {
        let userDefaults = makeIsolatedUserDefaults()
        let store = makeStore(userDefaults: userDefaults)
        store.setCalendarEnabled(true, calendarID: "calendar-1")
        XCTAssertTrue(store.menuBarPreferences.enabledCalendarIDs.contains("calendar-1"))

        store.setCalendarEnabled(false, calendarID: "calendar-1")
        XCTAssertFalse(store.menuBarPreferences.enabledCalendarIDs.contains("calendar-1"))
    }

    func testSetCalendarEnabledDisablesSingleCalendarWhenEmptyMeansAllSelected() {
        let userDefaults = makeIsolatedUserDefaults()
        let store = makeStore(userDefaults: userDefaults)

        store.setCalendarEnabled(
            false,
            calendarID: "calendar-2",
            allCalendarIDs: ["calendar-1", "calendar-2", "calendar-3"]
        )

        XCTAssertEqual(store.menuBarPreferences.enabledCalendarIDs, ["calendar-1", "calendar-3"])

        store.setCalendarEnabled(
            true,
            calendarID: "calendar-2",
            allCalendarIDs: ["calendar-1", "calendar-2", "calendar-3"]
        )

        XCTAssertTrue(store.menuBarPreferences.enabledCalendarIDs.isEmpty)
    }

    func testSetShowEventsDoesNotResetEventSourcePreferences() {
        let userDefaults = makeIsolatedUserDefaults()
        let store = makeStore(userDefaults: userDefaults)

        var prefs = store.menuBarPreferences
        prefs.showCalendarEvents = false
        prefs.showReminders = false
        prefs.enabledCalendarIDs = ["calendar-1"]
        prefs.enabledReminderCalendarIDs = ["reminder-1"]
        store.menuBarPreferences = prefs

        store.setShowEvents(false)
        store.setShowEvents(true)

        XCTAssertFalse(store.menuBarPreferences.showCalendarEvents)
        XCTAssertFalse(store.menuBarPreferences.showReminders)
        XCTAssertEqual(store.menuBarPreferences.enabledCalendarIDs, ["calendar-1"])
        XCTAssertEqual(store.menuBarPreferences.enabledReminderCalendarIDs, ["reminder-1"])
    }

    func testSetReminderCalendarEnabledDisablesSingleReminderListWhenEmptyMeansAllSelected() {
        let userDefaults = makeIsolatedUserDefaults()
        let store = makeStore(userDefaults: userDefaults)

        store.setReminderCalendarEnabled(
            false,
            calendarID: "reminder-2",
            allCalendarIDs: ["reminder-1", "reminder-2"]
        )

        XCTAssertEqual(store.menuBarPreferences.enabledReminderCalendarIDs, ["reminder-1"])

        store.setReminderCalendarEnabled(
            true,
            calendarID: "reminder-2",
            allCalendarIDs: ["reminder-1", "reminder-2"]
        )

        XCTAssertTrue(store.menuBarPreferences.enabledReminderCalendarIDs.isEmpty)
    }

    func testTokenStylePersistsForChineseFormats() {
        let suiteName = #function
        let userDefaults = makeIsolatedUserDefaults(name: suiteName)
        let store = makeStore(userDefaults: userDefaults)

        store.setTokenStyle(.chineseMonthDay, for: .date)
        store.setTokenStyle(.chineseWeekday, for: .weekday)

        let reloaded = makeStore(userDefaults: userDefaults)
        XCTAssertEqual(reloaded.menuBarPreferences.tokens.first(where: { $0.token == .date })?.style, .chineseMonthDay)
        XCTAssertEqual(reloaded.menuBarPreferences.tokens.first(where: { $0.token == .weekday })?.style, .chineseWeekday)
    }

    func testMenuBarTextStylePersists() {
        let suiteName = #function
        let userDefaults = makeIsolatedUserDefaults(name: suiteName)
        let store = makeStore(userDefaults: userDefaults)

        store.setMenuBarTextBold(true)
        store.setMenuBarTextColorHex("#334155")
        store.setMenuBarFilledBackground(true)
        store.setMenuBarFillColorHex("#E2E8F0")

        let reloaded = makeStore(userDefaults: userDefaults)

        XCTAssertTrue(reloaded.menuBarPreferences.textStyle.isBold)
        XCTAssertEqual(reloaded.menuBarPreferences.textStyle.foregroundColorHex, "#334155")
        XCTAssertTrue(reloaded.menuBarPreferences.textStyle.usesFilledBackground)
        XCTAssertEqual(reloaded.menuBarPreferences.textStyle.backgroundColorHex, "#E2E8F0")
    }

    func testResetMenuBarTextStylePersistsDefault() {
        let suiteName = #function
        let userDefaults = makeIsolatedUserDefaults(name: suiteName)
        let store = makeStore(userDefaults: userDefaults)

        store.setMenuBarTextBold(true)
        store.setMenuBarTextColorHex("#334155")
        store.setMenuBarFilledBackground(true)
        store.resetMenuBarTextStyle()

        let reloaded = makeStore(userDefaults: userDefaults)

        XCTAssertEqual(reloaded.menuBarPreferences.textStyle, .default)
    }

    func testSetWeekStart() {
        let suiteName = #function
        let userDefaults = makeIsolatedUserDefaults(name: suiteName)
        let store = makeStore(userDefaults: userDefaults)

        XCTAssertEqual(store.menuBarPreferences.weekStart, .monday)

        store.setWeekStart(.sunday)
        XCTAssertEqual(store.menuBarPreferences.weekStart, .sunday)

        let reloaded = makeStore(userDefaults: userDefaults)
        XCTAssertEqual(reloaded.menuBarPreferences.weekStart, .sunday)

        store.setWeekStart(.monday)
        XCTAssertEqual(store.menuBarPreferences.weekStart, .monday)
    }

    func testInitialLaunchAtLoginStatusReadsControllerState() {
        let controller = LaunchAtLoginControllerStub(status: .enabled)
        let store = makeStore(launchAtLoginController: controller)

        XCTAssertTrue(store.launchAtLoginEnabled)
        XCTAssertEqual(store.launchAtLoginStatus, .enabled)
        XCTAssertNil(store.launchAtLoginStatusMessage)
    }

    func testLaunchAtLoginDefaultsToEnabledWhenInitiallyDisabled() {
        let controller = LaunchAtLoginControllerStub(status: .disabled)
        let store = makeStore(launchAtLoginController: controller)

        XCTAssertEqual(controller.recordedRequests, [true])
        XCTAssertTrue(store.launchAtLoginEnabled)
        XCTAssertEqual(store.launchAtLoginStatus, .enabled)
    }

    func testSetLaunchAtLoginEnabledUpdatesStateOnSuccess() {
        let controller = LaunchAtLoginControllerStub(status: .enabled)
        let store = makeStore(launchAtLoginController: controller)

        XCTAssertTrue(store.launchAtLoginEnabled)
        XCTAssertEqual(store.launchAtLoginStatus, .enabled)

        store.setLaunchAtLoginEnabled(false)

        XCTAssertEqual(controller.recordedRequests, [false])
        XCTAssertFalse(store.launchAtLoginEnabled)
        XCTAssertEqual(store.launchAtLoginStatus, .disabled)
        XCTAssertNil(store.launchAtLoginStatusMessage)
    }

    func testSetLaunchAtLoginDisabledUpdatesStateOnSuccess() {
        let controller = LaunchAtLoginControllerStub(status: .enabled)
        let store = makeStore(launchAtLoginController: controller)

        store.setLaunchAtLoginEnabled(false)

        XCTAssertEqual(controller.recordedRequests, [false])
        XCTAssertFalse(store.launchAtLoginEnabled)
        XCTAssertEqual(store.launchAtLoginStatus, .disabled)
        XCTAssertNil(store.launchAtLoginStatusMessage)
    }

    func testSetLaunchAtLoginEnabledRollsBackAndShowsErrorOnFailure() {
        let controller = LaunchAtLoginControllerStub(status: .enabled)
        controller.nextError = StubError.operationFailed
        let store = makeStore(launchAtLoginController: controller)

        store.setLaunchAtLoginEnabled(false)

        XCTAssertTrue(store.launchAtLoginEnabled)
        XCTAssertEqual(store.launchAtLoginStatus, .enabled)
        XCTAssertEqual(
            store.launchAtLoginStatusMessage,
            "无法关闭开机启动：stub operation failed"
        )
    }

    func testSetLaunchAtLoginDisabledRollsBackAndShowsErrorOnFailure() {
        let controller = LaunchAtLoginControllerStub(status: .enabled)
        controller.nextError = StubError.operationFailed
        let store = makeStore(launchAtLoginController: controller)

        store.setLaunchAtLoginEnabled(false)

        XCTAssertTrue(store.launchAtLoginEnabled)
        XCTAssertEqual(store.launchAtLoginStatus, .enabled)
        XCTAssertEqual(
            store.launchAtLoginStatusMessage,
            "无法关闭开机启动：stub operation failed"
        )
    }

    func testSetLocationMode() {
        let suiteName = #function
        let userDefaults = makeIsolatedUserDefaults(name: suiteName)
        let store = makeStore(userDefaults: userDefaults)

        XCTAssertEqual(store.menuBarPreferences.locationMode, .automatic)

        store.setLocationMode(.manual)
        XCTAssertEqual(store.menuBarPreferences.locationMode, .manual)

        let reloaded = makeStore(userDefaults: userDefaults)
        XCTAssertEqual(reloaded.menuBarPreferences.locationMode, .manual)
    }

    func testSetManualLocation() {
        let suiteName = #function
        let userDefaults = makeIsolatedUserDefaults(name: suiteName)
        let store = makeStore(userDefaults: userDefaults)

        XCTAssertNil(store.menuBarPreferences.manualLocation)

        let location = WeatherLocation(latitude: 39.9, longitude: 116.4, name: "Beijing", country: "China", admin1: "Beijing")
        store.setManualLocation(location)

        XCTAssertEqual(store.menuBarPreferences.manualLocation?.name, "Beijing")
        XCTAssertEqual(store.menuBarPreferences.manualLocation?.latitude ?? .nan, 39.9, accuracy: 0.01)

        let reloaded = makeStore(userDefaults: userDefaults)
        XCTAssertEqual(reloaded.menuBarPreferences.manualLocation?.name, "Beijing")
    }

    func testSetManualLocationToNil() {
        let suiteName = #function
        let userDefaults = makeIsolatedUserDefaults(name: suiteName)
        let store = makeStore(userDefaults: userDefaults)

        let location = WeatherLocation(latitude: 39.9, longitude: 116.4, name: "Beijing", country: nil, admin1: nil)
        store.setManualLocation(location)
        XCTAssertNotNil(store.menuBarPreferences.manualLocation)

        store.setManualLocation(nil)
        XCTAssertNil(store.menuBarPreferences.manualLocation)

        let reloaded = makeStore(userDefaults: userDefaults)
        XCTAssertNil(reloaded.menuBarPreferences.manualLocation)
    }

    private func makeIsolatedUserDefaults(name: String = #function) -> UserDefaults {
        let userDefaults = UserDefaults(suiteName: name)!
        userDefaults.removePersistentDomain(forName: name)
        return userDefaults
    }

    private func makeStore(
        userDefaults: UserDefaults = UserDefaults(suiteName: #function)!,
        launchAtLoginController: LaunchAtLoginControllerStub = LaunchAtLoginControllerStub()
    ) -> SettingsStore {
        SettingsStore(
            userDefaults: userDefaults,
            launchAtLoginController: launchAtLoginController
        )
    }
}

private final class LaunchAtLoginControllerStub: LaunchAtLoginControlling {
    var statusValue: LaunchAtLoginStatus
    var nextError: Error?
    private(set) var recordedRequests: [Bool] = []

    init(status: LaunchAtLoginStatus = .disabled) {
        self.statusValue = status
    }

    func status() -> LaunchAtLoginStatus {
        statusValue
    }

    func setEnabled(_ enabled: Bool) throws {
        recordedRequests.append(enabled)

        if let nextError {
            self.nextError = nil
            throw nextError
        }

        statusValue = enabled ? .enabled : .disabled
    }
}

private enum StubError: LocalizedError {
    case operationFailed

    var errorDescription: String? {
        "stub operation failed"
    }
}
