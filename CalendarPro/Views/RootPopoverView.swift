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
    @ObservedObject var pomodoroStatsStore: PomodoroStatsStore
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
        CalendarItemCreationTimeRange?,
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
    let onPresentWeatherDetailWindow: (WeatherForecastOverview, @escaping () -> Void) -> Void
    let onPresentPomodoroStatisticsWindow: (@escaping () -> Void) -> Void
    let onDismissEventDetailWindow: () -> Void
    let onDismissWeatherDetailWindow: () -> Void
    let onDismissPomodoroStatisticsWindow: () -> Void
    let onQuit: () -> Void

    @State private var itemsForSelectedDate: [CalendarItem] = []
    @State private var isLoadingEvents: Bool = false
    @State private var eventsRequestID = UUID()
    @State private var boardReminders: [EKReminder] = []
    @State private var upcomingItems: [CalendarItem] = []
    @State private var isLoadingUpcomingPast: Bool = false
    @State private var isLoadingUpcomingFuture: Bool = false
    // Count-based paging cursors: the future cursor is the next window start
    // (advancing up from today's midnight), the past cursor the next window
    // upper bound (advancing down); nil = that direction's end is proven
    // (user limit / empty window / loop cap). Reset to page one on every
    // popover presentation.
    @State private var upcomingFutureCursor: Date?
    @State private var upcomingPastCursor: Date?
    // Bumped on every pagination reset; the section scrolls back to its top
    // anchor because data resets leave stale scroll offsets behind
    @State private var upcomingResetGeneration: Int = 0
    // Per-direction race IDs: each entry bumps its own and each completion
    // block validates and resets only its own direction, so a concurrent
    // past load and future load never cancel each other; reset/clear bumps
    // both IDs to invalidate everything in flight
    @State private var upcomingPastRequestID = UUID()
    @State private var upcomingFutureRequestID = UUID()
    // Per-direction page-full resume flags: set when the last assembly
    // ended page-full (not exhausted), so the next load re-queries the same
    // window and a resume window yielding nothing new is not the past end;
    // completion blocks write these back, reset/clear returns false
    @State private var isUpcomingPastResumingWindow = false
    @State private var isUpcomingFutureResumingWindow = false
    @State private var almanacDescriptor: AlmanacDescriptor?
    @State private var weatherDescriptor: WeatherDescriptor?
    @State private var isLoadingWeather: Bool = false
    @State private var weatherService = WeatherService(locationResolver: CoreLocationWeatherLocationResolver())
    @State private var weatherTask: Task<Void, Never>?
    @State private var weatherDetailTask: Task<Void, Never>?
    @State private var weatherRequestID = UUID()
    @State private var weatherDetailRequestID = UUID()
    @State private var boardRetentionRefreshTask: Task<Void, Never>?
    @State private var lastWeatherRefreshTime: Date?
    @State private var lastWeatherRequestedDate: Date?
    @State private var isLoadingWeatherDetails = false
    @State private var isWeatherDetailPresented = false
    @State private var isPomodoroStatisticsPresented = false

    private let almanacService = AlmanacService()
    private let weatherAutoRefreshInterval: TimeInterval = 15 * 60

    /// Count-based paging constants: page size, query window span and the
    /// per-page window loop cap. Page one takes 10 items from today's
    /// midnight (all-day events included); pages fill through 30-day window
    /// loops bounded by the user limit (future) or an empty window (past).
    static let upcomingPageSize = 10
    static let upcomingPageWindowDays = 30
    static let upcomingPageMaxWindows = 12

    enum UpcomingPageDirection {
        case past
        case future
    }

    /// Pure data output of one window slice (unit-testable).
    struct UpcomingPageWindowSlice {
        // Freshly taken items (loaded identities removed), stored ascending;
        // display order is UpcomingSnapshot's job
        let takenItems: [CalendarItem]
        // In-range item count before dedup, for the past empty-window check:
        // all-duplicates only means a recurring reminder repeats across
        // windows, not history's end
        let inRangeItemCount: Int
        let isPageFull: Bool
    }

    /// One paging step over an EventKit window result (pure, nonisolated for
    /// unit tests): filters to the half-open [windowStart, windowEnd), drops
    /// loaded identities, takes up to the remaining page size (future takes
    /// the earliest batch, past the most recent; both ascending) and returns
    /// the next cursor plus exhaustion. Cursor semantics live in the
    /// page-full and end branches below.
    nonisolated static func advanceUpcomingPage(
        direction: UpcomingPageDirection,
        windowItems: [CalendarItem],
        windowStart: Date,
        windowEnd: Date,
        collectedCount: Int,
        loadedIdentifiers: Set<String>,
        pageSize: Int,
        futureLimitEnd: Date?,
        isResumingWindow: Bool
    ) -> (slice: UpcomingPageWindowSlice, nextWindowStart: Date?, isExhausted: Bool) {
        // Re-check the range and drop loaded identities: page-full resumes
        // and same-instant page boundaries both dedupe on the identity set
        let inRangeItems = windowItems.filter { item in
            guard let startDate = item.startDate else { return false }
            return startDate >= windowStart && startDate < windowEnd
        }
        let freshItems = inRangeItems.filter {
            !loadedIdentifiers.contains($0.selectionIdentifier)
        }
        let remaining = pageSize - collectedCount
        let takeCount = max(0, min(remaining, freshItems.count))
        // Future takes the earliest batch (ascending head); past takes the
        // batch nearest the cursor (ascending tail). Both store ascending.
        let taken: [CalendarItem]
        switch direction {
        case .future:
            taken = Array(freshItems.prefix(takeCount))
        case .past:
            taken = Array(freshItems.suffix(takeCount))
        }
        let slice = UpcomingPageWindowSlice(
            takenItems: taken,
            inRangeItemCount: inRangeItems.count,
            isPageFull: collectedCount + taken.count >= pageSize
        )

        // Page-full: keep the cursor inside the window so the next page
        // resumes it. Future resumes at windowStart; past must resume at
        // windowEnd — rewinding to windowStart would skip this window's
        // leftovers and the next (empty) window would misread history's end
        if slice.isPageFull {
            let resumeCursor = direction == .past ? windowEnd : windowStart
            return (slice, resumeCursor, false)
        }

        switch direction {
        case .future:
            // Reaching the user limit at the window end means exhausted; an
            // empty window is not, the per-page window cap bounds the loop
            if let futureLimitEnd, windowEnd >= futureLimitEnd {
                return (slice, nil, true)
            }
            return (slice, windowEnd, false)
        case .past:
            // An empty past window means the historical start; a resume
            // window, or one holding only recurring-reminder repeats, keeps
            // going
            if inRangeItems.isEmpty, !isResumingWindow {
                return (slice, nil, true)
            }
            return (slice, windowStart, false)
        }
    }

    var body: some View {
        popoverContent
            .onAppear {
                timeRefreshCoordinator.refreshNow()
                eventService.checkAuthorizationStatus()
                refreshEventsForCurrentSelection(selectingTodayIfNeeded: true)
                // First-open first page load; popover reopen resets arrive via
                // the presentation generation channel below instead, because
                // onAppear does not re-fire reliably on reused popovers
                resetUpcomingPaginationAndLoadFirstPage()
                refreshInfoStrips()
                loadBoard()
            }
            .onChange(of: viewModel.popoverPresentationGeneration) { _, _ in
                // Explicit reopen channel: PopoverController bumps the
                // generation on every show; the reused content view never
                // re-fires onAppear, so resets hang off this change
                resetUpcomingPaginationAndLoadFirstPage()
            }
            .onReceive(eventService.$isAuthorized.dropFirst()) { _ in
                refreshEventsForCurrentSelection(selectingTodayIfNeeded: true)
                resetUpcomingPaginationAndLoadFirstPage()
            }
            .onReceive(eventService.$remindersAuthorized.dropFirst()) { isAuthorized in
                if isAuthorized {
                    eventService.fetchReminderCalendars()
                }
                refreshEventsForCurrentSelection()
                loadBoard()
                resetUpcomingPaginationAndLoadFirstPage()
            }
            .onChange(of: settingsStore.menuBarPreferences) { _, _ in
                refreshEventsForCurrentSelection(selectingTodayIfNeeded: true)
                resetUpcomingPaginationAndLoadFirstPage()
                refreshInfoStrips()
                loadBoard()
            }
            .onReceive(eventService.$storeChangeRevision.dropFirst()) { _ in
                refreshEventsForCurrentSelection()
                loadBoard()
                resetUpcomingPaginationAndLoadFirstPage()
            }
            .onReceive(viewModel.$selectedDate.dropFirst()) { newDate in
                if let date = newDate {
                    loadEvents(for: date)
                    refreshInfoStrips()
                } else {
                    clearLoadedEvents()
                }
                // Upcoming content is date-independent; paging does not
                // reset on selection changes
            }
            .onReceive(timeRefreshCoordinator.$currentDate) { currentDate in
                guard shouldAutoRefreshWeather(at: currentDate) else { return }
                refreshWeather(for: viewModel.selectedDate ?? currentDate)
            }
            .onReceive(timeRefreshCoordinator.$dayChangeRevision.dropFirst()) { _ in
                viewModel.syncCurrentDaySelectionIfNeeded(calendar: displayCalendar)
                refreshEventsForCurrentSelection(selectingTodayIfNeeded: true)
                // The paging base (today's midnight) moved with the day
                // change; start over from page one
                resetUpcomingPaginationAndLoadFirstPage()
                refreshInfoStrips()
                // Day change: overdue colors and due texts must be recomputed.
                loadBoard()
            }
            .onDisappear {
                cancelWeatherLoad()
                dismissWeatherDetail()
                dismissPomodoroStatistics()
            }
    }

    private var popoverContent: some View {
        let displayedMonthDays = monthDays
        let selectedDateSummary = makeSelectedDateSummary(visibleDays: displayedMonthDays)

        return CalendarPopoverView(
            displayedMonth: viewModel.displayedMonth,
            displayedYear: viewModel.displayedYear,
            displayedMonthNumber: viewModel.displayedMonthNumber,
            currentYear: viewModel.currentYear,
            currentMonthNumber: viewModel.currentMonthNumber,
            selectionMode: viewModel.selectionMode,
            weekdaySymbols: viewModel.weekdaySymbols(using: displayCalendar),
            weekendIndices: Self.weekendColumnIndices(for: displayCalendar),
            monthDays: displayedMonthDays,
            highlightWeekends: settingsStore.menuBarPreferences.highlightWeekends,
            showEvents: settingsStore.menuBarPreferences.showEvents,
            emptyStateText: settingsStore.menuBarPreferences.eventListEmptyStateText,
            showUpcomingSection: settingsStore.menuBarPreferences.showUpcomingSection,
            eventListMode: settingsStore.menuBarPreferences.effectiveEventListMode,
            upcomingItems: upcomingItems,
            isLoadingUpcomingPast: isLoadingUpcomingPast,
            isLoadingUpcomingFuture: isLoadingUpcomingFuture,
            hasMoreUpcomingPast: upcomingPastCursor != nil,
            hasMoreUpcomingFuture: upcomingFutureCursor != nil,
            upcomingResetGeneration: upcomingResetGeneration,
            selectedDate: viewModel.selectedDate,
            items: itemsForSelectedDate,
            selectedEventIdentifier: viewModel.selectedEventIdentifier,
            isLoadingEvents: isLoadingEvents,
            timeRefreshCoordinator: timeRefreshCoordinator,
            selectedDateSummary: selectedDateSummary,
            almanac: almanacDescriptor,
            showAlmanac: settingsStore.menuBarPreferences.showAlmanac,
            weather: weatherDescriptor,
            isLoadingWeather: isLoadingWeather,
            showWeather: settingsStore.menuBarPreferences.showWeather,
            isWeatherDetailPresented: isWeatherDetailPresented,
            isLoadingWeatherDetails: isLoadingWeatherDetails,
            pomodoroState: pomodoroTimer.state,
            pomodoroPreferences: settingsStore.pomodoroPreferences,
            showVacationGuideButton: showVacationGuideButton,
            isVacationGuideEnabled: isVacationGuideEnabled,
            vacationGuideDisabledReason: vacationGuideDisabledReason,
            showRemindersBoard: settingsStore.menuBarPreferences.showRemindersBoard,
            boardReminders: boardReminders,
            boardGroupingMode: settingsStore.menuBarPreferences.boardGroupingMode,
            boardColorMode: settingsStore.menuBarPreferences.boardColorMode,
            boardColorPreferences: settingsStore.menuBarPreferences.boardColorPreferences,
            boardShowCompleted: settingsStore.menuBarPreferences.boardShowCompleted,
            boardCompletedRetentionSeconds:
                settingsStore.menuBarPreferences.boardCompletedRetentionSeconds,
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
            onCreateEventAt: { timeRange in
                handleCreateItem(initialTimeRange: timeRange)
            },
            onSelectEventListMode: { mode in
                dismissEventDetail()
                settingsStore.setEventListMode(mode)
            },
            onLoadMoreUpcomingPast: handleLoadMoreUpcomingPast,
            onLoadMoreUpcomingFuture: handleLoadMoreUpcomingFuture,
            onOpenWeatherDetails: handleOpenWeatherDetails,
            onOpenVacationGuide: handleOpenVacationGuide,
            onResetToToday: handleResetToToday,
            onOpenPomodoroStatistics: handleOpenPomodoroStatistics,
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
            dismissWeatherDetail()
            cancelWeatherLoad()
            weatherService = WeatherService(
                manualLocation: expectedLocation,
                providerConfiguration: expectedProviderConfiguration,
                locationResolver: CoreLocationWeatherLocationResolver()
            )
        }

        cancelWeatherLoad()
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
        cancelWeatherLoad()
        dismissWeatherDetail()
        weatherDescriptor = nil
        lastWeatherRefreshTime = nil
        lastWeatherRequestedDate = nil
    }

    private func cancelWeatherLoad() {
        weatherTask?.cancel()
        weatherTask = nil
        weatherService.cancelInFlightSnapshot()
        weatherRequestID = UUID()
        isLoadingWeather = false
    }

    private func handleOpenWeatherDetails() {
        guard settingsStore.menuBarPreferences.showWeather else { return }
        guard weatherDescriptor?.hasContent == true else { return }

        if isWeatherDetailPresented {
            dismissWeatherDetail()
            return
        }

        dismissEventDetail()
        loadWeatherDetails()
    }

    private func handleOpenPomodoroStatistics() {
        if isPomodoroStatisticsPresented {
            dismissPomodoroStatistics()
            return
        }

        dismissEventDetail()
        dismissWeatherDetail()
        isPomodoroStatisticsPresented = true
        onPresentPomodoroStatisticsWindow {
            isPomodoroStatisticsPresented = false
        }
    }

    private func dismissPomodoroStatistics() {
        isPomodoroStatisticsPresented = false
        onDismissPomodoroStatisticsWindow()
    }

    private func loadWeatherDetails() {
        guard !isLoadingWeatherDetails else { return }

        let expectedLocation = preferredWeatherLocation
        let expectedProviderConfiguration = settingsStore.weatherProviderConfiguration()
        let requestID = UUID()
        let requestedCalendar = displayCalendar
        let service = weatherService

        weatherDetailRequestID = requestID
        isLoadingWeatherDetails = true
        weatherDetailTask?.cancel()
        weatherDetailTask = Task {
            let overview = await service.forecastOverview(days: 10, calendar: requestedCalendar)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard weatherDetailRequestID == requestID else { return }
                guard settingsStore.menuBarPreferences.showWeather else {
                    dismissWeatherDetail()
                    return
                }
                guard weatherService.manualLocation == expectedLocation else { return }
                guard weatherService.providerConfiguration == expectedProviderConfiguration else { return }

                isLoadingWeatherDetails = false
                weatherDetailTask = nil

                guard overview.hasContent else { return }
                isWeatherDetailPresented = true
                onPresentWeatherDetailWindow(overview) {
                    isWeatherDetailPresented = false
                }
            }
        }
    }

    private func dismissWeatherDetail() {
        weatherDetailTask?.cancel()
        weatherDetailTask = nil
        weatherDetailRequestID = UUID()
        isLoadingWeatherDetails = false
        isWeatherDetailPresented = false
        onDismissWeatherDetailWindow()
    }

    private func loadEvents(for date: Date) {
        let preferences = settingsStore.menuBarPreferences

        guard preferences.effectiveEventListMode == .day else {
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
        let requestID = UUID()
        eventsRequestID = requestID
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
                guard eventsRequestID == requestID,
                      settingsStore.menuBarPreferences.effectiveEventListMode == .day else { return }
                guard viewModel.selectedDate == requestedDate else { return }
                itemsForSelectedDate = items
                syncSelectedEvent(with: items)
                isLoadingEvents = false
            }
        }
    }

    private func refreshEventsForCurrentSelection(selectingTodayIfNeeded: Bool = false) {
        let preferences = settingsStore.menuBarPreferences

        guard preferences.effectiveEventListMode == .day else {
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
        eventsRequestID = UUID()
        itemsForSelectedDate = []
        isLoadingEvents = false
        viewModel.clearSelectedEvent()
        onDismissEventDetailWindow()
    }

    /// Resets pagination and loads page one: clears loaded items, returns
    /// both cursors to today's midnight, bumps the reset generation and
    /// loads the first future page (10 items, today's all-day included).
    /// Fired by the popover presentation generation (onAppear as the
    /// first-open fallback) and by authorization, settings, store and
    /// day-change refreshes so data changes restart from page one.
    private func resetUpcomingPaginationAndLoadFirstPage() {
        let preferences = settingsStore.menuBarPreferences

        guard preferences.effectiveEventListMode == .overview else {
            clearLoadedUpcoming()
            return
        }

        if eventService.isAuthorized {
            eventService.fetchCalendars()
        }

        if eventService.remindersAuthorized {
            eventService.fetchReminderCalendars()
        }

        // Reset before loading: bumping both request IDs invalidates
        // in-flight loads, stale results dropped by each direction's race
        // guard; resume flags return false since page one is never a resume
        upcomingPastRequestID = UUID()
        upcomingFutureRequestID = UUID()
        isUpcomingPastResumingWindow = false
        isUpcomingFutureResumingWindow = false
        upcomingItems = []
        isLoadingUpcomingPast = false
        isLoadingUpcomingFuture = false
        upcomingFutureCursor = displayCalendar.startOfDay(
            for: timeRefreshCoordinator.currentDate
        )
        upcomingPastCursor = displayCalendar.startOfDay(
            for: timeRefreshCoordinator.currentDate
        )
        upcomingResetGeneration += 1
        loadUpcomingPage(direction: .future)
    }

    /// Loads one page in one direction: loops 30-day windows from the
    /// cursor through the pure slicing function until the page fills, the
    /// end is proven or the 12-window cap (about 360 days) is hit against
    /// pathological data. Directions never block each other; results stale
    /// after a reset are dropped by the per-direction race guard.
    private func loadUpcomingPage(direction: UpcomingPageDirection) {
        let preferences = settingsStore.menuBarPreferences
        guard preferences.effectiveEventListMode == .overview else { return }
        guard let startCursor = direction == .future
            ? upcomingFutureCursor
            : upcomingPastCursor else {
            return
        }

        // Per-direction in-flight guard; the request ID joins this
        // direction's race domain only, and the resume flag is snapshotted
        // across the fetch (written back by the previous completion block)
        let requestID: UUID
        let startIsResumingWindow: Bool
        switch direction {
        case .past:
            guard !isLoadingUpcomingPast else { return }
            isLoadingUpcomingPast = true
            requestID = UUID()
            upcomingPastRequestID = requestID
            startIsResumingWindow = isUpcomingPastResumingWindow
        case .future:
            guard !isLoadingUpcomingFuture else { return }
            isLoadingUpcomingFuture = true
            requestID = UUID()
            upcomingFutureRequestID = requestID
            startIsResumingWindow = isUpcomingFutureResumingWindow
        }

        let now = timeRefreshCoordinator.currentDate
        // The day-limit setting (30/90/180/unlimited) becomes the future
        // direction's absolute end; 0 means unlimited. Unused for past.
        let futureLimitEnd: Date? = preferences.upcomingDayLimit > 0
            ? displayCalendar.date(byAdding: .day, value: preferences.upcomingDayLimit, to: now)
            : nil

        var loadedIdentifiers = Set(upcomingItems.map(\.selectionIdentifier))
        let enabledCalendarIDs = preferences.upcomingEnabledCalendarIDs
        let includeReminders = preferences.upcomingIncludeReminders
        let enabledReminderCalendarIDs = preferences.upcomingEnabledReminderCalendarIDs
        let calendar = displayCalendar
        let service = eventService

        Task {
            var collected: [CalendarItem] = []
            var cursor = startCursor
            // Whether the first window resumes a page-full interruption;
            // handed across windows below via isPageFull
            var isResumingWindow = startIsResumingWindow
            var isExhausted = false
            var queriedWindowCount = 0

            while !isExhausted,
                  collected.count < RootPopoverView.upcomingPageSize,
                  queriedWindowCount < RootPopoverView.upcomingPageMaxWindows {
                let activeRequestID = direction == .past
                    ? upcomingPastRequestID
                    : upcomingFutureRequestID
                guard activeRequestID == requestID,
                      settingsStore.menuBarPreferences.effectiveEventListMode == .overview else { return }
                // Future window [cursor, cursor+30d) clipped to the user
                // limit; past window [cursor-30d, cursor), cursor = upper
                // bound
                let windowStart: Date
                let windowEnd: Date
                switch direction {
                case .future:
                    windowStart = cursor
                    var end = calendar.date(
                        byAdding: .day,
                        value: RootPopoverView.upcomingPageWindowDays,
                        to: cursor
                    ) ?? cursor
                    if let futureLimitEnd, end > futureLimitEnd {
                        end = futureLimitEnd
                    }
                    windowEnd = end
                case .past:
                    windowEnd = cursor
                    windowStart = calendar.date(
                        byAdding: .day,
                        value: -RootPopoverView.upcomingPageWindowDays,
                        to: cursor
                    ) ?? cursor
                }
                guard windowEnd > windowStart else {
                    isExhausted = true
                    break
                }

                queriedWindowCount += 1
                let windowItems = await service.fetchUpcomingCalendarItems(
                    pastStart: windowStart,
                    futureEnd: windowEnd,
                    enabledCalendarIDs: enabledCalendarIDs,
                    includeReminders: includeReminders,
                    enabledReminderCalendarIDs: enabledReminderCalendarIDs
                )
                let step = RootPopoverView.advanceUpcomingPage(
                    direction: direction,
                    windowItems: windowItems,
                    windowStart: windowStart,
                    windowEnd: windowEnd,
                    collectedCount: collected.count,
                    loadedIdentifiers: loadedIdentifiers,
                    pageSize: RootPopoverView.upcomingPageSize,
                    futureLimitEnd: futureLimitEnd,
                    isResumingWindow: isResumingWindow
                )
                collected.append(contentsOf: step.slice.takenItems)
                for item in step.slice.takenItems {
                    loadedIdentifiers.insert(item.selectionIdentifier)
                }
                // Page-full: the next round resumes this window, and a
                // resume window yielding nothing new is not the past end
                isResumingWindow = step.slice.isPageFull
                if let nextWindowStart = step.nextWindowStart {
                    cursor = nextWindowStart
                }
                isExhausted = step.isExhausted
            }

            // Window cap reached while under-full: return what we have as
            // the end (nil cursor)
            let hitWindowCap = !isExhausted
                && collected.count < RootPopoverView.upcomingPageSize
            let nextCursor: Date? = (isExhausted || hitWindowCap) ? nil : cursor
            // Page-full finish keeps the cursor inside the window for the
            // same-window resume; exhausted/capped finishes get a nil cursor
            // and clear the flag
            let endedWithPageFull = nextCursor != nil
                && collected.count >= RootPopoverView.upcomingPageSize

            await MainActor.run {
                // Only this direction's race domain is checked: the other
                // direction bumping its own ID never invalidates this result
                switch direction {
                case .past:
                    guard upcomingPastRequestID == requestID else { return }
                    upcomingPastCursor = nextCursor
                    isUpcomingPastResumingWindow = endedWithPageFull
                    isLoadingUpcomingPast = false
                case .future:
                    guard upcomingFutureRequestID == requestID else { return }
                    upcomingFutureCursor = nextCursor
                    isUpcomingFutureResumingWindow = endedWithPageFull
                    isLoadingUpcomingFuture = false
                }
                upcomingItems.append(contentsOf: collected)
            }
        }
    }

    /// Top entry row: loads one past page. Ignored while exhausted or
    /// already loading.
    private func handleLoadMoreUpcomingPast() {
        loadUpcomingPage(direction: .past)
    }

    /// Bottom sentinel: loads the next future page; same guard semantics.
    private func handleLoadMoreUpcomingFuture() {
        loadUpcomingPage(direction: .future)
    }

    private func clearLoadedUpcoming() {
        upcomingPastRequestID = UUID()
        upcomingFutureRequestID = UUID()
        isUpcomingPastResumingWindow = false
        isUpcomingFutureResumingWindow = false
        upcomingItems = []
        isLoadingUpcomingPast = false
        isLoadingUpcomingFuture = false
        upcomingFutureCursor = nil
        upcomingPastCursor = nil
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
            // Shared toggle entry with the event list; keep the board in sync.
            loadBoard()
            // Completed reminders drop straight out of the loaded pages;
            // cursors and scroll stay put, a full reload waits for the next
            // open or data refresh
            let toggledIdentifier = CalendarItem.reminder(reminder).selectionIdentifier
            upcomingItems.removeAll { $0.selectionIdentifier == toggledIdentifier }
        } catch {
            print("Failed to toggle reminder completion: \(error)")
        }
    }

    /// Loads board reminders; when show-completed is off, completed rows inside
    /// the retention window are kept visible until a delayed refresh removes them.
    private func loadBoard() {
        let preferences = settingsStore.menuBarPreferences

        guard preferences.showRemindersBoard, eventService.remindersAuthorized else {
            boardReminders = []
            return
        }

        let enabledCalendarIDs = preferences.boardEnabledReminderCalendarIDs
        let includeCompleted = preferences.boardShowCompleted
        let retentionSeconds = preferences.boardCompletedRetentionSeconds
        // A window start avoids pulling the full completed history when only
        // the retention window matters.
        let recentCompletedWindowStart = includeCompleted || retentionSeconds <= 0
            ? nil
            : Date().addingTimeInterval(-Double(retentionSeconds))

        Task {
            let reminders = await eventService.fetchBoardReminders(
                enabledCalendarIDs: enabledCalendarIDs,
                includeCompleted: includeCompleted,
                recentCompletedWindowStart: recentCompletedWindowStart
            )
            await MainActor.run {
                // Discard the result when preferences changed during the fetch;
                // the change itself re-triggers a load.
                let currentPreferences = settingsStore.menuBarPreferences
                guard currentPreferences.showRemindersBoard,
                      currentPreferences.boardEnabledReminderCalendarIDs == enabledCalendarIDs,
                      currentPreferences.boardShowCompleted == includeCompleted,
                      currentPreferences.boardCompletedRetentionSeconds == retentionSeconds
                else { return }
                boardReminders = reminders
                scheduleBoardRetentionRefresh(after: reminders)
            }
        }
    }

    /// Schedules one board reload when the retention window expires so kept
    /// rows disappear on time; only the earliest in-window completion matters
    /// and any previous task is cancelled first.
    private func scheduleBoardRetentionRefresh(after reminders: [EKReminder]) {
        boardRetentionRefreshTask?.cancel()

        let preferences = settingsStore.menuBarPreferences
        guard !preferences.boardShowCompleted else { return }
        let retentionSeconds = preferences.boardCompletedRetentionSeconds
        guard retentionSeconds > 0 else { return }

        let windowStart = Date().addingTimeInterval(-Double(retentionSeconds))
        let earliestCompletedDate = reminders
            .filter { $0.isCompleted && ($0.completionDate.map { $0 > windowStart } ?? false) }
            .compactMap(\.completionDate)
            .min()
        guard let earliestCompletedDate else { return }

        let remaining = Double(retentionSeconds)
            - Date().timeIntervalSince(earliestCompletedDate)
        guard remaining > 0.05 else { return }

        boardRetentionRefreshTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            } catch {
                // Cancelled by a newer schedule; the new task takes over.
                return
            }
            loadBoard()
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

    private func handleCreateItem(
        initialTimeRange: CalendarItemCreationTimeRange? = nil
    ) {
        guard let selectedDate = viewModel.selectedDate else { return }
        if initialTimeRange != nil, !canCreateEvent {
            return
        }
        let initialKind: CalendarItemCreationKind = initialTimeRange != nil || canCreateEvent
            ? .event
            : .reminder

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
            initialTimeRange,
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

    private func makeSelectedDateSummary(visibleDays: [CalendarDay]) -> SelectedDateSummary {
        SelectedDateSummaryFactory(calendar: displayCalendar, registry: .live).make(
            selectedDate: viewModel.selectedDate,
            currentDate: timeRefreshCoordinator.currentDate,
            displayedMonth: viewModel.displayedMonth,
            preferences: settingsStore.menuBarPreferences,
            locale: AppLocalization.locale,
            showsLunarDate: LocaleFeatureAvailability.showLunarFeatures,
            offText: L("OFF"),
            workText: L("WRK"),
            visibleDays: visibleDays
        )
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
