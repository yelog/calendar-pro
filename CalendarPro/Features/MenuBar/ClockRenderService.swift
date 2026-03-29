import Foundation

struct MenuBarSupplementalText: Equatable {
    var lunarText: String?
    var holidayText: String?

    static let empty = MenuBarSupplementalText()
}

struct ClockRenderService {
    func render(
        now: Date,
        preferences: MenuBarPreferences,
        locale: Locale = .autoupdatingCurrent,
        calendar: Calendar = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent,
        supplementalText: MenuBarSupplementalText = .empty
    ) -> String {
        preferences.tokens
            .filter(\.isEnabled)
            .sorted { $0.order < $1.order }
            .compactMap { tokenPreference in
                renderToken(
                    tokenPreference,
                    now: now,
                    locale: locale,
                    calendar: calendar,
                    timeZone: timeZone,
                    supplementalText: supplementalText
                )
            }
            .filter { !$0.isEmpty }
            .joined(separator: preferences.separator)
    }

    private func renderToken(
        _ tokenPreference: DisplayTokenPreference,
        now: Date,
        locale: Locale,
        calendar: Calendar,
        timeZone: TimeZone,
        supplementalText: MenuBarSupplementalText
    ) -> String? {
        switch tokenPreference.token {
        case .date:
            return renderDate(now: now, style: tokenPreference.style, locale: locale, timeZone: timeZone)
        case .time:
            return renderTime(now: now, showSeconds: tokenPreference.showsSeconds || tokenPreference.style == .full, locale: locale, timeZone: timeZone)
        case .weekday:
            return renderWeekday(now: now, style: tokenPreference.style, locale: locale, calendar: calendar, timeZone: timeZone)
        case .lunar:
            return supplementalText.lunarText
        case .holiday:
            return supplementalText.holidayText
        }
    }

    private func renderDate(now: Date, style: DisplayTokenStyle, locale: Locale, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.calendar = Calendar(identifier: .gregorian)

        switch style {
        case .numeric:
            formatter.dateFormat = "MM/dd"
        case .short:
            formatter.dateFormat = "MM/dd"
        case .full:
            formatter.dateFormat = "yyyy/MM/dd"
        }

        return formatter.string(from: now)
    }

    private func renderTime(now: Date, showSeconds: Bool, locale: Locale, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = showSeconds ? "HH:mm:ss" : "HH:mm"
        return formatter.string(from: now)
    }

    private func renderWeekday(
        now: Date,
        style: DisplayTokenStyle,
        locale: Locale,
        calendar: Calendar,
        timeZone: TimeZone
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.calendar = calendar
        formatter.dateFormat = style == .full ? "EEEE" : "EEE"
        return formatter.string(from: now)
    }
}
