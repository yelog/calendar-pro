import XCTest
@testable import CalendarPro

@MainActor
final class CalendarPopoverViewModelTests: XCTestCase {
    func testNextMonthAdvancesAcrossYearBoundary() {
        let viewModel = CalendarPopoverViewModel(displayedMonth: makeDate(year: 2026, month: 12, day: 1))

        viewModel.showNextMonth(using: .gregorianMondayFirst)

        XCTAssertEqual(
            Calendar.gregorianMondayFirst.dateComponents([.year, .month], from: viewModel.displayedMonth),
            DateComponents(year: 2027, month: 1)
        )
    }

    func testPreviousMonthRetreatsAcrossYearBoundary() {
        let viewModel = CalendarPopoverViewModel(displayedMonth: makeDate(year: 2026, month: 1, day: 1))

        viewModel.showPreviousMonth(using: .gregorianMondayFirst)

        XCTAssertEqual(
            Calendar.gregorianMondayFirst.dateComponents([.year, .month], from: viewModel.displayedMonth),
            DateComponents(year: 2025, month: 12)
        )
    }

    func testWeekdaySymbolsRespectCalendarFirstWeekday() {
        var sundayFirst = Calendar(identifier: .gregorian)
        sundayFirst.locale = Locale(identifier: "en_US_POSIX")
        sundayFirst.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        sundayFirst.firstWeekday = 1

        let viewModel = CalendarPopoverViewModel(displayedMonth: makeDate(year: 2026, month: 3, day: 1))
        let symbols = viewModel.weekdaySymbols(using: sundayFirst)

        XCTAssertEqual(symbols.first, "Sun")
    }

    func testInitialSelectedDateIsNil() {
        let viewModel = CalendarPopoverViewModel()
        XCTAssertNil(viewModel.selectedDate)
    }

    func testSelectDate() {
        let viewModel = CalendarPopoverViewModel()
        let date = makeDate(year: 2026, month: 3, day: 29)
        viewModel.selectDate(date)
        XCTAssertEqual(viewModel.selectedDate, date)
    }

    func testSelectDateClearsSelectedEvent() {
        let viewModel = CalendarPopoverViewModel()

        viewModel.selectEvent(identifier: "event-1")
        viewModel.selectDate(makeDate(year: 2026, month: 3, day: 29))

        XCTAssertNil(viewModel.selectedEventIdentifier)
    }

    func testClearSelectedDate() {
        let viewModel = CalendarPopoverViewModel()
        viewModel.selectDate(makeDate(year: 2026, month: 3, day: 29))
        viewModel.clearSelectedDate()
        XCTAssertNil(viewModel.selectedDate)
    }

    func testSelectEventStoresIdentifier() {
        let viewModel = CalendarPopoverViewModel()

        viewModel.selectEvent(identifier: "event-1")

        XCTAssertEqual(viewModel.selectedEventIdentifier, "event-1")
    }

    func testToggleEventSelectionSelectsIdentifier() {
        let viewModel = CalendarPopoverViewModel()

        let shouldPresent = viewModel.toggleEventSelection(identifier: "event-1")

        XCTAssertTrue(shouldPresent)
        XCTAssertEqual(viewModel.selectedEventIdentifier, "event-1")
    }

    func testToggleEventSelectionClearsIdentifierWhenTappingSameEvent() {
        let viewModel = CalendarPopoverViewModel()
        _ = viewModel.toggleEventSelection(identifier: "event-1")

        let shouldPresent = viewModel.toggleEventSelection(identifier: "event-1")

        XCTAssertFalse(shouldPresent)
        XCTAssertNil(viewModel.selectedEventIdentifier)
    }

    func testClearSelectedEvent() {
        let viewModel = CalendarPopoverViewModel()

        viewModel.selectEvent(identifier: "event-1")
        viewModel.clearSelectedEvent()

        XCTAssertNil(viewModel.selectedEventIdentifier)
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
