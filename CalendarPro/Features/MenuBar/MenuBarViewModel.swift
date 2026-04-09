import Combine
import Foundation

enum RefreshGranularity: Equatable {
    case second
    case minute
}

@MainActor
final class MenuBarViewModel: ObservableObject {
    @Published private(set) var displayText: String = ""
    @Published private(set) var refreshGranularity: RefreshGranularity = .minute

    private let settingsStore: SettingsStore
    private let renderer: ClockRenderService
    private let registry: HolidayProviderRegistry
    private let now: () -> Date
    private let localeProvider: () -> Locale
    private let calendarProvider: () -> Calendar
    private let timeZoneProvider: () -> TimeZone
    private let notificationCenter: NotificationCenter

    private var settingsCancellable: AnyCancellable?
    private var timerCancellable: AnyCancellable?
    private var localeEventCancellable: AnyCancellable?
    private var significantTimeEventCancellable: AnyCancellable?
    private var alignedRefreshWorkItem: DispatchWorkItem?
    private var isRunning = false

    init(
        settingsStore: SettingsStore,
        renderer: ClockRenderService = ClockRenderService(),
        registry: HolidayProviderRegistry = .live,
        now: @escaping () -> Date = Date.init,
        localeProvider: @escaping () -> Locale = { AppLocalization.locale },
        calendarProvider: @escaping () -> Calendar = { .autoupdatingCurrent },
        timeZoneProvider: @escaping () -> TimeZone = { .autoupdatingCurrent },
        notificationCenter: NotificationCenter = .default
    ) {
        self.settingsStore = settingsStore
        self.renderer = renderer
        self.registry = registry
        self.now = now
        self.localeProvider = localeProvider
        self.calendarProvider = calendarProvider
        self.timeZoneProvider = timeZoneProvider
        self.notificationCenter = notificationCenter

        settingsCancellable = Publishers.CombineLatest3(
            settingsStore.$menuBarPreferences,
            settingsStore.$holidayDataRevision,
            settingsStore.$appLanguage
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] preferences, _, _ in
            guard let self else { return }
            let updatedGranularity: RefreshGranularity = preferences.requiresSecondRefresh ? .second : .minute
            let needsReschedule = self.refreshGranularity != updatedGranularity
            self.refreshGranularity = updatedGranularity
            self.renderNow(with: preferences)
            if self.isRunning, needsReschedule {
                self.scheduleTimer()
            }
        }

        localeEventCancellable = notificationCenter.publisher(for: NSLocale.currentLocaleDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.renderNow()
            }

        significantTimeEventCancellable = Publishers.Merge3(
            notificationCenter.publisher(for: .NSSystemTimeZoneDidChange),
            notificationCenter.publisher(for: .NSCalendarDayChanged),
            notificationCenter.publisher(for: .NSSystemClockDidChange)
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            guard let self else { return }
            self.renderNow()
            if self.isRunning {
                self.scheduleTimer()
            }
        }

        refreshGranularity = settingsStore.menuBarPreferences.requiresSecondRefresh ? .second : .minute
        renderNow(with: settingsStore.menuBarPreferences)
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        scheduleTimer()
    }

    func stop() {
        isRunning = false
        cancelScheduledRefresh()
    }

    private func scheduleTimer() {
        cancelScheduledRefresh()

        switch refreshGranularity {
        case .second:
            scheduleRepeatingTimer(every: 1.0)
        case .minute:
            scheduleAlignedMinuteTimer()
        }
    }

    private func cancelScheduledRefresh() {
        timerCancellable?.cancel()
        timerCancellable = nil
        alignedRefreshWorkItem?.cancel()
        alignedRefreshWorkItem = nil
    }

    private func scheduleRepeatingTimer(every interval: TimeInterval) {
        timerCancellable = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.renderNow()
            }
    }

    private func scheduleAlignedMinuteTimer() {
        let delay = Self.delayUntilNextMinuteBoundary(from: now(), calendar: calendarProvider())
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.isRunning else { return }
            self.renderNow()
            self.scheduleRepeatingTimer(every: 60.0)
            self.alignedRefreshWorkItem = nil
        }

        alignedRefreshWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    static func delayUntilNextMinuteBoundary(from date: Date, calendar: Calendar) -> TimeInterval {
        guard let nextMinute = calendar.nextDate(
            after: date,
            matching: DateComponents(second: 0),
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        ) else {
            return 60
        }

        return max(nextMinute.timeIntervalSince(date), 0)
    }

    private func renderNow(with preferences: MenuBarPreferences? = nil) {
        let currentDate = now()
        let prefs = preferences ?? settingsStore.menuBarPreferences
        let supplementalText: MenuBarSupplementalText

        if prefs.tokens.contains(where: { $0.isEnabled && ($0.token == .lunar || $0.token == .holiday) }) {
            let factory = CalendarDayFactory(calendar: calendarProvider(), registry: registry, now: now)
            let day = try? factory.makeDay(for: currentDate, displayedMonth: currentDate, preferences: prefs)
            supplementalText = MenuBarSupplementalText(
                lunarText: day?.lunarText,
                holidayText: day?.badges.first?.text
            )
        } else {
            supplementalText = .empty
        }

        displayText = renderer.render(
            now: currentDate,
            preferences: prefs,
            locale: localeProvider(),
            calendar: calendarProvider(),
            timeZone: timeZoneProvider(),
            supplementalText: supplementalText
        )
    }
}
