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
    let isWeekend: Bool
    let solarText: String
    let lunarText: String?
    let lunarTextSemantic: LunarTextSemantic
    let subtitleText: String?
    let supplementalBadges: [DayBadge]
    let badges: [DayBadge]

    var id: Date { date }
}

enum CalendarDayDisplayMetadata {
    struct Chip: Equatable, Identifiable {
        enum Style: String, Equatable {
            case primary
            case supplemental
            case status
        }

        let text: String
        let style: Style

        var id: String {
            "\(style.rawValue)-\(text)"
        }
    }

    static func supplementalIndicatorText(for day: CalendarDay) -> String? {
        guard !day.supplementalBadges.isEmpty else { return nil }
        return "+\(day.supplementalBadges.count)"
    }

    static func selectedDaySummaryTitle(
        for date: Date,
        calendar: Calendar = .autoupdatingCurrent,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = calendar
        dateFormatter.locale = locale
        dateFormatter.setLocalizedDateFormatFromTemplate("MMMd")

        let weekdayFormatter = DateFormatter()
        weekdayFormatter.calendar = calendar
        weekdayFormatter.locale = locale
        weekdayFormatter.setLocalizedDateFormatFromTemplate("EEE")

        return "\(dateFormatter.string(from: date)) \(weekdayFormatter.string(from: date))"
    }

    static func selectedDayMetadataTexts(
        for day: CalendarDay,
        offText: String,
        workText: String
    ) -> [String] {
        selectedDayMetadataChips(for: day, offText: offText, workText: workText).map(\.text)
    }

    static func selectedDayMetadataChips(
        for day: CalendarDay,
        offText: String,
        workText: String
    ) -> [Chip] {
        var chips: [Chip] = []

        if let subtitleText = day.subtitleText,
           shouldIncludePrimarySubtitle(day, subtitleText: subtitleText) {
            appendUnique(Chip(text: subtitleText, style: .primary), to: &chips)
        }

        for badge in day.supplementalBadges {
            appendUnique(Chip(text: badge.text, style: .supplemental), to: &chips)
        }

        if day.badges.contains(where: { $0.kind == .publicHoliday || $0.kind == .statutoryHoliday }) {
            appendUnique(Chip(text: offText, style: .status), to: &chips)
        }

        if day.badges.contains(where: { $0.kind == .workingAdjustmentDay }) {
            appendUnique(Chip(text: workText, style: .status), to: &chips)
        }

        return chips
    }

    private static func shouldIncludePrimarySubtitle(_ day: CalendarDay, subtitleText: String) -> Bool {
        if day.lunarTextSemantic == .solarTerm, day.lunarText == subtitleText {
            return true
        }

        return day.badges.contains { badge in
            guard badge.text == subtitleText else { return false }
            switch badge.kind {
            case .festival, .publicHoliday, .statutoryHoliday:
                return true
            case .workingAdjustmentDay:
                return false
            }
        }
    }

    private static func appendUnique(_ chip: Chip, to chips: inout [Chip]) {
        guard !chip.text.isEmpty, !chips.contains(where: { $0.text == chip.text }) else { return }
        chips.append(chip)
    }
}
