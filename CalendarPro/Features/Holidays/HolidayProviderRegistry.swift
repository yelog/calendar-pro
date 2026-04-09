import Foundation

struct HolidayProviderRegistry {
    let providers: [any HolidayProvider]

    static var `default`: HolidayProviderRegistry {
        HolidayProviderRegistry(
            providers: [
                MainlandCNProvider(),
                HongKongProvider(),
                UnitedStatesProvider(),
                UnitedKingdomProvider()
            ]
        )
    }

    static var live: HolidayProviderRegistry {
        HolidayProviderRegistry(
            providers: [
                MainlandCNProvider(cacheStore: .default),
                HongKongProvider(cacheStore: .default),
                UnitedStatesProvider(),
                UnitedKingdomProvider()
            ]
        )
    }

    func provider(for id: String) -> (any HolidayProvider)? {
        providers.first { $0.descriptor.id == id }
    }
}
