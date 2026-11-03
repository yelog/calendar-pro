import XCTest
import EventKit
@testable import CalendarPro

@MainActor
final class EventServiceTests: XCTestCase {
    func testInitialAuthorizationStatusIsNotDetermined() {
        let service = EventService()
        XCTAssertEqual(service.authorizationStatus, .notDetermined)
    }
    
    func testIsAuthorizedInitiallyFalse() {
        let service = EventService()
        XCTAssertFalse(service.isAuthorized)
    }
    
    func testStoreChangeRevisionInitiallyZero() {
        let service = EventService()
        XCTAssertEqual(service.storeChangeRevision, 0)
    }
    
    func testStoreChangeRevisionIncrementsOnNotification() async {
        let service = EventService()
        
        NotificationCenter.default.post(
            name: .EKEventStoreChanged,
            object: nil
        )
        
        // Wait for debounce (300ms) + margin
        try? await Task.sleep(for: .milliseconds(500))
        
        XCTAssertEqual(service.storeChangeRevision, 1)
    }

    func testDefaultEventRequestUsesSelectedFutureDayAtNine() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 4, day: 28, hour: 14))!
        let selectedDate = calendar.date(from: DateComponents(year: 2026, month: 5, day: 2))!

        let request = CalendarEventCreationRequest.makeDefault(
            selectedDate: selectedDate,
            calendarIdentifier: "work",
            calendar: calendar,
            now: now
        )

        XCTAssertEqual(request.calendarIdentifier, "work")
        XCTAssertEqual(calendar.component(.hour, from: request.startDate), 9)
        XCTAssertEqual(calendar.component(.hour, from: request.endDate), 10)
        XCTAssertFalse(request.isAllDay)
    }

    func testDefaultReminderRequestUsesNextHourForToday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 4, day: 28, hour: 14, minute: 30))!
        let selectedDate = calendar.date(from: DateComponents(year: 2026, month: 4, day: 28))!

        let request = ReminderCreationRequest.makeDefault(
            selectedDate: selectedDate,
            calendarIdentifier: "tasks",
            calendar: calendar,
            now: now
        )

        XCTAssertEqual(request.calendarIdentifier, "tasks")
        XCTAssertEqual(calendar.component(.hour, from: request.dueDate), 15)
        XCTAssertEqual(calendar.component(.minute, from: request.dueDate), 0)
        XCTAssertTrue(request.includesTime)
    }

    func testComposerInitialValuesUseTimelineRangeForEventAndReminder() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let selectedDate = calendar.date(from: DateComponents(year: 2026, month: 4, day: 29))!
        let startDate = calendar.date(from: DateComponents(year: 2026, month: 4, day: 29, hour: 10, minute: 30))!
        let endDate = calendar.date(from: DateComponents(year: 2026, month: 4, day: 29, hour: 11))!
        let timeRange = CalendarItemCreationTimeRange(startDate: startDate, endDate: endDate)

        let values = CalendarItemComposerView.initialValues(
            for: .create(kind: .event, selectedDate: selectedDate, initialTimeRange: timeRange),
            eventCalendars: [],
            reminderCalendars: [],
            calendar: calendar,
            now: selectedDate
        )

        XCTAssertEqual(values.kind, .event)
        XCTAssertEqual(values.startDate, startDate)
        XCTAssertEqual(values.endDate, endDate)
        XCTAssertEqual(values.dueDate, startDate)
        XCTAssertTrue(values.reminderIncludesTime)
    }

    func testComposerInitialValuesWithoutTimelineRangeKeepDefaultTimes() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let selectedDate = calendar.date(from: DateComponents(year: 2026, month: 4, day: 29))!
        let now = calendar.date(from: DateComponents(year: 2026, month: 4, day: 28, hour: 15))!

        let values = CalendarItemComposerView.initialValues(
            for: .create(kind: .event, selectedDate: selectedDate, initialTimeRange: nil),
            eventCalendars: [],
            reminderCalendars: [],
            calendar: calendar,
            now: now
        )

        XCTAssertEqual(calendar.component(.hour, from: values.startDate), 9)
        XCTAssertEqual(calendar.component(.hour, from: values.endDate), 10)
        XCTAssertEqual(calendar.component(.hour, from: values.dueDate), 9)
        XCTAssertTrue(values.reminderIncludesTime)
    }

    func testEditingEventRequestPreservesExistingValues() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let startDate = calendar.date(from: DateComponents(year: 2026, month: 4, day: 29, hour: 9))!
        let endDate = calendar.date(from: DateComponents(year: 2026, month: 4, day: 29, hour: 10))!
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.calendar = EKCalendar(for: .event, eventStore: store)
        event.title = "Planning"
        event.startDate = startDate
        event.endDate = endDate
        event.timeZone = calendar.timeZone
        event.isAllDay = false
        event.notes = "Room 1"

        let request = CalendarEventCreationRequest.makeEditing(event, calendar: calendar)

        XCTAssertEqual(request.title, "Planning")
        XCTAssertEqual(request.calendarIdentifier, event.calendar.calendarIdentifier)
        XCTAssertEqual(request.startDate, startDate)
        XCTAssertEqual(request.endDate, endDate)
        XCTAssertFalse(request.isAllDay)
        XCTAssertEqual(request.notes, "Room 1")
    }

    func testEventScheduleValidationRejectsEndBeforeOrEqualToStart() throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        for end in [start.addingTimeInterval(-60), start] {
            let request = CalendarEventCreationRequest(
                title: "Invalid",
                calendarIdentifier: "calendar",
                startDate: start,
                endDate: end,
                isAllDay: false,
                notes: nil
            )
            XCTAssertThrowsError(try request.validateSchedule()) {
                XCTAssertEqual($0 as? CalendarEventScheduleError, .endMustBeAfterStart)
            }
        }
    }

    func testEventScheduleValidationAcceptsOvernightAndMultiDayAllDayRanges() throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let overnightRequest = CalendarEventCreationRequest(
            title: "Overnight",
            calendarIdentifier: "calendar",
            startDate: start,
            endDate: start.addingTimeInterval(11 * 60 * 60),
            isAllDay: false,
            notes: nil
        )
        let allDayRequest = CalendarEventCreationRequest(
            title: "Multi-day",
            calendarIdentifier: "calendar",
            startDate: start,
            endDate: start.addingTimeInterval(48 * 60 * 60),
            isAllDay: true,
            notes: nil
        )

        XCTAssertNoThrow(try overnightRequest.validateSchedule())
        XCTAssertNoThrow(try allDayRequest.validateSchedule())
    }

    func testEventScheduleValidationAcceptsNonStandardAllDayEndWithoutNormalization() throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let end = start.addingTimeInterval(60 * 60 * 37)
        let request = CalendarEventCreationRequest(
            title: "Imported range",
            calendarIdentifier: "calendar",
            startDate: start,
            endDate: end,
            isAllDay: true,
            notes: nil
        )

        XCTAssertNoThrow(try request.validateSchedule())
        XCTAssertEqual(request.startDate, start)
        XCTAssertEqual(request.endDate, end)
    }

    func testEditingReminderRequestPreservesDueTimeAndNotes() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let store = EKEventStore()
        let reminder = EKReminder(eventStore: store)
        reminder.calendar = EKCalendar(for: .reminder, eventStore: store)
        reminder.title = "test todo"
        reminder.notes = "Follow up"
        reminder.dueDateComponents = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 4,
            day: 29,
            hour: 14,
            minute: 0
        )

        let request = ReminderCreationRequest.makeEditing(reminder, calendar: calendar)

        XCTAssertEqual(request.title, "test todo")
        XCTAssertEqual(request.calendarIdentifier, reminder.calendar.calendarIdentifier)
        XCTAssertEqual(calendar.component(.day, from: request.dueDate), 29)
        XCTAssertEqual(calendar.component(.hour, from: request.dueDate), 14)
        XCTAssertEqual(calendar.component(.minute, from: request.dueDate), 0)
        XCTAssertTrue(request.includesTime)
        XCTAssertEqual(request.notes, "Follow up")
    }

    func testReminderDueDateMatchingRejectsPreviousDayReminder() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let selectedDate = calendar.date(from: DateComponents(year: 2026, month: 4, day: 29))!

        let reminder = EKReminder(eventStore: EKEventStore())
        reminder.title = "test todo"
        reminder.dueDateComponents = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 4,
            day: 28,
            hour: 14,
            minute: 0
        )

        XCTAssertFalse(EventService.reminder(reminder, isDueOn: selectedDate, calendar: calendar))
    }

    func testReminderDueDateMatchingAcceptsSelectedDayReminder() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let selectedDate = calendar.date(from: DateComponents(year: 2026, month: 4, day: 29))!

        let reminder = EKReminder(eventStore: EKEventStore())
        reminder.title = "test todo"
        reminder.dueDateComponents = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 4,
            day: 29,
            hour: 14,
            minute: 0
        )

        XCTAssertTrue(EventService.reminder(reminder, isDueOn: selectedDate, calendar: calendar))
    }

    func testDailyRecurringReminderMatchesFutureDate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let originalDate = calendar.date(from: DateComponents(year: 2026, month: 4, day: 1))!
        let targetDate = calendar.date(from: DateComponents(year: 2026, month: 4, day: 15))!

        let reminder = EKReminder(eventStore: EKEventStore())
        reminder.title = "daily task"
        reminder.dueDateComponents = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 4,
            day: 1,
            hour: 9,
            minute: 0
        )
        reminder.recurrenceRules = [EKRecurrenceRule(
            recurrenceWith: .daily,
            interval: 1,
            end: nil
        )]

        XCTAssertTrue(EventService.reminder(reminder, isDueOn: targetDate, calendar: calendar))
    }

    func testDailyRecurringReminderDoesNotMatchBeforeOriginalDate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let originalDate = calendar.date(from: DateComponents(year: 2026, month: 4, day: 15))!
        let targetDate = calendar.date(from: DateComponents(year: 2026, month: 4, day: 10))!

        let reminder = EKReminder(eventStore: EKEventStore())
        reminder.title = "daily task"
        reminder.dueDateComponents = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 4,
            day: 15,
            hour: 9,
            minute: 0
        )
        reminder.recurrenceRules = [EKRecurrenceRule(
            recurrenceWith: .daily,
            interval: 1,
            end: nil
        )]

        XCTAssertFalse(EventService.reminder(reminder, isDueOn: targetDate, calendar: calendar))
    }

    func testEveryOtherDayRecurringReminderMatchesCorrectDays() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let targetDateMatch = calendar.date(from: DateComponents(year: 2026, month: 4, day: 11))!
        let targetDateNoMatch = calendar.date(from: DateComponents(year: 2026, month: 4, day: 12))!

        let reminder = EKReminder(eventStore: EKEventStore())
        reminder.title = "every other day"
        reminder.dueDateComponents = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 4,
            day: 1,
            hour: 9,
            minute: 0
        )
        reminder.recurrenceRules = [EKRecurrenceRule(
            recurrenceWith: .daily,
            interval: 2,
            end: nil
        )]

        XCTAssertTrue(EventService.reminder(reminder, isDueOn: targetDateMatch, calendar: calendar))
        XCTAssertFalse(EventService.reminder(reminder, isDueOn: targetDateNoMatch, calendar: calendar))
    }

    func testWeeklyRecurringReminderMatchesCorrectDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let targetDateMatch = calendar.date(from: DateComponents(year: 2026, month: 4, day: 29))!
        let targetDateNoMatch = calendar.date(from: DateComponents(year: 2026, month: 4, day: 30))!

        let reminder = EKReminder(eventStore: EKEventStore())
        reminder.title = "weekly task"
        reminder.dueDateComponents = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 4,
            day: 22,
            hour: 9,
            minute: 0
        )
        reminder.recurrenceRules = [EKRecurrenceRule(
            recurrenceWith: .weekly,
            interval: 1,
            end: nil
        )]

        XCTAssertTrue(EventService.reminder(reminder, isDueOn: targetDateMatch, calendar: calendar))
        XCTAssertFalse(EventService.reminder(reminder, isDueOn: targetDateNoMatch, calendar: calendar))
    }

    func testMonthlyRecurringReminderMatchesCorrectDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let targetDateMatch = calendar.date(from: DateComponents(year: 2026, month: 5, day: 15))!
        let targetDateNoMatch = calendar.date(from: DateComponents(year: 2026, month: 5, day: 16))!

        let reminder = EKReminder(eventStore: EKEventStore())
        reminder.title = "monthly task"
        reminder.dueDateComponents = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 1,
            day: 15,
            hour: 9,
            minute: 0
        )
        reminder.recurrenceRules = [EKRecurrenceRule(
            recurrenceWith: .monthly,
            interval: 1,
            end: nil
        )]

        XCTAssertTrue(EventService.reminder(reminder, isDueOn: targetDateMatch, calendar: calendar))
        XCTAssertFalse(EventService.reminder(reminder, isDueOn: targetDateNoMatch, calendar: calendar))
    }

    func testRecurringReminderWithOccurrenceCountEnd() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let withinCount = calendar.date(from: DateComponents(year: 2026, month: 4, day: 5))!
        let beyondCount = calendar.date(from: DateComponents(year: 2026, month: 4, day: 6))!

        let reminder = EKReminder(eventStore: EKEventStore())
        reminder.title = "limited daily"
        reminder.dueDateComponents = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 4,
            day: 1,
            hour: 9,
            minute: 0
        )
        reminder.recurrenceRules = [EKRecurrenceRule(
            recurrenceWith: .daily,
            interval: 1,
            end: EKRecurrenceEnd(occurrenceCount: 5)
        )]

        XCTAssertTrue(EventService.reminder(reminder, isDueOn: withinCount, calendar: calendar))
        XCTAssertFalse(EventService.reminder(reminder, isDueOn: beyondCount, calendar: calendar))
    }

    func testRecurringReminderWithEndDateBoundary() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let onEndDate = calendar.date(from: DateComponents(year: 2026, month: 4, day: 10))!
        let afterEndDate = calendar.date(from: DateComponents(year: 2026, month: 4, day: 11))!
        let endDate = calendar.date(from: DateComponents(year: 2026, month: 4, day: 10))!

        let reminder = EKReminder(eventStore: EKEventStore())
        reminder.title = "ending daily"
        reminder.dueDateComponents = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 4,
            day: 1,
            hour: 9,
            minute: 0
        )
        reminder.recurrenceRules = [EKRecurrenceRule(
            recurrenceWith: .daily,
            interval: 1,
            end: EKRecurrenceEnd(end: endDate)
        )]

        XCTAssertTrue(EventService.reminder(reminder, isDueOn: onEndDate, calendar: calendar))
        XCTAssertFalse(EventService.reminder(reminder, isDueOn: afterEndDate, calendar: calendar))
    }

    func testEventQueryWindowCoversAppAndSystemCivilDayRepresentations() {
        let shanghai = makeCalendar("Asia/Shanghai")
        let losAngeles = makeCalendar("America/Los_Angeles")
        let appStart = makeDate(2027, 1, 1, calendar: shanghai)
        let appEnd = shanghai.date(byAdding: .day, value: 1, to: appStart)!
        let systemStart = makeDate(2027, 1, 1, calendar: losAngeles)
        let systemEnd = losAngeles.date(byAdding: .day, value: 1, to: systemStart)!

        let window = CalendarItemDateResolver.queryWindow(
            from: appStart,
            through: appEnd,
            calendar: shanghai,
            systemCalendar: losAngeles
        )

        XCTAssertEqual(window.start, min(appStart, systemStart))
        XCTAssertEqual(window.end, max(appEnd, systemEnd))
    }

    func testReminderQueryPaddingCoversExtremeSourceZoneWithoutAllFutureItems() {
        let appCalendar = makeCalendar("Pacific/Kiritimati")
        let sourceCalendar = makeCalendar("Etc/GMT+12")
        let appStart = makeDate(2027, 1, 1, calendar: appCalendar)
        let appEnd = appCalendar.date(byAdding: .day, value: 1, to: appStart)!
        let components = DateComponents(
            calendar: sourceCalendar,
            timeZone: sourceCalendar.timeZone,
            year: 2027,
            month: 1,
            day: 1
        )
        let rawSourceDate = sourceCalendar.date(from: components)!
        let resolvedDate = CalendarItemDateResolver.reminderDate(from: components, calendar: appCalendar)!
        let queryEnd = CalendarItemDateResolver.reminderQueryEnd(after: appEnd)

        XCTAssertGreaterThan(rawSourceDate, appEnd)
        XCTAssertEqual(resolvedDate, appStart)
        XCTAssertLessThan(rawSourceDate, queryEnd)
        XCTAssertEqual(queryEnd.timeIntervalSince(appEnd), 48 * 60 * 60)
        XCTAssertLessThan(queryEnd, appCalendar.date(byAdding: .day, value: 3, to: appEnd)!)
    }

    func testReminderQueryPaddingRemainsTwoUTCDaysAcrossDaylightSaving() {
        let losAngeles = makeCalendar("America/Los_Angeles")
        for (month, day) in [(3, 8), (11, 1)] {
            let end = makeDate(2026, month, day, calendar: losAngeles)
            XCTAssertEqual(CalendarItemDateResolver.reminderQueryEnd(after: end).timeIntervalSince(end), 48 * 60 * 60)
        }
    }

    func testAllDayEventBelongsOnlyToItsCivilDayInAppZone() {
        let system = CalendarItemDateResolver.systemCalendar
        let losAngeles = makeCalendar("America/Los_Angeles")
        let event = makeEvent(
            start: makeDate(2027, 1, 1, calendar: system),
            end: makeDate(2027, 1, 2, calendar: system).addingTimeInterval(-1)
        )
        event.isAllDay = true
        event.timeZone = nil

        XCTAssertTrue(EventService.event(event, isOn: makeDate(2027, 1, 1, calendar: losAngeles), calendar: losAngeles))
        XCTAssertFalse(EventService.event(event, isOn: makeDate(2026, 12, 31, calendar: losAngeles), calendar: losAngeles))
        XCTAssertFalse(EventService.event(event, isOn: makeDate(2027, 1, 2, calendar: losAngeles), calendar: losAngeles))
    }

    func testFixedEventDayAndUpcomingBoundsUseAppCalendar() {
        let shanghai = makeCalendar("Asia/Shanghai")
        let losAngeles = makeCalendar("America/Los_Angeles")
        let start = makeDate(2027, 1, 1, hour: 0, minute: 30, calendar: shanghai)
        let event = makeEvent(start: start, end: start.addingTimeInterval(3600))
        event.timeZone = shanghai.timeZone
        let previousDay = makeDate(2026, 12, 31, calendar: losAngeles)
        let nextDay = makeDate(2027, 1, 1, calendar: losAngeles)

        XCTAssertTrue(EventService.event(event, isOn: previousDay, calendar: losAngeles))
        XCTAssertFalse(EventService.event(event, isOn: nextDay, calendar: losAngeles))
        XCTAssertTrue(EventService.event(
            event,
            isWithinUpcomingWindow: previousDay,
            enabledCalendarIDs: [],
            windowEnd: nextDay,
            calendar: losAngeles
        ))
        XCTAssertFalse(EventService.event(
            event,
            isWithinUpcomingWindow: previousDay,
            enabledCalendarIDs: [],
            windowEnd: start,
            calendar: losAngeles
        ))
    }

    func testFixedRecurringReminderKeepsSourceWallTimeAcrossDaylightSaving() {
        let shanghai = makeCalendar("Asia/Shanghai")
        let losAngeles = makeCalendar("America/Los_Angeles")
        let reminder = EKReminder(eventStore: EKEventStore())
        reminder.dueDateComponents = DateComponents(
            calendar: losAngeles,
            timeZone: losAngeles.timeZone,
            year: 2026,
            month: 3,
            day: 7,
            hour: 9,
            minute: 0
        )
        reminder.recurrenceRules = [EKRecurrenceRule(recurrenceWith: .daily, interval: 1, end: nil)]

        // LA switches to daylight time on March 8; 09:00 becomes midnight
        // March 9 in Shanghai, rather than the previous day's 01:00 offset.
        XCTAssertTrue(EventService.reminder(
            reminder,
            isDueWithin: makeDate(2026, 3, 8, hour: 23, minute: 30, calendar: shanghai),
            windowEnd: makeDate(2026, 3, 9, hour: 0, minute: 30, calendar: shanghai),
            calendar: shanghai
        ))
        XCTAssertFalse(EventService.reminder(
            reminder,
            isDueWithin: makeDate(2026, 3, 8, hour: 23, minute: 30, calendar: shanghai),
            windowEnd: makeDate(2026, 3, 9, calendar: shanghai),
            calendar: shanghai
        ))
    }

    func testTitleOnlyEventUpdatePreservesRawDatesAndOriginalTimeZone() {
        let system = CalendarItemDateResolver.systemCalendar
        let appCalendar = makeCalendar("America/Los_Angeles")
        for (isAllDay, timeZone) in [(true, nil), (false, nil), (false, TimeZone(identifier: "Asia/Shanghai"))] {
            let event = makeEvent(
                start: makeDate(2027, 1, 1, hour: isAllDay ? 0 : 9, calendar: system),
                end: makeDate(2027, 1, isAllDay ? 2 : 1, hour: isAllDay ? 0 : 10, calendar: system)
            )
            event.isAllDay = isAllDay
            event.timeZone = timeZone
            let originalStart = event.startDate
            let originalEnd = event.endDate
            let originalTimeZone = event.timeZone
            var request = CalendarEventCreationRequest.makeEditing(event, calendar: appCalendar)
            request.title = "Changed title"

            request.applySchedule(to: event)

            XCTAssertFalse(request.datesChanged)
            XCTAssertEqual(event.startDate, originalStart)
            XCTAssertEqual(event.endDate, originalEnd)
            XCTAssertEqual(event.timeZone, originalTimeZone)
            XCTAssertEqual(event.isAllDay, isAllDay)
        }
    }

    func testNewTimedEventBindsCapturedCalendarTimeZone() {
        let losAngeles = makeCalendar("America/Los_Angeles")
        let start = makeDate(2027, 1, 1, hour: 9, calendar: losAngeles)
        let request = CalendarEventCreationRequest(
            title: "New event",
            calendarIdentifier: "calendar",
            startDate: start,
            endDate: start.addingTimeInterval(3600),
            isAllDay: false,
            notes: nil,
            calendar: losAngeles
        )
        let event = makeEvent(start: start, end: start)

        request.applySchedule(to: event, isNew: true)

        XCTAssertEqual(event.timeZone, losAngeles.timeZone)
        XCTAssertEqual(event.startDate, start)
        XCTAssertEqual(event.endDate, request.endDate)
    }

    func testChangedEventDatesPreserveFixedAndFloatingSourceSemantics() {
        let shanghai = makeCalendar("Asia/Shanghai")
        let losAngeles = makeCalendar("America/Los_Angeles")
        let start = makeDate(2027, 1, 1, hour: 9, calendar: losAngeles)
        let request = CalendarEventCreationRequest(
            title: "Changed event",
            calendarIdentifier: "calendar",
            startDate: start,
            endDate: start.addingTimeInterval(3600),
            isAllDay: false,
            notes: nil,
            calendar: losAngeles
        )
        for timeZone in [nil, shanghai.timeZone] {
            let event = makeEvent(start: start, end: start.addingTimeInterval(3600))
            event.timeZone = timeZone

            request.applySchedule(to: event)

            XCTAssertEqual(event.timeZone, timeZone)
            XCTAssertEqual(CalendarItem.event(event).startDate(using: losAngeles), start)
            XCTAssertEqual(CalendarItem.event(event).endDate(using: losAngeles), request.endDate)
        }
    }

    func testChangingFixedEventToAllDayKeepsOneAppCivilDay() {
        let appCalendar = makeCalendar("America/Los_Angeles")
        let start = makeDate(2026, 11, 18, calendar: appCalendar)
        let end = makeDate(2026, 11, 19, calendar: appCalendar)
        let request = CalendarEventCreationRequest(
            title: "All day",
            calendarIdentifier: "calendar",
            startDate: start,
            endDate: end,
            isAllDay: true,
            notes: nil,
            calendar: appCalendar
        )
        for sourceZone in ["Europe/London", "Asia/Shanghai"] {
            let event = makeEvent(start: start, end: end)
            event.timeZone = TimeZone(identifier: sourceZone)

            request.applySchedule(to: event)

            let item = CalendarItem.event(event)
            XCTAssertTrue(event.isAllDay)
            XCTAssertNil(event.timeZone)
            XCTAssertEqual(item.startDate(using: appCalendar), start)
            XCTAssertEqual(CalendarEventScheduleDraft.coveredDayCount(
                startDate: item.startDate(using: appCalendar)!,
                endDate: item.endDate(using: appCalendar)!,
                isAllDay: true,
                calendar: appCalendar
            ), 1)
        }
    }

    func testTitleOnlyReminderUpdatePreservesOriginalComponentsIncludingSeconds() {
        let shanghai = makeCalendar("Asia/Shanghai")
        let losAngeles = makeCalendar("America/Los_Angeles")
        let store = EKEventStore()
        let reminder = EKReminder(eventStore: store)
        reminder.calendar = EKCalendar(for: .reminder, eventStore: store)
        reminder.dueDateComponents = DateComponents(
            calendar: shanghai,
            timeZone: shanghai.timeZone,
            year: 2027,
            month: 1,
            day: 1,
            hour: 0,
            minute: 30,
            second: 42
        )
        let originalComponents = reminder.dueDateComponents
        var request = ReminderCreationRequest.makeEditing(reminder, calendar: losAngeles)
        request.notes = "Changed notes"

        request.applySchedule(to: reminder)

        XCTAssertFalse(request.datesChanged)
        XCTAssertEqual(reminder.dueDateComponents, originalComponents)
        XCTAssertEqual(request.calendar.timeZone, losAngeles.timeZone)
    }

    func testChangedReminderDatesPreserveFixedAndFloatingTimeZoneMetadata() {
        let shanghai = makeCalendar("Asia/Shanghai")
        let losAngeles = makeCalendar("America/Los_Angeles")
        let changedDate = makeDate(2027, 1, 2, hour: 9, calendar: losAngeles)
        for timeZone in [nil, shanghai.timeZone] {
            let reminder = EKReminder(eventStore: EKEventStore())
            reminder.dueDateComponents = DateComponents(
                calendar: shanghai,
                timeZone: timeZone,
                year: 2027,
                month: 1,
                day: 1,
                hour: 9,
                minute: 0
            )
            let request = ReminderCreationRequest(
                title: "Changed reminder",
                calendarIdentifier: "list",
                dueDate: changedDate,
                includesTime: true,
                notes: nil,
                calendar: losAngeles
            )

            request.applySchedule(to: reminder)

            XCTAssertEqual(reminder.dueDateComponents?.timeZone, timeZone)
            XCTAssertEqual(CalendarItem.reminder(reminder).startDate(using: losAngeles), changedDate)
        }
    }

    func testChangedFloatingReminderPreservesWallTimeFromDifferentEmbeddedCalendars() {
        let appCalendar = makeCalendar("America/Los_Angeles")
        let changedDate = makeDate(2026, 11, 19, hour: 10, minute: 45, calendar: appCalendar)
        for sourceZone in ["America/New_York", "America/Los_Angeles", "UTC"] {
            let reminder = EKReminder(eventStore: EKEventStore())
            reminder.dueDateComponents = DateComponents(
                calendar: makeCalendar(sourceZone),
                year: 2026,
                month: 11,
                day: 18,
                hour: 9,
                minute: 30
            )
            let request = ReminderCreationRequest(
                title: "Changed floating reminder",
                calendarIdentifier: "list",
                dueDate: changedDate,
                includesTime: true,
                notes: nil,
                calendar: appCalendar
            )

            request.applySchedule(to: reminder)

            let components = reminder.dueDateComponents
            XCTAssertEqual(components?.year, 2026, sourceZone)
            XCTAssertEqual(components?.month, 11, sourceZone)
            XCTAssertEqual(components?.day, 19, sourceZone)
            XCTAssertEqual(components?.hour, 10, sourceZone)
            XCTAssertEqual(components?.minute, 45, sourceZone)
            XCTAssertNil(components?.timeZone, sourceZone)
            XCTAssertEqual(CalendarItem.reminder(reminder).startDate(using: appCalendar), changedDate, sourceZone)
        }
    }

    private func makeCalendar(_ identifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier)!
        return calendar
    }

    private func makeDate(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int = 0,
        minute: Int = 0,
        calendar: Calendar
    ) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func makeEvent(start: Date, end: Date) -> EKEvent {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.calendar = EKCalendar(for: .event, eventStore: store)
        event.startDate = start
        event.endDate = end
        event.timeZone = nil
        return event
    }
}
