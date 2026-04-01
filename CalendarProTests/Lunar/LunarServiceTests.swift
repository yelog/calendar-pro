import XCTest
@testable import CalendarPro

final class LunarServiceTests: XCTestCase {
    func testLunarServiceResolvesMidAutumnFestival() {
        let service = LunarService()
        let result = service.describe(date: makeDate(year: 2026, month: 9, day: 25))

        XCTAssertEqual(result.festivalName, "中秋节")
        XCTAssertNil(result.solarTermName)
        XCTAssertEqual(result.displayText(), "中秋节")
    }

    func testLunarServiceResolvesSpringFestival() {
        let service = LunarService()
        let result = service.describe(date: makeDate(year: 2026, month: 2, day: 17))

        XCTAssertEqual(result.month, 1)
        XCTAssertEqual(result.day, 1)
        XCTAssertEqual(result.festivalName, "春节")
    }

    func testLunarServiceResolvesBeginningOfSpringSolarTerm() {
        let service = LunarService()
        let result = service.describe(date: makeDate(year: 2026, month: 2, day: 4))

        XCTAssertEqual(result.solarTermName, "立春")
        XCTAssertEqual(result.displayText(), "立春")
        XCTAssertEqual(result.displayText(style: .yearMonthDay), "立春")
    }

    func testLunarServiceResolvesAwakeningOfInsectsSolarTerm() {
        let service = LunarService()
        let result = service.describe(date: makeDate(year: 2026, month: 3, day: 5))

        XCTAssertEqual(result.solarTermName, "惊蛰")
        XCTAssertEqual(result.displayText(), "惊蛰")
    }

    func testLunarServiceResolvesBeginningOfSummerSolarTerm() {
        let service = LunarService()
        let result = service.describe(date: makeDate(year: 2026, month: 5, day: 5))

        XCTAssertEqual(result.solarTermName, "立夏")
        XCTAssertEqual(result.displayText(), "立夏")
    }

    func testLunarServiceHandlesShiftedSolarTermDateInFollowingYear() {
        let service = LunarService()
        let result = service.describe(date: makeDate(year: 2027, month: 2, day: 4))

        XCTAssertEqual(result.solarTermName, "立春")
        XCTAssertEqual(result.displayText(), "立春")
    }

    func testLunarServiceBuildsDayTextForNonFestivalOrSolarTermDays() {
        let service = LunarService()
        let result = service.describe(date: makeDate(year: 2026, month: 2, day: 20))

        XCTAssertNil(result.festivalName)
        XCTAssertNil(result.solarTermName)
        XCTAssertEqual(result.dayText, "初四")
        XCTAssertEqual(result.displayText(), "初四")
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
