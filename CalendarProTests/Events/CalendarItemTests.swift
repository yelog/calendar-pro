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
}
