import CoreGraphics

enum WeatherDetailWindowSizing {
    static let width: CGFloat = 400
    static let minHeight: CGFloat = 360
    static let idealHeight: CGFloat = 560

    static func panelSize(for fittingSize: CGSize, availableHeight: CGFloat) -> CGSize {
        let preferredHeight = max(fittingSize.height, idealHeight)
        let maximumHeight = max(availableHeight, minHeight)
        let height = min(preferredHeight, maximumHeight)
        return CGSize(width: width, height: height)
    }
}
