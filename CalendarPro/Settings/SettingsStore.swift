import Combine
import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    @Published var menuBarPreferences: MenuBarPreferences
    @Published private(set) var holidayDataRevision: Int = 0

    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let menuBarPreferencesKey = "menuBarPreferences"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        if
            let data = userDefaults.data(forKey: menuBarPreferencesKey),
            let decoded = try? decoder.decode(MenuBarPreferences.self, from: data)
        {
            menuBarPreferences = decoded
        } else {
            menuBarPreferences = .default
        }
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

    func setTimeShowsSeconds(_ showsSeconds: Bool) {
        guard let index = menuBarPreferences.tokens.firstIndex(where: { $0.token == .time }) else { return }
        var prefs = menuBarPreferences
        prefs.tokens[index].showsSeconds = showsSeconds
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

    func setCalendarEnabled(_ enabled: Bool, calendarID: String) {
        var ids = menuBarPreferences.enabledCalendarIDs
        if enabled {
            if !ids.contains(calendarID) {
                ids.append(calendarID)
            }
        } else {
            ids.removeAll { $0 == calendarID }
        }
        var prefs = menuBarPreferences
        prefs.enabledCalendarIDs = ids
        menuBarPreferences = prefs
        persistMenuBarPreferences()
    }

    private func persistMenuBarPreferences() {
        guard let data = try? encoder.encode(menuBarPreferences) else { return }
        userDefaults.set(data, forKey: menuBarPreferencesKey)
    }
}