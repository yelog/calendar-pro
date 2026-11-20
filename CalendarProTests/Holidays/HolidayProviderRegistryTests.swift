import Foundation
import XCTest
@testable import CalendarPro

final class HolidayProviderRegistryTests: XCTestCase {
    func testRegistryExposesMainlandAndHongKongProviders() {
        let registry = HolidayProviderRegistry.default
        let ids = registry.providers.map(\.descriptor.id)

        XCTAssertTrue(ids.contains("mainland-cn"))
        XCTAssertTrue(ids.contains("hong-kong"))
    }

    func testHongKong2027PublicHolidaysLoadFromAppBundle() throws {
        let provider = HongKongProvider()
        XCTAssertEqual(provider.datasetAvailability(forYear: 2027), .bundled)

        let holidays = try provider.holidays(forYear: 2027)
        XCTAssertEqual(holidays.count, 17)
        XCTAssertTrue(holidays.allSatisfy { $0.kind == .publicHoliday })

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let newYear = try XCTUnwrap(calendar.date(from: DateComponents(year: 2027, month: 1, day: 1)))
        let lunarNewYearSubstitute = try XCTUnwrap(calendar.date(from: DateComponents(year: 2027, month: 2, day: 9)))

        XCTAssertEqual(holidays.first { $0.date == newYear }?.isObserved, false)
        XCTAssertEqual(holidays.filter(\.isObserved).map(\.date), [lunarNewYearSubstitute])
    }
}
