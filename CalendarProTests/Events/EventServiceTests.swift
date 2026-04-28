import XCTest
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
}
