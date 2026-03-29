import XCTest
@testable import CalendarPro

final class HolidayProviderRegistryTests: XCTestCase {
    func testRegistryExposesMainlandAndHongKongProviders() {
        let registry = HolidayProviderRegistry.default
        let ids = registry.providers.map(\.descriptor.id)

        XCTAssertTrue(ids.contains("mainland-cn"))
        XCTAssertTrue(ids.contains("hong-kong"))
    }
}
