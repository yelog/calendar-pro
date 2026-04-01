import XCTest
@testable import CalendarPro

final class EventDetailWindowSizingTests: XCTestCase {
    func testUsesFixedPopoverWidth() {
        let size = EventDetailWindowSizing.panelSize(for: CGSize(width: 780, height: 300), availableHeight: 360)

        XCTAssertEqual(size.width, 340)
    }

    func testPrefersIdealHeightForShortContentEvenWhenThereIsMoreSpace() {
        let size = EventDetailWindowSizing.panelSize(for: CGSize(width: 240, height: 260), availableHeight: 720)

        XCTAssertEqual(size.height, 360)
    }

    func testUsesMeasuredHeightWhenContentIsTallerThanIdealHeight() {
        let size = EventDetailWindowSizing.panelSize(for: CGSize(width: 240, height: 420), availableHeight: 720)

        XCTAssertEqual(size.height, 420)
    }

    func testClampsHeightToAvailableHeightForVeryTallContent() {
        let size = EventDetailWindowSizing.panelSize(for: CGSize(width: 240, height: 1_200), availableHeight: 400)

        XCTAssertEqual(size.height, 400)
    }
}
