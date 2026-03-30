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
        objectWillChange.send()
        menuBarPreferences.tokens[index].isEnabled = isEnabled
        persistMenuBarPreferences()
    }

    func setTokenStyle(_ style: DisplayTokenStyle, for token: DisplayTokenKind) {
        guard let index = menuBarPreferences.tokens.firstIndex(where: { $0.token == token }) else { return }
        objectWillChange.send()
        menuBarPreferences.tokens[index].style = style
        persistMenuBarPreferences()
    }

    func setTimeShowsSeconds(_ showsSeconds: Bool) {
        guard let index = menuBarPreferences.tokens.firstIndex(where: { $0.token == .time }) else { return }
        objectWillChange.send()
        menuBarPreferences.tokens[index].showsSeconds = showsSeconds
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

        objectWillChange.send()
        menuBarPreferences.tokens = reordered
        persistMenuBarPreferences()
    }

    func setSeparator(_ separator: String) {
        objectWillChange.send()
        menuBarPreferences.separator = separator
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

        objectWillChange.send()
        menuBarPreferences.activeRegionIDs = activeRegions
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

        objectWillChange.send()
        if enabledSetIDs.count == allKnownSetIDs.count {
            menuBarPreferences.enabledHolidayIDs = []
        } else {
            menuBarPreferences.enabledHolidayIDs = allKnownSetIDs.filter { enabledSetIDs.contains($0) }
        }
        persistMenuBarPreferences()
    }

    func noteHolidayDataUpdated() {
        holidayDataRevision += 1
    }

    func setShowEvents(_ show: Bool) {
        objectWillChange.send()
        menuBarPreferences.showEvents = show
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
        objectWillChange.send()
        menuBarPreferences.enabledCalendarIDs = ids
        persistMenuBarPreferences()
    }

    private func persistMenuBarPreferences() {
        guard let data = try? encoder.encode(menuBarPreferences) else { return }
        userDefaults.set(data, forKey: menuBarPreferencesKey)
    }
}
