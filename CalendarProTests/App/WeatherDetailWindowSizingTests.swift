import XCTest
@testable import CalendarPro

final class WeatherDetailWindowSizingTests: XCTestCase {
    func testUsesWiderForecastPanelWidth() {
        let size = WeatherDetailWindowSizing.panelSize(for: CGSize(width: 280, height: 400), availableHeight: 720)

        XCTAssertEqual(size.width, 400)
    }

    func testPrefersIdealHeightForForecastList() {
        let size = WeatherDetailWindowSizing.panelSize(for: CGSize(width: 400, height: 420), availableHeight: 900)

        XCTAssertEqual(size.height, 560)
    }

    func testClampsForecastPanelToAvailableHeight() {
        let size = WeatherDetailWindowSizing.panelSize(for: CGSize(width: 400, height: 900), availableHeight: 480)

        XCTAssertEqual(size.height, 480)
    }
}
