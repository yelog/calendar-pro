import Foundation

struct UnitedStatesProvider: HolidayProvider {
    private let loader: BundledHolidayDataLoader

    init(bundle: Bundle = .main, cacheStore: HolidayCacheStore? = nil) {
        loader = BundledHolidayDataLoader(bundle: bundle, cacheStore: cacheStore)
    }

    var descriptor: HolidayProviderDescriptor {
        HolidayProviderDescriptor(
            id: "us",
            displayName: L("United States"),
            supportsOfflineData: true,
            supportsRemoteRefresh: false,
            availableHolidaySets: [
                HolidaySet(
                    id: "federal-holidays",
                    displayName: L("Federal Holidays"),
                    supportedKinds: [.publicHoliday]
                )
            ]
        )
    }

    func holidays(forYear year: Int) throws -> [HolidayOccurrence] {
        try loader.load(regionID: descriptor.id, year: year)
    }
}
