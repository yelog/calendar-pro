import XCTest
@testable import CalendarPro

final class MonthCalendarServiceTests: XCTestCase {
    func testMonthGridReturnsFortyTwoCells() {
        let service = MonthCalendarService(calendar: .gregorianMondayFirst)
        let cells = service.makeMonthGrid(for: makeDate(year: 2026, month: 3, day: 1))

        XCTAssertEqual(cells.count, 42)
    }

    func testMonthGridIncludesLeadingAndTrailingSpilloverDays() {
        let service = MonthCalendarService(calendar: .gregorianMondayFirst)
        let cells = service.makeMonthGrid(for: makeDate(year: 2026, month: 3, day: 1))

        XCTAssertEqual(cells.first?.solarText, "23")
        XCTAssertEqual(cells.first?.isInDisplayedMonth, false)
        XCTAssertEqual(cells.last?.solarText, "5")
        XCTAssertEqual(cells.last?.isInDisplayedMonth, false)
    }

    func testMonthGridMarksTodayCell() {
        let today = makeDate(year: 2026, month: 3, day: 15)
        let service = MonthCalendarService(calendar: .gregorianMondayFirst, now: { today })
        let cells = service.makeMonthGrid(for: today)

        XCTAssertEqual(cells.filter(\.isToday).count, 1)
        XCTAssertTrue(cells.contains { $0.solarText == "15" && $0.isToday })
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
