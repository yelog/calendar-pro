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
}