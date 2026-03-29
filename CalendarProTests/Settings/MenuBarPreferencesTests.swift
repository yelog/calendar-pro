import XCTest
@testable import CalendarPro

final class MenuBarPreferencesTests: XCTestCase {
    func testDefaultShowEventsIsTrue() {
        let prefs = MenuBarPreferences.default
        XCTAssertTrue(prefs.showEvents)
    }
    
    func testDefaultEnabledCalendarIDsIsEmpty() {
        let prefs = MenuBarPreferences.default
        XCTAssertTrue(prefs.enabledCalendarIDs.isEmpty)
    }
    
    func testCodableRoundTrip() throws {
        let prefs = MenuBarPreferences.default
        let data = try JSONEncoder().encode(prefs)
        let decoded = try JSONDecoder().decode(MenuBarPreferences.self, from: data)
        XCTAssertEqual(prefs.showEvents, decoded.showEvents)
        XCTAssertEqual(prefs.enabledCalendarIDs, decoded.enabledCalendarIDs)
    }
}