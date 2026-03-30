import SwiftUI
import EventKit

struct RootPopoverView: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var eventService: EventService
    @StateObject private var viewModel = CalendarPopoverViewModel()
    let onQuit: () -> Void
    
    @State private var eventsForSelectedDate: [EKEvent] = []
    @State private var isLoadingEvents: Bool = false
    
    var body: some View {
        CalendarPopoverView(
            displayedMonth: viewModel.displayedMonth,
            weekdaySymbols: viewModel.weekdaySymbols(using: displayCalendar),
            monthDays: monthDays,
            showEvents: settingsStore.menuBarPreferences.showEvents && eventService.isAuthorized,
            selectedDate: viewModel.selectedDate,
            events: eventsForSelectedDate,
            isLoadingEvents: isLoadingEvents,
            onPreviousMonth: {
                viewModel.showPreviousMonth(using: displayCalendar)
            },
            onNextMonth: {
                viewModel.showNextMonth(using: displayCalendar)
            },
            onSelectDate: { date in
                viewModel.selectDate(date)
                loadEvents(for: date)
            },
            onResetToToday: {
                viewModel.resetToToday()
                viewModel.clearSelectedDate()
            },
            onQuit: onQuit
        )
        .onAppear {
            eventService.checkAuthorizationStatus()
            if eventService.isAuthorized && settingsStore.menuBarPreferences.showEvents {
                eventService.fetchCalendars()
                let today = Date()
                viewModel.selectDate(today)
                loadEvents(for: today)
            }
        }
        .onChange(of: eventService.isAuthorized) { _, isAuthorized in
            if isAuthorized && settingsStore.menuBarPreferences.showEvents {
                eventService.fetchCalendars()
                let today = Date()
                viewModel.selectDate(today)
                loadEvents(for: today)
            }
        }
        .onChange(of: viewModel.selectedDate) { _, newDate in
            if let date = newDate {
                loadEvents(for: date)
            }
        }
    }
    
    private func loadEvents(for date: Date) {
        guard settingsStore.menuBarPreferences.showEvents else {
            eventsForSelectedDate = []
            return
        }
        
        isLoadingEvents = true
        Task {
            let events = eventService.fetchEvents(for: date)
            let filtered = filterEventsByEnabledCalendars(events)
            await MainActor.run {
                eventsForSelectedDate = filtered
                isLoadingEvents = false
            }
        }
    }
    
    private func filterEventsByEnabledCalendars(_ events: [EKEvent]) -> [EKEvent] {
        let enabledIDs = settingsStore.menuBarPreferences.enabledCalendarIDs
        if enabledIDs.isEmpty {
            return events
        }
        return events.filter { enabledIDs.contains($0.calendar.calendarIdentifier) }
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