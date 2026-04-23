import SwiftUI
import EventKit

struct RootPopoverView: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var eventService: EventService
    @ObservedObject var viewModel: CalendarPopoverViewModel
    @ObservedObject var timeRefreshCoordinator: TimeRefreshCoordinator
    let onPresentEventDetailWindow: (EKEvent, @escaping () -> Void) -> Void
    let onPresentReminderDetailWindow: (EKReminder, @escaping (EKReminder) -> Void, @escaping () -> Void) -> Void
    let onPresentVacationGuide: (Date, @escaping (Date) -> Void) -> Void
    let onDismissEventDetailWindow: () -> Void
    let onQuit: () -> Void

    @State private var itemsForSelectedDate: [CalendarItem] = []
    @State private var isLoadingEvents: Bool = false
    @State private var almanacDescriptor: AlmanacDescriptor?
    @State private var weatherDescriptor: WeatherDescriptor?

    private let almanacService = AlmanacService()

    private var weatherService: WeatherService {
        WeatherService(manualLocation: settingsStore.menuBarPreferences.locationMode == .manual
            ? settingsStore.menuBarPreferences.manualLocation : nil)
    }

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
            timeRefreshCoordinator: timeRefreshCoordinator,
            almanac: almanacDescriptor,
            showAlmanac: settingsStore.menuBarPreferences.showAlmanac,
            weather: weatherDescriptor,
            showWeather: settingsStore.menuBarPreferences.showWeather,
            showVacationGuideButton: showVacationGuideButton,
            isVacationGuideEnabled: isVacationGuideEnabled,
            vacationGuideDisabledReason: vacationGuideDisabledReason,
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
            onOpenVacationGuide: {
                onPresentVacationGuide(viewModel.displayedMonth) { date in
                    dismissEventDetail()
                    viewModel.showMonth(containing: date, calendar: displayCalendar)
                    viewModel.selectDate(date)
                }
            },
            onResetToToday: {
                dismissEventDetail()
                viewModel.resetToToday()
                let today = timeRefreshCoordinator.currentDate
                viewModel.selectDate(today)
            },
            onQuit: onQuit
        )
        .onAppear {
            timeRefreshCoordinator.refreshNow()
            eventService.checkAuthorizationStatus()
            refreshEventsForCurrentSelection(selectingTodayIfNeeded: true)
            refreshInfoStrips()
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
        .onChange(of: settingsStore.menuBarPreferences.showWeather) { _, _ in
            refreshInfoStrips()
        }
    }

    private func refreshInfoStrips() {
        let date = viewModel.selectedDate ?? timeRefreshCoordinator.currentDate

        if settingsStore.menuBarPreferences.showAlmanac {
            almanacDescriptor = almanacService.describe(date: date)
        } else {
            almanacDescriptor = nil
        }

        if settingsStore.menuBarPreferences.showWeather {
            let requestedDate = date
            Task {
                let descriptor = await weatherService.describe(date: requestedDate, calendar: displayCalendar)
                await MainActor.run {
                    guard settingsStore.menuBarPreferences.showWeather else { return }
                    let currentSelectedDate = viewModel.selectedDate ?? timeRefreshCoordinator.currentDate
                    guard displayCalendar.isDate(currentSelectedDate, inSameDayAs: requestedDate) else { return }
                    weatherDescriptor = descriptor.hasContent ? descriptor : nil
                }
            }
        } else {
            weatherDescriptor = nil
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
            viewModel.selectDate(timeRefreshCoordinator.currentDate)
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

    private var showVacationGuideButton: Bool {
        LocaleFeatureAvailability.showVacationGuideFeatures
            && settingsStore.menuBarPreferences.activeRegionIDs.contains("mainland-cn")
    }

    private var isVacationGuideEnabled: Bool {
        showVacationGuideButton && isHolidaySetEnabled("statutory-holidays")
    }

    private var vacationGuideDisabledReason: String? {
        guard showVacationGuideButton, !isVacationGuideEnabled else {
            return nil
        }

        return "请先在地区设置中启用法定节假日"
    }

    private func isHolidaySetEnabled(_ holidaySetID: String) -> Bool {
        let enabledSetIDs = settingsStore.menuBarPreferences.enabledHolidayIDs
        return enabledSetIDs.isEmpty || enabledSetIDs.contains(holidaySetID)
    }

    private var monthDays: [CalendarDay] {
        let factory = CalendarDayFactory(
            calendar: displayCalendar,
            registry: .live,
            now: { timeRefreshCoordinator.currentDate }
        )
        return (try? factory.makeMonthGrid(
            for: viewModel.displayedMonth,
            preferences: settingsStore.menuBarPreferences,
            selectedDate: viewModel.selectedDate
        )) ?? monthService.makeMonthGrid(for: viewModel.displayedMonth)
    }
}
