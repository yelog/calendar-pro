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
    var activeRegionIDs: [String]
    var enabledHolidayIDs: [String]
    var weekStart: WeekStart
    var highlightWeekends: Bool
    var showEvents: Bool
    var showCalendarEvents: Bool
    var enabledCalendarIDs: [String]
    var showReminders: Bool
    var enabledReminderCalendarIDs: [String]
    var showAlmanac: Bool

    var requiresSecondRefresh: Bool {
        tokens.contains { $0.token == .time && $0.isEnabled && $0.style == .full }
    }

    var hasEnabledEventSources: Bool {
        showCalendarEvents || showReminders
    }

    var eventsSummaryText: String {
        if !showEvents {
            return "日程已关闭"
        }

        if !hasEnabledEventSources {
            return "未启用任何日程来源"
        }

        let calendarText = showCalendarEvents ? "日历开" : "日历关"
        let reminderText = showReminders ? "提醒开" : "提醒关"
        return "\(calendarText) / \(reminderText)"
    }

    var eventListEmptyStateText: String {
        hasEnabledEventSources ? "当天无日程" : "未启用任何日程来源"
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
        activeRegionIDs: ["mainland-cn"],
        enabledHolidayIDs: [],
        weekStart: .monday,
        highlightWeekends: true,
        showEvents: true,
        showCalendarEvents: true,
        enabledCalendarIDs: [],
        showReminders: true,
        enabledReminderCalendarIDs: [],
        showAlmanac: false
    )

    static let previewShort = MenuBarPreferences(
        tokens: [
            DisplayTokenPreference(token: .time, isEnabled: true, order: 0, style: .short),
            DisplayTokenPreference(token: .weekday, isEnabled: true, order: 1, style: .short),
            DisplayTokenPreference(token: .date, isEnabled: true, order: 2, style: .numeric)
        ],
        separator: " ",
        showLunarInMenuBar: false,
        activeRegionIDs: ["mainland-cn"],
        enabledHolidayIDs: [],
        weekStart: .monday,
        highlightWeekends: true,
        showEvents: true,
        showCalendarEvents: true,
        enabledCalendarIDs: [],
        showReminders: true,
        enabledReminderCalendarIDs: [],
        showAlmanac: false
    )
}

extension MenuBarPreferences {
    private enum CodingKeys: String, CodingKey {
        case tokens
        case separator
        case showLunarInMenuBar
        case activeRegionIDs
        case enabledHolidayIDs
        case weekStart
        case highlightWeekends
        case showEvents
        case showCalendarEvents
        case enabledCalendarIDs
        case showReminders
        case enabledReminderCalendarIDs
        case showAlmanac
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let showEvents = try container.decode(Bool.self, forKey: .showEvents)

        self.init(
            tokens: try container.decode([DisplayTokenPreference].self, forKey: .tokens),
            separator: try container.decode(String.self, forKey: .separator),
            showLunarInMenuBar: try container.decode(Bool.self, forKey: .showLunarInMenuBar),
            activeRegionIDs: try container.decode([String].self, forKey: .activeRegionIDs),
            enabledHolidayIDs: try container.decode([String].self, forKey: .enabledHolidayIDs),
            weekStart: try container.decode(WeekStart.self, forKey: .weekStart),
            highlightWeekends: try container.decodeIfPresent(Bool.self, forKey: .highlightWeekends) ?? true,
            showEvents: showEvents,
            showCalendarEvents: try container.decodeIfPresent(Bool.self, forKey: .showCalendarEvents) ?? showEvents,
            enabledCalendarIDs: try container.decode([String].self, forKey: .enabledCalendarIDs),
            showReminders: try container.decode(Bool.self, forKey: .showReminders),
            enabledReminderCalendarIDs: try container.decode([String].self, forKey: .enabledReminderCalendarIDs),
            showAlmanac: try container.decodeIfPresent(Bool.self, forKey: .showAlmanac) ?? false
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(tokens, forKey: .tokens)
        try container.encode(separator, forKey: .separator)
        try container.encode(showLunarInMenuBar, forKey: .showLunarInMenuBar)
        try container.encode(activeRegionIDs, forKey: .activeRegionIDs)
        try container.encode(enabledHolidayIDs, forKey: .enabledHolidayIDs)
        try container.encode(weekStart, forKey: .weekStart)
        try container.encode(highlightWeekends, forKey: .highlightWeekends)
        try container.encode(showEvents, forKey: .showEvents)
        try container.encode(showCalendarEvents, forKey: .showCalendarEvents)
        try container.encode(enabledCalendarIDs, forKey: .enabledCalendarIDs)
        try container.encode(showReminders, forKey: .showReminders)
        try container.encode(enabledReminderCalendarIDs, forKey: .enabledReminderCalendarIDs)
        try container.encode(showAlmanac, forKey: .showAlmanac)
    }
}
