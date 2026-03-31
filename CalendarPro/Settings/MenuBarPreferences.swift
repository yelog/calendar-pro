import Foundation

enum DisplayTokenKind: String, Codable, CaseIterable, Identifiable {
    case date
    case time
    case weekday
    case lunar
    case holiday

    var id: String { rawValue }
}

enum DisplayTokenStyle: String, Codable, CaseIterable {
    case numeric
    case short
    case full
    case chineseMonthDay
    case chineseWeekday
}

enum WeekStart: String, Codable, CaseIterable {
    case sunday
    case monday
}

struct DisplayTokenPreference: Codable, Equatable, Identifiable {
    var token: DisplayTokenKind
    var isEnabled: Bool
    var order: Int
    var style: DisplayTokenStyle

    var id: DisplayTokenKind { token }
}

struct MenuBarPreferences: Codable, Equatable {
    var tokens: [DisplayTokenPreference]
    var separator: String
    var showLunarInMenuBar: Bool
    var lunarDisplayStyle: LunarDisplayStyle
    var activeRegionIDs: [String]
    var enabledHolidayIDs: [String]
    var weekStart: WeekStart
    var showEvents: Bool
    var enabledCalendarIDs: [String]
    var showReminders: Bool
    var enabledReminderCalendarIDs: [String]

    var requiresSecondRefresh: Bool {
        tokens.contains { $0.token == .time && $0.isEnabled && $0.style == .full }
    }

    static let `default` = MenuBarPreferences(
        tokens: [
            DisplayTokenPreference(token: .date, isEnabled: true, order: 0, style: .short),
            DisplayTokenPreference(token: .time, isEnabled: true, order: 1, style: .short),
            DisplayTokenPreference(token: .weekday, isEnabled: true, order: 2, style: .short),
            DisplayTokenPreference(token: .lunar, isEnabled: false, order: 3, style: .short),
            DisplayTokenPreference(token: .holiday, isEnabled: false, order: 4, style: .short)
        ],
        separator: " ",
        showLunarInMenuBar: false,
        lunarDisplayStyle: .day,
        activeRegionIDs: ["mainland-cn"],
        enabledHolidayIDs: [],
        weekStart: .monday,
        showEvents: true,
        enabledCalendarIDs: [],
        showReminders: true,
        enabledReminderCalendarIDs: []
    )

    static let previewShort = MenuBarPreferences(
        tokens: [
            DisplayTokenPreference(token: .time, isEnabled: true, order: 0, style: .short),
            DisplayTokenPreference(token: .weekday, isEnabled: true, order: 1, style: .short),
            DisplayTokenPreference(token: .date, isEnabled: true, order: 2, style: .numeric)
        ],
        separator: " ",
        showLunarInMenuBar: false,
        lunarDisplayStyle: .day,
        activeRegionIDs: ["mainland-cn"],
        enabledHolidayIDs: [],
        weekStart: .monday,
        showEvents: true,
        enabledCalendarIDs: [],
        showReminders: true,
        enabledReminderCalendarIDs: []
    )
}
