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
    private var systemEventCancellable: AnyCancellable?

    init(
        settingsStore: SettingsStore,
        renderer: ClockRenderService = ClockRenderService(),
        registry: HolidayProviderRegistry = .live,
        now: @escaping () -> Date = Date.init,
        localeProvider: @escaping () -> Locale = { .autoupdatingCurrent },
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

        settingsCancellable = Publishers.CombineLatest(
            settingsStore.$menuBarPreferences,
            settingsStore.$holidayDataRevision
        )
        .sink { [weak self] preferences, _ in
            guard let self else { return }
            self.refreshGranularity = preferences.requiresSecondRefresh ? .second : .minute
            self.renderNow(with: preferences)
            self.scheduleTimer()
        }

        systemEventCancellable = Publishers.Merge3(
            notificationCenter.publisher(for: NSLocale.currentLocaleDidChangeNotification).map { _ in () },
            notificationCenter.publisher(for: .NSSystemTimeZoneDidChange).map { _ in () },
            notificationCenter.publisher(for: .NSCalendarDayChanged).map { _ in () }
        )
        .sink { [weak self] _ in
            guard let self else { return }
            self.renderNow()
            self.scheduleTimer()
        }

        refreshGranularity = settingsStore.menuBarPreferences.requiresSecondRefresh ? .second : .minute
        renderNow(with: settingsStore.menuBarPreferences)
    }

    func start() {
        scheduleTimer()
    }

    func stop() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    private func scheduleTimer() {
        timerCancellable?.cancel()

        let interval = refreshGranularity == .second ? 1.0 : 60.0
        timerCancellable = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.renderNow()
            }
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
