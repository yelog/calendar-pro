import XCTest
@testable import CalendarPro

final class ClockRenderServiceTests: XCTestCase {
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
            showEvents: true,
            enabledCalendarIDs: [],
            showReminders: true,
            enabledReminderCalendarIDs: []
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
            showEvents: true,
            enabledCalendarIDs: [],
            showReminders: true,
            enabledReminderCalendarIDs: []
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
}
