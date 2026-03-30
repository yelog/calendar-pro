import XCTest
@testable import CalendarPro

final class EventDetailWindowSizingTests: XCTestCase {
    func testUsesFixedPopoverWidth() {
        let size = EventDetailWindowSizing.panelSize(for: CGSize(width: 780, height: 300))

        XCTAssertEqual(size.width, 340)
    }

    func testClampsHeightIntoFloatingWindowRange() {
        let small = EventDetailWindowSizing.panelSize(for: CGSize(width: 240, height: 120))
        let large = EventDetailWindowSizing.panelSize(for: CGSize(width: 240, height: 1_200))

        XCTAssertEqual(small.height, 360)
        XCTAssertEqual(large.height, 440)
    }

    func testPrefersIdealHeightForShortContent() {
        let size = EventDetailWindowSizing.panelSize(for: CGSize(width: 240, height: 260))

        XCTAssertEqual(size.height, 360)
    }
}
