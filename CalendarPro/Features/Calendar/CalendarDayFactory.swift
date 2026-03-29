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

        return CalendarDay(
            date: date,
            isInDisplayedMonth: calendar.isDate(date, equalTo: displayedMonth ?? date, toGranularity: .month),
            isToday: calendar.isDate(date, inSameDayAs: monthService.now()),
            isSelected: selectedDate != nil && calendar.isDate(date, inSameDayAs: selectedDate!),
            solarText: String(calendar.component(.day, from: date)),
            lunarText: lunarDescriptor.displayText,
            badges: holidays.map(\.dayBadge)
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

            return CalendarDay(
                date: day.date,
                isInDisplayedMonth: day.isInDisplayedMonth,
                isToday: day.isToday,
                isSelected: selectedDate != nil && calendar.isDate(day.date, inSameDayAs: selectedDate!),
                solarText: day.solarText,
                lunarText: lunarDescriptor.displayText,
                badges: resolvedBadges
            )
        }
    }

    static func makePreview() -> CalendarDayFactory {
        CalendarDayFactory(calendar: .gregorianMondayFirst, registry: .default)
    }
}
