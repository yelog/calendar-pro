import Foundation

enum BadgeKind: String, Equatable {
    case festival
    case publicHoliday
    case statutoryHoliday
    case workingAdjustmentDay
}

struct DayBadge: Equatable, Identifiable {
    let kind: BadgeKind
    let text: String
    let priority: Int

    var id: String {
        "\(kind.rawValue)-\(text)-\(priority)"
    }
}

struct CalendarDay: Equatable, Identifiable {
    let date: Date
    let isInDisplayedMonth: Bool
    let isToday: Bool
    let isSelected: Bool
    let solarText: String
    let lunarText: String?
    let lunarTextSemantic: LunarTextSemantic
    let badges: [DayBadge]

    var id: Date { date }
}
