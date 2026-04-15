import Foundation

struct VacationPlanningService {
    private enum PlanningDayKind: Equatable {
        case weekend
        case statutoryHoliday([String])
        case leaveRequired
        case adjustmentWorkday
    }

    private struct PlanningDayStatus {
        let date: Date
        let kind: PlanningDayKind

        var requiresLeave: Bool {
            switch kind {
            case .leaveRequired, .adjustmentWorkday:
                true
            case .weekend, .statutoryHoliday:
                false
            }
        }

        var isHoliday: Bool {
            if case .statutoryHoliday = kind {
                return true
            }
            return false
        }
    }

    private struct HolidayBlock {
        let startIndex: Int
        let endIndex: Int
    }

    private struct VacationCandidate: Equatable {
        let year: Int
        let holidayName: String
        let startDate: Date
        let endDate: Date
        let focusDate: Date
        let leaveDaysRequired: Int
        let continuousRestDays: Int
        let segments: [VacationSegment]
        let rankingScore: Int
        let starRating: Int
        let summary: String
        let note: String

        var opportunity: VacationOpportunity {
            VacationOpportunity(
                year: year,
                holidayName: holidayName,
                startDate: startDate,
                endDate: endDate,
                focusDate: focusDate,
                leaveDaysRequired: leaveDaysRequired,
                continuousRestDays: continuousRestDays,
                segments: segments,
                rankingScore: rankingScore,
                starRating: starRating,
                summary: summary,
                note: note
            )
        }
    }

    let holidayResolver: HolidayResolver
    let calendar: Calendar
    let maxLeaveDays: Int
    let searchPaddingDays: Int

    init(
        registry: HolidayProviderRegistry = .live,
        calendar: Calendar = .autoupdatingCurrent,
        maxLeaveDays: Int = 5,
        searchPaddingDays: Int = 10
    ) {
        self.calendar = calendar
        self.maxLeaveDays = maxLeaveDays
        self.searchPaddingDays = searchPaddingDays
        holidayResolver = HolidayResolver(registry: registry, calendar: calendar)
    }

    func opportunities(
        forYear year: Int,
        activeRegionIDs: [String],
        enabledHolidaySetIDs: [String]
    ) throws -> [VacationOpportunity] {
        guard activeRegionIDs.contains("mainland-cn") else {
            return []
        }

        let yearStart = startOfYear(for: year)
        let yearEnd = endOfYear(for: year)
        let searchStart = addingDays(-searchPaddingDays, to: yearStart)
        let searchEnd = addingDays(searchPaddingDays, to: yearEnd)
        let searchDates = dates(from: searchStart, through: searchEnd)
        let holidayMap = try holidayResolver.holidaysByDay(
            for: searchDates,
            activeRegionIDs: ["mainland-cn"],
            enabledHolidaySetIDs: enabledHolidaySetIDs
        )
        let statuses = searchDates.map { date in
            makeStatus(for: date, occurrences: holidayMap[calendar.startOfDay(for: date)] ?? [])
        }
        let yearStatuses = statuses.enumerated().filter { element in
            let date = element.element.date
            return date >= yearStart && date <= yearEnd
        }
        let blocks = holidayBlocks(from: yearStatuses)

        guard !blocks.isEmpty else {
            return []
        }

        let candidates = blocks.compactMap { block in
            bestCandidate(
                for: block,
                within: statuses,
                targetYear: year
            )
        }

        let byRange = Dictionary(grouping: candidates) { candidate in
            "\(candidate.startDate.timeIntervalSinceReferenceDate)-\(candidate.endDate.timeIntervalSinceReferenceDate)"
        }

        return byRange.values
            .compactMap { values in
                values.sorted { lhs, rhs in
                    isBetter(lhs: lhs, rhs: rhs)
                }.first?.opportunity
            }
            .sorted { lhs, rhs in
                if lhs.focusDate != rhs.focusDate {
                    return lhs.focusDate < rhs.focusDate
                }

                if lhs.startDate != rhs.startDate {
                    return lhs.startDate < rhs.startDate
                }

                if lhs.leaveDaysRequired != rhs.leaveDaysRequired {
                    return lhs.leaveDaysRequired < rhs.leaveDaysRequired
                }

                return lhs.holidayName < rhs.holidayName
            }
    }

    private func bestCandidate(
        for block: HolidayBlock,
        within statuses: [PlanningDayStatus],
        targetYear: Int
    ) -> VacationCandidate? {
        let minStartIndex = max(0, block.startIndex - searchPaddingDays)
        let maxEndIndex = min(statuses.count - 1, block.endIndex + searchPaddingDays)
        var best: VacationCandidate?

        for startIndex in minStartIndex...block.startIndex {
            var leaveDays = 0

            for index in startIndex...maxEndIndex {
                if statuses[index].requiresLeave {
                    leaveDays += 1
                }

                if index < block.endIndex {
                    continue
                }

                if leaveDays > maxLeaveDays {
                    break
                }

                guard leaveDays > 0 else {
                    continue
                }

                let windowStatuses = Array(statuses[startIndex...index])
                guard let candidate = makeCandidate(
                    from: windowStatuses,
                    targetYear: targetYear
                ) else {
                    continue
                }

                if best == nil || isBetter(lhs: candidate, rhs: best!) {
                    best = candidate
                }
            }
        }

        return best
    }

    private func makeCandidate(
        from windowStatuses: [PlanningDayStatus],
        targetYear: Int
    ) -> VacationCandidate? {
        guard let firstStatus = windowStatuses.first,
              let lastStatus = windowStatuses.last else {
            return nil
        }

        // Keep windows anchored to natural rest boundaries instead of starting or
        // ending on an extra leave day, which otherwise over-favors "max leave" plans.
        guard !firstStatus.requiresLeave, !lastStatus.requiresLeave else {
            return nil
        }

        let startDate = firstStatus.date
        let endDate = lastStatus.date

        let leaveDaysRequired = windowStatuses.filter(\.requiresLeave).count
        let holidayNames = combinedHolidayNames(in: windowStatuses)

        guard leaveDaysRequired > 0, !holidayNames.isEmpty else {
            return nil
        }

        let focusDate = firstHolidayDate(in: windowStatuses, targetYear: targetYear) ?? startDate
        let adjustmentWorkdayCount = windowStatuses.filter {
            if case .adjustmentWorkday = $0.kind {
                return true
            }
            return false
        }.count
        let holidayDayCount = windowStatuses.filter(\.isHoliday).count
        let continuousRestDays = windowStatuses.count
        let efficiencyScore = (continuousRestDays * 100) / leaveDaysRequired
        let rankingScore = (continuousRestDays * 12) + (holidayDayCount * 2) - (leaveDaysRequired * 14) - (adjustmentWorkdayCount * 2)
        let starRating: Int
        switch (efficiencyScore, continuousRestDays) {
        case (430..., _), (_, 14...):
            starRating = 5
        case (300..., _), (_, 11...):
            starRating = 4
        case (230..., _), (_, 9...):
            starRating = 3
        case (180..., _), (_, 7...):
            starRating = 2
        default:
            starRating = 1
        }

        return VacationCandidate(
            year: targetYear,
            holidayName: holidayNames.joined(separator: "、"),
            startDate: startDate,
            endDate: endDate,
            focusDate: focusDate,
            leaveDaysRequired: leaveDaysRequired,
            continuousRestDays: continuousRestDays,
            segments: windowStatuses.map(makeSegment(from:)),
            rankingScore: rankingScore,
            starRating: starRating,
            summary: "请\(leaveDaysRequired)休\(continuousRestDays)",
            note: note(
                continuousRestDays: continuousRestDays,
                leaveDaysRequired: leaveDaysRequired,
                holidayCount: holidayNames.count
            )
        )
    }

    private func isBetter(lhs: VacationCandidate, rhs: VacationCandidate) -> Bool {
        if lhs.rankingScore != rhs.rankingScore {
            return lhs.rankingScore > rhs.rankingScore
        }

        if lhs.continuousRestDays != rhs.continuousRestDays {
            return lhs.continuousRestDays > rhs.continuousRestDays
        }

        if lhs.leaveDaysRequired != rhs.leaveDaysRequired {
            return lhs.leaveDaysRequired < rhs.leaveDaysRequired
        }

        return lhs.startDate < rhs.startDate
    }

    private func holidayBlocks(
        from yearStatuses: [(offset: Int, element: PlanningDayStatus)]
    ) -> [HolidayBlock] {
        var blocks: [HolidayBlock] = []
        var currentStart: Int?
        var currentEnd: Int?

        for entry in yearStatuses {
            let isHoliday = entry.element.isHoliday

            if isHoliday {
                if currentStart == nil {
                    currentStart = entry.offset
                }
                currentEnd = entry.offset
                continue
            }

            if let startIndex = currentStart, let endIndex = currentEnd {
                blocks.append(HolidayBlock(startIndex: startIndex, endIndex: endIndex))
                currentEnd = nil
                currentStart = nil
            }
        }

        if let startIndex = currentStart, let endIndex = currentEnd {
            blocks.append(HolidayBlock(startIndex: startIndex, endIndex: endIndex))
        }

        return blocks
    }

    private func makeStatus(
        for date: Date,
        occurrences: [HolidayOccurrence]
    ) -> PlanningDayStatus {
        let holidayNames = occurrences
            .filter { $0.kind == .statutoryHoliday || $0.kind == .publicHoliday }
            .map(\.name)

        if !holidayNames.isEmpty {
            return PlanningDayStatus(date: date, kind: .statutoryHoliday(stableUnique(holidayNames)))
        }

        if occurrences.contains(where: { $0.kind == .workingAdjustmentDay }) {
            return PlanningDayStatus(date: date, kind: .adjustmentWorkday)
        }

        if calendar.isDateInWeekend(date) {
            return PlanningDayStatus(date: date, kind: .weekend)
        }

        return PlanningDayStatus(date: date, kind: .leaveRequired)
    }

    private func combinedHolidayNames(in statuses: [PlanningDayStatus]) -> [String] {
        stableUnique(
            statuses.flatMap { status in
                if case let .statutoryHoliday(names) = status.kind {
                    return names
                }
                return []
            }
        )
    }

    private func firstHolidayDate(in statuses: [PlanningDayStatus], targetYear: Int) -> Date? {
        statuses.first { status in
            guard status.isHoliday else { return false }
            return calendar.component(.year, from: status.date) == targetYear
        }?.date
    }

    private func makeSegment(from status: PlanningDayStatus) -> VacationSegment {
        let label: String
        let kind: VacationSegmentKind

        switch status.kind {
        case .weekend:
            label = "周"
            kind = .weekend
        case .statutoryHoliday:
            label = "假"
            kind = .statutoryHoliday
        case .leaveRequired:
            label = "休"
            kind = .leaveRequired
        case .adjustmentWorkday:
            label = "班"
            kind = .adjustmentWorkday
        }

        return VacationSegment(date: status.date, kind: kind, label: label)
    }

    private func note(
        continuousRestDays: Int,
        leaveDaysRequired: Int,
        holidayCount: Int
    ) -> String {
        if holidayCount > 1 || continuousRestDays >= 12 {
            return "适合返乡或长线旅行"
        }

        if continuousRestDays >= 10 {
            return "适合安排一段中长线出行"
        }

        if leaveDaysRequired <= 3 {
            return "适合短途出行或错峰休整"
        }

        return "适合提前规划年假使用"
    }

    private func stableUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var unique: [String] = []

        for value in values where !seen.contains(value) {
            seen.insert(value)
            unique.append(value)
        }

        return unique
    }

    private func startOfYear(for year: Int) -> Date {
        DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: 1,
            day: 1
        ).date ?? Date()
    }

    private func endOfYear(for year: Int) -> Date {
        DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: 12,
            day: 31
        ).date ?? Date()
    }

    private func dates(from startDate: Date, through endDate: Date) -> [Date] {
        var dates: [Date] = []
        var current = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)

        while current <= end {
            dates.append(current)
            current = addingDays(1, to: current)
        }

        return dates
    }

    private func addingDays(_ value: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: value, to: date) ?? date
    }
}
