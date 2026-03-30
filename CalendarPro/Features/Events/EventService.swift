@preconcurrency import EventKit
import Combine

extension EKReminder: @unchecked @retroactive Sendable {}

@MainActor
final class EventService: ObservableObject {
    @Published private(set) var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published private(set) var calendars: [EKCalendar] = []
    @Published private(set) var isAuthorized: Bool = false
    @Published private(set) var remindersAuthorized: Bool = false
    @Published private(set) var reminderCalendars: [EKCalendar] = []
    
    private let eventStore = EKEventStore()
    
    func checkAuthorizationStatus() {
        let eventStatus = EKEventStore.authorizationStatus(for: .event)
        let reminderStatus = EKEventStore.authorizationStatus(for: .reminder)
        
        isAuthorized = eventStatus == .fullAccess || eventStatus == .writeOnly
        remindersAuthorized = reminderStatus == .fullAccess
        authorizationStatus = eventStatus
    }
    
    func requestAccess() async -> Bool {
        do {
            let eventGranted = try await eventStore.requestFullAccessToEvents()
            isAuthorized = eventGranted
            authorizationStatus = eventGranted ? .fullAccess : .denied
            
            if eventGranted {
                fetchCalendars()
            }
            
            return eventGranted
        } catch {
            isAuthorized = false
            authorizationStatus = .denied
            return false
        }
    }
    
    func requestReminderAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToReminders()
            remindersAuthorized = granted
            if granted {
                fetchReminderCalendars()
            }
            return granted
        } catch {
            remindersAuthorized = false
            return false
        }
    }
    
    func fetchCalendars() {
        guard isAuthorized else { return }
        calendars = eventStore.calendars(for: .event)
    }
    
    func fetchReminderCalendars() {
        guard remindersAuthorized else { return }
        reminderCalendars = eventStore.calendars(for: .reminder)
    }
    
    func fetchEvents(for date: Date) -> [EKEvent] {
        guard isAuthorized else { return [] }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        
        let predicate = eventStore.predicateForEvents(
            withStart: startOfDay,
            end: endOfDay,
            calendars: nil
        )
        
        return eventStore.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
    }
    
    func fetchReminders(for date: Date, enabledCalendarIDs: [String]) async -> [EKReminder] {
        guard remindersAuthorized else { return [] }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        
        let calendarsToFetch: [EKCalendar]
        if enabledCalendarIDs.isEmpty {
            calendarsToFetch = reminderCalendars
        } else {
            calendarsToFetch = reminderCalendars.filter { enabledCalendarIDs.contains($0.calendarIdentifier) }
        }
        
        guard !calendarsToFetch.isEmpty else { return [] }
        
        // Fetch incomplete reminders due on or before the selected day (includes overdue)
        let incompletePredicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: endOfDay,
            calendars: calendarsToFetch
        )
        
        // Fetch completed reminders that were due on the selected day
        let completedPredicate = eventStore.predicateForCompletedReminders(
            withCompletionDateStarting: startOfDay,
            ending: endOfDay,
            calendars: calendarsToFetch
        )
        
        let store = eventStore
        
        async let incompleteResult = withCheckedContinuation { (continuation: CheckedContinuation<[EKReminder], Never>) in
            store.fetchReminders(matching: incompletePredicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
        
        async let completedResult = withCheckedContinuation { (continuation: CheckedContinuation<[EKReminder], Never>) in
            store.fetchReminders(matching: completedPredicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
        
        let (incomplete, completed) = await (incompleteResult, completedResult)
        
        // Filter incomplete reminders: due today or overdue (has a due date before end of today)
        let filteredIncomplete = incomplete.filter { reminder in
            guard let components = reminder.dueDateComponents,
                  let dueDate = calendar.date(from: components) else { return false }
            return dueDate < endOfDay
        }
        
        // Combine and deduplicate
        var seen = Set<String>()
        var result: [EKReminder] = []
        for reminder in filteredIncomplete + completed {
            if seen.insert(reminder.calendarItemIdentifier).inserted {
                result.append(reminder)
            }
        }
        
        return result
    }
    
    func fetchCalendarItems(for date: Date, enabledCalendarIDs: [String], enabledReminderCalendarIDs: [String], showReminders: Bool) async -> [CalendarItem] {
        var items: [CalendarItem] = []
        
        let events = fetchEvents(for: date)
        let filteredEvents = events.filter { event in
            enabledCalendarIDs.isEmpty || enabledCalendarIDs.contains(event.calendar.calendarIdentifier)
        }
        items.append(contentsOf: filteredEvents.map { .event($0) })
        
        if showReminders {
            let reminders = await fetchReminders(for: date, enabledCalendarIDs: enabledReminderCalendarIDs)
            items.append(contentsOf: reminders.map { .reminder($0) })
        }
        
        let cal = Calendar.current
        return items.sorted { item1, item2 in
            // All-day items come first
            if item1.isAllDay != item2.isAllDay {
                return item1.isAllDay
            }

            guard let date1 = item1.startDate, let date2 = item2.startDate else {
                return item1.startDate != nil
            }

            // Compare by time-of-day so overdue reminders sort alongside
            // today's items with the same displayed time.
            let c1 = cal.dateComponents([.hour, .minute], from: date1)
            let c2 = cal.dateComponents([.hour, .minute], from: date2)
            let t1 = (c1.hour ?? 0) * 60 + (c1.minute ?? 0)
            let t2 = (c2.hour ?? 0) * 60 + (c2.minute ?? 0)
            return t1 < t2
        }
    }
    
    func calendar(withIdentifier identifier: String) -> EKCalendar? {
        return calendars.first { $0.calendarIdentifier == identifier }
    }
    
    func toggleReminderCompletion(_ reminder: EKReminder) throws {
        reminder.isCompleted = !reminder.isCompleted
        try eventStore.save(reminder, commit: true)
    }
    
    func reminderCalendar(withIdentifier identifier: String) -> EKCalendar? {
        return reminderCalendars.first { $0.calendarIdentifier == identifier }
    }
}
