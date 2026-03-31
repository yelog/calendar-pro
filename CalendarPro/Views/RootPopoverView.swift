import SwiftUI
import EventKit

struct RootPopoverView: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var eventService: EventService
    @StateObject private var viewModel = CalendarPopoverViewModel()
    let onPresentEventDetailWindow: (EKEvent, @escaping () -> Void) -> Void
    let onDismissEventDetailWindow: () -> Void
    let onQuit: () -> Void

    @State private var itemsForSelectedDate: [CalendarItem] = []
    @State private var isLoadingEvents: Bool = false

    var body: some View {
        CalendarPopoverView(
            displayedMonth: viewModel.displayedMonth,
            displayedYear: viewModel.displayedYear,
            displayedMonthNumber: viewModel.displayedMonthNumber,
            currentYear: viewModel.currentYear,
            currentMonthNumber: viewModel.currentMonthNumber,
            selectionMode: viewModel.selectionMode,
            weekdaySymbols: viewModel.weekdaySymbols(using: displayCalendar),
            monthDays: monthDays,
            showEvents: settingsStore.menuBarPreferences.showEvents && eventService.isAuthorized,
            selectedDate: viewModel.selectedDate,
            items: itemsForSelectedDate,
            selectedEventIdentifier: viewModel.selectedEventIdentifier,
            isLoadingEvents: isLoadingEvents,
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
            eventService.checkAuthorizationStatus()
            refreshEventsForCurrentSelection(selectingTodayIfNeeded: true)
        }
        .onChange(of: eventService.isAuthorized) { _, isAuthorized in
            if isAuthorized {
                refreshEventsForCurrentSelection(selectingTodayIfNeeded: true)
            } else {
                clearLoadedEvents()
            }
        }
        .onChange(of: eventService.remindersAuthorized) { _, isAuthorized in
            if isAuthorized {
                eventService.fetchReminderCalendars()
                refreshEventsForCurrentSelection()
            }
        }
        .onChange(of: settingsStore.menuBarPreferences.showEvents) { _, _ in
            refreshEventsForCurrentSelection(selectingTodayIfNeeded: true)
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
            } else {
                clearLoadedEvents()
            }
        }
    }

    private func loadEvents(for date: Date) {
        guard settingsStore.menuBarPreferences.showEvents, eventService.isAuthorized else {
            clearLoadedEvents()
            return
        }

        eventService.fetchCalendars()
        if eventService.remindersAuthorized {
            eventService.fetchReminderCalendars()
        }

        isLoadingEvents = true
        let requestedDate = date
        Task {
            let items = await eventService.fetchCalendarItems(
                for: date,
                enabledCalendarIDs: settingsStore.menuBarPreferences.enabledCalendarIDs,
                enabledReminderCalendarIDs: settingsStore.menuBarPreferences.enabledReminderCalendarIDs,
                showReminders: settingsStore.menuBarPreferences.showReminders
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
        guard settingsStore.menuBarPreferences.showEvents, eventService.isAuthorized else {
            clearLoadedEvents()
            return
        }

        eventService.fetchCalendars()

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
            if case .event(let event) = item {
                return event.selectionIdentifier == selectedIdentifier
            }
            return false
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
        guard let url = item.remindersAppURL else {
            // Fallback: open Reminders.app without navigating to a specific item
            if let fallback = URL(string: "x-apple-reminderkit://") {
                NSWorkspace.shared.open(fallback)
            }
            return
        }
        NSWorkspace.shared.open(url)
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