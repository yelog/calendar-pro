import Combine
import Foundation

@MainActor
final class MenuBarViewModel: ObservableObject {
    @Published private(set) var displayText: String = ""
    @Published private(set) var refreshGranularity: RefreshGranularity = .minute

    private let settingsStore: SettingsStore
    private let renderer: ClockRenderService
    private let registry: HolidayProviderRegistry
    private let localeProvider: () -> Locale
    private let calendarProvider: () -> Calendar
    private let timeZoneProvider: () -> TimeZone
    private let timeRefreshCoordinator: TimeRefreshCoordinator

    private var settingsCancellable: AnyCancellable?
    private var timeCancellable: AnyCancellable?
    private var localeEventCancellable: AnyCancellable?
    private var isRunning = false

    init(
        settingsStore: SettingsStore,
        renderer: ClockRenderService = ClockRenderService(),
        registry: HolidayProviderRegistry = .live,
        now: @escaping () -> Date = Date.init,
        localeProvider: @escaping () -> Locale = { AppLocalization.locale },
        calendarProvider: @escaping () -> Calendar = { .autoupdatingCurrent },
        timeZoneProvider: @escaping () -> TimeZone = { .autoupdatingCurrent },
        notificationCenter: NotificationCenter = .default,
        timeRefreshCoordinator: TimeRefreshCoordinator? = nil
    ) {
        self.settingsStore = settingsStore
        self.renderer = renderer
        self.registry = registry
        self.localeProvider = localeProvider
        self.calendarProvider = calendarProvider
        self.timeZoneProvider = timeZoneProvider
        self.timeRefreshCoordinator = timeRefreshCoordinator ?? TimeRefreshCoordinator(
            now: now,
            calendarProvider: calendarProvider,
            notificationCenter: notificationCenter
        )

        settingsCancellable = Publishers.CombineLatest3(
            settingsStore.$menuBarPreferences,
            settingsStore.$holidayDataRevision,
            settingsStore.$appLanguage
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] preferences, _, _ in
            guard let self else { return }
            let updatedGranularity: RefreshGranularity = preferences.requiresSecondRefresh ? .second : .minute
            self.refreshGranularity = updatedGranularity
            self.timeRefreshCoordinator.setGranularity(updatedGranularity)
            self.render(at: self.timeRefreshCoordinator.currentDate, with: preferences)
        }

        localeEventCancellable = notificationCenter.publisher(for: NSLocale.currentLocaleDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.renderNow()
            }

        timeCancellable = self.timeRefreshCoordinator.$currentDate
            .sink { [weak self] currentDate in
                self?.render(at: currentDate)
            }

        refreshGranularity = settingsStore.menuBarPreferences.requiresSecondRefresh ? .second : .minute
        self.timeRefreshCoordinator.setGranularity(refreshGranularity)
        render(at: self.timeRefreshCoordinator.currentDate, with: settingsStore.menuBarPreferences)
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        timeRefreshCoordinator.setGranularity(refreshGranularity)
        timeRefreshCoordinator.start()
    }

    func stop() {
        isRunning = false
        timeRefreshCoordinator.stop()
    }

    static func delayUntilNextMinuteBoundary(from date: Date, calendar: Calendar) -> TimeInterval {
        TimeRefreshCoordinator.delayUntilNextMinuteBoundary(from: date, calendar: calendar)
    }

    private func renderNow(with preferences: MenuBarPreferences? = nil) {
        render(at: timeRefreshCoordinator.currentDate, with: preferences)
    }

    private func render(at currentDate: Date, with preferences: MenuBarPreferences? = nil) {
        let prefs = preferences ?? settingsStore.menuBarPreferences
        let supplementalText: MenuBarSupplementalText

        if prefs.tokens.contains(where: { $0.isEnabled && ($0.token == .lunar || $0.token == .holiday) }) {
            let factory = CalendarDayFactory(calendar: calendarProvider(), registry: registry, now: { currentDate })
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
