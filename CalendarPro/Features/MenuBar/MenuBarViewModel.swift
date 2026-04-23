import Combine
import Foundation

@MainActor
final class MenuBarViewModel: ObservableObject {
    @Published private(set) var displayText: String = ""
    @Published private(set) var refreshGranularity: RefreshGranularity = .minute
    @Published private(set) var weatherDescriptor: WeatherDescriptor = .empty

    private let settingsStore: SettingsStore
    private let renderer: ClockRenderService
    private let registry: HolidayProviderRegistry
    private var weatherService: WeatherService
    private let localeProvider: () -> Locale
    private let calendarProvider: () -> Calendar
    private let timeZoneProvider: () -> TimeZone
    private let timeRefreshCoordinator: TimeRefreshCoordinator

    private var settingsCancellable: AnyCancellable?
    private var timeCancellable: AnyCancellable?
    private var localeEventCancellable: AnyCancellable?
    private var weatherFetchTask: Task<Void, Never>?
    private var weatherNextRefreshDate: Date = .distantPast
    private var weatherFailureCount = 0
    private var isRunning = false

    init(
        settingsStore: SettingsStore,
        renderer: ClockRenderService = ClockRenderService(),
        registry: HolidayProviderRegistry = .live,
        weatherService: WeatherService = WeatherService(),
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
        self.weatherService = weatherService
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
        weatherFetchTask?.cancel()
        weatherFetchTask = nil
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

        let weatherText: String? = weatherDescriptor.hasContent
            ? weatherDescriptor.temperatureText
            : nil

        let fullSupplemental = MenuBarSupplementalText(
            lunarText: supplementalText.lunarText,
            holidayText: supplementalText.holidayText,
            weatherText: weatherText
        )

        displayText = renderer.render(
            now: currentDate,
            preferences: prefs,
            locale: localeProvider(),
            calendar: calendarProvider(),
            timeZone: timeZoneProvider(),
            supplementalText: fullSupplemental
        )

        fetchWeatherIfNeeded(with: prefs, currentDate: currentDate)
    }

    private func fetchWeatherIfNeeded(with prefs: MenuBarPreferences, currentDate: Date) {
        let weatherTokenEnabled = prefs.tokens.contains(where: { $0.token == .weather && $0.isEnabled })

        guard prefs.showWeather || weatherTokenEnabled else {
            weatherFetchTask?.cancel()
            weatherFetchTask = nil
            weatherNextRefreshDate = .distantPast
            weatherFailureCount = 0
            if weatherDescriptor != .empty {
                weatherDescriptor = .empty
                renderNow()
            }
            return
        }

        let expectedLocation = prefs.locationMode == .manual ? prefs.manualLocation : nil
        if weatherService.manualLocation != expectedLocation {
            weatherFetchTask?.cancel()
            weatherFetchTask = nil
            weatherService = WeatherService(
                session: weatherService.session,
                now: weatherService.now,
                refreshInterval: weatherService.refreshInterval,
                manualLocation: expectedLocation
            )
            weatherNextRefreshDate = .distantPast
            weatherFailureCount = 0
            if weatherDescriptor != .empty {
                weatherDescriptor = .empty
                renderNow()
            }
        }

        guard weatherFetchTask == nil else { return }
        guard currentDate >= weatherNextRefreshDate else { return }

        let requestDate = currentDate
        let service = weatherService
        weatherFetchTask = Task {
            let descriptor = await service.fetchCurrentWeather()
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.weatherFetchTask = nil
                let latestPrefs = self.settingsStore.menuBarPreferences
                let latestWeatherTokenEnabled = latestPrefs.tokens.contains(where: { $0.token == .weather && $0.isEnabled })
                guard latestPrefs.showWeather || latestWeatherTokenEnabled else { return }
                guard self.weatherService.manualLocation == expectedLocation else { return }

                let baseDate = self.timeRefreshCoordinator.currentDate > requestDate
                    ? self.timeRefreshCoordinator.currentDate
                    : requestDate
                if descriptor.hasContent {
                    self.weatherFailureCount = 0
                    self.weatherNextRefreshDate = baseDate.addingTimeInterval(self.weatherService.refreshInterval)
                } else {
                    self.weatherFailureCount += 1
                    self.weatherNextRefreshDate = baseDate.addingTimeInterval(
                        Self.weatherRetryDelay(forFailureCount: self.weatherFailureCount)
                    )
                }

                let changed = self.weatherDescriptor != descriptor
                self.weatherDescriptor = descriptor
                if changed {
                    self.renderNow()
                }
            }
        }
    }

    private static func weatherRetryDelay(forFailureCount failureCount: Int) -> TimeInterval {
        switch failureCount {
        case ...1:
            return 60
        case 2:
            return 2 * 60
        default:
            return 5 * 60
        }
    }
}
