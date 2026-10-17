import SwiftUI
import XCTest
@testable import CalendarPro

@MainActor
final class PopoverSizingTests: XCTestCase {
    // Typical menu bar: 1440x900 screen, 25pt menu bar, button bottom at y=850.
    private let buttonFrameInScreen = NSRect(x: 1200, y: 850, width: 44, height: 25)
    private let visibleFrame = NSRect(x: 0, y: 0, width: 1440, height: 875)

    func testAvailableHeightUsesSpaceBelowAnchorButton() {
        let height = PopoverSizing.availableHeight(
            anchorButtonFrameInScreen: buttonFrameInScreen,
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(height, 838)
    }

    func testClampedContentSizeKeepsFittingHeightWhenContentFits() {
        let size = PopoverSizing.clampedContentSize(
            fittingSize: NSSize(width: 340, height: 600),
            anchorButtonFrameInScreen: buttonFrameInScreen,
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(size, NSSize(width: 340, height: 600))
    }

    func testClampedContentSizeLimitsHeightToAvailableSpace() {
        let size = PopoverSizing.clampedContentSize(
            fittingSize: NSSize(width: 340, height: 1600),
            anchorButtonFrameInScreen: buttonFrameInScreen,
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(size, NSSize(width: 340, height: 838))
    }

    func testAvailableHeightFloorsAtMinimumForDegenerateLayouts() {
        let height = PopoverSizing.availableHeight(
            anchorButtonFrameInScreen: NSRect(x: 1200, y: 5, width: 44, height: 25),
            visibleFrame: NSRect(x: 0, y: 100, width: 1440, height: 875)
        )

        XCTAssertEqual(height, PopoverSizing.minimumHeight)
    }

    func testHostingControllerPassesThroughPreferredContentSizeWithoutLimit() {
        let controller = PopoverSizingHostingController(rootView: AnyView(EmptyView()))
        controller.preferredContentSize = NSSize(width: 340, height: 1200)

        XCTAssertEqual(controller.preferredContentSize, NSSize(width: 340, height: 1200))
    }

    func testHostingControllerClampsPreferredContentSizeHeight() {
        let controller = PopoverSizingHostingController(rootView: AnyView(EmptyView()))
        controller.maximumContentHeight = 838
        controller.preferredContentSize = NSSize(width: 340, height: 1200)

        XCTAssertEqual(controller.preferredContentSize, NSSize(width: 340, height: 838))
    }
}
