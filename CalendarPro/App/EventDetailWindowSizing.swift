import CoreGraphics

enum EventDetailWindowSizing {
    static let width: CGFloat = PopoverSurfaceMetrics.width
    static let minHeight: CGFloat = 280
    static let idealHeight: CGFloat = 360
    static let maxHeight: CGFloat = 440

    static func panelSize(for fittingSize: CGSize) -> CGSize {
        let preferredHeight = max(fittingSize.height, idealHeight)

        return CGSize(
            width: width,
            height: min(max(preferredHeight, minHeight), maxHeight)
        )
    }
}
