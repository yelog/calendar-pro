import CoreGraphics

enum EventDetailWindowLayout {
    /// Height of the NSPopover arrow pointing to the menu bar.
    static let popoverArrowHeight: CGFloat = 13

    static func defaultFrame(
        panelSize: CGSize,
        anchorFrame: CGRect,
        visibleFrame: CGRect,
        spacing: CGFloat = 10
    ) -> CGRect {
        let size = CGSize(
            width: min(panelSize.width, visibleFrame.width),
            height: min(panelSize.height, visibleFrame.height)
        )
        let leftOriginX = anchorFrame.minX - spacing - size.width
        let rightOriginX = anchorFrame.maxX + spacing

        let preferredOriginX: CGFloat
        if leftOriginX >= visibleFrame.minX {
            preferredOriginX = leftOriginX
        } else if rightOriginX + size.width <= visibleFrame.maxX {
            preferredOriginX = rightOriginX
        } else {
            preferredOriginX = visibleFrame.maxX - size.width
        }

        // Align top with anchor window content top (excluding popover arrow)
        let anchorContentTop = anchorFrame.maxY - popoverArrowHeight
        let preferredOriginY = anchorContentTop - size.height

        return CGRect(
            x: clamp(preferredOriginX, min: visibleFrame.minX, max: visibleFrame.maxX - size.width),
            y: clamp(preferredOriginY, min: visibleFrame.minY, max: visibleFrame.maxY - size.height),
            width: size.width,
            height: size.height
        )
    }

    private static func clamp(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, min), max)
    }
}
