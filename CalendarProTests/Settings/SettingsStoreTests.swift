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

    func testSetCalendarEnabled() {
        let userDefaults = makeIsolatedUserDefaults()
        let store = makeStore(userDefaults: userDefaults)
        store.setCalendarEnabled(true, calendarID: "calendar-1")
        XCTAssertTrue(store.menuBarPreferences.enabledCalendarIDs.contains("calendar-1"))

        store.setCalendarEnabled(false, calendarID: "calendar-1")
        XCTAssertFalse(store.menuBarPreferences.enabledCalendarIDs.contains("calendar-1"))
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

    func testInitialLaunchAtLoginStatusReadsControllerState() {
        let controller = LaunchAtLoginControllerStub(status: .enabled)
        let store = makeStore(launchAtLoginController: controller)

        XCTAssertTrue(store.launchAtLoginEnabled)
        XCTAssertEqual(store.launchAtLoginStatus, .enabled)
        XCTAssertNil(store.launchAtLoginStatusMessage)
    }

    func testSetLaunchAtLoginEnabledUpdatesStateOnSuccess() {
        let controller = LaunchAtLoginControllerStub(status: .disabled)
        let store = makeStore(launchAtLoginController: controller)

        store.setLaunchAtLoginEnabled(true)

        XCTAssertEqual(controller.recordedRequests, [true])
        XCTAssertTrue(store.launchAtLoginEnabled)
        XCTAssertEqual(store.launchAtLoginStatus, .enabled)
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
        let controller = LaunchAtLoginControllerStub(status: .disabled)
        controller.nextError = StubError.operationFailed
        let store = makeStore(launchAtLoginController: controller)

        store.setLaunchAtLoginEnabled(true)

        XCTAssertFalse(store.launchAtLoginEnabled)
        XCTAssertEqual(store.launchAtLoginStatus, .disabled)
        XCTAssertEqual(
            store.launchAtLoginStatusMessage,
            "无法开启开机启动：stub operation failed"
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
