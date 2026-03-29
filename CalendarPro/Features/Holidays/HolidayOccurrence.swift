import Foundation

enum HolidayKind: String, Codable, CaseIterable {
    case festival
    case publicHoliday
    case statutoryHoliday
    case workingAdjustmentDay

    var priority: Int {
        switch self {
        case .statutoryHoliday:
            3
        case .publicHoliday:
            2
        case .festival:
            1
        case .workingAdjustmentDay:
            0
        }
    }

    var badgeKind: BadgeKind {
        switch self {
        case .festival:
            .festival
        case .publicHoliday:
            .publicHoliday
        case .statutoryHoliday:
            .statutoryHoliday
        case .workingAdjustmentDay:
            .workingAdjustmentDay
        }
    }
}

enum HolidaySource: String, Codable {
    case bundledJSON
    case remoteFeed
    case calculatedLunar
}

struct HolidayOccurrence: Equatable, Identifiable {
    let id: String
    let regionID: String
    let date: Date
    let name: String
    let kind: HolidayKind
    let holidaySetID: String
    let isObserved: Bool
    let isAdjustmentWorkday: Bool
    let source: HolidaySource

    var dayBadge: DayBadge {
        DayBadge(kind: kind.badgeKind, text: name, priority: kind.priority)
    }
}
