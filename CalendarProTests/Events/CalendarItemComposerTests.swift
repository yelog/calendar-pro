import XCTest
import EventKit
@testable import CalendarPro

@MainActor
final class CalendarItemComposerTests: XCTestCase {
    func testEditingMultiDayAllDayEventAndBuildingUnchangedRequestPreservesRange() throws {
        let calendar = makeCalendar("America/Los_Angeles")
        let sourceCalendar = CalendarItemDateResolver.systemCalendar
        let start = try makeDate(2026, 11, 18, calendar: sourceCalendar)
        let end = try makeDate(2026, 11, 20, calendar: sourceCalendar)
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
            notes: values.notes,
            calendar: calendar,
            datesChanged: !values.matchesEventSchedule(schedule)
        )
        request.applySchedule(to: event)

        XCTAssertEqual(values.startDate, try makeDate(2026, 11, 18, calendar: calendar))
        XCTAssertEqual(event.startDate, originalStart)
        XCTAssertEqual(event.endDate, originalEnd)
        XCTAssertNil(event.timeZone)
        XCTAssertFalse(request.datesChanged)
        XCTAssertTrue(request.isAllDay)
    }

    func testEditingOvernightTimedEventPreservesBothDates() throws {
        let calendar = utcCalendar
        let start = try makeDate(2026, 11, 18, hour: 22, calendar: calendar)
        let end = try makeDate(2026, 11, 19, hour: 9, calendar: calendar)
        let event = makeEvent(start: start, end: end, isAllDay: false, timeZone: calendar.timeZone)

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
            notes: values.notes,
            calendar: calendar,
            datesChanged: !values.matchesEventSchedule(schedule)
        )

        XCTAssertEqual(values.startDate, start)
        XCTAssertEqual(values.endDate, end)
        XCTAssertEqual(request.startDate, start)
        XCTAssertEqual(request.endDate, end)
        XCTAssertFalse(request.datesChanged)
        XCTAssertFalse(values.isAllDay)
    }

    func testEditingFloatingEventUsesEditorWallTimeAndPreservesUnchangedSourceDates() throws {
        let sourceCalendar = CalendarItemDateResolver.systemCalendar
        let calendar = makeCalendar("America/Los_Angeles")
        let event = makeEvent(
            start: try makeDate(2026, 11, 18, hour: 22, calendar: sourceCalendar),
            end: try makeDate(2026, 11, 19, hour: 9, calendar: sourceCalendar),
            isAllDay: false
        )
        let originalStart = event.startDate
        let originalEnd = event.endDate
        let values = initialValues(for: .editEvent(event), calendar: calendar)
        let schedule = makeSchedule(from: values, calendar: calendar)
        let request = try makeEventRequest(from: values, schedule: schedule)

        XCTAssertEqual(values.startDate, try makeDate(2026, 11, 18, hour: 22, calendar: calendar))
        XCTAssertEqual(values.endDate, try makeDate(2026, 11, 19, hour: 9, calendar: calendar))
        XCTAssertFalse(request.datesChanged)

        request.applySchedule(to: event)

        XCTAssertEqual(event.startDate, originalStart)
        XCTAssertEqual(event.endDate, originalEnd)
        XCTAssertNil(event.timeZone)
    }

    func testEditingFixedTimedEventInAnotherTimeZonePreservesInstantAndOriginalTimeZone() throws {
        let calendar = makeCalendar("America/Los_Angeles")
        let timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))
        let start = try makeDate(2026, 11, 18, calendar: utcCalendar)
        let end = try makeDate(2026, 11, 18, hour: 1, calendar: utcCalendar)
        let event = makeEvent(start: start, end: end, isAllDay: false, timeZone: timeZone)
        let values = initialValues(for: .editEvent(event), calendar: calendar)
        let request = try makeEventRequest(from: values, schedule: makeSchedule(from: values, calendar: calendar))

        XCTAssertEqual(values.startDate, start)
        XCTAssertEqual(calendar.component(.day, from: values.startDate), 17)
        XCTAssertEqual(calendar.component(.hour, from: values.startDate), 16)
        XCTAssertEqual(request.calendar.timeZone.identifier, "America/Los_Angeles")
        XCTAssertFalse(request.datesChanged)

        request.applySchedule(to: event)

        XCTAssertEqual(event.startDate, start)
        XCTAssertEqual(event.endDate, end)
        XCTAssertEqual(event.timeZone, timeZone)
    }

    func testChangedFloatingEventDatesAreWrittenAsSourceWallTime() throws {
        let sourceCalendar = CalendarItemDateResolver.systemCalendar
        let calendar = makeCalendar("America/Los_Angeles")
        let event = makeEvent(
            start: try makeDate(2026, 11, 18, hour: 9, calendar: sourceCalendar),
            end: try makeDate(2026, 11, 18, hour: 10, calendar: sourceCalendar),
            isAllDay: false
        )
        let values = initialValues(for: .editEvent(event), calendar: calendar)
        var schedule = makeSchedule(from: values, calendar: calendar)
        try schedule.setStartDay(makeDate(2026, 11, 19, calendar: calendar))
        let request = try makeEventRequest(from: values, schedule: schedule)

        XCTAssertTrue(request.datesChanged)
        request.applySchedule(to: event)

        XCTAssertEqual(event.startDate, try makeDate(2026, 11, 19, hour: 9, calendar: sourceCalendar))
        XCTAssertEqual(event.endDate, try makeDate(2026, 11, 19, hour: 10, calendar: sourceCalendar))
        XCTAssertNil(event.timeZone)
    }

    func testEditingDateOnlyReminderPreservesOriginalComponentsForTextOnlySave() throws {
        let calendar = makeCalendar("America/Los_Angeles")
        let sourceCalendar = makeCalendar("Asia/Shanghai")
        var components = DateComponents(year: 2026, month: 11, day: 18)
        components.calendar = sourceCalendar
        components.timeZone = sourceCalendar.timeZone
        let reminder = makeReminder(components: components)
        let originalComponents = reminder.dueDateComponents
        let values = initialValues(for: .editReminder(reminder), calendar: calendar)
        let request = makeReminderRequest(from: values, calendar: calendar)

        XCTAssertEqual(values.dueDate, try makeDate(2026, 11, 18, calendar: calendar))
        XCTAssertFalse(values.reminderIncludesTime)
        XCTAssertFalse(request.datesChanged)

        request.applySchedule(to: reminder)

        XCTAssertEqual(reminder.dueDateComponents, originalComponents)
    }

    func testEditingFloatingReminderUsesEditorWallTimeAndPreservesOriginalComponents() throws {
        let calendar = makeCalendar("America/Los_Angeles")
        let components = DateComponents(year: 2026, month: 11, day: 18, hour: 9, minute: 30, second: 15)
        let reminder = makeReminder(components: components)
        let originalComponents = reminder.dueDateComponents
        let values = initialValues(for: .editReminder(reminder), calendar: calendar)
        let request = makeReminderRequest(from: values, calendar: calendar)

        XCTAssertEqual(values.dueDate, try makeDate(2026, 11, 18, hour: 9, minute: 30, second: 15, calendar: calendar))
        XCTAssertTrue(values.reminderIncludesTime)
        XCTAssertFalse(request.datesChanged)

        request.applySchedule(to: reminder)

        XCTAssertEqual(reminder.dueDateComponents, originalComponents)
        XCTAssertNil(reminder.dueDateComponents?.timeZone)
    }

    func testChangedFloatingReminderDateKeepsWallTimeWithoutAddingTimeZone() throws {
        let calendar = makeCalendar("America/Los_Angeles")
        let reminder = makeReminder(components: DateComponents(year: 2026, month: 11, day: 18, hour: 9, minute: 30))
        let values = initialValues(for: .editReminder(reminder), calendar: calendar)
        let changedDate = try makeDate(2026, 11, 19, hour: 10, minute: 45, calendar: calendar)
        let request = makeReminderRequest(from: values, dueDate: changedDate, calendar: calendar)

        XCTAssertTrue(request.datesChanged)
        request.applySchedule(to: reminder)

        let components = try XCTUnwrap(reminder.dueDateComponents)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 11)
        XCTAssertEqual(components.day, 19)
        XCTAssertEqual(components.hour, 10)
        XCTAssertEqual(components.minute, 45)
        XCTAssertNil(components.timeZone)
    }

    func testUndatedReminderKeepsNoDueDateWhenOnlyTextChanges() {
        let calendar = makeCalendar("Asia/Shanghai")
        let reminder = makeReminder(components: nil)
        let values = initialValues(for: .editReminder(reminder), calendar: calendar)
        let request = makeReminderRequest(from: values, calendar: calendar)

        XCTAssertFalse(request.datesChanged)
        request.applySchedule(to: reminder)

        XCTAssertNil(reminder.dueDateComponents)
    }

    func testComposerKeepsOpenedCalendarAfterAppTimeZoneChanges() throws {
        let suiteName = "CalendarItemComposerTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settingsStore = SettingsStore(
            userDefaults: defaults,
            launchAtLoginController: ComposerLaunchAtLoginController()
        )
        settingsStore.setTimeZoneIdentifier("Asia/Shanghai")
        settingsStore.setWeekStart(.monday)
        let selectedDate = try makeDate(2026, 11, 18, calendar: settingsStore.displayCalendar)
        let view = CalendarItemComposerView(
            mode: .create(kind: .event, selectedDate: selectedDate, initialTimeRange: nil),
            eventCalendars: [],
            reminderCalendars: [],
            calendar: settingsStore.displayCalendar,
            onSaveEvent: { _ in },
            onSaveReminder: { _ in },
            onClose: {}
        )

        settingsStore.setTimeZoneIdentifier("America/Los_Angeles")
        settingsStore.setWeekStart(.sunday)

        XCTAssertEqual(view.editingCalendar.timeZone.identifier, "Asia/Shanghai")
        XCTAssertEqual(view.editingCalendar.firstWeekday, 2)
        XCTAssertEqual(settingsStore.displayCalendar.timeZone.identifier, "America/Los_Angeles")
        XCTAssertEqual(view.editingCalendar.component(.day, from: selectedDate), 18)
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func makeCalendar(_ timeZoneIdentifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier)!
        return calendar
    }

    private func initialValues(for mode: CalendarItemComposerMode, calendar: Calendar) -> CalendarItemComposerView.InitialValues {
        CalendarItemComposerView.initialValues(
            for: mode,
            eventCalendars: [],
            reminderCalendars: [],
            calendar: calendar
        )
    }

    private func makeSchedule(
        from values: CalendarItemComposerView.InitialValues,
        calendar: Calendar
    ) -> CalendarEventScheduleDraft {
        CalendarEventScheduleDraft(
            startDate: values.startDate,
            endDate: values.endDate,
            isAllDay: values.isAllDay,
            calendar: calendar
        )
    }

    private func makeEventRequest(
        from values: CalendarItemComposerView.InitialValues,
        schedule: CalendarEventScheduleDraft
    ) throws -> CalendarEventCreationRequest {
        try CalendarEventCreationRequest.make(
            title: "Updated title",
            calendarIdentifier: values.eventCalendarIdentifier,
            schedule: schedule,
            notes: "Updated notes",
            calendar: schedule.calendar,
            datesChanged: !values.matchesEventSchedule(schedule)
        )
    }

    private func makeReminderRequest(
        from values: CalendarItemComposerView.InitialValues,
        dueDate: Date? = nil,
        calendar: Calendar
    ) -> ReminderCreationRequest {
        let dueDate = dueDate ?? values.dueDate
        return ReminderCreationRequest(
            title: "Updated title",
            calendarIdentifier: values.reminderCalendarIdentifier,
            dueDate: dueDate,
            includesTime: values.reminderIncludesTime,
            notes: "Updated notes",
            calendar: calendar,
            datesChanged: !values.matchesReminderSchedule(dueDate: dueDate, includesTime: values.reminderIncludesTime)
        )
    }

    private func makeEvent(start: Date, end: Date, isAllDay: Bool, timeZone: TimeZone? = nil) -> EKEvent {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.calendar = EKCalendar(for: .event, eventStore: store)
        event.title = "Planning"
        event.timeZone = timeZone
        event.startDate = start
        event.endDate = end
        event.isAllDay = isAllDay
        event.notes = "Original notes"
        return event
    }

    private func makeReminder(components: DateComponents?) -> EKReminder {
        let store = EKEventStore()
        let reminder = EKReminder(eventStore: store)
        reminder.calendar = EKCalendar(for: .reminder, eventStore: store)
        reminder.title = "Planning"
        reminder.notes = "Original notes"
        reminder.dueDateComponents = components
        return reminder
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
            calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second)),
            file: file,
            line: line
        )
    }
}

private final class ComposerLaunchAtLoginController: LaunchAtLoginControlling {
    func status() -> LaunchAtLoginStatus { .enabled }
    func setEnabled(_ enabled: Bool) throws {}
}
