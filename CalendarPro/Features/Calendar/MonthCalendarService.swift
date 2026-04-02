import Foundation

struct MonthCalendarService {
    let calendar: Calendar
    let now: () -> Date

    init(calendar: Calendar = .autoupdatingCurrent, now: @escaping () -> Date = Date.init) {
        self.calendar = calendar
        self.now = now
    }

    func makeMonthGrid(for month: Date) -> [CalendarDay] {
        let monthStart = startOfMonth(for: month)
        let leadingDays = leadingDayCount(for: monthStart)
        let gridStart = calendar.date(byAdding: .day, value: -leadingDays, to: monthStart) ?? monthStart

        return (0..<42).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: gridStart) else {
                return nil
            }

            return CalendarDay(
                date: date,
                isInDisplayedMonth: calendar.isDate(date, equalTo: monthStart, toGranularity: .month),
                isToday: calendar.isDate(date, inSameDayAs: now()),
                isSelected: false,
                isWeekend: calendar.isDateInWeekend(date),
                solarText: String(calendar.component(.day, from: date)),
                lunarText: nil,
                lunarTextSemantic: .regular,
                badges: []
            )
        }
    }

    private func startOfMonth(for date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    private func leadingDayCount(for monthStart: Date) -> Int {
        let weekday = calendar.component(.weekday, from: monthStart)
        return (weekday - calendar.firstWeekday + 7) % 7
    }
}

extension Calendar {
    static var gregorianMondayFirst: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        calendar.firstWeekday = 2
        return calendar
    }
}
