@preconcurrency import EventKit
import Combine

extension EKReminder: @unchecked @retroactive Sendable {}

enum CalendarItemCreationKind: Equatable {
    case event
    case reminder
}

struct CalendarItemCreationTimeRange: Equatable {
    let startDate: Date
    let endDate: Date
}

struct CalendarEventCreationRequest: Equatable {
    var title: String
    var calendarIdentifier: String
    var startDate: Date
    var endDate: Date
    var isAllDay: Bool
    var notes: String?
    var calendar: Calendar = .autoupdatingCurrent
    var datesChanged: Bool = true

    static func make(
        title: String,
        calendarIdentifier: String,
        schedule: CalendarEventScheduleDraft,
        notes: String?,
        calendar: Calendar? = nil,
        datesChanged: Bool = true
    ) throws -> CalendarEventCreationRequest {
        let request = CalendarEventCreationRequest(
            title: title,
            calendarIdentifier: calendarIdentifier,
            startDate: schedule.startDate,
            endDate: schedule.endDate,
            isAllDay: schedule.isAllDay,
            notes: notes,
            calendar: CalendarItemDateResolver.snapshot(calendar ?? schedule.calendar),
            datesChanged: datesChanged
        )
        try request.validateSchedule()
        return request
    }

    func validateSchedule() throws {
        guard endDate > startDate else {
            throw isAllDay
                ? CalendarEventScheduleError.invalidAllDayRange
                : CalendarEventScheduleError.endMustBeAfterStart
        }
    }

    static func makeDefault(
        selectedDate: Date,
        calendarIdentifier: String,
        calendar: Calendar = .autoupdatingCurrent,
        now: Date = Date()
    ) -> CalendarEventCreationRequest {
        let calendar = CalendarItemDateResolver.snapshot(calendar)
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
            notes: nil,
            calendar: calendar
        )
    }

    static func makeEditing(
        _ event: EKEvent,
        calendar: Calendar = .autoupdatingCurrent
    ) -> CalendarEventCreationRequest {
        let calendar = CalendarItemDateResolver.snapshot(calendar)
        return CalendarEventCreationRequest(
            title: event.title ?? "",
            calendarIdentifier: event.calendar.calendarIdentifier,
            startDate: CalendarItemDateResolver.eventDate(event.startDate, event: event, calendar: calendar),
            endDate: CalendarItemDateResolver.eventDate(event.endDate, event: event, calendar: calendar),
            isAllDay: event.isAllDay,
            notes: event.notes,
            calendar: calendar,
            datesChanged: false
        )
    }

    /// Applies to an in-memory item as well, so date conversions can be tested
    /// without saving anything to the user's EventKit database.
    func applySchedule(to event: EKEvent, isNew: Bool = false) {
        guard isNew || datesChanged else { return }

        let timeZone = isAllDay ? nil : (isNew ? calendar.timeZone : event.timeZone)
        let usesWallClockDates = isAllDay || timeZone == nil
        let systemCalendar = CalendarItemDateResolver.systemCalendar
        // EventKit normalizes an all-day end to 23:59:59 and a non-nil zone
        // makes it timed again. Assign the exclusive range while timed, then
        // enable all-day last so neither setter can extend the covered dates.
        event.isAllDay = false
        event.timeZone = timeZone
        event.startDate = usesWallClockDates
            ? CalendarItemDateResolver.rebase(startDate, from: calendar, to: systemCalendar)
            : startDate
        event.endDate = usesWallClockDates
            ? CalendarItemDateResolver.rebase(endDate, from: calendar, to: systemCalendar)
            : endDate
        if isAllDay {
            event.isAllDay = true
        }
    }
}

struct ReminderCreationRequest: Equatable {
    var title: String
    var calendarIdentifier: String
    var dueDate: Date
    var includesTime: Bool
    var notes: String?
    var calendar: Calendar = .autoupdatingCurrent
    var datesChanged: Bool = true

    static func makeDefault(
        selectedDate: Date,
        calendarIdentifier: String,
        calendar: Calendar = .autoupdatingCurrent,
        now: Date = Date()
    ) -> ReminderCreationRequest {
        let calendar = CalendarItemDateResolver.snapshot(calendar)
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
            notes: nil,
            calendar: calendar
        )
    }

    static func makeEditing(_ reminder: EKReminder, calendar: Calendar = .autoupdatingCurrent) -> ReminderCreationRequest {
        let calendar = CalendarItemDateResolver.snapshot(calendar)
        let components = reminder.dueDateComponents
        let dueDate = components.flatMap {
            CalendarItemDateResolver.reminderDate(from: $0, calendar: calendar)
        } ?? Date()
        let includesTime = components?.hour != nil
            || components?.minute != nil
            || components?.second != nil

        return ReminderCreationRequest(
            title: reminder.title ?? "",
            calendarIdentifier: reminder.calendar.calendarIdentifier,
            dueDate: dueDate,
            includesTime: includesTime,
            notes: reminder.notes,
            calendar: calendar,
            datesChanged: false
        )
    }

    func applySchedule(to reminder: EKReminder, isNew: Bool = false) {
        guard isNew || datesChanged else { return }

        let originalComponents = isNew ? nil : reminder.dueDateComponents
        var dueCalendar = calendar
        if includesTime, let sourceTimeZone = originalComponents?.timeZone {
            dueCalendar = originalComponents?.calendar ?? calendar
            dueCalendar.timeZone = sourceTimeZone
        }

        let fields: Set<Calendar.Component> = includesTime
            ? [.year, .month, .day, .hour, .minute]
            : [.year, .month, .day]
        var components = dueCalendar.dateComponents(fields, from: dueDate)
        // Date-only values and existing floating reminders remain wall dates.
        let isFloating = originalComponents != nil && originalComponents?.timeZone == nil
        components.timeZone = includesTime && !isFloating ? dueCalendar.timeZone : nil
        // With no explicit zone, EventKit still normalizes through the
        // embedded calendar. Attach its default calendar to preserve the app
        // wall components instead of converting them a second time on write.
        components.calendar = components.timeZone == nil
            ? CalendarItemDateResolver.systemCalendar
            : dueCalendar
        reminder.dueDateComponents = components
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
    private let calendarProvider: () -> Calendar
    private var debounceTask: Task<Void, Never>?
    
    init(calendarProvider: @escaping () -> Calendar = { .autoupdatingCurrent }) {
        self.calendarProvider = calendarProvider
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
    
    func fetchEvents(for date: Date, calendar: Calendar? = nil) -> [EKEvent] {
        guard isAuthorized else { return [] }
        
        let calendar = CalendarItemDateResolver.snapshot(calendar ?? calendarProvider())
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        let queryWindow = CalendarItemDateResolver.queryWindow(
            from: startOfDay,
            through: endOfDay,
            calendar: calendar
        )
        
        let predicate = eventStore.predicateForEvents(
            withStart: queryWindow.start,
            end: queryWindow.end,
            calendars: nil
        )
        
        return eventStore.events(matching: predicate)
            .filter { Self.event($0, isOn: date, calendar: calendar) }
            .sorted {
                CalendarItemDateResolver.eventDate($0.startDate, event: $0, calendar: calendar)
                    < CalendarItemDateResolver.eventDate($1.startDate, event: $1, calendar: calendar)
            }
    }
    
    func fetchReminders(
        for date: Date,
        enabledCalendarIDs: [String],
        calendar: Calendar? = nil
    ) async -> [EKReminder] {
        guard remindersAuthorized else { return [] }
        
        let calendar = CalendarItemDateResolver.snapshot(calendar ?? calendarProvider())
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        
        let calendarsToFetch: [EKCalendar]
        if enabledCalendarIDs.isEmpty {
            calendarsToFetch = reminderCalendars
        } else {
            calendarsToFetch = reminderCalendars.filter { enabledCalendarIDs.contains($0.calendarIdentifier) }
        }
        
        guard !calendarsToFetch.isEmpty else { return [] }
        
        // Keep the recurring-reminder start unbounded. The padded upper bound
        // covers civil dates represented in another zone before local filtering.
        let incompletePredicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: CalendarItemDateResolver.reminderQueryEnd(after: endOfDay),
            calendars: calendarsToFetch
        )
        
        // Completion dates are absolute instants in the selected app day;
        // resolved due dates are checked after fetching.
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
    
    /// Fetches board reminders, optionally merging completed items
    /// (all of them, or only those completed after the given window start).
    func fetchBoardReminders(
        enabledCalendarIDs: [String],
        includeCompleted: Bool,
        recentCompletedWindowStart: Date? = nil
    ) async -> [EKReminder] {
        guard remindersAuthorized else { return [] }

        let calendarsToFetch: [EKCalendar]
        if enabledCalendarIDs.isEmpty {
            calendarsToFetch = reminderCalendars
        } else {
            calendarsToFetch = reminderCalendars.filter { enabledCalendarIDs.contains($0.calendarIdentifier) }
        }

        guard !calendarsToFetch.isEmpty else { return [] }

        let store = eventStore

        // nil start/end fetches every incomplete reminder; the board needs the
        // full set, not a single-day window.
        let incompletePredicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: calendarsToFetch
        )

        async let incompleteResult = withCheckedContinuation { (continuation: CheckedContinuation<[EKReminder], Never>) in
            store.fetchReminders(matching: incompletePredicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }

        let incomplete = await incompleteResult

        guard includeCompleted || recentCompletedWindowStart != nil else { return incomplete }

        let completedPredicate = eventStore.predicateForCompletedReminders(
            withCompletionDateStarting: includeCompleted ? nil : recentCompletedWindowStart,
            ending: nil,
            calendars: calendarsToFetch
        )

        let completed = await withCheckedContinuation { (continuation: CheckedContinuation<[EKReminder], Never>) in
            store.fetchReminders(matching: completedPredicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }

        var seen = Set<String>()
        var result: [EKReminder] = []
        for reminder in incomplete + completed {
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
        showReminders: Bool,
        calendar: Calendar? = nil
    ) async -> [CalendarItem] {
        let calendar = CalendarItemDateResolver.snapshot(calendar ?? calendarProvider())
        var items: [CalendarItem] = []

        if showCalendarEvents {
            let events = fetchEvents(for: date, calendar: calendar)
            let filteredEvents = events.filter { event in
                enabledCalendarIDs.isEmpty || enabledCalendarIDs.contains(event.calendar.calendarIdentifier)
            }
            items.append(contentsOf: filteredEvents.map { .event($0) })
        }

        if showReminders {
            let reminders = await fetchReminders(
                for: date,
                enabledCalendarIDs: enabledReminderCalendarIDs,
                calendar: calendar
            )
            items.append(contentsOf: reminders.map { .reminder($0) })
        }

        return items.sorted { item1, item2 in
            // All-day items come first
            if item1.isAllDay != item2.isAllDay {
                return item1.isAllDay
            }

            guard let date1 = item1.startDate(using: calendar),
                  let date2 = item2.startDate(using: calendar) else {
                return item1.startDate(using: calendar) != nil
            }

            // Compare by time-of-day so overdue reminders sort alongside
            // today's items with the same displayed time.
            let c1 = calendar.dateComponents([.hour, .minute], from: date1)
            let c2 = calendar.dateComponents([.hour, .minute], from: date2)
            let t1 = (c1.hour ?? 0) * 60 + (c1.minute ?? 0)
            let t2 = (c2.hour ?? 0) * 60 + (c2.minute ?? 0)
            return t1 < t2
        }
    }
    
    /// Fetches [pastStart, futureEnd) items (events plus optional timed
    /// incomplete reminders), ascending by start date. Multi-day events that
    /// started before pastStart are excluded so they show only once; ended
    /// events inside the window stay for history browsing. Recurring
    /// reminders use the per-day approximation below.
    func fetchUpcomingCalendarItems(
        pastStart: Date,
        futureEnd: Date,
        enabledCalendarIDs: [String],
        includeReminders: Bool,
        enabledReminderCalendarIDs: [String],
        calendar: Calendar? = nil
    ) async -> [CalendarItem] {
        let calendar = CalendarItemDateResolver.snapshot(calendar ?? calendarProvider())
        guard pastStart < futureEnd else { return [] }
        var items: [CalendarItem] = []

        if isAuthorized {
            let queryWindow = CalendarItemDateResolver.queryWindow(
                from: pastStart,
                through: futureEnd,
                calendar: calendar
            )
            let predicate = eventStore.predicateForEvents(
                withStart: queryWindow.start,
                end: queryWindow.end,
                calendars: nil
            )
            let events = eventStore.events(matching: predicate).filter {
                Self.event(
                    $0,
                    isWithinUpcomingWindow: pastStart,
                    enabledCalendarIDs: enabledCalendarIDs,
                    windowEnd: futureEnd,
                    calendar: calendar
                )
            }
            items.append(contentsOf: events.map { .event($0) })
        }

        if includeReminders {
            let reminders = await fetchUpcomingReminders(
                from: pastStart,
                through: futureEnd,
                enabledCalendarIDs: enabledReminderCalendarIDs,
                calendar: calendar
            )
            items.append(contentsOf: reminders.map { .reminder($0) })
        }

        return items.sorted {
            ($0.startDate(using: calendar) ?? .distantFuture)
                < ($1.startDate(using: calendar) ?? .distantFuture)
        }
    }

    /// Fetches incomplete timed reminders in the window, deduplicated by
    /// calendarItemIdentifier. The predicate starts at nil so recurring
    /// reminders based before the window are returned and filtered locally.
    private func fetchUpcomingReminders(
        from windowStart: Date,
        through windowEnd: Date,
        enabledCalendarIDs: [String],
        calendar: Calendar
    ) async -> [EKReminder] {
        guard remindersAuthorized else { return [] }

        let calendarsToFetch: [EKCalendar]
        if enabledCalendarIDs.isEmpty {
            calendarsToFetch = reminderCalendars
        } else {
            calendarsToFetch = reminderCalendars.filter {
                enabledCalendarIDs.contains($0.calendarIdentifier)
            }
        }

        guard !calendarsToFetch.isEmpty else { return [] }

        let predicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: CalendarItemDateResolver.reminderQueryEnd(after: windowEnd),
            calendars: calendarsToFetch
        )

        let store = eventStore
        let reminders: [EKReminder] = await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { result in
                continuation.resume(returning: result ?? [])
            }
        }

        var seen = Set<String>()
        return reminders.filter { reminder in
            guard !reminder.isCompleted else { return false }
            guard Self.reminder(
                reminder,
                isDueWithin: windowStart,
                windowEnd: windowEnd,
                calendar: calendar
            ) else {
                return false
            }
            return seen.insert(reminder.calendarItemIdentifier).inserted
        }
    }

    /// Whether the event belongs in the upcoming list. Both bounds must be at
    /// or after windowStart so multi-day events started earlier are excluded
    /// (and pathologically long data ending before the window is dropped).
    /// An event without a calendar (test fixtures) only matches the
    /// "all calendars" semantics.
    static func event(
        _ event: EKEvent,
        isWithinUpcomingWindow windowStart: Date,
        enabledCalendarIDs: [String],
        windowEnd: Date? = nil,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Bool {
        let startDate = CalendarItemDateResolver.eventDate(event.startDate, event: event, calendar: calendar)
        let endDate = CalendarItemDateResolver.eventDate(event.endDate, event: event, calendar: calendar)
        guard startDate >= windowStart,
              endDate > windowStart,
              windowEnd.map({ startDate < $0 }) ?? true else {
            return false
        }
        guard let calendarID = event.calendar?.calendarIdentifier else {
            return enabledCalendarIDs.isEmpty
        }
        return enabledCalendarIDs.isEmpty || enabledCalendarIDs.contains(calendarID)
    }

    static func event(_ event: EKEvent, isOn date: Date, calendar: Calendar) -> Bool {
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return false }
        let startDate = CalendarItemDateResolver.eventDate(event.startDate, event: event, calendar: calendar)
        let endDate = CalendarItemDateResolver.eventDate(event.endDate, event: event, calendar: calendar)
        return startDate < dayEnd && endDate > dayStart
    }

    /// Whether the reminder falls in [windowStart, windowEnd). Recurring
    /// reminders are expanded per-day from the later of base due date and
    /// window start (reusing isOccurrence); excluded dates are not handled,
    /// so the result is a daily approximation.
    static func reminder(
        _ reminder: EKReminder,
        isDueWithin windowStart: Date,
        windowEnd: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Bool {
        guard let components = reminder.dueDateComponents,
              let dueDate = CalendarItemDateResolver.reminderDate(from: components, calendar: calendar),
              windowStart < windowEnd else {
            return false
        }

        guard let rules = reminder.recurrenceRules, !rules.isEmpty else {
            return dueDate >= windowStart && dueDate < windowEnd
        }

        // Fixed-zone recurrences keep their source wall time across DST. Only
        // their resulting instants are compared with the app's window.
        var recurrenceCalendar = calendar
        let includesTime = components.hour != nil || components.minute != nil || components.second != nil
        if includesTime, let timeZone = components.timeZone {
            recurrenceCalendar = components.calendar ?? calendar
            recurrenceCalendar.timeZone = timeZone
        }
        let dueStart = recurrenceCalendar.startOfDay(for: dueDate)
        var day = recurrenceCalendar.startOfDay(for: max(dueDate, windowStart))
        let lastDay = recurrenceCalendar.startOfDay(for: windowEnd)
        let timeComponents = recurrenceCalendar.dateComponents([.hour, .minute, .second], from: dueDate)

        while day <= lastDay {
            var occurrenceComponents = recurrenceCalendar.dateComponents([.era, .year, .month, .day], from: day)
            occurrenceComponents.hour = timeComponents.hour
            occurrenceComponents.minute = timeComponents.minute
            occurrenceComponents.second = timeComponents.second
            let occurrenceDate = recurrenceCalendar.date(from: occurrenceComponents) ?? day
            if occurrenceDate >= windowStart,
               occurrenceDate < windowEnd,
               rules.contains(where: {
                isOccurrence(of: $0, fromDate: dueStart, toDate: day, calendar: recurrenceCalendar)
            }) {
                return true
            }
            guard let nextDay = recurrenceCalendar.date(byAdding: .day, value: 1, to: day) else {
                break
            }
            day = nextDay
        }

        return false
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

    static func reminder(_ reminder: EKReminder, isDueOn date: Date, calendar: Calendar = .autoupdatingCurrent) -> Bool {
        let targetStart = calendar.startOfDay(for: date)
        guard let targetEnd = calendar.date(byAdding: .day, value: 1, to: targetStart) else { return false }
        return Self.reminder(reminder, isDueWithin: targetStart, windowEnd: targetEnd, calendar: calendar)
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

        try request.validateSchedule()

        let event = EKEvent(eventStore: eventStore)
        event.calendar = calendar
        event.title = request.title.trimmingCharacters(in: .whitespacesAndNewlines)
        request.applySchedule(to: event, isNew: true)
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

        try request.validateSchedule()

        event.calendar = calendar
        event.title = request.title.trimmingCharacters(in: .whitespacesAndNewlines)
        request.applySchedule(to: event)
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
        request.applySchedule(to: reminder, isNew: true)

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
        request.applySchedule(to: reminder)

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
