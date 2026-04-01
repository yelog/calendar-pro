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

    func testInitialSelectionModeIsCalendar() {
        let viewModel = CalendarPopoverViewModel()
        XCTAssertEqual(viewModel.selectionMode, .calendar)
    }

    func testEnterYearSelection() {
        let viewModel = CalendarPopoverViewModel()

        viewModel.enterYearSelection()

        XCTAssertEqual(viewModel.selectionMode, .year)
    }

    func testEnterMonthSelection() {
        let viewModel = CalendarPopoverViewModel()

        viewModel.enterMonthSelection()

        XCTAssertEqual(viewModel.selectionMode, .month)
    }

    func testDismissPickerReturnsToCalendarMode() {
        let viewModel = CalendarPopoverViewModel()
        viewModel.enterYearSelection()

        viewModel.dismissPicker()

        XCTAssertEqual(viewModel.selectionMode, .calendar)
    }

    func testSelectYearChangesDisplayedMonth() {
        let viewModel = CalendarPopoverViewModel(displayedMonth: makeDate(year: 2025, month: 3, day: 15))

        viewModel.selectYear(2030, calendar: .gregorianMondayFirst)

        XCTAssertEqual(viewModel.displayedYear, 2030)
        XCTAssertEqual(viewModel.displayedMonthNumber, 3)
        XCTAssertEqual(viewModel.selectionMode, .month)
    }

    func testSelectMonthChangesDisplayedMonth() {
        let viewModel = CalendarPopoverViewModel(displayedMonth: makeDate(year: 2026, month: 3, day: 1))

        viewModel.selectMonth(12, calendar: .gregorianMondayFirst)

        XCTAssertEqual(viewModel.displayedYear, 2026)
        XCTAssertEqual(viewModel.displayedMonthNumber, 12)
        XCTAssertEqual(viewModel.selectionMode, .calendar)
    }

    func testDisplayedYearReturnsCurrentYear() {
        let viewModel = CalendarPopoverViewModel(displayedMonth: makeDate(year: 2026, month: 5, day: 10))

        XCTAssertEqual(viewModel.displayedYear, 2026)
    }

    func testDisplayedMonthNumberReturnsCurrentMonth() {
        let viewModel = CalendarPopoverViewModel(displayedMonth: makeDate(year: 2026, month: 5, day: 10))

        XCTAssertEqual(viewModel.displayedMonthNumber, 5)
    }

    func testCurrentYearReturnsTodaysYear() {
        let viewModel = CalendarPopoverViewModel()
        let expectedYear = Calendar.current.component(.year, from: Date())

        XCTAssertEqual(viewModel.currentYear, expectedYear)
    }

    func testCurrentMonthNumberReturnsTodaysMonth() {
        let viewModel = CalendarPopoverViewModel()
        let expectedMonth = Calendar.current.component(.month, from: Date())

        XCTAssertEqual(viewModel.currentMonthNumber, expectedMonth)
    }

    func testPopoverDidCloseRecordsTime() {
        let viewModel = CalendarPopoverViewModel()
        XCTAssertNil(viewModel.lastClosedTime)
        viewModel.popoverDidClose()
        XCTAssertNotNil(viewModel.lastClosedTime)
    }

    func testCheckAndResetDoesNothingWhenNotClosed() {
        let viewModel = CalendarPopoverViewModel()
        for _ in 0..<2 {
            viewModel.showPreviousMonth(using: Calendar.current)
        }
        viewModel.checkAndResetIfNeeded()
        XCTAssertNotNil(viewModel.displayedMonth)
        let nowMonth = Calendar.current.component(.month, from: Date())
        let displayedMonth = Calendar.current.component(.month, from: viewModel.displayedMonth)
        XCTAssertNotEqual(nowMonth, displayedMonth)
    }

    func testCheckAndResetDoesNothingWithin5Minutes() {
        let viewModel = CalendarPopoverViewModel()
        for _ in 0..<2 {
            viewModel.showPreviousMonth(using: Calendar.current)
        }
        viewModel.popoverDidClose()
        viewModel.lastClosedTime = Date().addingTimeInterval(-299)
        viewModel.checkAndResetIfNeeded()
        let nowMonth = Calendar.current.component(.month, from: Date())
        let displayedMonth = Calendar.current.component(.month, from: viewModel.displayedMonth)
        XCTAssertNotEqual(nowMonth, displayedMonth)
    }

    func testCheckAndResetAfter5Minutes() {
        let viewModel = CalendarPopoverViewModel()
        for _ in 0..<2 {
            viewModel.showPreviousMonth(using: Calendar.current)
        }
        viewModel.popoverDidClose()
        viewModel.lastClosedTime = Date().addingTimeInterval(-301)
        viewModel.checkAndResetIfNeeded()
        let nowMonth = Calendar.current.component(.month, from: Date())
        let displayedMonth = Calendar.current.component(.month, from: viewModel.displayedMonth)
        XCTAssertEqual(nowMonth, displayedMonth)
        XCTAssertNotNil(viewModel.selectedDate)
        XCTAssertTrue(Calendar.current.isDate(viewModel.selectedDate!, inSameDayAs: Date()))
        XCTAssertNil(viewModel.lastClosedTime)
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
