import Foundation

enum DisplayTokenKind: String, Codable, CaseIterable, Identifiable {
    case date
    case time
    case weekday
    case lunar
    case holiday
    case weather

    var id: String { rawValue }
}

enum DisplayTokenStyle: String, Codable, CaseIterable {
    case numeric
    case numericUnpadded = "numericUnpaddedDay"
    case short
    case shortUnpadded = "shortUnpaddedDay"
    case full
    case chineseMonthDay
    case chineseMonthDayUnpadded = "chineseMonthDayUnpaddedDay"
    case chineseFull
    case chineseFullUnpadded = "chineseFullUnpaddedDay"
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

struct MenuBarTextStyle: Codable, Equatable {
    var isBold: Bool
    var foregroundColorHex: String?
    var usesFilledBackground: Bool
    var backgroundColorHex: String

    static let defaultCustomForegroundColorHex = "#4B5563"
    static let defaultBackgroundColorHex = "#F2F4F7"

    static let `default` = MenuBarTextStyle(
        isBold: true,
        foregroundColorHex: nil,
        usesFilledBackground: false,
        backgroundColorHex: defaultBackgroundColorHex
    )

    static func automaticForegroundColorHex(for backgroundColorHex: String) -> String {
        guard let components = rgbComponents(from: backgroundColorHex) else {
            return defaultCustomForegroundColorHex
        }

        let luminance = 0.2126 * linearized(components.red)
            + 0.7152 * linearized(components.green)
            + 0.0722 * linearized(components.blue)

        return luminance > 0.55 ? defaultCustomForegroundColorHex : "#FFFFFF"
    }

    private static func rgbComponents(from hex: String) -> (red: Double, green: Double, blue: Double)? {
        let value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard value.count == 6, let integer = UInt64(value, radix: 16) else { return nil }

        return (
            red: Double((integer >> 16) & 0xFF) / 255,
            green: Double((integer >> 8) & 0xFF) / 255,
            blue: Double(integer & 0xFF) / 255
        )
    }

    private static func linearized(_ component: Double) -> Double {
        component <= 0.03928
            ? component / 12.92
            : pow((component + 0.055) / 1.055, 2.4)
    }
}

struct MenuBarPreferences: Codable, Equatable {
    var tokens: [DisplayTokenPreference]
    var separator: String
    var textStyle: MenuBarTextStyle = .default
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
    var showWeather: Bool

    var requiresSecondRefresh: Bool {
        tokens.contains { $0.token == .time && $0.isEnabled && $0.style == .full }
    }

    var hasEnabledEventSources: Bool {
        showCalendarEvents || showReminders
    }

    var eventsSummaryText: String {
        if !showEvents {
            return L("Events off")
        }

        if !hasEnabledEventSources {
            return L("No event sources enabled")
        }

        let calendarText = showCalendarEvents ? L("Cal on") : L("Cal off")
        let reminderText = showReminders ? L("Rem on") : L("Rem off")
        return "\(calendarText) / \(reminderText)"
    }

    var eventListEmptyStateText: String {
        hasEnabledEventSources ? L("No events today") : L("No event sources enabled")
    }

    static let `default` = defaultsForCurrentLocale()

    static func defaultsForCurrentLocale(
        locale: Locale = AppLocalization.locale
    ) -> MenuBarPreferences {
        let languageCode = locale.language.languageCode?.identifier ?? "en"
        let regionID = locale.region?.identifier ?? ""

        let (defaultRegions, defaultWeekStart): ([String], WeekStart)
        switch (languageCode, regionID) {
        case ("zh", _):
            defaultRegions = ["mainland-cn"]
            defaultWeekStart = .monday
        case ("en", "US"), ("en", "PR"), ("en", "UM"):
            defaultRegions = ["us"]
            defaultWeekStart = .sunday
        case ("en", "GB"), ("en", "UK"):
            defaultRegions = ["uk"]
            defaultWeekStart = .monday
        default:
            defaultRegions = []
            defaultWeekStart = .monday
        }

        let showLunar = languageCode == "zh"

        return MenuBarPreferences(
            tokens: [
                DisplayTokenPreference(token: .date, isEnabled: true, order: 0, style: .short),
                DisplayTokenPreference(token: .time, isEnabled: true, order: 1, style: .short),
                DisplayTokenPreference(token: .weekday, isEnabled: true, order: 2, style: .short),
                DisplayTokenPreference(token: .lunar, isEnabled: false, order: 3, style: .short),
                DisplayTokenPreference(token: .holiday, isEnabled: false, order: 4, style: .short),
                DisplayTokenPreference(token: .weather, isEnabled: false, order: 5, style: .short)
            ],
            separator: " ",
            textStyle: .default,
            showLunarInMenuBar: showLunar,
            activeRegionIDs: defaultRegions,
            enabledHolidayIDs: [],
            weekStart: defaultWeekStart,
            highlightWeekends: true,
            showEvents: true,
            showCalendarEvents: true,
            enabledCalendarIDs: [],
            showReminders: true,
            enabledReminderCalendarIDs: [],
            showAlmanac: false,
            showWeather: false
        )
    }

    static let previewShort = MenuBarPreferences(
        tokens: [
            DisplayTokenPreference(token: .time, isEnabled: true, order: 0, style: .short),
            DisplayTokenPreference(token: .weekday, isEnabled: true, order: 1, style: .short),
            DisplayTokenPreference(token: .date, isEnabled: true, order: 2, style: .numeric)
        ],
        separator: " ",
        textStyle: .default,
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
        showAlmanac: false,
        showWeather: false
    )
}

extension MenuBarPreferences {
    private enum CodingKeys: String, CodingKey {
        case tokens
        case separator
        case textStyle
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
        case showWeather
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let showEvents = try container.decode(Bool.self, forKey: .showEvents)

        self.init(
            tokens: try container.decode([DisplayTokenPreference].self, forKey: .tokens),
            separator: try container.decode(String.self, forKey: .separator),
            textStyle: try container.decodeIfPresent(MenuBarTextStyle.self, forKey: .textStyle) ?? .default,
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
            showAlmanac: try container.decodeIfPresent(Bool.self, forKey: .showAlmanac) ?? false,
            showWeather: try container.decodeIfPresent(Bool.self, forKey: .showWeather) ?? false
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(tokens, forKey: .tokens)
        try container.encode(separator, forKey: .separator)
        try container.encode(textStyle, forKey: .textStyle)
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
        try container.encode(showWeather, forKey: .showWeather)
    }
}
