import AppKit
import XCTest

private final class LaunchState: @unchecked Sendable {
    var error: Error?
}

final class CalendarPopoverUITests: XCTestCase {
    private let bundleIdentifier = "com.yelog.CalendarPro"

    override func setUpWithError() throws {
        continueAfterFailure = false
        terminateExistingInstances()
    }

    override func tearDownWithError() throws {
        terminateExistingInstances()
    }

    @MainActor
    func testPopoverRendersMonthNavigation() throws {
        let app = XCUIApplication(bundleIdentifier: bundleIdentifier)
        try launchApplication(app)

        XCTAssertTrue(app.buttons["previous-month-button"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["next-month-button"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["calendar-popover-selected-date-summary"].exists)
    }

    @MainActor
    func testEventViewSwitchShowsOneListAndRemembersSelection() throws {
        let suiteName = "CalendarPopoverUITests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            terminateExistingInstances()
            defaults.removePersistentDomain(forName: suiteName)
        }
        let preferences: [String: Any] = [
            "tokens": [["token": "date", "isEnabled": true, "order": 0, "style": "short"]],
            "separator": " ",
            "showLunarInMenuBar": false,
            "activeRegionIDs": [],
            "enabledHolidayIDs": [],
            "weekStart": "monday",
            "showEvents": true,
            "showCalendarEvents": false,
            "enabledCalendarIDs": [],
            "showReminders": false,
            "enabledReminderCalendarIDs": [],
            "showUpcomingSection": true,
            "upcomingIncludeReminders": false,
            "upcomingEnabledCalendarIDs": ["ui-test-unavailable-calendar"],
            "showRemindersBoard": false,
            "eventListMode": "day"
        ]
        defaults.set(try JSONSerialization.data(withJSONObject: preferences), forKey: "menuBarPreferences")
        defaults.synchronize()
        let environment = ["CALENDAR_PRO_UI_TEST_DEFAULTS_SUITE": suiteName]
        let app = XCUIApplication(bundleIdentifier: bundleIdentifier)
        try launchApplication(app, environment: environment)

        let picker = app.segmentedControls["calendar-popover-event-view-picker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["calendar-popover-day-events"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["calendar-popover-overview-events"].exists)
        attachScreenshot(app, name: "day-view")

        picker.buttons.element(boundBy: 1).click()
        XCTAssertTrue(app.descendants(matching: .any)["calendar-popover-overview-events"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["calendar-popover-day-events"].exists)
        XCTAssertFalse(app.buttons["calendar-popover-upcoming-toggle"].exists)
        attachScreenshot(app, name: "overview-view")

        app.terminate()
        try launchApplication(app, environment: environment)
        XCTAssertTrue(app.descendants(matching: .any)["calendar-popover-overview-events"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["calendar-popover-day-events"].exists)

        app.segmentedControls["calendar-popover-event-view-picker"].buttons.element(boundBy: 0).click()
        XCTAssertTrue(app.descendants(matching: .any)["calendar-popover-day-events"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["calendar-popover-overview-events"].exists)
    }

    @MainActor
    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func launchApplication(_ app: XCUIApplication, environment: [String: String] = [:]) throws {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance = true
        configuration.environment = ["CALENDAR_PRO_UI_TEST_MODE": "popover-window"]
            .merging(environment) { _, override in override }
        configuration.arguments = ["-appLanguage", "simplifiedChinese"]

        let appURL = try applicationURL()
        let launchExpectation = expectation(description: "launch CalendarPro")
        let launchState = LaunchState()

        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { _, error in
            launchState.error = error
            launchExpectation.fulfill()
        }

        wait(for: [launchExpectation], timeout: 10)
        if let error = launchState.error {
            throw error
        }

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }
}
    
private extension CalendarPopoverUITests {
    func applicationURL() throws -> URL {
        let productsDirectory = Bundle.main.bundleURL.deletingLastPathComponent()
        let appURL = productsDirectory.appendingPathComponent("CalendarPro.app")
        guard FileManager.default.fileExists(atPath: appURL.path) else {
            throw NSError(
                domain: "CalendarPopoverUITests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Missing app at \(appURL.path)"]
            )
        }
        return appURL
    }

    func terminateExistingInstances() {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).forEach { runningApplication in
            _ = runningApplication.terminate()
        }
    }
}
