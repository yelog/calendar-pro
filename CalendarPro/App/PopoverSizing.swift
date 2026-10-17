import AppKit
import SwiftUI

// Popover size constraints: caps the popover height to the screen space
// below the status bar button so content growth scrolls inside the popover
// instead of pushing the anchored window past the top of the screen.

enum PopoverSizing {
    /// Safety gap between the popover and the status bar button (arrow gap
    /// plus screen-edge margin).
    static let verticalSpacingMargin: CGFloat = 12

    /// Fallback height for degenerate layouts; matches
    /// EventDetailWindowSizing.minHeight.
    static let minimumHeight: CGFloat = 280

    /// Maximum usable popover height below the anchor button; falls back to
    /// `minimumHeight` when the button sits below the visible frame.
    static func availableHeight(
        anchorButtonFrameInScreen: NSRect,
        visibleFrame: NSRect
    ) -> CGFloat {
        let spaceBelowButton = anchorButtonFrameInScreen.minY - visibleFrame.minY
        return max(spaceBelowButton - verticalSpacingMargin, minimumHeight)
    }

    /// Clamps the content fitting size to the available height; overflow
    /// scrolls inside the popover's own ScrollView. Width is kept as-is.
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

/// Hosting controller that clamps the popover height. With
/// sizingOptions = .preferredContentSize the popover resizes with its
/// content (e.g. when a section expands); overriding the read path keeps
/// that growth within maximumContentHeight so the window stays on screen.
final class PopoverSizingHostingController: NSHostingController<AnyView> {
    /// Height cap; nil means uncapped (before the first presentation, where
    /// PopoverSizing.availableHeight writes it on every show).
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
