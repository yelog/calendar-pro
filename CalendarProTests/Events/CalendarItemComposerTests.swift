import XCTest
import EventKit
@testable import CalendarPro

@MainActor
final class CalendarItemComposerTests: XCTestCase {
    func testEditingMultiDayAllDayEventAndBuildingUnchangedRequestPreservesRange() throws {
        let calendar = utcCalendar
        let start = try makeDate(2026, 11, 18, calendar: calendar)
        let end = try makeDate(2026, 11, 20, calendar: calendar)
        let event = makeEvent(start: start, end: end, isAllDay: true)
        let originalStart = event.startDate
        let originalEnd = event.endDate

        let values = CalendarItemComposerView.initialValues(
            for: .editEvent(event),
            eventCalendars: [],
            reminderCalendars: [],
            calendar: calendar
        )
        let schedule = CalendarEventScheduleDraft(
            startDate: values.startDate,
            endDate: values.endDate,
            isAllDay: values.isAllDay,
            calendar: calendar
        )
        let request = try CalendarEventCreationRequest.make(
            title: "Updated title",
            calendarIdentifier: values.eventCalendarIdentifier,
            schedule: schedule,
            notes: values.notes
        )

        XCTAssertEqual(request.startDate, originalStart)
        XCTAssertEqual(request.endDate, originalEnd)
        XCTAssertTrue(request.isAllDay)
    }

    func testEditingOvernightTimedEventPreservesBothDates() throws {
        let calendar = utcCalendar
        let start = try makeDate(2026, 11, 18, hour: 22, calendar: calendar)
        let end = try makeDate(2026, 11, 19, hour: 9, calendar: calendar)
        let event = makeEvent(start: start, end: end, isAllDay: false)

        let values = CalendarItemComposerView.initialValues(
            for: .editEvent(event),
            eventCalendars: [],
            reminderCalendars: [],
            calendar: calendar
        )
        let schedule = CalendarEventScheduleDraft(
            startDate: values.startDate,
            endDate: values.endDate,
            isAllDay: values.isAllDay,
            calendar: calendar
        )
        let request = try CalendarEventCreationRequest.make(
            title: "Updated title",
            calendarIdentifier: values.eventCalendarIdentifier,
            schedule: schedule,
            notes: values.notes
        )

        XCTAssertEqual(values.startDate, start)
        XCTAssertEqual(values.endDate, end)
        XCTAssertEqual(request.startDate, start)
        XCTAssertEqual(request.endDate, end)
        XCTAssertFalse(values.isAllDay)
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func makeEvent(start: Date, end: Date, isAllDay: Bool) -> EKEvent {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.calendar = EKCalendar(for: .event, eventStore: store)
        event.title = "Planning"
        event.startDate = start
        event.endDate = end
        event.isAllDay = isAllDay
        event.notes = "Original notes"
        return event
    }

    private func makeDate(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int = 0,
        calendar: Calendar,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> Date {
        try XCTUnwrap(
            calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)),
            file: file,
            line: line
        )
    }
}
