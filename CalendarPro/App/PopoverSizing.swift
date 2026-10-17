import AppKit
import SwiftUI

enum PopoverSizing {
    /// Gap reserved between the status bar button and the popover
    /// (NSPopover arrow gap plus a top-edge margin).
    static let verticalSpacingMargin: CGFloat = 12

    /// Popover height floor for degenerate screen layouts.
    static let minimumHeight: CGFloat = 280

    /// Maximum usable popover height below the anchor button, with the
    /// spacing margin subtracted and the floor applied.
    static func availableHeight(
        anchorButtonFrameInScreen: NSRect,
        visibleFrame: NSRect
    ) -> CGFloat {
        let spaceBelowButton = anchorButtonFrameInScreen.minY - visibleFrame.minY
        return max(spaceBelowButton - verticalSpacingMargin, minimumHeight)
    }

    /// Clamps the popover height to the space below the anchor button; any
    /// overflow is handled by the popover's internal ScrollView.
    static func clampedContentSize(
        fittingSize: NSSize,
        anchorButtonFrameInScreen: NSRect,
        visibleFrame: NSRect
    ) -> NSSize {
        let maximumHeight = availableHeight(
            anchorButtonFrameInScreen: anchorButtonFrameInScreen,
            visibleFrame: visibleFrame
        )
        return NSSize(
            width: fittingSize.width,
            height: min(fittingSize.height, maximumHeight)
        )
    }
}

/// SwiftUI host that keeps the popover on screen: the popover resizes with the
/// SwiftUI content (e.g. expanding board sections), so the preferredContentSize
/// getter clamps the height to maximumContentHeight. Writes still go through
/// super, so behavior is native until a limit is set.
final class PopoverSizingHostingController: NSHostingController<AnyView> {
    /// Height cap; nil means no limit yet (before the first show).
    var maximumContentHeight: CGFloat?

    override var preferredContentSize: NSSize {
        get {
            let size = super.preferredContentSize
            guard let maximumContentHeight else { return size }
            return NSSize(
                width: size.width,
                height: min(size.height, maximumContentHeight)
            )
        }
        set { super.preferredContentSize = newValue }
    }
}
