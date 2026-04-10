import XCTest
import EventKit
@testable import CalendarPro

final class CalendarItemTests: XCTestCase {

    // MARK: - remindersAppURL

    func testRemindersAppURL_eventReturnsNil() {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.title = "Test Event"
        let item = CalendarItem.event(event)
        XCTAssertNil(item.remindersAppURL)
    }

    func testRemindersAppURL_reminderWithExternalID() {
        let store = EKEventStore()
        let reminder = EKReminder(eventStore: store)
        reminder.title = "Test Reminder"
        let item = CalendarItem.reminder(reminder)

        // calendarItemExternalIdentifier may be nil/empty for unsaved reminders,
        // so the URL should be nil in that case.
        if let externalID = reminder.calendarItemExternalIdentifier,
           !externalID.isEmpty {
            let expected = URL(string: "x-apple-reminderkit://REMCDReminder/\(externalID)")
            XCTAssertEqual(item.remindersAppURL, expected)
        } else {
            XCTAssertNil(item.remindersAppURL)
        }
    }

    func testRemindersAppURL_urlScheme() {
        let store = EKEventStore()
        let reminder = EKReminder(eventStore: store)
        let item = CalendarItem.reminder(reminder)

        // Regardless of whether the URL is nil or not, if it exists it must
        // use the x-apple-reminderkit scheme.
        if let url = item.remindersAppURL {
            XCTAssertEqual(url.scheme, "x-apple-reminderkit")
            XCTAssertTrue(url.absoluteString.contains("REMCDReminder"))
        }
    }

    // MARK: - isReminder

    func testIsReminder_trueForReminder() {
        let store = EKEventStore()
        let reminder = EKReminder(eventStore: store)
        let item = CalendarItem.reminder(reminder)
        XCTAssertTrue(item.isReminder)
    }

    func testIsReminder_falseForEvent() {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        let item = CalendarItem.event(event)
        XCTAssertFalse(item.isReminder)
    }

    // MARK: - isCanceled

    func testIsCanceled_falseForNormalEvent() {
        let item = CalendarItem.event(makeEvent(
            title: "会议",
            start: makeDate(year: 2026, month: 4, day: 1, hour: 9, minute: 0),
            end: makeDate(year: 2026, month: 4, day: 1, hour: 10, minute: 0)
        ))

        XCTAssertFalse(item.isCanceled)
    }

    func testIsCanceled_trueForCanceledEvent() {
        let event = makeEvent(
            title: "取消会议",
            start: makeDate(year: 2026, month: 4, day: 1, hour: 9, minute: 0),
            end: makeDate(year: 2026, month: 4, day: 1, hour: 10, minute: 0)
        )
        event.setValue(EKEventStatus.canceled.rawValue, forKey: "status")

        let item = CalendarItem.event(event)

        XCTAssertTrue(item.isCanceled)
    }

    func testIsCanceled_falseForReminder() {
        let item = CalendarItem.reminder(makeReminder(
            year: 2026,
            month: 4,
            day: 1,
            hour: 17,
            minute: 15
        ))

        XCTAssertFalse(item.isCanceled)
    }

    // MARK: - timeline

    func testHasExplicitTime_trueForTimedReminder() {
        let item = CalendarItem.reminder(makeReminder(year: 2026, month: 4, day: 1, hour: 17, minute: 15))

        XCTAssertTrue(item.hasExplicitTime)
        XCTAssertEqual(item.timelinePlacement(using: .gregorianMondayFirst), .timed(minutes: 17 * 60 + 15))
    }

    func testHasExplicitTime_falseForDateOnlyReminder() {
        let item = CalendarItem.reminder(makeDateOnlyReminder(year: 2026, month: 4, day: 1))

        XCTAssertFalse(item.hasExplicitTime)
        XCTAssertEqual(item.timelinePlacement(using: .gregorianMondayFirst), .untimed)
    }

    func testTimelineSnapshotSplitsTimedAllDayAndUntimedItems() {
        let timedEvent = CalendarItem.event(makeEvent(
            title: "站会",
            start: makeDate(year: 2026, month: 4, day: 1, hour: 9, minute: 0),
            end: makeDate(year: 2026, month: 4, day: 1, hour: 10, minute: 0)
        ))
        let timedReminder = CalendarItem.reminder(makeReminder(
            year: 2026,
            month: 4,
            day: 1,
            hour: 17,
            minute: 15,
            title: "发布版本"
        ))
        let allDayEvent = CalendarItem.event(makeAllDayEvent(
            title: "清明节",
            start: makeDate(year: 2026, month: 4, day: 1, hour: 0, minute: 0),
            end: makeDate(year: 2026, month: 4, day: 1, hour: 23, minute: 59)
        ))
        let untimedReminder = CalendarItem.reminder(makeDateOnlyReminder(
            year: 2026,
            month: 4,
            day: 1,
            title: "补充周报"
        ))

        let snapshot = EventTimelineSnapshot.make(
            items: [allDayEvent, timedEvent, untimedReminder, timedReminder],
            selectedDate: makeDate(year: 2026, month: 4, day: 1, hour: 0, minute: 0),
            now: makeDate(year: 2026, month: 4, day: 1, hour: 8, minute: 30),
            calendar: .gregorianMondayFirst
        )

        XCTAssertEqual(snapshot.timedGroups.map(\.displayTime), ["09:00", "17:15"])
        XCTAssertEqual(snapshot.allDayItems.count, 1)
        XCTAssertEqual(snapshot.untimedItems.count, 1)
    }

    func testTimelineSnapshotPrefersOngoingGroupForMarker() {
        let ongoingEvent = CalendarItem.event(makeEvent(
            title: "评审会",
            start: makeDate(year: 2026, month: 4, day: 1, hour: 12, minute: 0),
            end: makeDate(year: 2026, month: 4, day: 1, hour: 13, minute: 0)
        ))
        let laterReminder = CalendarItem.reminder(makeReminder(
            year: 2026,
            month: 4,
            day: 1,
            hour: 17,
            minute: 0
        ))

        let snapshot = EventTimelineSnapshot.make(
            items: [ongoingEvent, laterReminder],
            selectedDate: makeDate(year: 2026, month: 4, day: 1, hour: 0, minute: 0),
            now: makeDate(year: 2026, month: 4, day: 1, hour: 12, minute: 30),
            calendar: .gregorianMondayFirst
        )

        guard let marker = snapshot.marker else {
            return XCTFail("Expected marker for ongoing event")
        }

        XCTAssertEqual(marker.groupID, "12:00")
        switch marker.position {
        case .withinItem(let selectionIdentifier, let progress):
            XCTAssertEqual(selectionIdentifier, ongoingEvent.selectionIdentifier)
            XCTAssertEqual(progress, 0.5, accuracy: 0.001)
        default:
            XCTFail("Expected withinItem marker")
        }
        XCTAssertEqual(snapshot.scrollTargetGroupID, "12:00")
    }

    func testTimelineProgressReturnsElapsedRatioForOngoingEvent() {
        let item = CalendarItem.event(makeEvent(
            title: "评审会",
            start: makeDate(year: 2026, month: 4, day: 1, hour: 10, minute: 0),
            end: makeDate(year: 2026, month: 4, day: 1, hour: 11, minute: 0)
        ))

        let progress = item.timelineProgress(
            at: makeDate(year: 2026, month: 4, day: 1, hour: 10, minute: 18),
            calendar: .gregorianMondayFirst
        )

        guard let progress else {
            return XCTFail("Expected progress for ongoing event")
        }

        XCTAssertEqual(progress, 0.3, accuracy: 0.001)
    }

    func testTimelineProgressReturnsCenteredValueForCurrentMinuteReminder() {
        let item = CalendarItem.reminder(makeReminder(
            year: 2026,
            month: 4,
            day: 1,
            hour: 17,
            minute: 15
        ))

        let progress = item.timelineProgress(
            at: makeDate(year: 2026, month: 4, day: 1, hour: 17, minute: 15),
            calendar: .gregorianMondayFirst
        )

        guard let progress else {
            return XCTFail("Expected progress for current-minute reminder")
        }

        XCTAssertEqual(progress, 0.5, accuracy: 0.001)
    }

    func testTimelineSnapshotFallsBackToNextDisplayedTimeGroup() {
        let morningEvent = CalendarItem.event(makeEvent(
            title: "晨会",
            start: makeDate(year: 2026, month: 4, day: 1, hour: 9, minute: 0),
            end: makeDate(year: 2026, month: 4, day: 1, hour: 9, minute: 30)
        ))
        let futureReminder = CalendarItem.reminder(makeReminder(
            year: 2026,
            month: 4,
            day: 1,
            hour: 17,
            minute: 15
        ))

        let snapshot = EventTimelineSnapshot.make(
            items: [morningEvent, futureReminder],
            selectedDate: makeDate(year: 2026, month: 4, day: 1, hour: 0, minute: 0),
            now: makeDate(year: 2026, month: 4, day: 1, hour: 10, minute: 0),
            calendar: .gregorianMondayFirst
        )

        XCTAssertEqual(snapshot.marker, EventTimelineMarker(groupID: "17:15", position: .beforeGroup))
        XCTAssertEqual(snapshot.scrollTargetGroupID, "17:15")
    }

    func testTimelineSnapshotPlacesMarkerBeforeMixedReminderGroupUsingDisplayedTime() {
        let overdueReminder = CalendarItem.reminder(makeReminder(
            year: 2026,
            month: 3,
            day: 31,
            hour: 20,
            minute: 0,
            title: "昨晚待办"
        ))
        let futureReminder = CalendarItem.reminder(makeReminder(
            year: 2026,
            month: 4,
            day: 1,
            hour: 20,
            minute: 0,
            title: "今晚待办"
        ))
        let laterEvent = CalendarItem.event(makeEvent(
            title: "夜间会议",
            start: makeDate(year: 2026, month: 4, day: 1, hour: 21, minute: 0),
            end: makeDate(year: 2026, month: 4, day: 1, hour: 21, minute: 30)
        ))

        let snapshot = EventTimelineSnapshot.make(
            items: [overdueReminder, futureReminder, laterEvent],
            selectedDate: makeDate(year: 2026, month: 4, day: 1, hour: 0, minute: 0),
            now: makeDate(year: 2026, month: 4, day: 1, hour: 18, minute: 20),
            calendar: .gregorianMondayFirst
        )

        XCTAssertEqual(snapshot.timedGroups.map(\.displayTime), ["20:00", "21:00"])
        XCTAssertEqual(snapshot.timedGroups.first?.items.count, 2)
        XCTAssertEqual(snapshot.marker, EventTimelineMarker(groupID: "20:00", position: .beforeGroup))
        XCTAssertEqual(snapshot.scrollTargetGroupID, "20:00")
    }

    func testTimelineSnapshotDoesNotShowMarkerForNonTodaySelection() {
        let event = CalendarItem.event(makeEvent(
            title: "旧会议",
            start: makeDate(year: 2026, month: 3, day: 31, hour: 9, minute: 0),
            end: makeDate(year: 2026, month: 3, day: 31, hour: 10, minute: 0)
        ))

        let snapshot = EventTimelineSnapshot.make(
            items: [event],
            selectedDate: makeDate(year: 2026, month: 3, day: 31, hour: 0, minute: 0),
            now: makeDate(year: 2026, month: 4, day: 1, hour: 10, minute: 0),
            calendar: .gregorianMondayFirst
        )

        XCTAssertNil(snapshot.marker)
        XCTAssertNil(snapshot.scrollTargetGroupID)
    }

    private func makeEvent(title: String = "会议", start: Date, end: Date) -> EKEvent {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = start
        event.endDate = end
        if let calendar = store.defaultCalendarForNewEvents {
            event.calendar = calendar
        }
        return event
    }

    private func makeAllDayEvent(title: String = "全天事件", start: Date, end: Date) -> EKEvent {
        let event = makeEvent(title: title, start: start, end: end)
        event.isAllDay = true
        return event
    }

    private func makeReminder(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        title: String = "提醒"
    ) -> EKReminder {
        let reminder = EKReminder(eventStore: EKEventStore())
        reminder.title = title
        reminder.dueDateComponents = DateComponents(
            calendar: Calendar.gregorianMondayFirst,
            timeZone: TimeZone(secondsFromGMT: 0),
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )
        return reminder
    }

    private func makeDateOnlyReminder(
        year: Int,
        month: Int,
        day: Int,
        title: String = "日期提醒"
    ) -> EKReminder {
        let reminder = EKReminder(eventStore: EKEventStore())
        reminder.title = title
        reminder.dueDateComponents = DateComponents(
            calendar: Calendar.gregorianMondayFirst,
            timeZone: TimeZone(secondsFromGMT: 0),
            year: year,
            month: month,
            day: day
        )
        return reminder
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        DateComponents(
            calendar: Calendar.gregorianMondayFirst,
            timeZone: TimeZone(secondsFromGMT: 0),
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ).date!
    }
}
