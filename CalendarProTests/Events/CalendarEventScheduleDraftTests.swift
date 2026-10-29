import XCTest
@testable import CalendarPro

final class CalendarEventScheduleDraftTests: XCTestCase {
    func testAllDayRangeDisplaysLastCoveredDayAndRoundTripsUnchanged() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))
        let start = try makeDate(2026, 11, 18, calendar: calendar)
        let end = try makeDate(2026, 11, 20, calendar: calendar)
        let draft = CalendarEventScheduleDraft(startDate: start, endDate: end, isAllDay: true, calendar: calendar)

        XCTAssertEqual(draft.displayedEndDate, try makeDate(2026, 11, 19, calendar: calendar))
        XCTAssertEqual(draft.coveredDayCount, 2)
        XCTAssertNil(draft.validationError)
        XCTAssertEqual(draft.startDate, start)
        XCTAssertEqual(draft.endDate, end)
    }

    func testSingleDayAllDayRangeDisplaysStartDay() throws {
        let calendar = utcCalendar
        let start = try makeDate(2026, 11, 18, calendar: calendar)
        let end = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: start))
        let draft = CalendarEventScheduleDraft(startDate: start, endDate: end, isAllDay: true, calendar: calendar)

        XCTAssertEqual(draft.displayedEndDate, start)
        XCTAssertEqual(draft.coveredDayCount, 1)
    }

    func testNonStandardAllDayEndIncludesItsCalendarDayAndPreservesInstant() throws {
        let calendar = utcCalendar
        let start = try makeDate(2026, 11, 18, calendar: calendar)
        let end = try makeDate(2026, 11, 20, hour: 12, calendar: calendar)
        let draft = CalendarEventScheduleDraft(startDate: start, endDate: end, isAllDay: true, calendar: calendar)

        XCTAssertEqual(draft.displayedEndDate, try makeDate(2026, 11, 20, calendar: calendar))
        XCTAssertEqual(draft.coveredDayCount, 3)
        XCTAssertEqual(draft.endDate, end)
    }

    func testAllDayConversionPreservesMidnightEndAsLastCoveredPreviousDay() throws {
        let calendar = utcCalendar
        let start = try makeDate(2026, 11, 18, hour: 22, calendar: calendar)
        let end = try makeDate(2026, 11, 19, calendar: calendar)
        var draft = CalendarEventScheduleDraft(startDate: start, endDate: end, isAllDay: false, calendar: calendar)

        try draft.setAllDay(true)

        XCTAssertEqual(draft.startDate, try makeDate(2026, 11, 18, calendar: calendar))
        XCTAssertEqual(draft.endDate, try makeDate(2026, 11, 19, calendar: calendar))
        XCTAssertEqual(draft.displayedEndDate, try makeDate(2026, 11, 18, calendar: calendar))
        XCTAssertEqual(draft.coveredDayCount, 1)
    }

    func testAllDayEndDateCacheSurvivesSelectingTheSameDay() throws {
        let calendar = utcCalendar
        let start = try makeDate(2026, 11, 18, hour: 9, calendar: calendar)
        let end = try makeDate(2026, 11, 18, hour: 10, calendar: calendar)
        var draft = CalendarEventScheduleDraft(startDate: start, endDate: end, isAllDay: false, calendar: calendar)

        try draft.setAllDay(true)
        try draft.setEndDay(try XCTUnwrap(draft.displayedEndDate))
        try draft.setAllDay(false)

        XCTAssertEqual(draft.startDate, start)
        XCTAssertEqual(draft.endDate, end)
    }

    func testCrossYearAllDayRangeDisplaysCorrectFinalDay() throws {
        let calendar = utcCalendar
        let start = try makeDate(2026, 12, 31, calendar: calendar)
        let end = try makeDate(2027, 1, 3, calendar: calendar)
        let draft = CalendarEventScheduleDraft(startDate: start, endDate: end, isAllDay: true, calendar: calendar)

        XCTAssertEqual(draft.displayedEndDate, try makeDate(2027, 1, 2, calendar: calendar))
        XCTAssertEqual(draft.coveredDayCount, 3)
    }

    func testMovingAllDayStartPreservesCoveredDayCount() throws {
        let calendar = utcCalendar
        let start = try makeDate(2026, 11, 18, calendar: calendar)
        let end = try makeDate(2026, 11, 20, calendar: calendar)
        var draft = CalendarEventScheduleDraft(startDate: start, endDate: end, isAllDay: true, calendar: calendar)

        try draft.setStartDay(makeDate(2026, 11, 20, calendar: calendar))

        XCTAssertEqual(draft.startDate, try makeDate(2026, 11, 20, calendar: calendar))
        XCTAssertEqual(draft.displayedEndDate, try makeDate(2026, 11, 21, calendar: calendar))
        XCTAssertEqual(draft.endDate, try makeDate(2026, 11, 22, calendar: calendar))
        XCTAssertEqual(draft.coveredDayCount, 2)
    }

    func testChangingAllDayEndUsesExclusiveNextDayBoundary() throws {
        let calendar = utcCalendar
        let start = try makeDate(2026, 11, 18, calendar: calendar)
        let end = try makeDate(2026, 11, 20, calendar: calendar)
        var draft = CalendarEventScheduleDraft(startDate: start, endDate: end, isAllDay: true, calendar: calendar)

        try draft.setEndDay(makeDate(2026, 11, 21, calendar: calendar))

        XCTAssertEqual(draft.displayedEndDate, try makeDate(2026, 11, 21, calendar: calendar))
        XCTAssertEqual(draft.endDate, try makeDate(2026, 11, 22, calendar: calendar))
        XCTAssertEqual(draft.coveredDayCount, 4)
    }

    func testInvalidAllDayEndKeepsTheSelectedCoveredDayVisible() throws {
        let calendar = utcCalendar
        let start = try makeDate(2026, 11, 18, calendar: calendar)
        let end = try makeDate(2026, 11, 20, calendar: calendar)
        var draft = CalendarEventScheduleDraft(startDate: start, endDate: end, isAllDay: true, calendar: calendar)

        try draft.setEndDay(makeDate(2026, 11, 16, calendar: calendar))

        XCTAssertEqual(draft.displayedEndDate, try makeDate(2026, 11, 16, calendar: calendar))
        XCTAssertEqual(draft.endDate, try makeDate(2026, 11, 17, calendar: calendar))
        XCTAssertNil(draft.coveredDayCount)
        XCTAssertEqual(draft.validationError, .invalidAllDayRange)
    }

    func testMovingTimedStartDayPreservesBothLocalTimes() throws {
        let calendar = utcCalendar
        let start = try makeDate(2026, 11, 18, hour: 22, calendar: calendar)
        let end = try makeDate(2026, 11, 19, hour: 9, calendar: calendar)
        var draft = CalendarEventScheduleDraft(startDate: start, endDate: end, isAllDay: false, calendar: calendar)

        try draft.setStartDay(makeDate(2026, 11, 19, calendar: calendar))

        XCTAssertEqual(draft.startDate, try makeDate(2026, 11, 19, hour: 22, calendar: calendar))
        XCTAssertEqual(draft.endDate, try makeDate(2026, 11, 20, hour: 9, calendar: calendar))
    }

    func testMovingTimedStartTimePreservesElapsedDuration() throws {
        let calendar = utcCalendar
        let start = try makeDate(2026, 11, 18, hour: 10, calendar: calendar)
        let end = try makeDate(2026, 11, 18, hour: 11, calendar: calendar)
        var draft = CalendarEventScheduleDraft(startDate: start, endDate: end, isAllDay: false, calendar: calendar)

        try draft.setStartTime(hour: 23, minute: 0)

        XCTAssertEqual(draft.startDate, try makeDate(2026, 11, 18, hour: 23, calendar: calendar))
        XCTAssertEqual(draft.endDate, try makeDate(2026, 11, 19, hour: 0, calendar: calendar))
    }

    func testDirectEndEditCanRemainInvalidAndStartEditCanCorrectIt() throws {
        let calendar = utcCalendar
        let start = try makeDate(2026, 11, 18, hour: 10, calendar: calendar)
        let end = try makeDate(2026, 11, 18, hour: 11, calendar: calendar)
        var draft = CalendarEventScheduleDraft(startDate: start, endDate: end, isAllDay: false, calendar: calendar)

        try draft.setEndTime(hour: 9, minute: 0)
        XCTAssertEqual(draft.validationError, .endMustBeAfterStart)
        XCTAssertEqual(draft.endDate, try makeDate(2026, 11, 18, hour: 9, calendar: calendar))

        try draft.setStartTime(hour: 8, minute: 0)
        XCTAssertNil(draft.validationError)
        XCTAssertEqual(draft.endDate, try makeDate(2026, 11, 18, hour: 9, calendar: calendar))
    }

    func testSelectingCurrentDayDoesNotDiscardSeconds() throws {
        let calendar = utcCalendar
        let start = try makeDate(2026, 11, 18, hour: 10, minute: 15, second: 42, calendar: calendar)
        let end = try makeDate(2026, 11, 18, hour: 11, minute: 15, second: 42, calendar: calendar)
        var draft = CalendarEventScheduleDraft(startDate: start, endDate: end, isAllDay: false, calendar: calendar)

        try draft.setStartDay(start)
        try draft.setEndDay(end)
        try draft.setStartTime(hour: 10, minute: 15)
        try draft.setEndTime(hour: 11, minute: 15)

        XCTAssertEqual(draft.startDate, start)
        XCTAssertEqual(draft.endDate, end)
    }

    func testTimedAllDayTimedToggleRestoresOriginalInstants() throws {
        let calendar = utcCalendar
        let start = try makeDate(2026, 11, 18, hour: 22, minute: 10, second: 37, calendar: calendar)
        let end = try makeDate(2026, 11, 19, hour: 9, minute: 10, second: 37, calendar: calendar)
        var draft = CalendarEventScheduleDraft(startDate: start, endDate: end, isAllDay: false, calendar: calendar)

        try draft.setAllDay(true)
        XCTAssertEqual(draft.startDate, try makeDate(2026, 11, 18, calendar: calendar))
        XCTAssertEqual(draft.endDate, try makeDate(2026, 11, 20, calendar: calendar))
        try draft.setAllDay(false)

        XCTAssertEqual(draft.startDate, start)
        XCTAssertEqual(draft.endDate, end)
    }

    func testTimedEventEndingAtMidnightDoesNotAddAnExtraAllDay() throws {
        let calendar = utcCalendar
        let start = try makeDate(2026, 11, 18, hour: 22, calendar: calendar)
        let end = try makeDate(2026, 11, 19, calendar: calendar)
        var draft = CalendarEventScheduleDraft(startDate: start, endDate: end, isAllDay: false, calendar: calendar)

        try draft.setAllDay(true)

        XCTAssertEqual(draft.startDate, try makeDate(2026, 11, 18, calendar: calendar))
        XCTAssertEqual(draft.endDate, try makeDate(2026, 11, 19, calendar: calendar))
        XCTAssertEqual(draft.coveredDayCount, 1)
    }

    func testChangingAllDayDateInvalidatesTimedRangeCache() throws {
        let calendar = utcCalendar
        let start = try makeDate(2026, 11, 18, hour: 9, calendar: calendar)
        let end = try makeDate(2026, 11, 18, hour: 10, calendar: calendar)
        var draft = CalendarEventScheduleDraft(startDate: start, endDate: end, isAllDay: false, calendar: calendar)

        try draft.setAllDay(true)
        try draft.setStartDay(makeDate(2026, 11, 19, calendar: calendar))
        try draft.setAllDay(false)

        XCTAssertEqual(draft.startDate, try makeDate(2026, 11, 19, hour: 9, calendar: calendar))
        XCTAssertEqual(draft.endDate, try makeDate(2026, 11, 19, hour: 10, calendar: calendar))
    }

    func testInvalidRangeCannotBeConvertedToAllDay() throws {
        let calendar = utcCalendar
        let start = try makeDate(2026, 11, 18, hour: 10, calendar: calendar)
        let end = try makeDate(2026, 11, 18, hour: 9, calendar: calendar)
        var draft = CalendarEventScheduleDraft(startDate: start, endDate: end, isAllDay: false, calendar: calendar)

        XCTAssertThrowsError(try draft.setAllDay(true))
        XCTAssertFalse(draft.isAllDay)
        XCTAssertEqual(draft.startDate, start)
        XCTAssertEqual(draft.endDate, end)
    }

    func testSpringForwardNonexistentTimeIsRejectedAtomically() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let start = try makeDate(2026, 3, 8, hour: 1, minute: 30, calendar: calendar)
        let end = try makeDate(2026, 3, 8, hour: 3, minute: 30, calendar: calendar)
        var draft = CalendarEventScheduleDraft(startDate: start, endDate: end, isAllDay: false, calendar: calendar)

        XCTAssertThrowsError(try draft.setStartTime(hour: 2, minute: 30)) {
            XCTAssertEqual($0 as? CalendarEventScheduleError, .localTimeDoesNotExist)
        }
        XCTAssertEqual(draft.startDate, start)
        XCTAssertEqual(draft.endDate, end)
    }

    func testMovingAllDayRangeAcrossFallBackKeepsCalendarBoundaries() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let start = try makeDate(2026, 10, 31, calendar: calendar)
        let end = try makeDate(2026, 11, 2, calendar: calendar)
        var draft = CalendarEventScheduleDraft(startDate: start, endDate: end, isAllDay: true, calendar: calendar)

        try draft.setStartDay(makeDate(2026, 11, 1, calendar: calendar))

        XCTAssertEqual(draft.coveredDayCount, 2)
        XCTAssertEqual(calendar.component(.hour, from: draft.startDate), 0)
        XCTAssertEqual(calendar.component(.hour, from: draft.endDate), 0)
        XCTAssertEqual(draft.displayedEndDate, try makeDate(2026, 11, 2, calendar: calendar))
        XCTAssertEqual(draft.endDate, try makeDate(2026, 11, 3, calendar: calendar))
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func makeDate(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int = 0,
        minute: Int = 0,
        second: Int = 0,
        calendar: Calendar,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> Date {
        try XCTUnwrap(
            calendar.date(from: DateComponents(
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute,
                second: second
            )),
            file: file,
            line: line
        )
    }
}
