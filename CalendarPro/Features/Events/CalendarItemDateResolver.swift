import EventKit
import Foundation

/// Interprets EventKit's wall-clock values without changing the process time zone.
enum CalendarItemDateResolver {
    static func snapshot(_ calendar: Calendar) -> Calendar {
        var snapshot = calendar
        snapshot.timeZone = TimeZone(identifier: calendar.timeZone.identifier)
            ?? TimeZone(secondsFromGMT: calendar.timeZone.secondsFromGMT())!
        return snapshot
    }

    static var systemCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    static func reminderDate(from components: DateComponents, calendar: Calendar) -> Date? {
        let includesTime = components.hour != nil || components.minute != nil || components.second != nil
        var resolved = components

        if includesTime, let timeZone = components.timeZone {
            var sourceCalendar = components.calendar ?? calendar
            sourceCalendar.timeZone = timeZone
            resolved.calendar = sourceCalendar
            resolved.timeZone = timeZone
            return sourceCalendar.date(from: resolved)
        }

        // A date-only due date is a civil date even when EventKit attaches a
        // source time zone. Floating times likewise belong to the app calendar.
        resolved.calendar = calendar
        resolved.timeZone = calendar.timeZone
        return calendar.date(from: resolved)
    }

    static func eventDate(_ date: Date, event: EKEvent, calendar: Calendar) -> Date {
        guard event.isAllDay || event.timeZone == nil else { return date }
        return rebase(date, from: systemCalendar, to: calendar)
    }

    static func rebase(_ date: Date, from source: Calendar, to target: Calendar) -> Date {
        guard source.identifier != target.identifier || source.timeZone != target.timeZone else { return date }
        let components = source.dateComponents(
            [.era, .year, .month, .day, .hour, .minute, .second, .nanosecond],
            from: date
        )
        return target.date(from: components) ?? date
    }

    /// EventKit searches absolute dates, including its system-zone rendering of
    /// floating/all-day values. Cover both representations before local filtering.
    static func queryWindow(
        from start: Date,
        through end: Date,
        calendar: Calendar,
        systemCalendar: Calendar = CalendarItemDateResolver.systemCalendar
    ) -> DateInterval {
        let systemStart = rebase(start, from: calendar, to: systemCalendar)
        let systemEnd = rebase(end, from: calendar, to: systemCalendar)
        return DateInterval(start: min(start, systemStart), end: max(end, systemEnd))
    }

    /// A predicate uses EventKit's date representation before app civil-date
    /// resolution. Two UTC days cover even UTC+14 versus UTC-12 sources, while
    /// leaving distant-future reminders out of these frequent queries.
    static func reminderQueryEnd(after end: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar.date(byAdding: .day, value: 2, to: end) ?? .distantFuture
    }
}
