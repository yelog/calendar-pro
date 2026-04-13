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

enum ReminderRecurrenceSummaryStyle {
    case compact
    case detailed
}

enum EventParticipationChoice: CaseIterable, Equatable {
    case accept
    case maybe
    case decline

    init?(participantStatus: EKParticipantStatus) {
        switch participantStatus {
        case .accepted:
            self = .accept
        case .tentative:
            self = .maybe
        case .declined:
            self = .decline
        default:
            return nil
        }
    }

    init?(participantStatusRawValue: Int) {
        guard let status = EKParticipantStatus(rawValue: participantStatusRawValue) else {
            return nil
        }
        self.init(participantStatus: status)
    }

    var eventKitStatus: EKParticipantStatus {
        switch self {
        case .accept:
            return .accepted
        case .maybe:
            return .tentative
        case .decline:
            return .declined
        }
    }
}

enum EventParticipationPresentation: Equatable {
    case hidden
    case readOnly
    case editable(currentChoice: EventParticipationChoice?)
}

extension EKEvent {
    var isCanceled: Bool {
        status == .canceled
    }

    private var currentUserActsAsOrganizer: Bool {
        organizer?.isCurrentUser == true
    }

    private var hasReliableCurrentUserParticipationIdentity: Bool {
        if let attendees, attendees.contains(where: { $0.isCurrentUser }) {
            return true
        }

        if runtimeBoolValue(forKey: "currentUserInvitedAttendee") {
            return true
        }

        if let participantRole = runtimeIntValue(forKey: "currentUserGeneralizedParticipantRole"), participantRole != 0 {
            return true
        }

        return false
    }

    private var supportsParticipationStatusModifications: Bool {
        runtimeBoolValue(forKey: "allowsParticipationStatusModifications")
            || runtimeBoolValue(forKey: "canBeRespondedTo")
    }

    private var resolvedCurrentUserParticipationChoice: EventParticipationChoice? {
        if let participant = attendees?.first(where: { $0.isCurrentUser }) {
            return EventParticipationChoice(participantStatus: participant.participantStatus)
        }

        guard hasReliableCurrentUserParticipationIdentity else {
            return nil
        }

        return EventParticipationChoice(
            participantStatusRawValue: runtimeIntValue(forKey: "participationStatus")
                ?? EKParticipantStatus.unknown.rawValue
        )
    }

    var selectionIdentifier: String {
        if let eventIdentifier {
            return eventIdentifier
        }

        return [
            calendar?.calendarIdentifier ?? "unknown-calendar",
            title ?? "untitled",
            String(startDate.timeIntervalSinceReferenceDate),
            String(endDate.timeIntervalSinceReferenceDate)
        ].joined(separator: "|")
    }

    var hasCurrentUserParticipationContext: Bool {
        currentUserParticipationPresentation != .hidden
    }

    var currentUserParticipationPresentation: EventParticipationPresentation {
        guard !currentUserActsAsOrganizer else {
            return .hidden
        }

        let currentChoice = resolvedCurrentUserParticipationChoice

        if supportsParticipationStatusModifications {
            return .editable(currentChoice: currentChoice)
        }

        if hasReliableCurrentUserParticipationIdentity {
            return .readOnly
        }

        return .hidden
    }

    var currentUserParticipationChoice: EventParticipationChoice? {
        guard case .editable(let currentChoice) = currentUserParticipationPresentation else {
            return nil
        }

        return currentChoice
    }

    var canModifyCurrentUserParticipationChoice: Bool {
        if case .editable = currentUserParticipationPresentation {
            return true
        }

        return false
    }

    var isRecurringParticipationSeries: Bool {
        hasRecurrenceRules || occurrenceDate != nil
    }

    func updateCurrentUserParticipationChoice(_ choice: EventParticipationChoice, span: EKSpan) throws {
        guard case .editable = currentUserParticipationPresentation else {
            throw NSError(
                domain: "CalendarPro.EventParticipation",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "This event does not allow participation updates."]
            )
        }

        guard let eventStore = value(forKey: "eventStore") as? EKEventStore else {
            throw NSError(
                domain: "CalendarPro.EventParticipation",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Unable to access the backing event store."]
            )
        }

        setValue(choice.eventKitStatus.rawValue, forKey: "participationStatus")

        do {
            try eventStore.save(self, span: span)
        } catch {
            throw error
        }
    }

    private func runtimeBoolValue(forKey key: String) -> Bool {
        guard responds(to: NSSelectorFromString(key)) else {
            return false
        }

        return (value(forKey: key) as? NSNumber)?.boolValue ?? false
    }

    private func runtimeIntValue(forKey key: String) -> Int? {
        guard responds(to: NSSelectorFromString(key)) else {
            return nil
        }

        return (value(forKey: key) as? NSNumber)?.intValue
    }
}

extension EKReminder {
    func recurrenceSummary(style: ReminderRecurrenceSummaryStyle = .detailed) -> String? {
        guard let rules = recurrenceRules, !rules.isEmpty,
              let rule = rules.first else {
            return nil
        }
        return rule.localizedSummary(style: style)
    }
}

private extension EKRecurrenceRule {
    func localizedSummary(style: ReminderRecurrenceSummaryStyle) -> String {
        let interval = max(interval, 1)

        switch frequency {
        case .daily:
            return interval == 1 ? L("Daily") : LF("Every %d Days", interval)
        case .weekly:
            if interval == 1 {
                if style == .detailed,
                   let days = daysOfTheWeek,
                   !days.isEmpty {
                    let dayNames = days
                        .map { weekdayName($0.dayOfTheWeek) }
                        .filter { !$0.isEmpty }
                    if !dayNames.isEmpty {
                        return LF("Weekly %@", dayNames.joined(separator: ", "))
                    }
                }
                return L("Weekly")
            }
            return LF("Every %d Weeks", interval)
        case .monthly:
            return interval == 1 ? L("Monthly") : LF("Every %d Months", interval)
        case .yearly:
            return interval == 1 ? L("Yearly") : LF("Every %d Years", interval)
        @unknown default:
            return L("Custom Repeat")
        }
    }

    private func weekdayName(_ weekday: EKWeekday) -> String {
        let calendar = Calendar.autoupdatingCurrent
        let formatter = DateFormatter()
        formatter.locale = AppLocalization.locale
        let symbols = formatter.shortStandaloneWeekdaySymbols ?? calendar.shortWeekdaySymbols

        switch weekday {
        case .sunday: return symbols[0]
        case .monday: return symbols[1]
        case .tuesday: return symbols[2]
        case .wednesday: return symbols[3]
        case .thursday: return symbols[4]
        case .friday: return symbols[5]
        case .saturday: return symbols[6]
        @unknown default: return ""
        }
    }
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
            return event.title ?? L("Untitled")
        case .reminder(let reminder):
            return reminder.title ?? L("Untitled")
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

    var isCanceled: Bool {
        switch self {
        case .event(let event):
            return event.isCanceled
        case .reminder:
            return false
        }
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

    var meetingLink: MeetingLink? {
        guard case .event(let event) = self else {
            return nil
        }
        return MeetingLinkDetector.detect(in: event)
    }

    var meetingParticipantCount: Int? {
        guard case .event(let event) = self,
              let attendees = event.attendees,
              !attendees.isEmpty else {
            return nil
        }
        return attendees.count
    }

    var currentUserParticipationChoice: EventParticipationChoice? {
        guard case .event(let event) = self else {
            return nil
        }
        return event.currentUserParticipationChoice
    }

    var reminderRecurrenceText: String? {
        guard case .reminder(let reminder) = self else {
            return nil
        }
        return reminder.recurrenceSummary(style: .compact)
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

    func timelineProgress(at now: Date, calendar: Calendar = .autoupdatingCurrent) -> Double? {
        switch self {
        case .event(let event):
            guard !event.isAllDay,
                  event.startDate <= now,
                  now <= event.endDate else {
                return nil
            }

            let duration = event.endDate.timeIntervalSince(event.startDate)
            guard duration > 0 else { return 0.5 }

            let progress = now.timeIntervalSince(event.startDate) / duration
            return min(max(progress, 0), 1)
        case .reminder:
            guard let dueDate = timelineDate,
                  Self.isSameMinute(dueDate, now, calendar: calendar) else {
                return nil
            }
            return 0.5
        }
    }

    private static func isSameMinute(_ lhs: Date, _ rhs: Date, calendar: Calendar) -> Bool {
        let left = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: lhs)
        let right = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: rhs)
        return left == right
    }
}
