import Foundation

struct MainlandCNProvider: HolidayProvider {
    private let loader: BundledHolidayDataLoader

    init(bundle: Bundle = .main, cacheStore: HolidayCacheStore? = nil) {
        loader = BundledHolidayDataLoader(bundle: bundle, cacheStore: cacheStore)
    }

    var descriptor: HolidayProviderDescriptor {
        HolidayProviderDescriptor(
            id: "mainland-cn",
            displayName: "中国大陆",
            supportsOfflineData: true,
            supportsRemoteRefresh: true,
            availableHolidaySets: [
                HolidaySet(
                    id: "statutory-holidays",
                    displayName: "法定节假日",
                    supportedKinds: [.statutoryHoliday]
                ),
                HolidaySet(
                    id: "adjustment-workdays",
                    displayName: "调休上班",
                    supportedKinds: [.workingAdjustmentDay]
                )
            ]
        )
    }

    func holidays(forYear year: Int) throws -> [HolidayOccurrence] {
        try loader.load(regionID: descriptor.id, year: year)
    }
}
