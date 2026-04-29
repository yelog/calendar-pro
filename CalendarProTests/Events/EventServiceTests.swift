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
        event.isAllDay = false
        event.notes = "Room 1"

        let request = CalendarEventCreationRequest.makeEditing(event)

        XCTAssertEqual(request.title, "Planning")
        XCTAssertEqual(request.calendarIdentifier, event.calendar.calendarIdentifier)
        XCTAssertEqual(request.startDate, startDate)
        XCTAssertEqual(request.endDate, endDate)
        XCTAssertFalse(request.isAllDay)
        XCTAssertEqual(request.notes, "Room 1")
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
}
