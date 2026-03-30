import XCTest
@testable import CalendarPro

final class EventDetailWindowLayoutTests: XCTestCase {
    func testPrefersLeftSideWhenThereIsEnoughRoom() {
        let anchorFrame = CGRect(x: 900, y: 500, width: 340, height: 400)
        let visibleFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)

        let frame = EventDetailWindowLayout.defaultFrame(
            panelSize: CGSize(width: 340, height: 360),
            anchorFrame: anchorFrame,
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(frame.origin.x, 550)
        XCTAssertLessThan(frame.maxX, anchorFrame.minX)
    }

    func testFallsBackToRightSideWhenLeftSideIsTooTight() {
        let anchorFrame = CGRect(x: 20, y: 500, width: 340, height: 400)
        let visibleFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)

        let frame = EventDetailWindowLayout.defaultFrame(
            panelSize: CGSize(width: 340, height: 360),
            anchorFrame: anchorFrame,
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(frame.origin.x, 370)
        XCTAssertGreaterThanOrEqual(frame.minX, anchorFrame.maxX)
    }

    func testClampsVerticalOriginIntoVisibleFrame() {
        let anchorFrame = CGRect(x: 900, y: 120, width: 340, height: 120)
        let visibleFrame = CGRect(x: 0, y: 80, width: 1440, height: 820)

        let frame = EventDetailWindowLayout.defaultFrame(
            panelSize: CGSize(width: 340, height: 360),
            anchorFrame: anchorFrame,
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(frame.origin.y, 80)
    }

    func testKeepsConfiguredGapFromAnchorWhenPlacedOnLeftSide() {
        let anchorFrame = CGRect(x: 900, y: 500, width: 340, height: 400)
        let visibleFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)

        let frame = EventDetailWindowLayout.defaultFrame(
            panelSize: CGSize(width: 340, height: 360),
            anchorFrame: anchorFrame,
            visibleFrame: visibleFrame,
            spacing: 8
        )

        XCTAssertEqual(anchorFrame.minX - frame.maxX, 8, accuracy: 0.5)
    }
}
