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
        XCTAssertEqual(nationalDay.subtitleText, "National Day")
    }

    func testMonthGridShowsTraditionalFestivalNameOnlyOnActualFestivalDateAcrossHolidayBreak() throws {
        var preferences = MenuBarPreferences.default
        preferences.activeRegionIDs = ["mainland-cn"]
        let factory = CalendarDayFactory.makePreview()
        let days = try factory.makeMonthGrid(for: makeDate(year: 2026, month: 6, day: 1), preferences: preferences)

        let festivalDay = try XCTUnwrap(days.first { $0.solarText == "19" && $0.isInDisplayedMonth })
        let holidayBridgeDay = try XCTUnwrap(days.first { $0.solarText == "20" && $0.isInDisplayedMonth })
        let holidaySunday = try XCTUnwrap(days.first { $0.solarText == "21" && $0.isInDisplayedMonth })

        XCTAssertEqual(festivalDay.subtitleText, "端午节")
        XCTAssertEqual(holidayBridgeDay.subtitleText, holidayBridgeDay.lunarText)
        XCTAssertEqual(holidaySunday.subtitleText, holidaySunday.lunarText)
        XCTAssertTrue(holidayBridgeDay.badges.contains { $0.kind == .statutoryHoliday && $0.text == "端午节" })
        XCTAssertTrue(holidaySunday.badges.contains { $0.kind == .statutoryHoliday && $0.text == "端午节" })
    }

    func testMonthGridShowsFixedGregorianHolidayNameOnlyOnActualHolidayDateAcrossHolidayBreak() throws {
        var preferences = MenuBarPreferences.default
        preferences.activeRegionIDs = ["mainland-cn"]
        let factory = CalendarDayFactory.makePreview()
        let days = try factory.makeMonthGrid(for: makeDate(year: 2026, month: 1, day: 1), preferences: preferences)

        let newYearsDay = try XCTUnwrap(days.first { $0.solarText == "1" && $0.isInDisplayedMonth })
        let holidayBridgeDay = try XCTUnwrap(days.first { $0.solarText == "2" && $0.isInDisplayedMonth })

        XCTAssertEqual(newYearsDay.subtitleText, "元旦")
        XCTAssertEqual(holidayBridgeDay.subtitleText, holidayBridgeDay.lunarText)
        XCTAssertTrue(holidayBridgeDay.badges.contains { $0.kind == .statutoryHoliday && $0.text == "元旦" })
    }

    func testMonthGridDecoratesMainlandGregorianObservanceFestival() throws {
        var preferences = MenuBarPreferences.default
        preferences.activeRegionIDs = ["mainland-cn"]
        let factory = CalendarDayFactory.makePreview()
        let days = try factory.makeMonthGrid(for: makeDate(year: 2026, month: 5, day: 1), preferences: preferences)

        let mothersDay = try XCTUnwrap(days.first { $0.solarText == "10" && $0.isInDisplayedMonth })

        XCTAssertTrue(mothersDay.badges.contains { $0.kind == .festival && $0.text == "母亲节" })
    }

    func testMonthGridFiltersMainlandGregorianObservanceFestivalWhenSetDisabled() throws {
        var preferences = MenuBarPreferences.default
        preferences.activeRegionIDs = ["mainland-cn"]
        preferences.enabledHolidayIDs = [
            "statutory-holidays",
            "adjustment-workdays"
        ]
        let factory = CalendarDayFactory.makePreview()
        let days = try factory.makeMonthGrid(for: makeDate(year: 2026, month: 5, day: 1), preferences: preferences)

        let mothersDay = try XCTUnwrap(days.first { $0.solarText == "10" && $0.isInDisplayedMonth })

        XCTAssertFalse(mothersDay.badges.contains { $0.text == "母亲节" })
    }

    func testDayFactoryShowsSolarTermTextOnSolarTermDay() throws {
        let factory = CalendarDayFactory.makePreview()
        let day = try factory.makeDay(
            for: makeDate(year: 2026, month: 2, day: 4),
            displayedMonth: makeDate(year: 2026, month: 2, day: 1)
        )

        XCTAssertEqual(day.lunarText, "立春")
        XCTAssertEqual(day.lunarTextSemantic, .solarTerm)
    }

    func testDayFactoryMarksRegularLunarTextAsNonSolarTerm() throws {
        let factory = CalendarDayFactory.makePreview()
        let day = try factory.makeDay(
            for: makeDate(year: 2026, month: 2, day: 20),
            displayedMonth: makeDate(year: 2026, month: 2, day: 1)
        )

        XCTAssertEqual(day.lunarText, "初四")
        XCTAssertEqual(day.lunarTextSemantic, .regular)
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
