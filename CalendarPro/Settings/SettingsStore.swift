import Combine
import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    @Published var menuBarPreferences: MenuBarPreferences
    @Published private(set) var holidayDataRevision: Int = 0
    @Published private(set) var launchAtLoginStatus: LaunchAtLoginStatus = .disabled
    @Published private(set) var launchAtLoginEnabled: Bool = false
    @Published private(set) var launchAtLoginStatusMessage: String?

    private let userDefaults: UserDefaults
    private let launchAtLoginController: any LaunchAtLoginControlling
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let menuBarPreferencesKey = "menuBarPreferences"

    init(
        userDefaults: UserDefaults = .standard,
        launchAtLoginController: any LaunchAtLoginControlling = SystemLaunchAtLoginController()
    ) {
        self.userDefaults = userDefaults
        self.launchAtLoginController = launchAtLoginController

        if
            let data = userDefaults.data(forKey: menuBarPreferencesKey),
            let decoded = try? decoder.decode(MenuBarPreferences.self, from: data)
        {
            menuBarPreferences = decoded
        } else {
            menuBarPreferences = .default
        }

        syncLaunchAtLoginState()
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
            return "系统需要批准后才能完成开机启动，请前往“系统设置 > 通用 > 登录项”继续操作。"
        case .unavailable:
            return "当前无法配置开机启动，请从已安装的应用包启动 Calendar Pro 后重试。"
        case .enabled, .disabled:
            let action = requestedState ? "开启" : "关闭"
            return "无法\(action)开机启动：\(error.localizedDescription)"
        }
    }
}
