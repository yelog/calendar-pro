import SwiftUI
import EventKit

struct RootPopoverView: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var eventService: EventService
    @StateObject private var viewModel = CalendarPopoverViewModel()
    let onQuit: () -> Void
    
    @State private var itemsForSelectedDate: [CalendarItem] = []
    @State private var isLoadingEvents: Bool = false
    
    var body: some View {
        CalendarPopoverView(
            displayedMonth: viewModel.displayedMonth,
            weekdaySymbols: viewModel.weekdaySymbols(using: displayCalendar),
            monthDays: monthDays,
            showEvents: settingsStore.menuBarPreferences.showEvents && eventService.isAuthorized,
            selectedDate: viewModel.selectedDate,
            items: itemsForSelectedDate,
            selectedEvent: selectedEvent,
            isLoadingEvents: isLoadingEvents,
            onPreviousMonth: {
                viewModel.showPreviousMonth(using: displayCalendar)
            },
            onNextMonth: {
                viewModel.showNextMonth(using: displayCalendar)
            },
            onSelectDate: { date in
                viewModel.selectDate(date)
            },
            onSelectEvent: { event in
                let identifier = event.selectionIdentifier
                if viewModel.selectedEventIdentifier == identifier {
                    viewModel.clearSelectedEvent()
                } else {
                    viewModel.selectEvent(identifier: identifier)
                }
            },
            onDismissEventDetail: {
                viewModel.clearSelectedEvent()
            },
            onResetToToday: {
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
        .onChange(of: settingsStore.menuBarPreferences.showEvents) { _, _ in
            refreshEventsForCurrentSelection(selectingTodayIfNeeded: true)
        }
        .onChange(of: settingsStore.menuBarPreferences.enabledCalendarIDs) { _, _ in
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
            return
        }
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

    private var selectedEvent: EKEvent? {
        guard let selectedIdentifier = viewModel.selectedEventIdentifier else {
            return nil
        }
        for item in itemsForSelectedDate {
            if case .event(let event) = item, event.selectionIdentifier == selectedIdentifier {
                return event
            }
        }
        return nil
    }
}
