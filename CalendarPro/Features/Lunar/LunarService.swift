import Foundation

struct LunarService {
    private var chineseCalendar: Calendar
    private let festivalResolver: TraditionalFestivalResolver

    init(
        calendar: Calendar = Calendar(identifier: .chinese),
        festivalResolver: TraditionalFestivalResolver = TraditionalFestivalResolver()
    ) {
        var calendar = calendar
        calendar.locale = Locale(identifier: "zh_Hans_CN")
        chineseCalendar = calendar
        self.festivalResolver = festivalResolver
    }

    func describe(date: Date, timeZone: TimeZone = .autoupdatingCurrent) -> LunarDateDescriptor {
        let components = chineseCalendar.dateComponents(in: timeZone, from: date)
        let month = components.month ?? 1
        let day = components.day ?? 1
        let isLeapMonth = components.isLeapMonth ?? false

        let monthText = Self.monthText(for: month, isLeapMonth: isLeapMonth)
        let dayText = Self.dayText(for: day)

        return LunarDateDescriptor(
            month: month,
            day: day,
            isLeapMonth: isLeapMonth,
            monthText: monthText,
            dayText: dayText,
            festivalName: festivalResolver.festivalName(month: month, day: day, isLeapMonth: isLeapMonth)
        )
    }

    private static func monthText(for month: Int, isLeapMonth: Bool) -> String {
        let monthNames = [
            "正月", "二月", "三月", "四月", "五月", "六月",
            "七月", "八月", "九月", "十月", "冬月", "腊月"
        ]

        let resolvedMonth = monthNames[max(0, min(monthNames.count - 1, month - 1))]
        return isLeapMonth ? "闰\(resolvedMonth)" : resolvedMonth
    }

    private static func dayText(for day: Int) -> String {
        let dayNames = [
            "初一", "初二", "初三", "初四", "初五",
            "初六", "初七", "初八", "初九", "初十",
            "十一", "十二", "十三", "十四", "十五",
            "十六", "十七", "十八", "十九", "二十",
            "廿一", "廿二", "廿三", "廿四", "廿五",
            "廿六", "廿七", "廿八", "廿九", "三十"
        ]

        return dayNames[max(0, min(dayNames.count - 1, day - 1))]
    }
}
