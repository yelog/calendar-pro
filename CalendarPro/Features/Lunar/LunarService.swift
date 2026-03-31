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
        let year = components.year ?? 1
        let month = components.month ?? 1
        let day = components.day ?? 1
        let isLeapMonth = components.isLeapMonth ?? false

        let yearText = Self.yearText(for: year)
        let monthText = Self.monthText(for: month, isLeapMonth: isLeapMonth)
        let dayText = Self.dayText(for: day)

        return LunarDateDescriptor(
            year: year,
            month: month,
            day: day,
            isLeapMonth: isLeapMonth,
            yearText: yearText,
            monthText: monthText,
            dayText: dayText,
            festivalName: festivalResolver.festivalName(month: month, day: day, isLeapMonth: isLeapMonth)
        )
    }

    private static func yearText(for year: Int) -> String {
        let gan = ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"]
        let zhi = ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"]
        
        let ganIndex = (year - 4) % 10
        let zhiIndex = (year - 4) % 12
        
        return gan[max(0, min(9, ganIndex))] + zhi[max(0, min(11, zhiIndex))] + "年"
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