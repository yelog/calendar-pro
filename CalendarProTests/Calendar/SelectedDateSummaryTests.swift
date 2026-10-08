import XCTest
@testable import CalendarPro

final class SelectedDateSummaryTests: XCTestCase {
    func testOrdinaryDayIncludesSolarAndFullLunarDateWithoutChips() {
        let summary = makeSummary(on: Self.makeDate(year: 2026, month: 2, day: 24))

        XCTAssertEqual(summary.solarDateText, "2月24日")
        XCTAssertEqual(summary.weekdayText, "周二")
        XCTAssertEqual(summary.lunarDateText, "丙午年正月初八")
        XCTAssertTrue(summary.chips.isEmpty)
    }

    func testSummaryRetainsHolidayOutsideDisplayedGrid() {
        let summary = makeSummary(
            on: Self.makeDate(year: 2026, month: 10, day: 1),
            displayedMonth: Self.makeDate(year: 2026, month: 12, day: 1)
        )

        XCTAssertEqual(summary.chips.map(\.text), ["国庆节", "休"])
        XCTAssertEqual(summary.chips.map(\.style), [.primary, .dayOff])
    }

    func testSummaryIncludesYearWhenDisplayedYearDiffers() {
        let summary = makeSummary(
            on: Self.makeDate(year: 2026, month: 10, day: 1),
            displayedMonth: Self.makeDate(year: 2027, month: 1, day: 1)
        )

        XCTAssertTrue(summary.solarDateText.contains("2026"))
        XCTAssertTrue(summary.fullSolarDateText.contains("2026"))
    }

    func testNilSelectionUsesCurrentDateForEveryDateField() {
        let currentDate = Self.makeDate(year: 2026, month: 2, day: 24)
        let summary = makeSummary(selectedDate: nil, currentDate: currentDate)

        XCTAssertEqual(summary.date, currentDate)
        XCTAssertEqual(summary.solarDateText, "2月24日")
        XCTAssertEqual(summary.lunarDateText, "丙午年正月初八")
    }

    func testEnglishSummaryKeepsSolarDateWithoutLunarDate() {
        let summary = makeSummary(
            on: Self.makeDate(year: 2026, month: 10, day: 1),
            locale: Locale(identifier: "en_US"),
            showsLunarDate: false
        )

        XCTAssertEqual(summary.solarDateText, "Oct 1")
        XCTAssertNil(summary.lunarDateText)
    }

    func testSummaryIgnoresMenuBarLunarStyleAndEnabledState() {
        var preferences = makePreferences()
        let date = Self.makeDate(year: 2026, month: 2, day: 24)

        preferences.tokens = preferences.tokens.map { token in
            guard token.token == .lunar else { return token }
            return DisplayTokenPreference(token: .lunar, isEnabled: false, order: token.order, style: .short)
        }
        let shortDisabled = makeSummary(on: date, preferences: preferences)

        preferences.tokens = preferences.tokens.map { token in
            guard token.token == .lunar else { return token }
            return DisplayTokenPreference(token: .lunar, isEnabled: true, order: token.order, style: .full)
        }
        let fullEnabled = makeSummary(on: date, preferences: preferences)

        XCTAssertEqual(shortDisabled.lunarDateText, "丙午年正月初八")
        XCTAssertEqual(fullEnabled.lunarDateText, shortDisabled.lunarDateText)
    }

    func testSummaryRespectsHolidayPreferences() {
        var preferences = makePreferences()
        preferences.enabledHolidayIDs = [
            MainlandCNProvider.statutoryHolidaySetID,
            MainlandCNProvider.adjustmentWorkdaySetID
        ]

        let summary = makeSummary(
            on: Self.makeDate(year: 2026, month: 5, day: 10),
            preferences: preferences
        )

        XCTAssertFalse(summary.chips.contains { $0.text == "母亲节" })
    }

    func testSummaryPreservesSolarTermAndSupplementalFestival() {
        let summary = makeSummary(on: Self.makeDate(year: 2026, month: 6, day: 21))

        XCTAssertEqual(summary.chips.map(\.text), ["夏至", "父亲节", "休"])
        XCTAssertEqual(summary.chips.map(\.style), [.primary, .supplemental, .dayOff])
    }

    func testSummaryUsesCalendarTimeZoneForSolarAndLunarDate() {
        let date = ISO8601DateFormatter().date(from: "2026-02-16T16:30:00Z")!
        var shanghaiCalendar = Calendar(identifier: .gregorian)
        shanghaiCalendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let shanghai = makeSummary(on: date, calendar: shanghaiCalendar)
        let utc = makeSummary(on: date, calendar: utcCalendar)

        XCTAssertTrue(shanghai.solarDateText.contains("2月17日"))
        XCTAssertEqual(shanghai.lunarDateText, "丙午年正月初一")
        XCTAssertTrue(utc.solarDateText.contains("2月16日"))
        XCTAssertEqual(utc.lunarDateText, "乙巳年腊月廿九")
    }

    private func makeSummary(
        selectedDate: Date? = nil,
        currentDate: Date = selectedSummaryTestDate(year: 2026, month: 10, day: 3),
        displayedMonth: Date = selectedSummaryTestDate(year: 2026, month: 10, day: 1),
        preferences: MenuBarPreferences? = nil,
        locale: Locale = Locale(identifier: "zh-Hans"),
        showsLunarDate: Bool = true,
        calendar: Calendar = .gregorianMondayFirst
    ) -> SelectedDateSummary {
        SelectedDateSummaryFactory(calendar: calendar, registry: .default).make(
            selectedDate: selectedDate,
            currentDate: currentDate,
            displayedMonth: displayedMonth,
            preferences: preferences ?? makePreferences(),
            locale: locale,
            showsLunarDate: showsLunarDate,
            offText: "休",
            workText: "班"
        )
    }

    private func makeSummary(
        on date: Date,
        displayedMonth: Date = selectedSummaryTestDate(year: 2026, month: 10, day: 1),
        preferences: MenuBarPreferences? = nil,
        locale: Locale = Locale(identifier: "zh-Hans"),
        showsLunarDate: Bool = true,
        calendar: Calendar = .gregorianMondayFirst
    ) -> SelectedDateSummary {
        makeSummary(
            selectedDate: date,
            currentDate: date,
            displayedMonth: displayedMonth,
            preferences: preferences,
            locale: locale,
            showsLunarDate: showsLunarDate,
            calendar: calendar
        )
    }

    private func makePreferences() -> MenuBarPreferences {
        var preferences = MenuBarPreferences.defaultsForCurrentLocale(
            locale: Locale(identifier: "zh-Hans")
        )
        preferences.activeRegionIDs = ["mainland-cn"]
        return preferences
    }

    private static func makeDate(year: Int, month: Int, day: Int) -> Date {
        Calendar.gregorianMondayFirst.date(from: DateComponents(year: year, month: month, day: day))!
    }

}

private func selectedSummaryTestDate(year: Int, month: Int, day: Int) -> Date {
    Calendar.gregorianMondayFirst.date(from: DateComponents(year: year, month: month, day: day))!
}
