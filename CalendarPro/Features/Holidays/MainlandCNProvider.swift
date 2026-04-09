import Foundation

struct MainlandCNProvider: HolidayProvider {
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
                    id: "statutory-holidays",
                    displayName: L("Statutory Holidays"),
                    supportedKinds: [.statutoryHoliday]
                ),
                HolidaySet(
                    id: "adjustment-workdays",
                    displayName: L("Adjustment Workdays"),
                    supportedKinds: [.workingAdjustmentDay]
                )
            ]
        )
    }

    func holidays(forYear year: Int) throws -> [HolidayOccurrence] {
        try loader.load(regionID: descriptor.id, year: year)
    }
}
