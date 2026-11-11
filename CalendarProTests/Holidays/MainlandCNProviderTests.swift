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
        let holidays = try provider.holidays(forYear: 2030)

        XCTAssertTrue(
            holidays.contains {
                Calendar.gregorianMondayFirst.isDate($0.date, inSameDayAs: makeDate(year: 2030, month: 5, day: 12))
                    && $0.name == "母亲节"
                    && $0.kind == .festival
            }
        )
    }

    func testMainlandProviderIncludesPublished2027Schedule() throws {
        let provider = MainlandCNProvider()
        let holidays = try provider.holidays(forYear: 2027)

        XCTAssertEqual(holidays.filter { $0.kind == .statutoryHoliday }.count, 29)
        XCTAssertEqual(holidays.filter { $0.kind == .workingAdjustmentDay }.count, 5)
        XCTAssertTrue(
            holidays.contains {
                Calendar.gregorianMondayFirst.isDate($0.date, inSameDayAs: makeDate(year: 2027, month: 2, day: 5))
                    && $0.name == "春节"
                    && $0.kind == .statutoryHoliday
            }
        )
        XCTAssertTrue(
            holidays.contains {
                Calendar.gregorianMondayFirst.isDate($0.date, inSameDayAs: makeDate(year: 2027, month: 1, day: 31))
                    && $0.kind == .workingAdjustmentDay
            }
        )
        XCTAssertEqual(provider.datasetAvailability(forYear: 2027), .bundled)
    }

    func testMainlandProviderReportsMissingFutureDataset() {
        let provider = MainlandCNProvider()

        XCTAssertEqual(provider.datasetAvailability(forYear: 2030), .missing)
    }

    func testMainlandProviderPrefersCachedRemoteDataWhenAvailable() throws {
        let cacheStore = makeCacheStore(name: #function)
        defer { try? FileManager.default.removeItem(at: cacheStore.baseURL) }

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

    func testMainlandProviderIgnoresCachedDataFromDifferentYear() throws {
        let cacheStore = makeCacheStore(name: #function)
        defer { try? FileManager.default.removeItem(at: cacheStore.baseURL) }

        try cacheStore.saveHolidayData(
            Data(
                """
                [
                  {
                    "date": "2025-02-17",
                    "name": "错误年份",
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

        XCTAssertTrue(holidays.contains { $0.name == "春节" && $0.source == .bundledJSON })
        XCTAssertEqual(provider.datasetAvailability(forYear: 2026), .bundled)
    }

    func testMainlandProviderIgnoresEmptyCachedDataset() throws {
        let cacheStore = makeCacheStore(name: #function)
        defer { try? FileManager.default.removeItem(at: cacheStore.baseURL) }

        try cacheStore.saveHolidayData(
            Data("[]".utf8),
            regionID: "mainland-cn",
            year: 2026
        )

        let provider = MainlandCNProvider(cacheStore: cacheStore)
        let holidays = try provider.holidays(forYear: 2026)

        XCTAssertTrue(holidays.contains { $0.name == "春节" && $0.source == .bundledJSON })
        XCTAssertEqual(provider.datasetAvailability(forYear: 2026), .bundled)
    }

    func testMainlandProviderIgnoresConflictingCachedWorkdayRecords() throws {
        let cacheStore = makeCacheStore(name: #function)
        defer { try? FileManager.default.removeItem(at: cacheStore.baseURL) }

        try cacheStore.saveHolidayData(
            Data(
                """
                [
                  {
                    "date": "2026-02-17",
                    "name": "春节",
                    "kind": "statutoryHoliday",
                    "holidaySetID": "statutory-holidays"
                  },
                  {
                    "date": "2026-02-17",
                    "name": "春节调休上班",
                    "kind": "workingAdjustmentDay",
                    "holidaySetID": "adjustment-workdays",
                    "isAdjustmentWorkday": true
                  }
                ]
                """.utf8
            ),
            regionID: "mainland-cn",
            year: 2026
        )

        let provider = MainlandCNProvider(cacheStore: cacheStore)
        let holidays = try provider.holidays(forYear: 2026)

        XCTAssertTrue(holidays.contains { $0.name == "春节" && $0.source == .bundledJSON })
        XCTAssertEqual(provider.datasetAvailability(forYear: 2026), .bundled)
    }

    func testMainlandProviderFallsBackWhenCachedPayloadCannotBeRead() throws {
        let cacheStore = makeCacheStore(name: #function)
        defer { try? FileManager.default.removeItem(at: cacheStore.baseURL) }

        let unreadablePayloadURL = cacheStore.baseURL
            .appendingPathComponent("mainland-cn-2026.json", isDirectory: true)
        try FileManager.default.createDirectory(
            at: unreadablePayloadURL,
            withIntermediateDirectories: true
        )

        let provider = MainlandCNProvider(cacheStore: cacheStore)
        let holidays = try provider.holidays(forYear: 2026)

        XCTAssertTrue(holidays.contains { $0.name == "春节" && $0.source == .bundledJSON })
        XCTAssertEqual(provider.datasetAvailability(forYear: 2026), .bundled)
    }

    func testMainlandProviderReportsUnreadableCacheForYearWithoutBundle() throws {
        let cacheStore = makeCacheStore(name: #function)
        defer { try? FileManager.default.removeItem(at: cacheStore.baseURL) }

        let unreadablePayloadURL = cacheStore.baseURL
            .appendingPathComponent("mainland-cn-2030.json", isDirectory: true)
        try FileManager.default.createDirectory(
            at: unreadablePayloadURL,
            withIntermediateDirectories: true
        )

        let provider = MainlandCNProvider(cacheStore: cacheStore)

        XCTAssertEqual(provider.datasetAvailability(forYear: 2030), .invalid)
    }

    func testMainlandProviderRejectsCachedKindAndHolidaySetMismatch() throws {
        let cacheStore = makeCacheStore(name: #function)
        defer { try? FileManager.default.removeItem(at: cacheStore.baseURL) }

        try cacheStore.saveHolidayData(
            Data(
                """
                [
                  {
                    "date": "2026-02-17",
                    "name": "错误集合",
                    "kind": "statutoryHoliday",
                    "holidaySetID": "adjustment-workdays"
                  }
                ]
                """.utf8
            ),
            regionID: "mainland-cn",
            year: 2026
        )

        let provider = MainlandCNProvider(cacheStore: cacheStore)
        let holidays = try provider.holidays(forYear: 2026)

        XCTAssertTrue(holidays.contains { $0.name == "春节" && $0.source == .bundledJSON })
        XCTAssertEqual(provider.datasetAvailability(forYear: 2026), .bundled)
    }

    func testHolidayDataLoaderAcceptsSourceScheduleYearMetadata() throws {
        let occurrences = try BundledHolidayDataLoader.decode(
            data: Data(
                """
                [
                  {
                    "date": "2027-01-01",
                    "name": "元旦",
                    "kind": "statutoryHoliday",
                    "holidaySetID": "statutory-holidays",
                    "sourceScheduleYear": 2027
                  }
                ]
                """.utf8
            ),
            regionID: "mainland-cn",
            year: 2027,
            source: .remoteFeed
        )

        XCTAssertEqual(occurrences.first?.name, "元旦")
    }

    private func makeCacheStore(name: String) -> HolidayCacheStore {
        let cacheURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CalendarProTests", isDirectory: true)
            .appendingPathComponent(name.replacingOccurrences(of: "/", with: "-"), isDirectory: true)
        return HolidayCacheStore(baseURL: cacheURL)
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
