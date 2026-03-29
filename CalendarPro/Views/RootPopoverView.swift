import SwiftUI
import EventKit

struct RootPopoverView: View {
    @ObservedObject var settingsStore: SettingsStore
    @StateObject private var viewModel = CalendarPopoverViewModel()
    @StateObject private var eventService = EventService()
    let onQuit: () -> Void
    
    @State private var eventsForSelectedDate: [EKEvent] = []
    @State private var isLoadingEvents: Bool = false
    
    var body: some View {
        CalendarPopoverView(
            displayedMonth: viewModel.displayedMonth,
            weekdaySymbols: viewModel.weekdaySymbols(using: displayCalendar),
            monthDays: monthDays,
            regionSummary: regionSummary,
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
            // 每次显示时重新检查授权状态
            eventService.checkAuthorizationStatus()
            if eventService.isAuthorized && settingsStore.menuBarPreferences.showEvents {
                eventService.fetchCalendars()
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
    
    private var regionSummary: String {
        let names = settingsStore.menuBarPreferences.activeRegionIDs.compactMap { regionID in
            HolidayProviderRegistry.live.provider(for: regionID)?.descriptor.displayName
        }
        
        if names.isEmpty {
            return "未启用地区节假日"
        }
        
        return "地区：\(names.joined(separator: "、"))"
    }
}