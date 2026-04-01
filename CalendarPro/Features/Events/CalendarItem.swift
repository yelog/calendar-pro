import SwiftUI
import EventKit

enum CalendarItemTimelineStatus: Equatable {
    case past
    case ongoing
    case future
}

enum CalendarItemTimelinePlacement: Equatable {
    case timed(minutes: Int)
    case allDay
    case untimed
}

enum CalendarItem: Identifiable {
    case event(EKEvent)
    case reminder(EKReminder)
    
    var id: String {
        switch self {
        case .event(let event):
            return "event-\(event.eventIdentifier ?? "unknown")"
        case .reminder(let reminder):
            return "reminder-\(reminder.calendarItemIdentifier)"
        }
    }
    
    var title: String {
        switch self {
        case .event(let event):
            return event.title ?? "无标题"
        case .reminder(let reminder):
            return reminder.title ?? "无标题"
        }
    }
    
    var startDate: Date? {
        switch self {
        case .event(let event):
            return event.startDate
        case .reminder(let reminder):
            guard let components = reminder.dueDateComponents else { return nil }
            return Calendar.current.date(from: components)
        }
    }
    
    var isCompleted: Bool {
        switch self {
        case .event:
            return false
        case .reminder(let reminder):
            return reminder.isCompleted
        }
    }
    
    var isReminder: Bool {
        if case .reminder = self { return true }
        return false
    }
    
    var ekReminder: EKReminder? {
        if case .reminder(let reminder) = self { return reminder }
        return nil
    }
    
    var color: NSColor {
        switch self {
        case .event(let event):
            return event.calendar.color
        case .reminder(let reminder):
            return reminder.calendar.color
        }
    }
    
    var location: String? {
        switch self {
        case .event(let event):
            return event.location
        case .reminder:
            return nil
        }
    }
    
    var isAllDay: Bool {
        switch self {
        case .event(let event):
            return event.isAllDay
        case .reminder:
            return false
        }
    }
    
    var endDate: Date? {
        switch self {
        case .event(let event):
            return event.endDate
        case .reminder:
            return nil
        }
    }

    /// Stable identifier used for tracking selection state in the detail panel.
    var selectionIdentifier: String {
        switch self {
        case .event(let event):
            return event.selectionIdentifier
        case .reminder(let reminder):
            return "reminder-\(reminder.calendarItemIdentifier)"
        }
    }

    /// Deep-link URL that opens the reminder in Reminders.app.
    var remindersAppURL: URL? {
        guard case .reminder(let reminder) = self,
              let externalID = reminder.calendarItemExternalIdentifier,
              !externalID.isEmpty else {
            return nil
        }
        return URL(string: "x-apple-reminderkit://REMCDReminder/\(externalID)")
    }

    var hasExplicitTime: Bool {
        switch self {
        case .event(let event):
            return !event.isAllDay
        case .reminder(let reminder):
            guard let components = reminder.dueDateComponents else { return false }
            return components.hour != nil || components.minute != nil || components.second != nil
        }
    }

    var timelineDate: Date? {
        guard hasExplicitTime else { return nil }
        return startDate
    }

    var sourceTitle: String {
        switch self {
        case .event(let event):
            return event.calendar.title
        case .reminder(let reminder):
            return reminder.calendar.title
        }
    }

    func timelinePlacement(using calendar: Calendar = .autoupdatingCurrent) -> CalendarItemTimelinePlacement {
        if isAllDay {
            return .allDay
        }

        guard let date = timelineDate else {
            return .untimed
        }

        let components = calendar.dateComponents([.hour, .minute], from: date)
        let minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        return .timed(minutes: minutes)
    }

    func timelineStatus(at now: Date, calendar: Calendar = .autoupdatingCurrent) -> CalendarItemTimelineStatus? {
        switch self {
        case .event(let event):
            guard !event.isAllDay else { return nil }
            if event.startDate <= now, now <= event.endDate {
                return .ongoing
            }
            return event.endDate < now ? .past : .future
        case .reminder:
            guard let dueDate = timelineDate else { return nil }
            if Self.isSameMinute(dueDate, now, calendar: calendar) {
                return .ongoing
            }
            return dueDate < now ? .past : .future
        }
    }

    private static func isSameMinute(_ lhs: Date, _ rhs: Date, calendar: Calendar) -> Bool {
        let left = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: lhs)
        let right = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: rhs)
        return left == right
    }
}
