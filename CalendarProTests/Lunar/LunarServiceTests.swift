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

    func testLunarServiceMarksQixiAsFestivalSemantic() {
        let service = LunarService()
        let result = service.describe(date: makeDate(year: 2026, month: 8, day: 19))

        XCTAssertEqual(result.festivalName, "七夕")
        XCTAssertEqual(result.displayText(), "七夕")
        XCTAssertEqual(result.displaySemantic, .festival)
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

    func testLunarYearTextUsesChineseCalendarCycleYear() {
        let cases: [(Int, Int, Int, String)] = [
            (1984, 2, 2, "甲子年"),
            (2024, 2, 10, "甲辰年"),
            (2026, 2, 4, "乙巳年"),
            (2026, 2, 16, "乙巳年"),
            (2026, 2, 17, "丙午年"),
            (2026, 10, 3, "丙午年")
        ]

        for (year, month, day, expected) in cases {
            let result = describeShanghaiDate(year: year, month: month, day: day)
            XCTAssertEqual(result.yearText, expected, "\(year)-\(month)-\(day)")
        }
    }

    func testFullLunarDateRetainsDateOnFestivalsAndSolarTerms() {
        let cases: [(Int, Int, Int, String, String)] = [
            (2026, 10, 3, "丙午年八月廿三", "廿三"),
            (2026, 2, 16, "乙巳年腊月廿九", "廿九"),
            (2026, 2, 17, "丙午年正月初一", "春节"),
            (2026, 9, 25, "丙午年八月十五", "中秋节"),
            (2026, 2, 4, "乙巳年腊月十七", "立春"),
            (2025, 7, 25, "乙巳年闰六月初一", "闰六月")
        ]

        for (year, month, day, fullText, compactText) in cases {
            let result = describeShanghaiDate(year: year, month: month, day: day)
            XCTAssertEqual(result.fullDateText, fullText, "\(year)-\(month)-\(day)")
            XCTAssertEqual(result.displayText(), compactText)

            if result.festivalName == nil && result.solarTermName == nil {
                XCTAssertEqual(result.displayText(style: .yearMonthDay), fullText)
            } else {
                XCTAssertEqual(result.displayText(style: .yearMonthDay), compactText)
            }
        }
    }

    func testFullLunarDateUsesRequestedTimeZoneAcrossNewYearBoundary() {
        let date = ISO8601DateFormatter().date(from: "2026-02-16T16:30:00Z")!
        let service = LunarService()
        let shanghai = service.describe(
            date: date,
            timeZone: TimeZone(identifier: "Asia/Shanghai")!
        )
        let utc = service.describe(date: date, timeZone: TimeZone(secondsFromGMT: 0)!)

        XCTAssertEqual(shanghai.fullDateText, "丙午年正月初一")
        XCTAssertEqual(utc.fullDateText, "乙巳年腊月廿九")
    }

    private func describeShanghaiDate(year: Int, month: Int, day: Int) -> LunarDateDescriptor {
        let timeZone = TimeZone(identifier: "Asia/Shanghai")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let date = calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: 12
        ))!
        return LunarService().describe(date: date, timeZone: timeZone)
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
