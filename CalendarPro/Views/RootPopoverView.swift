import SwiftUI
import EventKit

struct RootPopoverView: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var eventService: EventService
    @StateObject private var viewModel = CalendarPopoverViewModel()
    let onPresentEventDetailWindow: (EKEvent, @escaping () -> Void) -> Void
    let onPresentReminderDetailWindow: (EKReminder, @escaping (EKReminder) -> Void, @escaping () -> Void) -> Void
    let onDismissEventDetailWindow: () -> Void
    let onQuit: () -> Void

    @State private var itemsForSelectedDate: [CalendarItem] = []
    @State private var isLoadingEvents: Bool = false
    @State private var almanacDescriptor: AlmanacDescriptor?

    private let almanacService = AlmanacService()

    var body: some View {
        CalendarPopoverView(
            displayedMonth: viewModel.displayedMonth,
            displayedYear: viewModel.displayedYear,
            displayedMonthNumber: viewModel.displayedMonthNumber,
            currentYear: viewModel.currentYear,
            currentMonthNumber: viewModel.currentMonthNumber,
            selectionMode: viewModel.selectionMode,
            weekdaySymbols: viewModel.weekdaySymbols(using: displayCalendar),
            weekendIndices: Self.weekendColumnIndices(for: displayCalendar),
            monthDays: monthDays,
            highlightWeekends: settingsStore.menuBarPreferences.highlightWeekends,
            showEvents: settingsStore.menuBarPreferences.showEvents,
            emptyStateText: settingsStore.menuBarPreferences.eventListEmptyStateText,
            selectedDate: viewModel.selectedDate,
            items: itemsForSelectedDate,
            selectedEventIdentifier: viewModel.selectedEventIdentifier,
            isLoadingEvents: isLoadingEvents,
            almanac: almanacDescriptor,
            showAlmanac: settingsStore.menuBarPreferences.showAlmanac,
            onPreviousMonth: {
                viewModel.showPreviousMonth(using: displayCalendar)
            },
            onNextMonth: {
                viewModel.showNextMonth(using: displayCalendar)
            },
            onSelectYear: {
                viewModel.enterYearSelection()
            },
            onSelectMonth: {
                viewModel.enterMonthSelection()
            },
            onSelectYearValue: { year in
                viewModel.selectYear(year, calendar: displayCalendar)
            },
            onSelectMonthValue: { month in
                viewModel.selectMonth(month, calendar: displayCalendar)
            },
            onDismissPicker: {
                viewModel.dismissPicker()
            },
            onSelectDate: { date in
                dismissEventDetail()
                viewModel.selectDate(date)
            },
            onSelectEvent: { event in
                handleEventSelection(event)
            },
            onToggleReminder: { reminder in
                handleToggleReminder(reminder)
            },
            onOpenReminder: { reminder in
                handleOpenReminder(reminder)
            },
            onResetToToday: {
                dismissEventDetail()
                viewModel.resetToToday()
                let today = Date()
                viewModel.selectDate(today)
            },
            onQuit: onQuit
        )
        .onAppear {
            viewModel.checkAndResetIfNeeded()
            eventService.checkAuthorizationStatus()
            refreshEventsForCurrentSelection(selectingTodayIfNeeded: true)
            refreshInfoStrips()
        }
        .onReceive(NotificationCenter.default.publisher(for: .PopoverDidCloseNotification)) { _ in
            viewModel.popoverDidClose()
        }
        .onChange(of: eventService.isAuthorized) { _, _ in
            refreshEventsForCurrentSelection(selectingTodayIfNeeded: true)
        }
        .onChange(of: eventService.remindersAuthorized) { _, isAuthorized in
            if isAuthorized {
                eventService.fetchReminderCalendars()
            }
            refreshEventsForCurrentSelection()
        }
        .onChange(of: settingsStore.menuBarPreferences.showEvents) { _, _ in
            refreshEventsForCurrentSelection(selectingTodayIfNeeded: true)
        }
        .onChange(of: settingsStore.menuBarPreferences.showCalendarEvents) { _, _ in
            refreshEventsForCurrentSelection()
        }
        .onChange(of: settingsStore.menuBarPreferences.showReminders) { _, _ in
            refreshEventsForCurrentSelection()
        }
        .onChange(of: settingsStore.menuBarPreferences.enabledCalendarIDs) { _, _ in
            refreshEventsForCurrentSelection()
        }
        .onChange(of: settingsStore.menuBarPreferences.enabledReminderCalendarIDs) { _, _ in
            refreshEventsForCurrentSelection()
        }
        .onChange(of: eventService.storeChangeRevision) { _, _ in
            refreshEventsForCurrentSelection()
        }
        .onChange(of: viewModel.selectedDate) { _, newDate in
            if let date = newDate {
                loadEvents(for: date)
                refreshInfoStrips()
            } else {
                clearLoadedEvents()
            }
        }
        .onChange(of: settingsStore.menuBarPreferences.showAlmanac) { _, _ in
            refreshInfoStrips()
        }
    }

    private func refreshInfoStrips() {
        let date = viewModel.selectedDate ?? Date()

        if settingsStore.menuBarPreferences.showAlmanac {
            almanacDescriptor = almanacService.describe(date: date)
        } else {
            almanacDescriptor = nil
        }

    }

    private func loadEvents(for date: Date) {
        let preferences = settingsStore.menuBarPreferences

        guard preferences.showEvents else {
            clearLoadedEvents()
            return
        }

        guard preferences.hasEnabledEventSources else {
            clearLoadedEvents()
            return
        }

        if eventService.isAuthorized {
            eventService.fetchCalendars()
        }

        if eventService.remindersAuthorized {
            eventService.fetchReminderCalendars()
        }

        isLoadingEvents = true
        let requestedDate = date
        Task {
            let items = await eventService.fetchCalendarItems(
                for: date,
                enabledCalendarIDs: preferences.enabledCalendarIDs,
                enabledReminderCalendarIDs: preferences.enabledReminderCalendarIDs,
                showCalendarEvents: preferences.showCalendarEvents,
                showReminders: preferences.showReminders
            )
            await MainActor.run {
                guard viewModel.selectedDate == requestedDate else { return }
                itemsForSelectedDate = items
                syncSelectedEvent(with: items)
                isLoadingEvents = false
            }
        }
    }

    private func refreshEventsForCurrentSelection(selectingTodayIfNeeded: Bool = false) {
        let preferences = settingsStore.menuBarPreferences

        guard preferences.showEvents else {
            clearLoadedEvents()
            return
        }

        if eventService.isAuthorized {
            eventService.fetchCalendars()
        }

        if eventService.remindersAuthorized {
            eventService.fetchReminderCalendars()
        }

        if let selectedDate = viewModel.selectedDate {
            loadEvents(for: selectedDate)
        } else if selectingTodayIfNeeded {
            viewModel.selectDate(Date())
        }
    }

    private func clearLoadedEvents() {
        itemsForSelectedDate = []
        isLoadingEvents = false
        viewModel.clearSelectedEvent()
        onDismissEventDetailWindow()
    }

    private func syncSelectedEvent(with items: [CalendarItem]) {
        guard let selectedIdentifier = viewModel.selectedEventIdentifier else { return }
        let found = items.contains { item in
            return item.selectionIdentifier == selectedIdentifier
        }
        guard found else {
            viewModel.clearSelectedEvent()
            onDismissEventDetailWindow()
            return
        }
    }

    private func handleEventSelection(_ event: EKEvent) {
        let shouldPresent = viewModel.toggleEventSelection(identifier: event.selectionIdentifier)
        if shouldPresent {
            onPresentEventDetailWindow(event) {
                viewModel.clearSelectedEvent()
            }
        } else {
            onDismissEventDetailWindow()
        }
    }

    private func handleToggleReminder(_ reminder: EKReminder) {
        do {
            try eventService.toggleReminderCompletion(reminder)
            refreshEventsForCurrentSelection()
        } catch {
            print("Failed to toggle reminder completion: \(error)")
        }
    }

    private func handleOpenReminder(_ reminder: EKReminder) {
        let item = CalendarItem.reminder(reminder)
        let shouldPresent = viewModel.toggleEventSelection(identifier: item.selectionIdentifier)
        if shouldPresent {
            onPresentReminderDetailWindow(reminder, { [weak eventService] toggledReminder in
                do {
                    try eventService?.toggleReminderCompletion(toggledReminder)
                } catch {
                    print("Failed to toggle reminder completion: \(error)")
                }
            }) {
                viewModel.clearSelectedEvent()
            }
        } else {
            onDismissEventDetailWindow()
        }
    }

    private func dismissEventDetail() {
        viewModel.clearSelectedEvent()
        onDismissEventDetailWindow()
    }

    private var displayCalendar: Calendar {
        var calendar = Calendar.autoupdatingCurrent
        calendar.firstWeekday = settingsStore.menuBarPreferences.weekStart == .monday ? 2 : 1
        return calendar
    }

    private static func weekendColumnIndices(for calendar: Calendar) -> Set<Int> {
        let firstWeekday = calendar.firstWeekday
        let weekendDays = [1, 7]
        var indices = Set<Int>()
        for weekday in weekendDays {
            let adjustedIndex = (weekday - firstWeekday + 7) % 7
            indices.insert(adjustedIndex)
        }
        return indices
    }

    private var monthService: MonthCalendarService {
        MonthCalendarService(calendar: displayCalendar)
    }

    private var monthDays: [CalendarDay] {
        let factory = CalendarDayFactory(calendar: displayCalendar, registry: .live)
        return (try? factory.makeMonthGrid(
            for: viewModel.displayedMonth,
            preferences: settingsStore.menuBarPreferences,
            selectedDate: viewModel.selectedDate
        )) ?? monthService.makeMonthGrid(for: viewModel.displayedMonth)
    }
}
