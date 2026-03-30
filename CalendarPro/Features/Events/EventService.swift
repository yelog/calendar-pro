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
        remindersAuthorized = reminderStatus == .fullAccess || reminderStatus == .writeOnly
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
        
        let predicate = eventStore.predicateForReminders(in: calendarsToFetch)

        return await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                let filtered = reminders?.filter { reminder in
                    guard let dueDate = reminder.dueDateComponents?.date else { return false }
                    return dueDate >= startOfDay && dueDate < endOfDay
                } ?? []
                continuation.resume(returning: filtered)
            }
        }
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
        
        return items.sorted { item1, item2 in
            let date1 = item1.startDate ?? Date.distantFuture
            let date2 = item2.startDate ?? Date.distantFuture
            return date1 < date2
        }
    }
    
    func calendar(withIdentifier identifier: String) -> EKCalendar? {
        return calendars.first { $0.calendarIdentifier == identifier }
    }
    
    func reminderCalendar(withIdentifier identifier: String) -> EKCalendar? {
        return reminderCalendars.first { $0.calendarIdentifier == identifier }
    }
}
