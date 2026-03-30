import Foundation

struct HolidaySet: Equatable, Identifiable {
    let id: String
    let displayName: String
    let supportedKinds: [HolidayKind]
}

struct HolidayProviderDescriptor: Equatable {
    let id: String
    let displayName: String
    let supportsOfflineData: Bool
    let supportsRemoteRefresh: Bool
    let availableHolidaySets: [HolidaySet]
}

protocol HolidayProvider {
    var descriptor: HolidayProviderDescriptor { get }
    func holidays(forYear year: Int) throws -> [HolidayOccurrence]
}

enum HolidayProviderError: Error, Equatable {
    case resourceNotFound(String)
    case invalidDate(String)
}

struct BundledHolidayDataLoader {
    let bundle: Bundle
    let cacheStore: HolidayCacheStore?

    init(bundle: Bundle = .main, cacheStore: HolidayCacheStore? = nil) {
        self.bundle = bundle
        self.cacheStore = cacheStore
    }

    func load(regionID: String, year: Int) throws -> [HolidayOccurrence] {
        if
            let cacheStore,
            let cachedData = try cacheStore.loadHolidayData(regionID: regionID, year: year),
            let cachedRecords = try? Self.decode(data: cachedData, regionID: regionID, source: .remoteFeed)
        {
            return cachedRecords
        }

        let resourceName = "\(regionID)-\(year)"

        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            return []
        }

        let data = try Data(contentsOf: url)
        return try Self.decode(data: data, regionID: regionID, source: .bundledJSON)
    }

    static func decode(data: Data, regionID: String, source: HolidaySource) throws -> [HolidayOccurrence] {
        let records = try JSONDecoder().decode([BundledHolidayRecord].self, from: data)

        return try records.map { record in
            HolidayOccurrence(
                id: "\(regionID)-\(record.date)-\(record.holidaySetID)-\(record.kind.rawValue)",
                regionID: regionID,
                date: try Self.makeDate(record.date),
                name: record.name,
                kind: record.kind,
                holidaySetID: record.holidaySetID,
                isObserved: record.isObserved ?? false,
                isAdjustmentWorkday: record.isAdjustmentWorkday ?? false,
                source: source
            )
        }
    }

    private static func makeDate(_ value: String) throws -> Date {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"

        guard let date = formatter.date(from: value) else {
            throw HolidayProviderError.invalidDate(value)
        }

        return date
    }
}

private struct BundledHolidayRecord: Decodable {
    let date: String
    let name: String
    let kind: HolidayKind
    let holidaySetID: String
    let isObserved: Bool?
    let isAdjustmentWorkday: Bool?
}
