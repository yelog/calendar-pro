import Foundation

struct UnitedKingdomProvider: HolidayProvider {
    private let loader: BundledHolidayDataLoader

    init(bundle: Bundle = .main, cacheStore: HolidayCacheStore? = nil) {
        loader = BundledHolidayDataLoader(bundle: bundle, cacheStore: cacheStore)
    }

    var descriptor: HolidayProviderDescriptor {
        HolidayProviderDescriptor(
            id: "uk",
            displayName: String(localized: "United Kingdom"),
            supportsOfflineData: true,
            supportsRemoteRefresh: false,
            availableHolidaySets: [
                HolidaySet(
                    id: "bank-holidays",
                    displayName: String(localized: "Bank Holidays"),
                    supportedKinds: [.publicHoliday]
                )
            ]
        )
    }

    func holidays(forYear year: Int) throws -> [HolidayOccurrence] {
        try loader.load(regionID: descriptor.id, year: year)
    }
}
