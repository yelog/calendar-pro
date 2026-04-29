@preconcurrency import EventKit
import Combine

extension EKReminder: @unchecked @retroactive Sendable {}

enum CalendarItemCreationKind: Equatable {
    case event
    case reminder
}

struct CalendarEventCreationRequest: Equatable {
    var title: String
    var calendarIdentifier: String
    var startDate: Date
    var endDate: Date
    var isAllDay: Bool
    var notes: String?

    static func makeDefault(
        selectedDate: Date,
        calendarIdentifier: String,
        calendar: Calendar = .autoupdatingCurrent,
        now: Date = Date()
    ) -> CalendarEventCreationRequest {
        let dayStart = calendar.startOfDay(for: selectedDate)
        let selectedHour = calendar.isDate(selectedDate, inSameDayAs: now)
            ? max(calendar.component(.hour, from: now) + 1, 9)
            : 9
        let startComponents = DateComponents(hour: min(selectedHour, 22), minute: 0)
        let startDate = calendar.date(byAdding: startComponents, to: dayStart) ?? dayStart
        let endDate = calendar.date(byAdding: .hour, value: 1, to: startDate) ?? startDate

        return CalendarEventCreationRequest(
            title: "",
            calendarIdentifier: calendarIdentifier,
            startDate: startDate,
            endDate: endDate,
            isAllDay: false,
            notes: nil
        )
    }

    static func makeEditing(_ event: EKEvent) -> CalendarEventCreationRequest {
        CalendarEventCreationRequest(
            title: event.title ?? "",
            calendarIdentifier: event.calendar.calendarIdentifier,
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            notes: event.notes
        )
    }
}

struct ReminderCreationRequest: Equatable {
    var title: String
    var calendarIdentifier: String
    var dueDate: Date
    var includesTime: Bool
    var notes: String?

    static func makeDefault(
        selectedDate: Date,
        calendarIdentifier: String,
        calendar: Calendar = .autoupdatingCurrent,
        now: Date = Date()
    ) -> ReminderCreationRequest {
        let dayStart = calendar.startOfDay(for: selectedDate)
        let selectedHour = calendar.isDate(selectedDate, inSameDayAs: now)
            ? max(calendar.component(.hour, from: now) + 1, 9)
            : 9
        let dueDate = calendar.date(
            byAdding: DateComponents(hour: min(selectedHour, 22), minute: 0),
            to: dayStart
        ) ?? dayStart

        return ReminderCreationRequest(
            title: "",
            calendarIdentifier: calendarIdentifier,
            dueDate: dueDate,
            includesTime: true,
            notes: nil
        )
    }

    static func makeEditing(_ reminder: EKReminder, calendar: Calendar = .autoupdatingCurrent) -> ReminderCreationRequest {
        let components = reminder.dueDateComponents
        let dueDate = components.flatMap { calendar.date(from: $0) } ?? Date()
        let includesTime = components?.hour != nil
            || components?.minute != nil
            || components?.second != nil

        return ReminderCreationRequest(
            title: reminder.title ?? "",
            calendarIdentifier: reminder.calendar.calendarIdentifier,
            dueDate: dueDate,
            includesTime: includesTime,
            notes: reminder.notes
        )
    }
}

@MainActor
final class EventService: ObservableObject {
    @Published private(set) var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published private(set) var calendars: [EKCalendar] = []
    @Published private(set) var isAuthorized: Bool = false
    @Published private(set) var remindersAuthorized: Bool = false
    @Published private(set) var reminderCalendars: [EKCalendar] = []
    @Published private(set) var storeChangeRevision: Int = 0
    
    private let eventStore = EKEventStore()
    private var debounceTask: Task<Void, Never>?
    
    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStoreChanged),
            name: .EKEventStoreChanged,
            object: nil
        )
    }
    
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
        
        // Fetch incomplete reminders due on or before the selected day.
        // Using nil as start date to catch recurring reminders whose original
        // due date is before the target day.
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
        
        let filteredIncomplete = incomplete.filter {
            Self.reminder($0, isDueOn: date, calendar: calendar)
        }
        let filteredCompleted = completed.filter {
            Self.reminder($0, isDueOn: date, calendar: calendar)
        }
        
        // Combine and deduplicate
        var seen = Set<String>()
        var result: [EKReminder] = []
        for reminder in filteredIncomplete + filteredCompleted {
            if seen.insert(reminder.calendarItemIdentifier).inserted {
                result.append(reminder)
            }
        }
        
        return result
    }
    
    func fetchCalendarItems(
        for date: Date,
        enabledCalendarIDs: [String],
        enabledReminderCalendarIDs: [String],
        showCalendarEvents: Bool,
        showReminders: Bool
    ) async -> [CalendarItem] {
        var items: [CalendarItem] = []

        if showCalendarEvents {
            let events = fetchEvents(for: date)
            let filteredEvents = events.filter { event in
                enabledCalendarIDs.isEmpty || enabledCalendarIDs.contains(event.calendar.calendarIdentifier)
            }
            items.append(contentsOf: filteredEvents.map { .event($0) })
        }

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

    var writableCalendars: [EKCalendar] {
        calendars.filter(\.allowsContentModifications)
    }

    var writableReminderCalendars: [EKCalendar] {
        reminderCalendars.filter(\.allowsContentModifications)
    }

    static func reminder(_ reminder: EKReminder, isDueOn date: Date, calendar: Calendar = .current) -> Bool {
        guard let components = reminder.dueDateComponents,
              let dueDate = calendar.date(from: components) else {
            return false
        }

        guard let rules = reminder.recurrenceRules, !rules.isEmpty else {
            return calendar.isDate(dueDate, inSameDayAs: date)
        }

        let targetStart = calendar.startOfDay(for: date)
        let dueStart = calendar.startOfDay(for: dueDate)

        guard targetStart >= dueStart else { return false }

        for rule in rules {
            if isOccurrence(of: rule, fromDate: dueStart, toDate: targetStart, calendar: calendar) {
                return true
            }
        }

        return false
    }

    private static func isOccurrence(
        of rule: EKRecurrenceRule,
        fromDate baseDate: Date,
        toDate targetDate: Date,
        calendar: Calendar
    ) -> Bool {
        let interval = max(rule.interval, 1)
        let daysBetween = calendar.dateComponents([.day], from: baseDate, to: targetDate).day ?? 0

        switch rule.frequency {
        case .daily:
            guard daysBetween >= 0 && daysBetween % interval == 0 else { return false }
            if let end = rule.recurrenceEnd {
                if end.occurrenceCount > 0 {
                    let occurrenceNumber = daysBetween / interval + 1
                    guard occurrenceNumber <= end.occurrenceCount else { return false }
                } else if let endDate = end.endDate {
                    guard targetDate <= calendar.startOfDay(for: endDate) else { return false }
                }
            }
            return true
        case .weekly:
            let weeksBetween = calendar.dateComponents([.weekOfYear], from: baseDate, to: targetDate).weekOfYear ?? 0
            guard weeksBetween >= 0 && weeksBetween % interval == 0 else { return false }
            if let end = rule.recurrenceEnd {
                if end.occurrenceCount > 0 {
                    let occurrenceNumber = weeksBetween / interval + 1
                    guard occurrenceNumber <= end.occurrenceCount else { return false }
                } else if let endDate = end.endDate {
                    guard targetDate <= calendar.startOfDay(for: endDate) else { return false }
                }
            }
            if let days = rule.daysOfTheWeek, !days.isEmpty {
                let targetWeekday = calendar.component(.weekday, from: targetDate)
                return days.contains { $0.dayOfTheWeek.rawValue == targetWeekday }
            }
            return calendar.component(.weekday, from: baseDate) == calendar.component(.weekday, from: targetDate)
        case .monthly:
            let baseMonth = calendar.component(.month, from: baseDate)
            let baseYear = calendar.component(.year, from: baseDate)
            let targetMonth = calendar.component(.month, from: targetDate)
            let targetYear = calendar.component(.year, from: targetDate)
            let monthsBetween = (targetYear - baseYear) * 12 + (targetMonth - baseMonth)
            guard monthsBetween >= 0 && monthsBetween % interval == 0 else { return false }
            if let end = rule.recurrenceEnd {
                if end.occurrenceCount > 0 {
                    let occurrenceNumber = monthsBetween / interval + 1
                    guard occurrenceNumber <= end.occurrenceCount else { return false }
                } else if let endDate = end.endDate {
                    guard targetDate <= calendar.startOfDay(for: endDate) else { return false }
                }
            }
            if let days = rule.daysOfTheMonth, !days.isEmpty {
                let targetDay = calendar.component(.day, from: targetDate)
                return days.contains { $0.intValue == targetDay }
            }
            return calendar.component(.day, from: baseDate) == calendar.component(.day, from: targetDate)
        case .yearly:
            let baseYear = calendar.component(.year, from: baseDate)
            let targetYear = calendar.component(.year, from: targetDate)
            let yearsBetween = targetYear - baseYear
            guard yearsBetween >= 0 && yearsBetween % interval == 0 else { return false }
            if let end = rule.recurrenceEnd {
                if end.occurrenceCount > 0 {
                    let occurrenceNumber = yearsBetween / interval + 1
                    guard occurrenceNumber <= end.occurrenceCount else { return false }
                } else if let endDate = end.endDate {
                    guard targetDate <= calendar.startOfDay(for: endDate) else { return false }
                }
            }
            if let months = rule.monthsOfTheYear, !months.isEmpty {
                let targetMonth = calendar.component(.month, from: targetDate)
                return months.contains { $0.intValue == targetMonth }
            }
            return calendar.component(.month, from: baseDate) == calendar.component(.month, from: targetDate)
                && calendar.component(.day, from: baseDate) == calendar.component(.day, from: targetDate)
        @unknown default:
            return false
        }
    }

    func createEvent(_ request: CalendarEventCreationRequest) throws -> EKEvent {
        guard isAuthorized else {
            throw NSError(
                domain: "CalendarPro.EventCreation",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: L("Calendar Access Required")]
            )
        }

        guard let calendar = calendar(withIdentifier: request.calendarIdentifier),
              calendar.allowsContentModifications else {
            throw NSError(
                domain: "CalendarPro.EventCreation",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: L("No writable calendar is available.")]
            )
        }

        let event = EKEvent(eventStore: eventStore)
        event.calendar = calendar
        event.title = request.title.trimmingCharacters(in: .whitespacesAndNewlines)
        event.startDate = request.startDate
        event.endDate = max(request.endDate, request.startDate)
        event.isAllDay = request.isAllDay
        event.notes = normalizedOptionalText(request.notes)

        try eventStore.save(event, span: .thisEvent, commit: true)
        return event
    }

    func updateEvent(_ event: EKEvent, with request: CalendarEventCreationRequest) throws {
        guard isAuthorized else {
            throw NSError(
                domain: "CalendarPro.EventUpdate",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: L("Calendar Access Required")]
            )
        }

        guard let calendar = calendar(withIdentifier: request.calendarIdentifier),
              calendar.allowsContentModifications else {
            throw NSError(
                domain: "CalendarPro.EventUpdate",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: L("No writable calendar is available.")]
            )
        }

        event.calendar = calendar
        event.title = request.title.trimmingCharacters(in: .whitespacesAndNewlines)
        event.startDate = request.startDate
        event.endDate = max(request.endDate, request.startDate)
        event.isAllDay = request.isAllDay
        event.notes = normalizedOptionalText(request.notes)

        try eventStore.save(event, span: .thisEvent, commit: true)
    }

    func deleteEvent(_ event: EKEvent) throws {
        guard isAuthorized else {
            throw NSError(
                domain: "CalendarPro.EventDelete",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: L("Calendar Access Required")]
            )
        }

        try eventStore.remove(event, span: .thisEvent, commit: true)
    }

    func createReminder(_ request: ReminderCreationRequest) throws -> EKReminder {
        guard remindersAuthorized else {
            throw NSError(
                domain: "CalendarPro.ReminderCreation",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: L("Reminders Access Required")]
            )
        }

        guard let calendar = reminderCalendar(withIdentifier: request.calendarIdentifier),
              calendar.allowsContentModifications else {
            throw NSError(
                domain: "CalendarPro.ReminderCreation",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: L("No writable reminder list is available.")]
            )
        }

        let reminder = EKReminder(eventStore: eventStore)
        reminder.calendar = calendar
        reminder.title = request.title.trimmingCharacters(in: .whitespacesAndNewlines)
        reminder.notes = normalizedOptionalText(request.notes)
        reminder.dueDateComponents = dueDateComponents(for: request.dueDate, includesTime: request.includesTime)

        try eventStore.save(reminder, commit: true)
        return reminder
    }

    func updateReminder(_ reminder: EKReminder, with request: ReminderCreationRequest) throws {
        guard remindersAuthorized else {
            throw NSError(
                domain: "CalendarPro.ReminderUpdate",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: L("Reminders Access Required")]
            )
        }

        guard let calendar = reminderCalendar(withIdentifier: request.calendarIdentifier),
              calendar.allowsContentModifications else {
            throw NSError(
                domain: "CalendarPro.ReminderUpdate",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: L("No writable reminder list is available.")]
            )
        }

        reminder.calendar = calendar
        reminder.title = request.title.trimmingCharacters(in: .whitespacesAndNewlines)
        reminder.notes = normalizedOptionalText(request.notes)
        reminder.dueDateComponents = dueDateComponents(for: request.dueDate, includesTime: request.includesTime)

        try eventStore.save(reminder, commit: true)
    }

    func deleteReminder(_ reminder: EKReminder) throws {
        guard remindersAuthorized else {
            throw NSError(
                domain: "CalendarPro.ReminderDelete",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: L("Reminders Access Required")]
            )
        }

        try eventStore.remove(reminder, commit: true)
    }

    private func dueDateComponents(for date: Date, includesTime: Bool) -> DateComponents {
        let calendar = Calendar.autoupdatingCurrent
        let components: Set<Calendar.Component> = includesTime
            ? [.calendar, .timeZone, .year, .month, .day, .hour, .minute]
            : [.calendar, .timeZone, .year, .month, .day]
        var dateComponents = calendar.dateComponents(components, from: date)
        dateComponents.calendar = calendar
        dateComponents.timeZone = calendar.timeZone
        return dateComponents
    }

    private func normalizedOptionalText(_ text: String?) -> String? {
        let normalized = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return normalized.isEmpty ? nil : normalized
    }
    
    @objc private func handleStoreChanged(_ notification: Notification) {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            fetchCalendars()
            fetchReminderCalendars()
            storeChangeRevision += 1
        }
    }
}
