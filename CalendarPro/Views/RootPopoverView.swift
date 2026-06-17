import Combine
import SwiftUI
import EventKit
import AppKit

struct RootPopoverView: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var eventService: EventService
    @ObservedObject var viewModel: CalendarPopoverViewModel
    @ObservedObject var timeRefreshCoordinator: TimeRefreshCoordinator
    @ObservedObject var pomodoroTimer: PomodoroTimerController
    let onPresentEventDetailWindow: (
        EKEvent,
        @escaping (EKEvent) -> Void,
        @escaping (EKEvent) -> Void,
        @escaping () -> Void
    ) -> Void
    let onPresentReminderDetailWindow: (
        EKReminder,
        @escaping (EKReminder) -> Void,
        @escaping (EKReminder) -> Void,
        @escaping (EKReminder) -> Void,
        @escaping () -> Void
    ) -> Void
    let onPresentItemComposer: (
        CalendarItemCreationKind,
        Date,
        [EKCalendar],
        [EKCalendar],
        @escaping (CalendarEventCreationRequest) throws -> Void,
        @escaping (ReminderCreationRequest) throws -> Void,
        @escaping () -> Void
    ) -> Void
    let onPresentItemEditor: (
        CalendarItemComposerMode,
        [EKCalendar],
        [EKCalendar],
        @escaping (CalendarEventCreationRequest) throws -> Void,
        @escaping (ReminderCreationRequest) throws -> Void,
        @escaping () -> Void
    ) -> Void
    let onPresentVacationGuide: (Date, @escaping (Date) -> Void) -> Void
    let onDismissEventDetailWindow: () -> Void
    let onQuit: () -> Void

    @State private var itemsForSelectedDate: [CalendarItem] = []
    @State private var isLoadingEvents: Bool = false
    @State private var almanacDescriptor: AlmanacDescriptor?
    @State private var weatherDescriptor: WeatherDescriptor?
    @State private var isLoadingWeather: Bool = false
    @State private var weatherService = WeatherService(locationResolver: CoreLocationWeatherLocationResolver())
    @State private var weatherTask: Task<Void, Never>?
    @State private var weatherRequestID = UUID()
    @State private var lastWeatherRefreshTime: Date?
    @State private var lastWeatherRequestedDate: Date?

    private let almanacService = AlmanacService()
    private let weatherAutoRefreshInterval: TimeInterval = 15 * 60

    var body: some View {
        popoverContent
            .onAppear {
                timeRefreshCoordinator.refreshNow()
                eventService.checkAuthorizationStatus()
                refreshEventsForCurrentSelection(selectingTodayIfNeeded: true)
                refreshInfoStrips()
            }
            .onReceive(eventService.$isAuthorized.dropFirst()) { _ in
                refreshEventsForCurrentSelection(selectingTodayIfNeeded: true)
            }
            .onReceive(eventService.$remindersAuthorized.dropFirst()) { isAuthorized in
                if isAuthorized {
                    eventService.fetchReminderCalendars()
                }
                refreshEventsForCurrentSelection()
            }
            .onReceive(settingsStore.$menuBarPreferences.dropFirst()) { _ in
                refreshEventsForCurrentSelection(selectingTodayIfNeeded: true)
                refreshInfoStrips()
            }
            .onReceive(eventService.$storeChangeRevision.dropFirst()) { _ in
                refreshEventsForCurrentSelection()
            }
            .onReceive(viewModel.$selectedDate.dropFirst()) { newDate in
                if let date = newDate {
                    loadEvents(for: date)
                    refreshInfoStrips()
                } else {
                    clearLoadedEvents()
                }
            }
            .onReceive(settingsStore.$qWeatherAPIKey.dropFirst()) { _ in
                refreshInfoStrips()
            }
            .onReceive(timeRefreshCoordinator.$currentDate) { currentDate in
                guard shouldAutoRefreshWeather(at: currentDate) else { return }
                refreshWeather(for: viewModel.selectedDate ?? currentDate)
            }
            .onReceive(timeRefreshCoordinator.$dayChangeRevision.dropFirst()) { _ in
                viewModel.syncCurrentDaySelectionIfNeeded(calendar: displayCalendar)
                refreshEventsForCurrentSelection(selectingTodayIfNeeded: true)
                refreshInfoStrips()
            }
            .onDisappear {
                weatherTask?.cancel()
            }
    }

    private var popoverContent: some View {
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
            isLoadingWeather: isLoadingWeather,
            showWeather: settingsStore.menuBarPreferences.showWeather,
            pomodoroState: pomodoroTimer.state,
            pomodoroPreferences: settingsStore.pomodoroPreferences,
            showVacationGuideButton: showVacationGuideButton,
            isVacationGuideEnabled: isVacationGuideEnabled,
            vacationGuideDisabledReason: vacationGuideDisabledReason,
            canCreateEvent: canCreateEvent,
            canCreateReminder: canCreateReminder,
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
            onSelectDate: handleDateSelection,
            onSelectEvent: { event in
                handleEventSelection(event)
            },
            onToggleReminder: { reminder in
                handleToggleReminder(reminder)
            },
            onOpenReminder: { reminder in
                handleOpenReminder(reminder)
            },
            onCreateItem: {
                handleCreateItem()
            },
            onOpenVacationGuide: handleOpenVacationGuide,
            onResetToToday: handleResetToToday,
            onStartPomodoroFocus: {
                pomodoroTimer.startFocus()
            },
            onPausePomodoro: {
                pomodoroTimer.pause()
            },
            onResumePomodoro: {
                pomodoroTimer.resume()
            },
            onSkipPomodoro: {
                pomodoroTimer.skip()
            },
            onEndPomodoro: {
                pomodoroTimer.end()
            },
            onQuit: onQuit
        )
    }

    private func handleDateSelection(_ date: Date) {
        dismissEventDetail()
        viewModel.selectDate(date)
    }

    private func handleOpenVacationGuide() {
        onPresentVacationGuide(viewModel.displayedMonth) { date in
            dismissEventDetail()
            viewModel.showMonth(containing: date, calendar: displayCalendar)
            viewModel.selectDate(date)
        }
    }

    private func handleResetToToday() {
        dismissEventDetail()
        viewModel.resetToToday()
        viewModel.selectDate(timeRefreshCoordinator.currentDate, followsCurrentDay: true)
    }

    private func refreshInfoStrips() {
        let date = viewModel.selectedDate ?? timeRefreshCoordinator.currentDate

        if settingsStore.menuBarPreferences.showAlmanac {
            almanacDescriptor = almanacService.describe(date: date)
        } else {
            almanacDescriptor = nil
        }

        refreshWeather(for: date)
    }

    private func refreshWeather(for date: Date) {
        guard settingsStore.menuBarPreferences.showWeather else {
            clearWeather()
            return
        }

        let expectedLocation = preferredWeatherLocation
        let expectedProviderConfiguration = settingsStore.weatherProviderConfiguration()
        if weatherService.manualLocation != expectedLocation
            || weatherService.providerConfiguration != expectedProviderConfiguration {
            weatherTask?.cancel()
            weatherService = WeatherService(
                manualLocation: expectedLocation,
                providerConfiguration: expectedProviderConfiguration,
                locationResolver: CoreLocationWeatherLocationResolver()
            )
        }

        weatherTask?.cancel()
        weatherDescriptor = nil
        isLoadingWeather = true
        lastWeatherRefreshTime = timeRefreshCoordinator.currentDate
        lastWeatherRequestedDate = date

        let requestID = UUID()
        weatherRequestID = requestID
        let requestedDate = date
        let requestedCalendar = displayCalendar
        let service = weatherService

        weatherTask = Task {
            let descriptor = await service.describe(date: requestedDate, calendar: requestedCalendar)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard weatherRequestID == requestID else { return }
                guard settingsStore.menuBarPreferences.showWeather else {
                    clearWeather()
                    return
                }
                guard weatherService.manualLocation == expectedLocation else { return }
                guard weatherService.providerConfiguration == expectedProviderConfiguration else { return }

                let currentSelectedDate = viewModel.selectedDate ?? timeRefreshCoordinator.currentDate
                guard requestedCalendar.isDate(currentSelectedDate, inSameDayAs: requestedDate) else { return }

                weatherDescriptor = descriptor.hasContent ? descriptor : nil
                isLoadingWeather = false
                weatherTask = nil
            }
        }
    }

    private func clearWeather() {
        weatherTask?.cancel()
        weatherTask = nil
        weatherRequestID = UUID()
        weatherDescriptor = nil
        isLoadingWeather = false
        lastWeatherRefreshTime = nil
        lastWeatherRequestedDate = nil
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
            viewModel.selectDate(timeRefreshCoordinator.currentDate, followsCurrentDay: true)
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
            onPresentEventDetailWindow(
                event,
                { event in
                    handleEditEvent(event)
                },
                { event in
                    handleDeleteEvent(event)
                },
                {
                    viewModel.clearSelectedEvent()
                }
            )
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
            onPresentReminderDetailWindow(
                reminder,
                { [weak eventService] toggledReminder in
                    do {
                        try eventService?.toggleReminderCompletion(toggledReminder)
                    } catch {
                        print("Failed to toggle reminder completion: \(error)")
                    }
                },
                { reminder in
                    handleEditReminder(reminder)
                },
                { reminder in
                    handleDeleteReminder(reminder)
                },
                {
                    viewModel.clearSelectedEvent()
                }
            )
        } else {
            onDismissEventDetailWindow()
        }
    }

    private func handleEditEvent(_ event: EKEvent) {
        guard event.calendar.allowsContentModifications else { return }

        if eventService.isAuthorized {
            eventService.fetchCalendars()
        }
        if eventService.remindersAuthorized {
            eventService.fetchReminderCalendars()
        }

        onPresentItemEditor(
            .editEvent(event),
            eventService.writableCalendars,
            eventService.writableReminderCalendars,
            { request in
                try eventService.updateEvent(event, with: request)
                refreshEventsForCurrentSelection()
            },
            { _ in },
            {
                viewModel.clearSelectedEvent()
            }
        )
    }

    private func handleEditReminder(_ reminder: EKReminder) {
        guard reminder.calendar.allowsContentModifications else { return }

        if eventService.isAuthorized {
            eventService.fetchCalendars()
        }
        if eventService.remindersAuthorized {
            eventService.fetchReminderCalendars()
        }

        onPresentItemEditor(
            .editReminder(reminder),
            eventService.writableCalendars,
            eventService.writableReminderCalendars,
            { _ in },
            { request in
                try eventService.updateReminder(reminder, with: request)
                refreshEventsForCurrentSelection()
            },
            {
                viewModel.clearSelectedEvent()
            }
        )
    }

    private func handleDeleteEvent(_ event: EKEvent) {
        do {
            try eventService.deleteEvent(event)
            dismissEventDetail()
            refreshEventsForCurrentSelection()
        } catch {
            presentDeletionError(title: L("Failed to Delete Event"), error: error)
        }
    }

    private func handleDeleteReminder(_ reminder: EKReminder) {
        do {
            try eventService.deleteReminder(reminder)
            dismissEventDetail()
            refreshEventsForCurrentSelection()
        } catch {
            presentDeletionError(title: L("Failed to Delete Reminder"), error: error)
        }
    }

    private func presentDeletionError(title: String, error: Error) {
        let alert = NSAlert(error: error)
        alert.messageText = title
        alert.runModal()
    }

    private func handleCreateItem() {
        guard let selectedDate = viewModel.selectedDate else { return }
        let initialKind: CalendarItemCreationKind = canCreateEvent ? .event : .reminder

        dismissEventDetail()
        if eventService.isAuthorized {
            eventService.fetchCalendars()
        }
        if eventService.remindersAuthorized {
            eventService.fetchReminderCalendars()
        }

        onPresentItemComposer(
            initialKind,
            selectedDate,
            eventService.writableCalendars,
            eventService.writableReminderCalendars,
            { request in
                _ = try eventService.createEvent(request)
                refreshEventsForCurrentSelection()
            },
            { request in
                _ = try eventService.createReminder(request)
                refreshEventsForCurrentSelection()
            },
            {
                viewModel.clearSelectedEvent()
            }
        )
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

    private var preferredWeatherLocation: WeatherLocation? {
        settingsStore.menuBarPreferences.locationMode == .manual
            ? settingsStore.menuBarPreferences.manualLocation
            : nil
    }

    private var canCreateEvent: Bool {
        settingsStore.menuBarPreferences.showEvents
            && settingsStore.menuBarPreferences.showCalendarEvents
            && eventService.isAuthorized
            && !eventService.writableCalendars.isEmpty
    }

    private var canCreateReminder: Bool {
        settingsStore.menuBarPreferences.showEvents
            && settingsStore.menuBarPreferences.showReminders
            && eventService.remindersAuthorized
            && !eventService.writableReminderCalendars.isEmpty
    }

    private func shouldAutoRefreshWeather(at currentDate: Date) -> Bool {
        guard settingsStore.menuBarPreferences.showWeather else { return false }
        guard weatherTask == nil else { return false }

        if let selectedDate = viewModel.selectedDate,
           let lastRequestedDate = lastWeatherRequestedDate,
           !displayCalendar.isDate(selectedDate, inSameDayAs: lastRequestedDate) {
            return false
        }

        guard let lastWeatherRefreshTime else { return true }
        return currentDate.timeIntervalSince(lastWeatherRefreshTime) >= weatherAutoRefreshInterval
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
