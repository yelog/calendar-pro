import Foundation

struct MainlandCNProvider: HolidayProvider {
    static let statutoryHolidaySetID = "statutory-holidays"
    static let adjustmentWorkdaySetID = "adjustment-workdays"
    static let commemorativeFestivalSetID = "commemorative-festivals"

    private let loader: BundledHolidayDataLoader

    init(bundle: Bundle = .main, cacheStore: HolidayCacheStore? = nil) {
        loader = BundledHolidayDataLoader(bundle: bundle, cacheStore: cacheStore)
    }

    var descriptor: HolidayProviderDescriptor {
        HolidayProviderDescriptor(
            id: "mainland-cn",
            displayName: L("Mainland China"),
            supportsOfflineData: true,
            supportsRemoteRefresh: true,
            availableHolidaySets: [
                HolidaySet(
                    id: Self.statutoryHolidaySetID,
                    displayName: L("Statutory Holidays"),
                    supportedKinds: [.statutoryHoliday]
                ),
                HolidaySet(
                    id: Self.adjustmentWorkdaySetID,
                    displayName: L("Adjustment Workdays"),
                    supportedKinds: [.workingAdjustmentDay]
                ),
                HolidaySet(
                    id: Self.commemorativeFestivalSetID,
                    displayName: L("Commemorative Festivals"),
                    supportedKinds: [.festival]
                )
            ]
        )
    }

    func holidays(forYear year: Int) throws -> [HolidayOccurrence] {
        let loaded = try loader.load(regionID: descriptor.id, year: year)
        let generated = Self.gregorianFestivalRules.compactMap {
            $0.makeOccurrence(year: year, regionID: descriptor.id)
        }

        return Self.deduplicated(loaded + generated)
    }

    private static let gregorianFestivalRules: [GregorianFestivalRule] = [
        GregorianFestivalRule(name: "母亲节", month: 5, weekday: 1, weekdayOrdinal: 2),
        GregorianFestivalRule(name: "父亲节", month: 6, weekday: 1, weekdayOrdinal: 3)
    ]

    private static func deduplicated(_ holidays: [HolidayOccurrence]) -> [HolidayOccurrence] {
        var seenIDs: Set<String> = []
        return holidays.filter { holiday in
            seenIDs.insert(holiday.id).inserted
        }
    }
}

private struct GregorianFestivalRule {
    let name: String
    let month: Int
    let weekday: Int
    let weekdayOrdinal: Int

    func makeOccurrence(year: Int, regionID: String) -> HolidayOccurrence? {
        let calendar = Self.calendar
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            weekday: weekday,
            weekdayOrdinal: weekdayOrdinal
        )

        guard let date = components.date else { return nil }
        let dayComponents = calendar.dateComponents([.year, .month, .day], from: date)
        guard
            dayComponents.year == year,
            dayComponents.month == month,
            let day = dayComponents.day
        else {
            return nil
        }

        let dateID = String(format: "%04d-%02d-%02d", year, month, day)
        return HolidayOccurrence(
            id: "\(regionID)-\(dateID)-\(MainlandCNProvider.commemorativeFestivalSetID)-\(HolidayKind.festival.rawValue)",
            regionID: regionID,
            date: date,
            name: name,
            kind: .festival,
            holidaySetID: MainlandCNProvider.commemorativeFestivalSetID,
            isObserved: false,
            isAdjustmentWorkday: false,
            source: .calculatedGregorian
        )
    }

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
