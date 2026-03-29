import XCTest
@testable import CalendarPro

final class CalendarProTests: XCTestCase {
    func testAppModuleLoads() {
        let renderer = ClockRenderService()
        let text = renderer.render(
            now: Date(timeIntervalSince1970: 0),
            preferences: .default,
            locale: Locale(identifier: "en_US_POSIX"),
            calendar: Calendar(identifier: .gregorian),
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        XCTAssertFalse(text.isEmpty)
    }
}
