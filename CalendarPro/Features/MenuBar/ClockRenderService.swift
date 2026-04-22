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

    func renderPreview(
        token: DisplayTokenKind,
        style: DisplayTokenStyle,
        now: Date = Date(),
        locale: Locale = .autoupdatingCurrent,
        calendar: Calendar = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent,
        supplementalText: MenuBarSupplementalText = .empty
    ) -> String {
        let preference = DisplayTokenPreference(token: token, isEnabled: true, order: 0, style: style)
        return renderToken(preference, now: now, locale: locale, calendar: calendar, timeZone: timeZone, supplementalText: supplementalText) ?? ""
    }

    func renderToken(
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
            return renderTime(now: now, showSeconds: tokenPreference.style == .full, locale: locale, timeZone: timeZone)
        case .weekday:
            return renderWeekday(now: now, style: tokenPreference.style, locale: locale, calendar: calendar, timeZone: timeZone)
        case .lunar:
            guard LocaleFeatureAvailability.showLunarFeatures else { return nil }
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
            formatter.dateFormat = "dd/MM"
        case .numericUnpadded:
            formatter.dateFormat = "d/M"
        case .short:
            formatter.setLocalizedDateFormatFromTemplate("yMMdd")
        case .shortUnpadded:
            formatter.setLocalizedDateFormatFromTemplate("yMd")
        case .full:
            formatter.dateStyle = .long
            formatter.timeStyle = .none
        case .chineseMonthDay:
            guard LocaleFeatureAvailability.showChineseDateStyles else {
                formatter.setLocalizedDateFormatFromTemplate("MMMMdd")
                return formatter.string(from: now)
            }
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "MM月dd日"
        case .chineseMonthDayUnpadded:
            guard LocaleFeatureAvailability.showChineseDateStyles else {
                formatter.setLocalizedDateFormatFromTemplate("MMMd")
                return formatter.string(from: now)
            }
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "M月d日"
        case .chineseFull:
            guard LocaleFeatureAvailability.showChineseDateStyles else {
                formatter.dateStyle = .long
                formatter.timeStyle = .none
                return formatter.string(from: now)
            }
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "yyyy年MM月dd日"
        case .chineseFullUnpadded:
            guard LocaleFeatureAvailability.showChineseDateStyles else {
                formatter.setLocalizedDateFormatFromTemplate("yMMMd")
                return formatter.string(from: now)
            }
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "yyyy年M月d日"
        case .chineseWeekday:
            formatter.setLocalizedDateFormatFromTemplate("yMMdd")
        }

        return formatter.string(from: now)
    }

    private func renderTime(now: Date, showSeconds: Bool, locale: Locale, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateStyle = .none
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
        if style == .chineseWeekday && LocaleFeatureAvailability.showChineseDateStyles {
            var localizedCalendar = calendar
            localizedCalendar.timeZone = timeZone
            let weekday = localizedCalendar.component(.weekday, from: now)
            let chineseWeekdays = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
            return chineseWeekdays[weekday - 1]
        }

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.calendar = calendar
        formatter.dateFormat = style == .full ? "EEEE" : "EEE"
        return formatter.string(from: now)
    }
}
