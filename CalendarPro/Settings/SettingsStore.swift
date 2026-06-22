import Combine
import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    @Published var menuBarPreferences: MenuBarPreferences
    @Published var pomodoroPreferences: PomodoroPreferences
    @Published var appLanguage: AppLanguage
    @Published private(set) var holidayDataRevision: Int = 0
    @Published private(set) var launchAtLoginStatus: LaunchAtLoginStatus = .disabled
    @Published private(set) var launchAtLoginEnabled: Bool = false
    @Published private(set) var launchAtLoginStatusMessage: String?

    private let userDefaults: UserDefaults
    private let launchAtLoginController: any LaunchAtLoginControlling
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let menuBarPreferencesKey = "menuBarPreferences"
    private let pomodoroPreferencesKey = "pomodoroPreferences"
    private let appLanguageKey = "appLanguage"

    init(
        userDefaults: UserDefaults = .standard,
        launchAtLoginController: any LaunchAtLoginControlling = SystemLaunchAtLoginController()
    ) {
        self.userDefaults = userDefaults
        self.launchAtLoginController = launchAtLoginController

        if let rawValue = userDefaults.string(forKey: appLanguageKey),
           let appLanguage = AppLanguage(rawValue: rawValue) {
            self.appLanguage = appLanguage
        } else {
            self.appLanguage = .simplifiedChinese
        }

        if
            let data = userDefaults.data(forKey: menuBarPreferencesKey),
            let decoded = try? decoder.decode(MenuBarPreferences.self, from: data)
        {
            menuBarPreferences = decoded
        } else {
            menuBarPreferences = .default
        }

        if
            let data = userDefaults.data(forKey: pomodoroPreferencesKey),
            let decoded = try? decoder.decode(PomodoroPreferences.self, from: data)
        {
            pomodoroPreferences = decoded
        } else {
            pomodoroPreferences = .default
        }

        migrateMenuBarPreferencesIfNeeded()
        syncLaunchAtLoginState()

        if !launchAtLoginEnabled {
            setLaunchAtLoginEnabled(true)
        }
    }

    func setAppLanguage(_ appLanguage: AppLanguage) {
        self.appLanguage = appLanguage
        userDefaults.set(appLanguage.rawValue, forKey: appLanguageKey)
        objectWillChange.send()
    }

    func setTokenEnabled(_ isEnabled: Bool, for token: DisplayTokenKind) {
        guard let index = menuBarPreferences.tokens.firstIndex(where: { $0.token == token }) else { return }
        var prefs = menuBarPreferences
        prefs.tokens[index].isEnabled = isEnabled
        menuBarPreferences = prefs
        persistMenuBarPreferences()
    }

    func setTokenStyle(_ style: DisplayTokenStyle, for token: DisplayTokenKind) {
        guard let index = menuBarPreferences.tokens.firstIndex(where: { $0.token == token }) else { return }
        var prefs = menuBarPreferences
        prefs.tokens[index].style = style
        menuBarPreferences = prefs
        persistMenuBarPreferences()
    }

    func moveToken(_ token: DisplayTokenKind, by delta: Int) {
        let sorted = menuBarPreferences.tokens.sorted { $0.order < $1.order }

        guard let currentIndex = sorted.firstIndex(where: { $0.token == token }) else { return }

        let targetIndex = currentIndex + delta
        guard sorted.indices.contains(targetIndex) else { return }

        var reordered = sorted
        reordered.swapAt(currentIndex, targetIndex)

        for index in reordered.indices {
            reordered[index].order = index
        }

        var prefs = menuBarPreferences
        prefs.tokens = reordered
        menuBarPreferences = prefs
        persistMenuBarPreferences()
    }

    func setSeparator(_ separator: String) {
        var prefs = menuBarPreferences
        prefs.separator = separator
        menuBarPreferences = prefs
        persistMenuBarPreferences()
    }

    func setMenuBarTextBold(_ isBold: Bool) {
        var prefs = menuBarPreferences
        prefs.textStyle.isBold = isBold
        menuBarPreferences = prefs
        persistMenuBarPreferences()
    }

    func setMenuBarTextColorHex(_ colorHex: String?) {
        var prefs = menuBarPreferences
        prefs.textStyle.foregroundColorHex = colorHex
        menuBarPreferences = prefs
        persistMenuBarPreferences()
    }

    func setMenuBarFilledBackground(_ enabled: Bool) {
        var prefs = menuBarPreferences
        prefs.textStyle.usesFilledBackground = enabled
        menuBarPreferences = prefs
        persistMenuBarPreferences()
    }

    func setMenuBarFillColorHex(_ colorHex: String) {
        var prefs = menuBarPreferences
        prefs.textStyle.backgroundColorHex = colorHex
        menuBarPreferences = prefs
        persistMenuBarPreferences()
    }

    func resetMenuBarTextStyle() {
        var prefs = menuBarPreferences
        prefs.textStyle = .default
        menuBarPreferences = prefs
        persistMenuBarPreferences()
    }

    func setPomodoroEnabled(_ enabled: Bool) {
        var prefs = pomodoroPreferences
        prefs.isEnabled = enabled
        pomodoroPreferences = prefs
        persistPomodoroPreferences()
    }

    func setPomodoroMenuBarStyle(_ style: PomodoroMenuBarStyle) {
        var prefs = pomodoroPreferences
        prefs.menuBarStyle = style
        pomodoroPreferences = prefs
        persistPomodoroPreferences()
    }

    func setPomodoroNotificationsEnabled(_ enabled: Bool) {
        var prefs = pomodoroPreferences
        prefs.reminders.notificationsEnabled = enabled
        pomodoroPreferences = prefs
        persistPomodoroPreferences()
    }

    func setPomodoroSoundEnabled(_ enabled: Bool) {
        var prefs = pomodoroPreferences
        prefs.reminders.soundEnabled = enabled
        pomodoroPreferences = prefs
        persistPomodoroPreferences()
    }

    private func migrateMenuBarPreferencesIfNeeded() {
        guard !menuBarPreferences.enabledHolidayIDs.isEmpty else { return }
        guard !menuBarPreferences.enabledHolidayIDs.contains(MainlandCNProvider.commemorativeFestivalSetID) else { return }

        let mainlandSetIDs = [
            MainlandCNProvider.statutoryHolidaySetID,
            MainlandCNProvider.adjustmentWorkdaySetID
        ]
        guard menuBarPreferences.enabledHolidayIDs.contains(where: mainlandSetIDs.contains) else { return }

        var prefs = menuBarPreferences
        prefs.enabledHolidayIDs.append(MainlandCNProvider.commemorativeFestivalSetID)
        menuBarPreferences = prefs
        persistMenuBarPreferences()
    }

    func setRegionEnabled(_ isEnabled: Bool, regionID: String) {
        var activeRegions = menuBarPreferences.activeRegionIDs

        if isEnabled {
            if !activeRegions.contains(regionID) {
                activeRegions.append(regionID)
            }
        } else {
            activeRegions.removeAll { $0 == regionID }
        }

        var prefs = menuBarPreferences
        prefs.activeRegionIDs = activeRegions
        menuBarPreferences = prefs
        persistMenuBarPreferences()
    }

    func setHolidaySetEnabled(_ isEnabled: Bool, holidaySetID: String, allKnownSetIDs: [String]) {
        var enabledSetIDs = Set(menuBarPreferences.enabledHolidayIDs)

        if enabledSetIDs.isEmpty {
            enabledSetIDs = Set(allKnownSetIDs)
        }

        if isEnabled {
            enabledSetIDs.insert(holidaySetID)
        } else {
            enabledSetIDs.remove(holidaySetID)
        }

        var prefs = menuBarPreferences
        if enabledSetIDs.count == allKnownSetIDs.count {
            prefs.enabledHolidayIDs = []
        } else {
            prefs.enabledHolidayIDs = allKnownSetIDs.filter { enabledSetIDs.contains($0) }
        }
        menuBarPreferences = prefs
        persistMenuBarPreferences()
    }

    func noteHolidayDataUpdated() {
        holidayDataRevision += 1
    }

    func setShowEvents(_ show: Bool) {
        var prefs = menuBarPreferences
        prefs.showEvents = show
        menuBarPreferences = prefs
        persistMenuBarPreferences()
    }

    func setShowCalendarEvents(_ enabled: Bool) {
        var prefs = menuBarPreferences
        prefs.showCalendarEvents = enabled
        menuBarPreferences = prefs
        persistMenuBarPreferences()
    }

    func setCalendarEnabled(_ enabled: Bool, calendarID: String, allCalendarIDs: [String] = []) {
        let hasAllCalendarIDs = !allCalendarIDs.isEmpty
        var ids = menuBarPreferences.enabledCalendarIDs

        if hasAllCalendarIDs && ids.isEmpty {
            ids = allCalendarIDs
        }

        if enabled {
            if !ids.contains(calendarID) {
                ids.append(calendarID)
            }
        } else {
            ids.removeAll { $0 == calendarID }
        }

        var prefs = menuBarPreferences
        if hasAllCalendarIDs && Set(ids) == Set(allCalendarIDs) {
            prefs.enabledCalendarIDs = []
        } else if hasAllCalendarIDs {
            prefs.enabledCalendarIDs = allCalendarIDs.filter { ids.contains($0) }
        } else {
            prefs.enabledCalendarIDs = ids
        }
        menuBarPreferences = prefs
        persistMenuBarPreferences()
    }

    func setShowReminders(_ enabled: Bool) {
        var prefs = menuBarPreferences
        prefs.showReminders = enabled
        menuBarPreferences = prefs
        persistMenuBarPreferences()
    }

    func setWeekStart(_ weekStart: WeekStart) {
        var prefs = menuBarPreferences
        prefs.weekStart = weekStart
        menuBarPreferences = prefs
        persistMenuBarPreferences()
    }

    func setHighlightWeekends(_ enabled: Bool) {
        var prefs = menuBarPreferences
        prefs.highlightWeekends = enabled
        menuBarPreferences = prefs
        persistMenuBarPreferences()
    }

    func setShowAlmanac(_ enabled: Bool) {
        var prefs = menuBarPreferences
        prefs.showAlmanac = enabled
        menuBarPreferences = prefs
        persistMenuBarPreferences()
    }

    func setShowWeather(_ enabled: Bool) {
        var prefs = menuBarPreferences
        prefs.showWeather = enabled
        menuBarPreferences = prefs
        persistMenuBarPreferences()
    }

    func setLocationMode(_ mode: LocationMode) {
        var prefs = menuBarPreferences
        prefs.locationMode = mode
        menuBarPreferences = prefs
        persistMenuBarPreferences()
    }

    func setManualLocation(_ location: WeatherLocation?) {
        var prefs = menuBarPreferences
        prefs.manualLocation = location
        menuBarPreferences = prefs
        persistMenuBarPreferences()
    }

    func setWeatherProvider(_ provider: WeatherProvider) {
        var prefs = menuBarPreferences
        prefs.weatherProvider = provider
        menuBarPreferences = prefs
        persistMenuBarPreferences()
    }

    func setQWeatherAPIHost(_ apiHost: String) {
        var prefs = menuBarPreferences
        prefs.qWeatherAPIHost = Self.normalizedQWeatherAPIHost(apiHost)
        menuBarPreferences = prefs
        persistMenuBarPreferences()
    }

    func setQWeatherAPIKey(_ apiKey: String) {
        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        var prefs = menuBarPreferences
        prefs.qWeatherAPIKey = trimmedAPIKey
        menuBarPreferences = prefs
        persistMenuBarPreferences()
    }

    func weatherProviderConfiguration(for preferences: MenuBarPreferences? = nil) -> WeatherProviderConfiguration {
        let preferences = preferences ?? menuBarPreferences

        switch preferences.weatherProvider {
        case .openMeteo:
            return .openMeteo
        case .qWeather:
            return .qWeather(
                apiHost: preferences.qWeatherAPIHost,
                apiKey: preferences.qWeatherAPIKey
            )
        case .wttrIn:
            return .wttrIn
        case .sevenTimer:
            return .sevenTimer
        }
    }

    func setShowUpcomingIndicator(_ enabled: Bool) {
        var prefs = menuBarPreferences
        prefs.showUpcomingIndicator = enabled
        menuBarPreferences = prefs
        persistMenuBarPreferences()
    }

    func setUpcomingReminderMinutes(_ minutes: Int) {
        var prefs = menuBarPreferences
        prefs.upcomingReminderMinutes = minutes
        menuBarPreferences = prefs
        persistMenuBarPreferences()
    }

    func setReminderCalendarEnabled(_ enabled: Bool, calendarID: String, allCalendarIDs: [String] = []) {
        let hasAllCalendarIDs = !allCalendarIDs.isEmpty
        var ids = menuBarPreferences.enabledReminderCalendarIDs

        if hasAllCalendarIDs && ids.isEmpty {
            ids = allCalendarIDs
        }

        if enabled {
            if !ids.contains(calendarID) {
                ids.append(calendarID)
            }
        } else {
            ids.removeAll { $0 == calendarID }
        }

        var prefs = menuBarPreferences
        if hasAllCalendarIDs && Set(ids) == Set(allCalendarIDs) {
            prefs.enabledReminderCalendarIDs = []
        } else if hasAllCalendarIDs {
            prefs.enabledReminderCalendarIDs = allCalendarIDs.filter { ids.contains($0) }
        } else {
            prefs.enabledReminderCalendarIDs = ids
        }
        menuBarPreferences = prefs
        persistMenuBarPreferences()
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        launchAtLoginStatusMessage = nil

        do {
            try launchAtLoginController.setEnabled(enabled)
            syncLaunchAtLoginState()
        } catch {
            syncLaunchAtLoginState()
            launchAtLoginStatusMessage = launchAtLoginFailureMessage(
                requestedState: enabled,
                currentStatus: launchAtLoginStatus,
                error: error
            )
        }
    }

    private func persistMenuBarPreferences() {
        guard let data = try? encoder.encode(menuBarPreferences) else { return }
        userDefaults.set(data, forKey: menuBarPreferencesKey)
    }

    private func persistPomodoroPreferences() {
        guard let data = try? encoder.encode(pomodoroPreferences) else { return }
        userDefaults.set(data, forKey: pomodoroPreferencesKey)
    }

    private func syncLaunchAtLoginState() {
        let status = launchAtLoginController.status()
        launchAtLoginStatus = status
        launchAtLoginEnabled = status.isEnabled
    }

    private func launchAtLoginFailureMessage(
        requestedState: Bool,
        currentStatus: LaunchAtLoginStatus,
        error: Error
    ) -> String {
        switch currentStatus {
        case .requiresApproval:
            return L("Launch approval required")
        case .unavailable:
            return L("Launch unavailable")
        case .enabled, .disabled:
            let action = requestedState ? L("Enable") : L("Disable")
            return LF("Unable to %@ launch at login: %@", action, error.localizedDescription)
        }
    }

    private static func normalizedQWeatherAPIHost(_ apiHost: String) -> String {
        let trimmed = apiHost.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        if let url = URL(string: trimmed), let host = url.host {
            return host
        }

        let withoutScheme = trimmed
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
        return withoutScheme.split(separator: "/").first.map(String.init) ?? ""
    }
}
