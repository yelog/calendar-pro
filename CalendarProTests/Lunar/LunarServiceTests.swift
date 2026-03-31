import XCTest
@testable import CalendarPro

final class LunarServiceTests: XCTestCase {
    func testLunarServiceResolvesMidAutumnFestival() {
        let service = LunarService()
        let result = service.describe(date: makeDate(year: 2026, month: 9, day: 25))

        XCTAssertEqual(result.festivalName, "中秋节")
        XCTAssertEqual(result.displayText(), "中秋节")
    }

    func testLunarServiceResolvesSpringFestival() {
        let service = LunarService()
        let result = service.describe(date: makeDate(year: 2026, month: 2, day: 17))

        XCTAssertEqual(result.month, 1)
        XCTAssertEqual(result.day, 1)
        XCTAssertEqual(result.festivalName, "春节")
    }

    func testLunarServiceBuildsDayTextForNonFestivalDays() {
        let service = LunarService()
        let result = service.describe(date: makeDate(year: 2026, month: 2, day: 18))

        XCTAssertNil(result.festivalName)
        XCTAssertEqual(result.dayText, "初二")
        XCTAssertEqual(result.displayText(), "初二")
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
