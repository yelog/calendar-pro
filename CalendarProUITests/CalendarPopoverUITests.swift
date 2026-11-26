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
    func testTimeZonePickerUpdatesOpenCalendarAndPersistsSelection() throws {
        let suiteName = "CalendarPopoverTimeZonePickerUITests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            terminateExistingInstances()
            defaults.removePersistentDomain(forName: suiteName)
        }
        defaults.set("Pacific/Honolulu", forKey: "appTimeZoneIdentifier")
        defaults.synchronize()
        let environment = [
            "CALENDAR_PRO_UI_TEST_DEFAULTS_SUITE": suiteName,
            "CALENDAR_PRO_UI_TEST_NOW": "2026-12-31T12:30:00Z"
        ]
        let app = XCUIApplication(url: try applicationURL())
        try launchApplication(app, environment: environment)
        let year = app.buttons["calendar-popover-year"]
        XCTAssertTrue(year.waitForExistence(timeout: 5))
        XCTAssertTrue(year.label.contains("2026"))

        app.buttons["calendar-popover-settings"].click()
        let picker = app.buttons["timeZonePicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        attachScreenshot(app, name: "time-zone-settings")
        picker.click()
        let search = app.textFields["timeZoneSearch"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.click()
        search.typeText("Pacific/Kiritimati")
        let option = app.buttons["timeZoneOption-Pacific/Kiritimati"]
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        attachScreenshot(app, name: "time-zone-picker-search")
        option.click()

        let yearUpdated = expectation(for: NSPredicate(format: "label CONTAINS %@", "2027"), evaluatedWith: year)
        wait(for: [yearUpdated], timeout: 5)
        app.terminate()
        try launchApplication(app, environment: environment)
        XCTAssertTrue(year.waitForExistence(timeout: 5))
        XCTAssertTrue(year.label.contains("2027"))
    }

    @MainActor
    func testWeatherProviderPickerListsEveryProvider() throws {
        let suiteName = "CalendarPopoverWeatherProviderUITests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            terminateExistingInstances()
            defaults.removePersistentDomain(forName: suiteName)
        }
        let preferences: [String: Any] = [
            "tokens": [],
            "separator": " ",
            "showLunarInMenuBar": true,
            "activeRegionIDs": ["mainland-cn"],
            "enabledHolidayIDs": [],
            "weekStart": "monday",
            "showEvents": true,
            "enabledCalendarIDs": [],
            "showReminders": true,
            "enabledReminderCalendarIDs": [],
            "showWeather": true,
            "weatherProvider": "openMeteo",
            "locationMode": "manual",
            "manualLocation": [
                "latitude": 31.2304,
                "longitude": 121.4737,
                "name": "Shanghai",
                "country": "China",
                "admin1": "Shanghai"
            ]
        ]
        defaults.set(try JSONSerialization.data(withJSONObject: preferences), forKey: "menuBarPreferences")
        defaults.synchronize()

        let app = XCUIApplication(url: try applicationURL())
        try launchApplication(app, environment: ["CALENDAR_PRO_UI_TEST_DEFAULTS_SUITE": suiteName])
        let settingsButton = app.buttons["calendar-popover-settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.click()

        let picker = app.popUpButtons["weatherProviderPicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.click()

        for provider in ["Open-Meteo", "和风天气", "wttr.in", "7Timer"] {
            XCTAssertTrue(app.menuItems[provider].waitForExistence(timeout: 2), "Missing \(provider)")
        }
        attachScreenshot(app, name: "weather-provider-picker")
    }

    @MainActor
    func testPopoverUsesPersistedAppTimeZoneAcrossYearBoundary() throws {
        let suiteName = "CalendarPopoverTimeZoneUITests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            terminateExistingInstances()
            defaults.removePersistentDomain(forName: suiteName)
        }
        defaults.set("Pacific/Kiritimati", forKey: "appTimeZoneIdentifier")
        defaults.synchronize()
        let environment = [
            "CALENDAR_PRO_UI_TEST_DEFAULTS_SUITE": suiteName,
            "CALENDAR_PRO_UI_TEST_NOW": "2026-12-31T12:30:00Z"
        ]
        let app = XCUIApplication(url: try applicationURL())
        try launchApplication(app, environment: environment)
        let year = app.buttons["calendar-popover-year"]
        XCTAssertTrue(year.waitForExistence(timeout: 5))
        XCTAssertTrue(year.label.contains("2027"))
        attachScreenshot(app, name: "time-zone-kiritimati-new-year")

        app.terminate()
        defaults.set("Pacific/Honolulu", forKey: "appTimeZoneIdentifier")
        defaults.synchronize()
        try launchApplication(app, environment: environment)
        XCTAssertTrue(year.waitForExistence(timeout: 5))
        XCTAssertTrue(year.label.contains("2026"))
        attachScreenshot(app, name: "time-zone-honolulu-previous-year")
    }

    @MainActor
    func testPopoverRendersMonthNavigation() throws {
        let app = XCUIApplication(url: try applicationURL())
        try launchApplication(app)

        XCTAssertTrue(app.buttons["previous-month-button"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["next-month-button"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["calendar-popover-selected-date-summary"].exists)
    }

    @MainActor
    func testPublished2027HolidayScheduleAppearsInCalendar() throws {
        let suiteName = "CalendarPopover2027HolidayUITests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            terminateExistingInstances()
            defaults.removePersistentDomain(forName: suiteName)
        }
        let environment = [
            "CALENDAR_PRO_UI_TEST_DEFAULTS_SUITE": suiteName,
            "CALENDAR_PRO_UI_TEST_NOW": "2027-02-10T12:00:00Z"
        ]
        let app = XCUIApplication(url: try applicationURL())
        try launchApplication(app, environment: environment)

        let springFestival = app.descendants(matching: .any)["calendar-day-2027-02-06"]
        XCTAssertTrue(springFestival.waitForExistence(timeout: 5))
        XCTAssertTrue(springFestival.label.contains("春节"))
        XCTAssertTrue(springFestival.label.contains("OFF"))

        let adjustmentWorkday = app.descendants(matching: .any)["calendar-day-2027-02-14"]
        XCTAssertTrue(adjustmentWorkday.exists)
        XCTAssertTrue(adjustmentWorkday.label.contains("WRK"))
        attachScreenshot(app, name: "holiday-schedule-2027")
    }

    @MainActor
    func testUnitedKingdom2027ObservedHolidaysAppearInCalendar() throws {
        let suiteName = "CalendarProUK2027HolidayUITests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            terminateExistingInstances()
            defaults.removePersistentDomain(forName: suiteName)
        }
        defaults.set(
            try JSONSerialization.data(withJSONObject: holidayPreferences(activeRegionIDs: ["uk"])),
            forKey: "menuBarPreferences"
        )
        defaults.synchronize()

        let app = XCUIApplication(url: try applicationURL())
        try launchApplication(
            app,
            environment: [
                "CALENDAR_PRO_UI_TEST_DEFAULTS_SUITE": suiteName,
                "CALENDAR_PRO_UI_TEST_NOW": "2027-12-01T12:00:00Z"
            ],
            language: "english"
        )

        let christmas = app.descendants(matching: .any)["calendar-day-2027-12-27"]
        XCTAssertTrue(christmas.waitForExistence(timeout: 5))
        XCTAssertTrue(christmas.label.contains("Christmas Day (Observed)"))
        XCTAssertTrue(christmas.label.contains("OFF"))

        let boxingDay = app.descendants(matching: .any)["calendar-day-2027-12-28"]
        XCTAssertTrue(boxingDay.exists)
        XCTAssertTrue(boxingDay.label.contains("Boxing Day (Observed)"))
        XCTAssertTrue(boxingDay.label.contains("OFF"))

        let actualChristmas = app.descendants(matching: .any)["calendar-day-2027-12-25"]
        XCTAssertTrue(actualChristmas.exists)
        XCTAssertFalse(actualChristmas.label.contains("Christmas Day"))
        let actualBoxingDay = app.descendants(matching: .any)["calendar-day-2027-12-26"]
        XCTAssertTrue(actualBoxingDay.exists)
        XCTAssertFalse(actualBoxingDay.label.contains("Boxing Day"))
        attachScreenshot(app, name: "uk-2027-observed-holidays")
    }

    @MainActor
    func testUnitedStates2027FederalHolidaysUseOriginalDates() throws {
        let suiteName = "CalendarProUS2027HolidayUITests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            terminateExistingInstances()
            defaults.removePersistentDomain(forName: suiteName)
        }
        defaults.set(
            try JSONSerialization.data(withJSONObject: holidayPreferences(activeRegionIDs: ["us"])),
            forKey: "menuBarPreferences"
        )
        defaults.synchronize()

        let app = XCUIApplication(url: try applicationURL())
        try launchApplication(
            app,
            environment: [
                "CALENDAR_PRO_UI_TEST_DEFAULTS_SUITE": suiteName,
                "CALENDAR_PRO_UI_TEST_NOW": "2027-06-15T12:00:00Z"
            ],
            language: "english"
        )

        let juneteenth = app.descendants(matching: .any)["calendar-day-2027-06-19"]
        XCTAssertTrue(juneteenth.waitForExistence(timeout: 5))
        XCTAssertTrue(juneteenth.label.contains("Juneteenth"))
        XCTAssertTrue(juneteenth.label.contains("OFF"))
        let juneteenthObserved = app.descendants(matching: .any)["calendar-day-2027-06-18"]
        XCTAssertTrue(juneteenthObserved.exists)
        XCTAssertFalse(juneteenthObserved.label.contains("Juneteenth"))

        app.buttons["next-month-button"].click()
        let independenceDay = app.descendants(matching: .any)["calendar-day-2027-07-04"]
        XCTAssertTrue(independenceDay.waitForExistence(timeout: 5))
        XCTAssertTrue(independenceDay.label.contains("Independence Day"))
        XCTAssertTrue(independenceDay.label.contains("OFF"))
        let independenceDayObserved = app.descendants(matching: .any)["calendar-day-2027-07-05"]
        XCTAssertTrue(independenceDayObserved.exists)
        XCTAssertFalse(independenceDayObserved.label.contains("Independence Day"))

        app.terminate()
        try launchApplication(
            app,
            environment: [
                "CALENDAR_PRO_UI_TEST_DEFAULTS_SUITE": suiteName,
                "CALENDAR_PRO_UI_TEST_NOW": "2027-12-01T12:00:00Z"
            ],
            language: "english"
        )

        let christmas = app.descendants(matching: .any)["calendar-day-2027-12-25"]
        XCTAssertTrue(christmas.waitForExistence(timeout: 5))
        XCTAssertTrue(christmas.label.contains("Christmas Day"))
        XCTAssertTrue(christmas.label.contains("OFF"))
        let christmasObserved = app.descendants(matching: .any)["calendar-day-2027-12-24"]
        XCTAssertTrue(christmasObserved.exists)
        XCTAssertFalse(christmasObserved.label.contains("Christmas Day"))
        let newYearsObserved = app.descendants(matching: .any)["calendar-day-2027-12-31"]
        XCTAssertTrue(newYearsObserved.exists)
        XCTAssertFalse(newYearsObserved.label.contains("New Year's Day"))
        attachScreenshot(app, name: "us-2027-original-dates")
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
        let app = XCUIApplication(url: try applicationURL())
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
    private func launchApplication(
        _ app: XCUIApplication,
        environment: [String: String] = [:],
        language: String = "simplifiedChinese"
    ) throws {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance = true
        configuration.environment = ["CALENDAR_PRO_UI_TEST_MODE": "popover-window"]
            .merging(environment) { _, override in override }
        configuration.arguments = ["-appLanguage", language]

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

        let testApplicationPath = appURL.resolvingSymlinksInPath().standardizedFileURL.path
        let testApplication = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .first { $0.bundleURL?.resolvingSymlinksInPath().standardizedFileURL.path == testApplicationPath }
        testApplication?.activate(options: [.activateAllWindows])
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }
}
    
private extension CalendarPopoverUITests {
    func holidayPreferences(activeRegionIDs: [String]) -> [String: Any] {
        [
            "tokens": [],
            "separator": " ",
            "showLunarInMenuBar": false,
            "activeRegionIDs": activeRegionIDs,
            "enabledHolidayIDs": [],
            "weekStart": "monday",
            "showEvents": false,
            "showCalendarEvents": false,
            "enabledCalendarIDs": [],
            "showReminders": false,
            "enabledReminderCalendarIDs": [],
            "showAlmanac": false,
            "showWeather": false,
            "showUpcomingSection": false,
            "upcomingIncludeReminders": false,
            "showRemindersBoard": false
        ]
    }

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
        guard let testAppURL = try? applicationURL().standardizedFileURL else { return }
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).forEach { runningApplication in
            guard runningApplication.bundleURL?.standardizedFileURL == testAppURL else { return }
            _ = runningApplication.terminate()
        }
    }
}
