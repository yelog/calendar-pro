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

    func testUnitedKingdom2027PublicHolidaysLoadFromAppBundle() throws {
        let provider = UnitedKingdomProvider()
        XCTAssertEqual(provider.datasetAvailability(forYear: 2027), .bundled)

        let holidays = try provider.holidays(forYear: 2027)
        XCTAssertEqual(holidays.count, 8)
        XCTAssertEqual(Set(holidays.map(\.date)).count, 8)
        XCTAssertTrue(
            holidays.allSatisfy {
                $0.kind == .publicHoliday && $0.holidaySetID == "bank-holidays"
            }
        )
        XCTAssertEqual(
            utcDateStrings(holidays),
            [
                "2027-01-01",
                "2027-03-26",
                "2027-03-29",
                "2027-05-03",
                "2027-05-31",
                "2027-08-30",
                "2027-12-27",
                "2027-12-28"
            ]
        )

        let observedHolidays = holidays.filter(\.isObserved)
        XCTAssertEqual(utcDateStrings(observedHolidays), ["2027-12-27", "2027-12-28"])
        XCTAssertEqual(observedHolidays.map(\.name), ["Christmas Day (Observed)", "Boxing Day (Observed)"])
    }

    func testUnitedStates2027FederalHolidaysLoadFromAppBundle() throws {
        let provider = UnitedStatesProvider()
        XCTAssertEqual(provider.datasetAvailability(forYear: 2027), .bundled)

        let holidays = try provider.holidays(forYear: 2027)
        XCTAssertEqual(holidays.count, 11)
        XCTAssertEqual(Set(holidays.map(\.date)).count, 11)
        XCTAssertTrue(
            holidays.allSatisfy {
                $0.kind == .publicHoliday
                    && $0.holidaySetID == "federal-holidays"
                    && !$0.isObserved
            }
        )
        XCTAssertEqual(
            utcDateStrings(holidays),
            [
                "2027-01-01",
                "2027-01-18",
                "2027-02-15",
                "2027-05-31",
                "2027-06-19",
                "2027-07-04",
                "2027-09-06",
                "2027-10-11",
                "2027-11-11",
                "2027-11-25",
                "2027-12-25"
            ]
        )
    }

    func testUnitedKingdomAndUnitedStates2026DatasetsRemainBundled() throws {
        let ukProvider = UnitedKingdomProvider()
        XCTAssertEqual(ukProvider.datasetAvailability(forYear: 2026), .bundled)
        let ukHolidays = try ukProvider.holidays(forYear: 2026)
        XCTAssertEqual(ukHolidays.count, 8)
        XCTAssertEqual(utcDateStrings(ukHolidays.filter(\.isObserved)), ["2026-12-28"])

        let usProvider = UnitedStatesProvider()
        XCTAssertEqual(usProvider.datasetAvailability(forYear: 2026), .bundled)
        let usHolidays = try usProvider.holidays(forYear: 2026)
        XCTAssertEqual(usHolidays.count, 11)
        XCTAssertFalse(usHolidays.contains(where: \.isObserved))
    }

    private func utcDateStrings(_ holidays: [HolidayOccurrence]) -> [String] {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return holidays.map { formatter.string(from: $0.date) }
    }
}
