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

enum HolidayDatasetAvailability: Equatable {
    case cache
    case bundled
    case missing
    case invalid
}

protocol HolidayProvider {
    var descriptor: HolidayProviderDescriptor { get }
    func holidays(forYear year: Int) throws -> [HolidayOccurrence]
    func datasetAvailability(forYear year: Int) -> HolidayDatasetAvailability
}

enum HolidayProviderError: Error, Equatable {
    case resourceNotFound(String)
    case invalidDate(String)
    case emptyDataset(String)
    case invalidRecord(String)
}

struct BundledHolidayDataLoader {
    let bundle: Bundle
    let cacheStore: HolidayCacheStore?

    init(bundle: Bundle = .main, cacheStore: HolidayCacheStore? = nil) {
        self.bundle = bundle
        self.cacheStore = cacheStore
    }

    func load(
        regionID: String,
        year: Int,
        validate: ((HolidayOccurrence) -> Bool)? = nil
    ) throws -> [HolidayOccurrence] {
        if
            let cacheStore,
            let cachedData = try? cacheStore.loadHolidayData(regionID: regionID, year: year),
            let cachedRecords = try? Self.decode(
                data: cachedData,
                regionID: regionID,
                year: year,
                source: .remoteFeed,
                validate: validate
            )
        {
            return cachedRecords
        }

        let resourceName = "\(regionID)-\(year)"

        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            return []
        }

        guard let data = try? Data(contentsOf: url) else {
            return []
        }

        return (try? Self.decode(
            data: data,
            regionID: regionID,
            year: year,
            source: .bundledJSON,
            validate: validate
        )) ?? []
    }

    func datasetAvailability(
        regionID: String,
        year: Int,
        validate: ((HolidayOccurrence) -> Bool)? = nil
    ) -> HolidayDatasetAvailability {
        var cacheIsInvalid = false
        if let cacheStore {
            do {
                if let cachedData = try cacheStore.loadHolidayData(regionID: regionID, year: year) {
                    if (try? Self.decode(
                        data: cachedData,
                        regionID: regionID,
                        year: year,
                        source: .remoteFeed,
                        validate: validate
                    )) != nil {
                        return .cache
                    }
                    cacheIsInvalid = true
                }
            } catch {
                cacheIsInvalid = true
            }
        }

        let resourceName = "\(regionID)-\(year)"
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            return cacheIsInvalid ? .invalid : .missing
        }

        guard let data = try? Data(contentsOf: url) else {
            return .invalid
        }

        return (try? Self.decode(
            data: data,
            regionID: regionID,
            year: year,
            source: .bundledJSON,
            validate: validate
        )) != nil
            ? .bundled
            : .invalid
    }

    static func decode(
        data: Data,
        regionID: String,
        year expectedYear: Int? = nil,
        source: HolidaySource,
        validate: ((HolidayOccurrence) -> Bool)? = nil
    ) throws -> [HolidayOccurrence] {
        let records = try JSONDecoder().decode([BundledHolidayRecord].self, from: data)
        guard !records.isEmpty else {
            throw HolidayProviderError.emptyDataset(regionID)
        }

        let calendar = Self.gregorianUTC
        var seenIDs: Set<String> = []
        var workStatusByDate: [String: Bool] = [:]
        var occurrences: [HolidayOccurrence] = []

        for record in records {
            let trimmedName = record.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else {
                throw HolidayProviderError.invalidRecord("\(regionID)-\(record.date): empty name")
            }
            guard !record.holidaySetID.isEmpty else {
                throw HolidayProviderError.invalidRecord("\(regionID)-\(record.date): empty holiday set")
            }

            let date = try Self.makeDate(record.date)
            if let expectedYear {
                let actualYear = calendar.component(.year, from: date)
                guard actualYear == expectedYear else {
                    throw HolidayProviderError.invalidRecord(
                        "\(regionID)-\(record.date): expected year \(expectedYear), found \(actualYear)"
                    )
                }
            }

            let isAdjustmentWorkday = record.isAdjustmentWorkday ?? false
            if record.kind == .workingAdjustmentDay, !isAdjustmentWorkday {
                throw HolidayProviderError.invalidRecord(
                    "\(regionID)-\(record.date): adjustment workday is not marked"
                )
            }
            if record.kind != .workingAdjustmentDay, isAdjustmentWorkday {
                throw HolidayProviderError.invalidRecord(
                    "\(regionID)-\(record.date): non-workday is marked as adjustment"
                )
            }

            if
                let existingWorkStatus = workStatusByDate[record.date],
                existingWorkStatus != (record.kind == .workingAdjustmentDay)
            {
                throw HolidayProviderError.invalidRecord(
                    "\(regionID)-\(record.date): conflicting holiday and workday records"
                )
            }
            workStatusByDate[record.date] = record.kind == .workingAdjustmentDay

            let occurrence = HolidayOccurrence(
                id: "\(regionID)-\(record.date)-\(record.holidaySetID)-\(record.kind.rawValue)",
                regionID: regionID,
                date: date,
                name: trimmedName,
                kind: record.kind,
                holidaySetID: record.holidaySetID,
                isObserved: record.isObserved ?? false,
                isAdjustmentWorkday: isAdjustmentWorkday,
                source: source
            )
            guard validate?(occurrence) ?? true else {
                throw HolidayProviderError.invalidRecord(
                    "\(regionID)-\(record.date): record violates provider constraints"
                )
            }
            guard seenIDs.insert(occurrence.id).inserted else {
                throw HolidayProviderError.invalidRecord(
                    "\(regionID)-\(record.date): duplicate holiday record"
                )
            }
            occurrences.append(occurrence)
        }

        return occurrences
    }

    private static var gregorianUTC: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
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
