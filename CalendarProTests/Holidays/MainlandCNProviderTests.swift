import XCTest
@testable import CalendarPro

final class MainlandCNProviderTests: XCTestCase {
    func testMainlandProviderMarksSpringFestivalAsStatutoryHoliday() throws {
        let provider = MainlandCNProvider()
        let holidays = try provider.holidays(forYear: 2026)

        XCTAssertTrue(
            holidays.contains {
                Calendar.gregorianMondayFirst.isDate($0.date, inSameDayAs: makeDate(year: 2026, month: 2, day: 17))
                    && $0.name == "春节"
                    && $0.kind == .statutoryHoliday
            }
        )
    }

    func testMainlandProviderIncludesAdjustmentWorkday() throws {
        let provider = MainlandCNProvider()
        let holidays = try provider.holidays(forYear: 2026)

        XCTAssertTrue(
            holidays.contains {
                Calendar.gregorianMondayFirst.isDate($0.date, inSameDayAs: makeDate(year: 2026, month: 10, day: 10))
                    && $0.kind == .workingAdjustmentDay
                    && $0.isAdjustmentWorkday
            }
        )
    }

    func testMainlandProviderGeneratesGregorianObservanceFestivals() throws {
        let provider = MainlandCNProvider()
        let holidays = try provider.holidays(forYear: 2026)

        XCTAssertTrue(
            holidays.contains {
                Calendar.gregorianMondayFirst.isDate($0.date, inSameDayAs: makeDate(year: 2026, month: 5, day: 10))
                    && $0.name == "母亲节"
                    && $0.kind == .festival
                    && $0.holidaySetID == MainlandCNProvider.commemorativeFestivalSetID
                    && $0.source == .calculatedGregorian
            }
        )

        XCTAssertTrue(
            holidays.contains {
                Calendar.gregorianMondayFirst.isDate($0.date, inSameDayAs: makeDate(year: 2026, month: 6, day: 21))
                    && $0.name == "父亲节"
                    && $0.kind == .festival
                    && $0.holidaySetID == MainlandCNProvider.commemorativeFestivalSetID
                    && $0.source == .calculatedGregorian
            }
        )
    }

    func testMainlandProviderGeneratesGregorianObservanceFestivalsBeyondBundledYears() throws {
        let provider = MainlandCNProvider()
        let holidays = try provider.holidays(forYear: 2027)

        XCTAssertTrue(
            holidays.contains {
                Calendar.gregorianMondayFirst.isDate($0.date, inSameDayAs: makeDate(year: 2027, month: 5, day: 9))
                    && $0.name == "母亲节"
                    && $0.kind == .festival
            }
        )
    }

    func testMainlandProviderPrefersCachedRemoteDataWhenAvailable() throws {
        let cacheURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CalendarProTests", isDirectory: true)
            .appendingPathComponent(#function, isDirectory: true)
        let cacheStore = HolidayCacheStore(baseURL: cacheURL)
        defer { try? FileManager.default.removeItem(at: cacheURL) }

        try cacheStore.saveHolidayData(
            Data(
                """
                [
                  {
                    "date": "2026-02-17",
                    "name": "春节缓存",
                    "kind": "statutoryHoliday",
                    "holidaySetID": "statutory-holidays"
                  }
                ]
                """.utf8
            ),
            regionID: "mainland-cn",
            year: 2026
        )

        let provider = MainlandCNProvider(cacheStore: cacheStore)
        let holidays = try provider.holidays(forYear: 2026)

        XCTAssertEqual(holidays.first?.name, "春节缓存")
        XCTAssertEqual(holidays.first?.source, .remoteFeed)
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        DateComponents(
            calendar: Calendar.gregorianMondayFirst,
            timeZone: TimeZone(secondsFromGMT: 0),
            year: year,
            month: month,
            day: day
        ).date!
    }
}
