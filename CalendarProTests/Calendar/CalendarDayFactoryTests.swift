import XCTest
@testable import CalendarPro

final class CalendarDayFactoryTests: XCTestCase {
    func testDayFactoryAddsHolidayBadgeAndLunarText() throws {
        let factory = CalendarDayFactory.makePreview()
        let day = try factory.makeDay(
            for: makeDate(year: 2026, month: 2, day: 17),
            displayedMonth: makeDate(year: 2026, month: 2, day: 1)
        )

        XCTAssertEqual(day.lunarText, "春节")
        XCTAssertFalse(day.badges.isEmpty)
        XCTAssertTrue(day.badges.contains { $0.kind == .statutoryHoliday })
    }

    func testMonthGridDecoratesHongKongPublicHolidayWhenRegionEnabled() throws {
        var preferences = MenuBarPreferences.default
        preferences.activeRegionIDs = ["hong-kong"]
        let factory = CalendarDayFactory.makePreview()
        let days = try factory.makeMonthGrid(for: makeDate(year: 2026, month: 10, day: 1), preferences: preferences)

        let nationalDay = try XCTUnwrap(days.first { $0.solarText == "1" && $0.isInDisplayedMonth })
        XCTAssertTrue(nationalDay.badges.contains { $0.kind == .publicHoliday })
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        DateComponents(
            calendar: Calendar.gregorianMondayFirst,
            timeZone: TimeZone(secondsFromGMT: 0),
            year: year,
            month: month,
            day: day
        ).date!
    }
}
