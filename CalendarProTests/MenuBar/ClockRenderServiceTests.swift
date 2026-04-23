import XCTest
@testable import CalendarPro

final class ClockRenderServiceTests: XCTestCase {
    func testTextImageRendererUsesTemplateImageForDefaultStyle() {
        let renderer = MenuBarTextImageRenderer()

        let result = renderer.render(text: "10:30 Tue 04/22", style: .default)

        XCTAssertTrue(result.usesTemplateColor)
        XCTAssertTrue(result.image.isTemplate)
        XCTAssertGreaterThan(result.image.size.width, 0)
    }

    func testTextImageRendererUsesOriginalImageForCustomForegroundColor() {
        let renderer = MenuBarTextImageRenderer()
        let style = MenuBarTextStyle(
            isBold: true,
            foregroundColorHex: "#334155",
            usesFilledBackground: false,
            backgroundColorHex: MenuBarTextStyle.defaultBackgroundColorHex
        )

        let result = renderer.render(text: "10:30 Tue 04/22", style: style)

        XCTAssertFalse(result.usesTemplateColor)
        XCTAssertFalse(result.image.isTemplate)
    }

    func testTextImageRendererUsesOriginalImageForFilledBackground() {
        let renderer = MenuBarTextImageRenderer()
        let style = MenuBarTextStyle(
            isBold: true,
            foregroundColorHex: nil,
            usesFilledBackground: true,
            backgroundColorHex: "#111827"
        )

        let result = renderer.render(text: "10:30 Tue 04/22", style: style)

        XCTAssertFalse(result.usesTemplateColor)
        XCTAssertFalse(result.image.isTemplate)
        XCTAssertGreaterThan(result.image.size.height, 0)
    }

    func testRendererRespectsTokenOrderAndShortStyles() {
        let renderer = ClockRenderService()
        let text = renderer.render(
            now: Date(timeIntervalSince1970: 0),
            preferences: .previewShort,
            locale: Locale(identifier: "en_US_POSIX"),
            calendar: Calendar(identifier: .gregorian),
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        XCTAssertEqual(text, "00:00 Thu 01/01")
    }

    func testRendererSkipsEmptySupplementalTokens() {
        let renderer = ClockRenderService()
        let preferences = MenuBarPreferences(
            tokens: [
                DisplayTokenPreference(token: .time, isEnabled: true, order: 0, style: .short),
                DisplayTokenPreference(token: .lunar, isEnabled: true, order: 1, style: .short)
            ],
            separator: " ",
            showLunarInMenuBar: true,
            activeRegionIDs: ["mainland-cn"],
            enabledHolidayIDs: [],
            weekStart: .monday,
            highlightWeekends: true,
            showEvents: true,
            showCalendarEvents: true,
            enabledCalendarIDs: [],
            showReminders: true,
            enabledReminderCalendarIDs: [],
            showAlmanac: false,
            showWeather: false
        )

        let text = renderer.render(
            now: Date(timeIntervalSince1970: 0),
            preferences: preferences,
            locale: Locale(identifier: "en_US_POSIX"),
            calendar: Calendar(identifier: .gregorian),
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        XCTAssertEqual(text, "00:00")
    }

    func testRendererSupportsChineseDateAndWeekdayStyles() {
        let renderer = ClockRenderService()
        let timeZone = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 30, hour: 9, minute: 0))!

        let preferences = MenuBarPreferences(
            tokens: [
                DisplayTokenPreference(token: .date, isEnabled: true, order: 0, style: .chineseMonthDay),
                DisplayTokenPreference(token: .weekday, isEnabled: true, order: 1, style: .chineseWeekday)
            ],
            separator: " ",
            showLunarInMenuBar: false,
            activeRegionIDs: ["mainland-cn"],
            enabledHolidayIDs: [],
            weekStart: .monday,
            highlightWeekends: true,
            showEvents: true,
            showCalendarEvents: true,
            enabledCalendarIDs: [],
            showReminders: true,
            enabledReminderCalendarIDs: [],
            showAlmanac: false,
            showWeather: false
        )

        let text = renderer.render(
            now: now,
            preferences: preferences,
            locale: Locale(identifier: "en_US_POSIX"),
            calendar: calendar,
            timeZone: timeZone
        )

        XCTAssertEqual(text, "03月30日 周一")
    }

    func testRendererNumericFormatUsesDayFirst() {
        let renderer = ClockRenderService()
        let timeZone = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let now = calendar.date(from: DateComponents(year: 2026, month: 4, day: 5, hour: 10, minute: 0))!

        let preferences = MenuBarPreferences(
            tokens: [
                DisplayTokenPreference(token: .date, isEnabled: true, order: 0, style: .numeric)
            ],
            separator: " ",
            showLunarInMenuBar: false,
            activeRegionIDs: ["mainland-cn"],
            enabledHolidayIDs: [],
            weekStart: .monday,
            highlightWeekends: true,
            showEvents: true,
            showCalendarEvents: true,
            enabledCalendarIDs: [],
            showReminders: true,
            enabledReminderCalendarIDs: [],
            showAlmanac: false,
            showWeather: false
        )

        let text = renderer.render(
            now: now,
            preferences: preferences,
            locale: Locale(identifier: "en_US_POSIX"),
            calendar: calendar,
            timeZone: timeZone
        )

        XCTAssertEqual(text, "05/04")
    }

    func testRendererChineseFullFormat() {
        let renderer = ClockRenderService()
        let timeZone = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let now = calendar.date(from: DateComponents(year: 2026, month: 4, day: 5, hour: 10, minute: 0))!

        let preferences = MenuBarPreferences(
            tokens: [
                DisplayTokenPreference(token: .date, isEnabled: true, order: 0, style: .chineseFull)
            ],
            separator: " ",
            showLunarInMenuBar: false,
            activeRegionIDs: ["mainland-cn"],
            enabledHolidayIDs: [],
            weekStart: .monday,
            highlightWeekends: true,
            showEvents: true,
            showCalendarEvents: true,
            enabledCalendarIDs: [],
            showReminders: true,
            enabledReminderCalendarIDs: [],
            showAlmanac: false,
            showWeather: false
        )

        let text = renderer.render(
            now: now,
            preferences: preferences,
            locale: Locale(identifier: "en_US_POSIX"),
            calendar: calendar,
            timeZone: timeZone
        )

        XCTAssertEqual(text, "2026年04月05日")
    }

    func testRendererSupportsUnpaddedDateStyles() {
        let renderer = ClockRenderService()
        let timeZone = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let now = calendar.date(from: DateComponents(year: 2026, month: 4, day: 5, hour: 10, minute: 0))!

        XCTAssertEqual(
            renderer.renderPreview(
                token: .date,
                style: .numericUnpadded,
                now: now,
                locale: Locale(identifier: "zh_CN"),
                calendar: calendar,
                timeZone: timeZone
            ),
            "5/4"
        )
        XCTAssertEqual(
            renderer.renderPreview(
                token: .date,
                style: .shortUnpadded,
                now: now,
                locale: Locale(identifier: "zh_CN"),
                calendar: calendar,
                timeZone: timeZone
            ),
            "2026/4/5"
        )
        XCTAssertEqual(
            renderer.renderPreview(
                token: .date,
                style: .chineseMonthDayUnpadded,
                now: now,
                locale: Locale(identifier: "zh_CN"),
                calendar: calendar,
                timeZone: timeZone
            ),
            "4月5日"
        )
        XCTAssertEqual(
            renderer.renderPreview(
                token: .date,
                style: .chineseFullUnpadded,
                now: now,
                locale: Locale(identifier: "zh_CN"),
                calendar: calendar,
                timeZone: timeZone
            ),
            "2026年4月5日"
        )
    }

    func testRendererUnpaddedDateStylesStayDistinctForDoubleDigitDay() {
        let renderer = ClockRenderService()
        let timeZone = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let now = calendar.date(from: DateComponents(year: 2026, month: 4, day: 22, hour: 10, minute: 0))!

        XCTAssertEqual(
            renderer.renderPreview(
                token: .date,
                style: .numericUnpadded,
                now: now,
                locale: Locale(identifier: "zh_CN"),
                calendar: calendar,
                timeZone: timeZone
            ),
            "22/4"
        )
        XCTAssertEqual(
            renderer.renderPreview(
                token: .date,
                style: .shortUnpadded,
                now: now,
                locale: Locale(identifier: "zh_CN"),
                calendar: calendar,
                timeZone: timeZone
            ),
            "2026/4/22"
        )
        XCTAssertEqual(
            renderer.renderPreview(
                token: .date,
                style: .chineseMonthDayUnpadded,
                now: now,
                locale: Locale(identifier: "zh_CN"),
                calendar: calendar,
                timeZone: timeZone
            ),
            "4月22日"
        )
        XCTAssertEqual(
            renderer.renderPreview(
                token: .date,
                style: .chineseFullUnpadded,
                now: now,
                locale: Locale(identifier: "zh_CN"),
                calendar: calendar,
                timeZone: timeZone
            ),
            "2026年4月22日"
        )
    }
}
