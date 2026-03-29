import Foundation

struct HolidayResolver {
    let registry: HolidayProviderRegistry
    let calendar: Calendar

    init(registry: HolidayProviderRegistry = .default, calendar: Calendar = .autoupdatingCurrent) {
        self.registry = registry
        self.calendar = calendar
    }

    func holidays(
        on date: Date,
        activeRegionIDs: [String],
        enabledHolidaySetIDs: [String]
    ) throws -> [HolidayOccurrence] {
        let byDay = try holidaysByDay(
            for: [date],
            activeRegionIDs: activeRegionIDs,
            enabledHolidaySetIDs: enabledHolidaySetIDs
        )

        return byDay[calendar.startOfDay(for: date)] ?? []
    }

    func holidaysByDay(
        for dates: [Date],
        activeRegionIDs: [String],
        enabledHolidaySetIDs: [String]
    ) throws -> [Date: [HolidayOccurrence]] {
        let years = Set(dates.map { calendar.component(.year, from: $0) })
        var resolved: [HolidayOccurrence] = []

        for regionID in activeRegionIDs {
            guard let provider = registry.provider(for: regionID) else { continue }
            for year in years.sorted() {
                resolved.append(contentsOf: try provider.holidays(forYear: year))
            }
        }

        if !enabledHolidaySetIDs.isEmpty {
            let enabled = Set(enabledHolidaySetIDs)
            resolved = resolved.filter { enabled.contains($0.holidaySetID) }
        }

        let grouped = Dictionary(grouping: resolved) { occurrence in
            calendar.startOfDay(for: occurrence.date)
        }

        return grouped.mapValues { occurrences in
            occurrences.sorted { lhs, rhs in
                if lhs.kind.priority == rhs.kind.priority {
                    return lhs.name < rhs.name
                }
                return lhs.kind.priority > rhs.kind.priority
            }
        }
    }
}
