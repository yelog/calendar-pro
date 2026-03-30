import SwiftUI
import EventKit

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
}
