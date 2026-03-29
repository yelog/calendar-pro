import Foundation

struct HongKongProvider: HolidayProvider {
    private let loader: BundledHolidayDataLoader

    init(bundle: Bundle = .main, cacheStore: HolidayCacheStore? = nil) {
        loader = BundledHolidayDataLoader(bundle: bundle, cacheStore: cacheStore)
    }

    var descriptor: HolidayProviderDescriptor {
        HolidayProviderDescriptor(
            id: "hong-kong",
            displayName: "中国香港",
            supportsOfflineData: true,
            supportsRemoteRefresh: true,
            availableHolidaySets: [
                HolidaySet(
                    id: "public-holidays",
                    displayName: "公众假期",
                    supportedKinds: [.publicHoliday]
                )
            ]
        )
    }

    func holidays(forYear year: Int) throws -> [HolidayOccurrence] {
        try loader.load(regionID: descriptor.id, year: year)
    }
}
