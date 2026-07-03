import Foundation

struct CalendarDayFactory {
    let monthService: MonthCalendarService
    let lunarService: LunarService
    let holidayResolver: HolidayResolver
    let calendar: Calendar

    init(
        calendar: Calendar = .autoupdatingCurrent,
        registry: HolidayProviderRegistry = .default,
        now: @escaping () -> Date = Date.init
    ) {
        self.calendar = calendar
        monthService = MonthCalendarService(calendar: calendar, now: now)
        lunarService = LunarService()
        holidayResolver = HolidayResolver(registry: registry, calendar: calendar)
    }

    func makeDay(
        for date: Date,
        displayedMonth: Date? = nil,
        preferences: MenuBarPreferences = .default,
        selectedDate: Date? = nil
    ) throws -> CalendarDay {
        let lunarDescriptor = lunarService.describe(date: date, timeZone: calendar.timeZone)
        let holidays = try holidayResolver.holidays(
            on: date,
            activeRegionIDs: preferences.activeRegionIDs,
            enabledHolidaySetIDs: preferences.enabledHolidayIDs
        )
        let badges = holidays.map(\.dayBadge)
        let lunarText = lunarDescriptor.displayText(style: lunarDisplayStyle(from: preferences))
        let subtitle = subtitleText(for: date, lunarText: lunarText, badges: badges)

        return CalendarDay(
            date: date,
            isInDisplayedMonth: calendar.isDate(date, equalTo: displayedMonth ?? date, toGranularity: .month),
            isToday: calendar.isDate(date, inSameDayAs: monthService.now()),
            isSelected: selectedDate != nil && calendar.isDate(date, inSameDayAs: selectedDate!),
            isWeekend: calendar.isDateInWeekend(date),
            solarText: String(calendar.component(.day, from: date)),
            lunarText: lunarText,
            lunarTextSemantic: lunarDescriptor.displaySemantic,
            subtitleText: subtitle,
            supplementalBadges: supplementalBadges(primarySubtitleText: subtitle, badges: badges),
            badges: badges
        )
    }

    func makeMonthGrid(
        for month: Date,
        preferences: MenuBarPreferences = .default,
        selectedDate: Date? = nil
    ) throws -> [CalendarDay] {
        let baseDays = monthService.makeMonthGrid(for: month)
        let holidayMap = try holidayResolver.holidaysByDay(
            for: baseDays.map(\.date),
            activeRegionIDs: preferences.activeRegionIDs,
            enabledHolidaySetIDs: preferences.enabledHolidayIDs
        )

        return baseDays.map { day in
            let lunarDescriptor = lunarService.describe(date: day.date, timeZone: calendar.timeZone)
            let resolvedBadges = holidayMap[calendar.startOfDay(for: day.date)]?.map(\.dayBadge) ?? []
            let lunarText = lunarDescriptor.displayText(style: lunarDisplayStyle(from: preferences))
            let subtitle = subtitleText(for: day.date, lunarText: lunarText, badges: resolvedBadges)

            return CalendarDay(
                date: day.date,
                isInDisplayedMonth: day.isInDisplayedMonth,
                isToday: day.isToday,
                isSelected: selectedDate != nil && calendar.isDate(day.date, inSameDayAs: selectedDate!),
                isWeekend: calendar.isDateInWeekend(day.date),
                solarText: day.solarText,
                lunarText: lunarText,
                lunarTextSemantic: lunarDescriptor.displaySemantic,
                subtitleText: subtitle,
                supplementalBadges: supplementalBadges(primarySubtitleText: subtitle, badges: resolvedBadges),
                badges: resolvedBadges
            )
        }
    }

    private func subtitleText(for date: Date, lunarText: String?, badges: [DayBadge]) -> String? {
        guard let badge = badges.first else {
            return lunarText
        }

        switch badge.kind {
        case .festival, .publicHoliday:
            return badge.text
        case .workingAdjustmentDay:
            return lunarText
        case .statutoryHoliday:
            return shouldShowStatutoryHolidayName(badge.text, on: date, lunarText: lunarText)
                ? badge.text
                : lunarText ?? badge.text
        }
    }

    private func supplementalBadges(primarySubtitleText: String?, badges: [DayBadge]) -> [DayBadge] {
        badges.filter { badge in
            guard badge.kind == .festival else { return false }
            return badge.text != primarySubtitleText
        }
    }

    private func shouldShowStatutoryHolidayName(_ holidayName: String, on date: Date, lunarText: String?) -> Bool {
        if let lunarText, holidayName == lunarText || holidayName == "\(lunarText)节" {
            return true
        }

        let components = calendar.dateComponents([.month, .day], from: date)
        guard let month = components.month, let day = components.day else {
            return false
        }

        switch holidayName {
        case "元旦":
            return month == 1 && day == 1
        case "劳动节":
            return month == 5 && day == 1
        case "国庆节":
            return month == 10 && day == 1
        default:
            return false
        }
    }

    private func lunarDisplayStyle(from preferences: MenuBarPreferences) -> LunarDisplayStyle {
        let lunarTokenStyle = preferences.tokens.first(where: { $0.token == .lunar })?.style ?? .short
        switch lunarTokenStyle {
        case .short:
            return .day
        case .chineseMonthDay:
            return .monthDay
        case .full:
            return .yearMonthDay
        default:
            return .day
        }
    }

    static func makePreview() -> CalendarDayFactory {
        CalendarDayFactory(calendar: .gregorianMondayFirst, registry: .default)
    }
}
