import CoreGraphics

enum EventDetailWindowSizing {
    static let width: CGFloat = PopoverSurfaceMetrics.width
    static let minHeight: CGFloat = 280
    static let idealHeight: CGFloat = 360

    static func panelSize(for fittingSize: CGSize, availableHeight: CGFloat, prefersFullHeight: Bool = true) -> CGSize {
        let height: CGFloat
        if prefersFullHeight {
            height = max(availableHeight, minHeight)
        } else {
            height = min(max(fittingSize.height, minHeight), availableHeight)
        }
        return CGSize(width: width, height: height)
    }
}
