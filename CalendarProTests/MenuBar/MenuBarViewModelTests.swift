import Combine
import XCTest
@testable import CalendarPro

@MainActor
final class MenuBarViewModelTests: XCTestCase {
    func testMenuBarSchedulerUsesMinuteGranularityByDefault() {
        let store = makeStore(name: #function)
        let viewModel = makeViewModel(store: store)

        XCTAssertEqual(viewModel.refreshGranularity, .minute)
    }

    func testMenuBarSchedulerUsesSecondGranularityWhenStyleIsFull() async {
        let store = makeStore(name: #function)
        let viewModel = makeViewModel(store: store)

        store.setTokenStyle(.full, for: .time)
        await Task.yield()

        XCTAssertEqual(viewModel.refreshGranularity, .second)
    }

    func testLocaleChangeNotificationRerendersDisplayText() async {
        let store = makeStore(name: #function)
        let notificationCenter = NotificationCenter()
        let localeBox = MutableBox(Locale(identifier: "en_US_POSIX"))
        let viewModel = MenuBarViewModel(
            settingsStore: store,
            registry: .default,
            now: { Date(timeIntervalSince1970: 0) },
            localeProvider: { localeBox.value },
            calendarProvider: { .gregorianMondayFirst },
            timeZoneProvider: { TimeZone(secondsFromGMT: 0)! },
            notificationCenter: notificationCenter
        )

        let initialText = viewModel.displayText
        localeBox.value = Locale(identifier: "zh_CN")
        notificationCenter.post(name: NSLocale.currentLocaleDidChangeNotification, object: nil)
        await Task.yield()

        XCTAssertNotEqual(viewModel.displayText, initialText)
    }

    func testWeekdayPickerDistinguishesLocalizedAndFixedChineseStyles() throws {
        let store = makeStore(name: #function)
        store.setTimeZoneIdentifier("UTC")
        let calendar = store.displayCalendar
        let monday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 16, hour: 12)))
        let settingsView = MenuBarSettingsView(store: store)

        withAppLanguage(.simplifiedChinese) {
            let options = settingsView.stylePreviews(for: .weekday, at: monday, calendar: calendar, timeZone: calendar.timeZone)

            XCTAssertEqual(options.map(\.style), [.short, .full, .chineseWeekday])
            XCTAssertEqual(options.map(\.label), ["周一（随语言）", "星期一", "周一（固定）"])
        }
    }

    func testSettingsPreviewsMatchLiveMenuBarInBothAppLanguages() throws {
        let store = makeStore(name: #function)
        store.setTimeZoneIdentifier("UTC")
        store.menuBarPreferences.tokens = [
            DisplayTokenPreference(token: .weekday, isEnabled: true, order: 0, style: .full)
        ]
        store.pomodoroPreferences = .default
        let calendar = store.displayCalendar
        let monday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 16, hour: 12)))
        let settingsView = MenuBarSettingsView(store: store)
        let expectedWeekdays: [(AppLanguage, String)] = [(.simplifiedChinese, "星期一"), (.english, "Monday")]

        for (language, expectedWeekday) in expectedWeekdays {
            withAppLanguage(language) {
                let viewModel = MenuBarViewModel(settingsStore: store, registry: .default, now: { monday })
                let preview = settingsView.previewText(at: monday, calendar: calendar, timeZone: calendar.timeZone)
                let options = settingsView.stylePreviews(for: .weekday, at: monday, calendar: calendar, timeZone: calendar.timeZone)

                XCTAssertEqual(viewModel.displayText, expectedWeekday)
                XCTAssertEqual(preview, viewModel.displayText)
                XCTAssertEqual(options.first { $0.style == .full }?.label, viewModel.displayText)
            }
        }
    }

    func testLocaleChangeNotificationPostedOffMainThreadRerendersDisplayText() async {
        let store = makeStore(name: #function)
        let notificationCenter = NotificationCenter()
        let localeBox = MutableBox(Locale(identifier: "en_US_POSIX"))
        let viewModel = MenuBarViewModel(
            settingsStore: store,
            registry: .default,
            now: { Date(timeIntervalSince1970: 0) },
            localeProvider: { localeBox.value },
            calendarProvider: { .gregorianMondayFirst },
            timeZoneProvider: { TimeZone(secondsFromGMT: 0)! },
            notificationCenter: notificationCenter
        )

        let initialText = viewModel.displayText
        let rerendered = expectation(description: "display text rerendered after off-main locale change")
        var cancellable: AnyCancellable?
        cancellable = viewModel.$displayText
            .dropFirst()
            .sink { updatedText in
                if updatedText != initialText {
                    rerendered.fulfill()
                    cancellable?.cancel()
                }
            }

        localeBox.value = Locale(identifier: "zh_CN")
        DispatchQueue.global(qos: .userInitiated).async {
            notificationCenter.post(name: NSLocale.currentLocaleDidChangeNotification, object: nil)
        }

        await fulfillment(of: [rerendered], timeout: 2.0)
        XCTAssertNotEqual(viewModel.displayText, initialText)
        cancellable?.cancel()
    }

    func testSystemClockChangeNotificationRerendersDisplayText() async {
        let store = makeStore(name: #function)
        let notificationCenter = NotificationCenter()
        let currentTime = MutableBox(Date(timeIntervalSince1970: 0))
        let viewModel = MenuBarViewModel(
            settingsStore: store,
            registry: .default,
            now: { currentTime.value },
            localeProvider: { Locale(identifier: "en_US_POSIX") },
            calendarProvider: { .gregorianMondayFirst },
            timeZoneProvider: { TimeZone(secondsFromGMT: 0)! },
            notificationCenter: notificationCenter
        )

        let initialText = viewModel.displayText
        currentTime.value = Date(timeIntervalSince1970: 60)
        notificationCenter.post(name: .NSSystemClockDidChange, object: nil)
        await Task.yield()

        XCTAssertNotEqual(viewModel.displayText, initialText)
    }

    func testDelayUntilNextMinuteBoundaryUsesRemainingSecondsInCurrentMinute() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: DateComponents(year: 2026, month: 4, day: 5, hour: 11, minute: 28, second: 31))!

        let delay = MenuBarViewModel.delayUntilNextMinuteBoundary(from: date, calendar: calendar)

        XCTAssertEqual(delay, 29, accuracy: 0.001)
    }

    func testDelayUntilNextMinuteBoundaryAdvancesFullMinuteWhenAlreadyAligned() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: DateComponents(year: 2026, month: 4, day: 5, hour: 11, minute: 28, second: 0))!

        let delay = MenuBarViewModel.delayUntilNextMinuteBoundary(from: date, calendar: calendar)

        XCTAssertEqual(delay, 60, accuracy: 0.001)
    }

    func testMenuBarWeatherTextUsesSelectedFormat() {
        var preferences = MenuBarPreferences.default
        preferences.showWeather = true
        preferences.tokens = [
            DisplayTokenPreference(token: .weather, isEnabled: true, order: 0, style: .weatherTemperaturePM25)
        ]

        let text = MenuBarViewModel.menuBarWeatherText(
            for: makeWeatherDescriptor(pm25: 18.4),
            preferences: preferences
        )

        XCTAssertEqual(text, "23° PM2.5 18")
    }

    func testMenuBarWeatherTextFallsBackToTemperatureWhenMetricMissing() {
        var preferences = MenuBarPreferences.default
        preferences.showWeather = true
        preferences.tokens = [
            DisplayTokenPreference(token: .weather, isEnabled: true, order: 0, style: .weatherTemperatureAQI)
        ]

        let text = MenuBarViewModel.menuBarWeatherText(
            for: makeWeatherDescriptor(airQualityIndex: nil),
            preferences: preferences
        )

        XCTAssertEqual(text, "23°")
    }

    func testMenuBarWeatherTextRequiresWeatherSwitchAndToken() {
        var preferences = MenuBarPreferences.default
        preferences.showWeather = false
        preferences.tokens = [
            DisplayTokenPreference(token: .weather, isEnabled: true, order: 0, style: .weatherConditionTemperature)
        ]

        XCTAssertNil(MenuBarViewModel.menuBarWeatherText(for: makeWeatherDescriptor(), preferences: preferences))

        preferences.showWeather = true
        preferences.tokens = [
            DisplayTokenPreference(token: .weather, isEnabled: false, order: 0, style: .weatherConditionTemperature)
        ]

        XCTAssertNil(MenuBarViewModel.menuBarWeatherText(for: makeWeatherDescriptor(), preferences: preferences))
    }

    private func withAppLanguage(_ language: AppLanguage, perform: () -> Void) {
        let defaults = UserDefaults.standard
        let domain = UserDefaults.argumentDomain
        let originalArguments = defaults.volatileDomain(forName: domain)
        var arguments = originalArguments
        arguments[AppLocalization.appLanguageDefaultsKey] = language.rawValue
        defaults.setVolatileDomain(arguments, forName: domain)
        defer { defaults.setVolatileDomain(originalArguments, forName: domain) }

        perform()
    }

    private func makeStore(name: String) -> SettingsStore {
        let userDefaults = UserDefaults(suiteName: name)!
        userDefaults.removePersistentDomain(forName: name)
        return SettingsStore(userDefaults: userDefaults)
    }

    private func makeViewModel(store: SettingsStore) -> MenuBarViewModel {
        MenuBarViewModel(
            settingsStore: store,
            registry: .default,
            now: { Date(timeIntervalSince1970: 0) },
            localeProvider: { Locale(identifier: "en_US_POSIX") },
            calendarProvider: { .gregorianMondayFirst },
            timeZoneProvider: { TimeZone(secondsFromGMT: 0)! },
            notificationCenter: NotificationCenter()
        )
    }

    private func makeWeatherDescriptor(
        airQualityIndex: Int? = 42,
        pm25: Double? = 18.4
    ) -> WeatherDescriptor {
        WeatherDescriptor(
            locationName: "Beijing",
            temperatureText: "23°",
            apparentTemperature: 28,
            forecastDate: nil,
            weatherCode: 2,
            isDaytime: true,
            isCurrentConditions: true,
            airQualityIndex: airQualityIndex,
            pm25: pm25
        )
    }
}

private final class MutableBox<Value> {
    var value: Value

    init(_ value: Value) {
        self.value = value
    }
}
