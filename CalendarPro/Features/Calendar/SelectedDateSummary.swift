import Foundation

struct SelectedDateSummary: Equatable {
    let date: Date
    let solarDateText: String
    let weekdayText: String
    let fullSolarDateText: String
    let lunarDateText: String?
    let chips: [CalendarDayDisplayMetadata.Chip]
}

struct SelectedDateSummaryFactory {
    let calendar: Calendar
    let registry: HolidayProviderRegistry

    init(
        calendar: Calendar = .autoupdatingCurrent,
        registry: HolidayProviderRegistry = .default
    ) {
        self.calendar = calendar
        self.registry = registry
    }

    func make(
        selectedDate: Date?,
        currentDate: Date,
        displayedMonth: Date,
        preferences: MenuBarPreferences,
        locale: Locale,
        showsLunarDate: Bool,
        offText: String,
        workText: String,
        visibleDays: [CalendarDay] = []
    ) -> SelectedDateSummary {
        let date = selectedDate ?? currentDate
        let solarCalendar = Self.gregorianCalendar(from: calendar, locale: locale)
        let includesYear = !solarCalendar.isDate(date, equalTo: displayedMonth, toGranularity: .year)
        let solarDateText = Self.formattedDate(
            date,
            template: includesYear ? "yMMMd" : "MMMd",
            calendar: solarCalendar,
            locale: locale
        )
        let weekdayText = Self.formattedDate(date, template: "EEE", calendar: solarCalendar, locale: locale)
        let fullSolarDateText = Self.formattedDate(
            date,
            template: "yMMMMdEEEE",
            calendar: solarCalendar,
            locale: locale
        )

        let lunarDateText = showsLunarDate
            ? LunarService().describe(date: date, timeZone: calendar.timeZone).fullDateText
            : nil

        let day = visibleDays.first { calendar.isDate($0.date, inSameDayAs: date) }
            ?? (try? CalendarDayFactory(
                calendar: calendar,
                registry: registry,
                now: { currentDate }
            ).makeDay(
                for: date,
                displayedMonth: displayedMonth,
                preferences: preferences,
                selectedDate: date
            ))
        let chips = day.map {
            CalendarDayDisplayMetadata.selectedDayMetadataChips(
                for: $0,
                offText: offText,
                workText: workText
            )
        } ?? []

        return SelectedDateSummary(
            date: date,
            solarDateText: solarDateText,
            weekdayText: weekdayText,
            fullSolarDateText: fullSolarDateText,
            lunarDateText: lunarDateText,
            chips: chips
        )
    }

    private static func formattedDate(
        _ date: Date,
        template: String,
        calendar: Calendar,
        locale: Locale
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }

    private static func gregorianCalendar(from calendar: Calendar, locale: Locale) -> Calendar {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.locale = locale
        gregorian.timeZone = calendar.timeZone
        gregorian.firstWeekday = calendar.firstWeekday
        return gregorian
    }
}
