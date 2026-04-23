import XCTest
@testable import CalendarPro

final class MenuBarPreferencesTests: XCTestCase {
    func testDefaultShowEventsIsTrue() {
        let prefs = MenuBarPreferences.default
        XCTAssertTrue(prefs.showEvents)
    }

    func testDefaultShowCalendarEventsIsTrue() {
        let prefs = MenuBarPreferences.default
        XCTAssertTrue(prefs.showCalendarEvents)
    }

    func testDefaultTextStyleFollowsSystemMenuBarColor() {
        let prefs = MenuBarPreferences.default

        XCTAssertTrue(prefs.textStyle.isBold)
        XCTAssertNil(prefs.textStyle.foregroundColorHex)
        XCTAssertFalse(prefs.textStyle.usesFilledBackground)
        XCTAssertEqual(prefs.textStyle.backgroundColorHex, MenuBarTextStyle.defaultBackgroundColorHex)
    }

    func testDefaultEnabledCalendarIDsIsEmpty() {
        let prefs = MenuBarPreferences.default
        XCTAssertTrue(prefs.enabledCalendarIDs.isEmpty)
    }

    func testCodableRoundTrip() throws {
        let prefs = MenuBarPreferences.default
        let data = try JSONEncoder().encode(prefs)
        let decoded = try JSONDecoder().decode(MenuBarPreferences.self, from: data)
        XCTAssertEqual(prefs, decoded)
    }

    func testCodableRoundTripPreservesChineseStyles() throws {
        var prefs = MenuBarPreferences.default
        if let dateIndex = prefs.tokens.firstIndex(where: { $0.token == .date }) {
            prefs.tokens[dateIndex].style = .chineseMonthDay
        }
        if let weekdayIndex = prefs.tokens.firstIndex(where: { $0.token == .weekday }) {
            prefs.tokens[weekdayIndex].style = .chineseWeekday
        }

        let data = try JSONEncoder().encode(prefs)
        let decoded = try JSONDecoder().decode(MenuBarPreferences.self, from: data)

        XCTAssertEqual(decoded.tokens.first(where: { $0.token == .date })?.style, .chineseMonthDay)
        XCTAssertEqual(decoded.tokens.first(where: { $0.token == .weekday })?.style, .chineseWeekday)
    }

    func testLegacyDecodingDefaultsShowCalendarEventsToShowEvents() throws {
        let legacyJSON = """
        {
          "tokens": [
            { "token": "date", "isEnabled": true, "order": 0, "style": "short" }
          ],
          "separator": " ",
          "showLunarInMenuBar": false,
          "activeRegionIDs": ["mainland-cn"],
          "enabledHolidayIDs": [],
          "weekStart": "monday",
          "showEvents": false,
          "enabledCalendarIDs": [],
          "showReminders": true,
          "enabledReminderCalendarIDs": []
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(MenuBarPreferences.self, from: legacyJSON)

        XCTAssertFalse(decoded.showEvents)
        XCTAssertFalse(decoded.showCalendarEvents)
        XCTAssertTrue(decoded.showReminders)
        XCTAssertEqual(decoded.textStyle, .default)
    }

    func testEventsSummaryTextWhenModuleDisabled() {
        var prefs = MenuBarPreferences.default
        prefs.showEvents = false

        XCTAssertEqual(prefs.eventsSummaryText, "日程已关闭")
    }

    func testEventsSummaryTextWhenNoSourcesEnabled() {
        var prefs = MenuBarPreferences.default
        prefs.showCalendarEvents = false
        prefs.showReminders = false

        XCTAssertEqual(prefs.eventsSummaryText, "未启用任何日程来源")
        XCTAssertEqual(prefs.eventListEmptyStateText, "未启用任何日程来源")
    }

    func testDefaultLocationModeIsAutomatic() {
        let prefs = MenuBarPreferences.default
        XCTAssertEqual(prefs.locationMode, .automatic)
        XCTAssertNil(prefs.manualLocation)
    }

    func testCodableRoundTripPreservesLocationMode() throws {
        var prefs = MenuBarPreferences.default
        prefs.locationMode = .manual
        prefs.manualLocation = WeatherLocation(latitude: 22.3, longitude: 114.2, name: "Hong Kong", country: "HK", admin1: nil)

        let data = try JSONEncoder().encode(prefs)
        let decoded = try JSONDecoder().decode(MenuBarPreferences.self, from: data)

        XCTAssertEqual(decoded.locationMode, .manual)
        XCTAssertEqual(decoded.manualLocation?.name, "Hong Kong")
        XCTAssertEqual(decoded.manualLocation?.latitude ?? .nan, 22.3, accuracy: 0.01)
    }

    func testLegacyDecodingDefaultsLocationModeToAutomatic() throws {
        let legacyJSON = """
        {
          "tokens": [{ "token": "date", "isEnabled": true, "order": 0, "style": "short" }],
          "separator": " ",
          "showLunarInMenuBar": false,
          "activeRegionIDs": [],
          "enabledHolidayIDs": [],
          "weekStart": "monday",
          "showEvents": true,
          "enabledCalendarIDs": [],
          "showReminders": true,
          "enabledReminderCalendarIDs": []
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(MenuBarPreferences.self, from: legacyJSON)

        XCTAssertEqual(decoded.locationMode, .automatic)
        XCTAssertNil(decoded.manualLocation)
    }

    func testAutomaticForegroundColorUsesContrastForFilledBackground() {
        XCTAssertEqual(
            MenuBarTextStyle.automaticForegroundColorHex(for: "#F2F4F7"),
            MenuBarTextStyle.defaultCustomForegroundColorHex
        )
        XCTAssertEqual(
            MenuBarTextStyle.automaticForegroundColorHex(for: "#1F2937"),
            "#FFFFFF"
        )
    }
}
