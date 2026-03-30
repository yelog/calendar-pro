import CoreGraphics

enum EventDetailWindowSizing {
    static let width: CGFloat = PopoverSurfaceMetrics.width
    static let minHeight: CGFloat = 280
    static let idealHeight: CGFloat = 360

    static func panelSize(for fittingSize: CGSize, availableHeight: CGFloat) -> CGSize {
        return CGSize(
            width: width,
            height: max(availableHeight, minHeight)
        )
    }
}
