import XCTest
@testable import CalendarPro

final class EventDetailWindowSizingTests: XCTestCase {
    func testUsesFixedPopoverWidth() {
        let size = EventDetailWindowSizing.panelSize(for: CGSize(width: 780, height: 300), availableHeight: 360)

        XCTAssertEqual(size.width, 340)
    }

    func testClampsHeightIntoFloatingWindowRange() {
        let small = EventDetailWindowSizing.panelSize(for: CGSize(width: 240, height: 120), availableHeight: 280)
        let large = EventDetailWindowSizing.panelSize(for: CGSize(width: 240, height: 1_200), availableHeight: 400)

        XCTAssertEqual(small.height, 280)
        XCTAssertEqual(large.height, 400)
    }

    func testPrefersIdealHeightForShortContent() {
        let size = EventDetailWindowSizing.panelSize(for: CGSize(width: 240, height: 260), availableHeight: 360)

        XCTAssertEqual(size.height, 360)
    }
}
