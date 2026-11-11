import Combine
import Foundation

@MainActor
final class RegionSettingsViewModel: ObservableObject {
    struct HolidaySetOption: Equatable, Identifiable {
        let id: String
        let displayName: String
        let isEnabled: Bool
    }

    struct RegionOption: Equatable, Identifiable {
        let id: String
        let displayName: String
        let isEnabled: Bool
        let holidaySets: [HolidaySetOption]
    }

    @Published private(set) var availableRegions: [RegionOption] = []
    @Published private(set) var refreshStatusMessage: String = ""
    @Published private(set) var isRefreshingFeed = false

    private let store: SettingsStore
    private let registry: HolidayProviderRegistry
    private let feedClient: HolidayFeedClient?
    private let refreshScheduler: HolidayFeedRefreshScheduler?
    private let cacheStore: HolidayCacheStore
    private var cancellables = Set<AnyCancellable>()

    init(
        store: SettingsStore,
        registry: HolidayProviderRegistry = .default,
        feedClient: HolidayFeedClient? = nil,
        refreshScheduler: HolidayFeedRefreshScheduler? = nil,
        cacheStore: HolidayCacheStore = .default
    ) {
        self.store = store
        self.registry = registry
        self.feedClient = feedClient
        self.refreshScheduler = refreshScheduler
        self.cacheStore = cacheStore
        refreshStatusMessage = Self.makeRefreshStatus(cacheStore: cacheStore, feedClient: feedClient)

        store.$menuBarPreferences
            .sink { [weak self] preferences in
                self?.rebuild(from: preferences)
            }
            .store(in: &cancellables)

        if let refreshScheduler {
            refreshScheduler.$latestOutcome
                .compactMap { $0 }
                .sink { [weak self] outcome in
                    self?.apply(outcome)
                }
                .store(in: &cancellables)
        }

        rebuild(from: store.menuBarPreferences)
    }

    func setRegionEnabled(_ isEnabled: Bool, regionID: String) {
        store.setRegionEnabled(isEnabled, regionID: regionID)
    }

    func setHolidaySetEnabled(_ isEnabled: Bool, holidaySetID: String) {
        store.setHolidaySetEnabled(isEnabled, holidaySetID: holidaySetID, allKnownSetIDs: allKnownHolidaySetIDs)
    }

    var canRefreshRemoteFeed: Bool {
        refreshScheduler != nil || feedClient != nil
    }

    func refreshHolidayFeed() async {
        guard canRefreshRemoteFeed else {
            refreshStatusMessage = Self.makeRefreshStatus(cacheStore: cacheStore, feedClient: nil)
            return
        }

        isRefreshingFeed = true
        defer { isRefreshingFeed = false }

        do {
            let result: HolidayFeedClient.RefreshResult
            if let refreshScheduler {
                result = try await refreshScheduler.refresh(force: true)
            } else if let feedClient {
                result = try await feedClient.refreshIfNeeded(force: true)
            } else {
                refreshStatusMessage = Self.makeRefreshStatus(cacheStore: cacheStore, feedClient: nil)
                return
            }

            refreshStatusMessage = Self.makeRefreshStatus(from: result)
            if result.didUpdatePayloads, refreshScheduler == nil {
                store.noteHolidayDataUpdated()
            }
        } catch {
            refreshStatusMessage = Self.makeRefreshStatus(
                cacheStore: cacheStore,
                feedClient: feedClient,
                errorDescription: error.localizedDescription
            )
        }
    }

    private func apply(_ outcome: HolidayFeedRefreshScheduler.Outcome) {
        switch outcome {
        case let .success(result):
            refreshStatusMessage = Self.makeRefreshStatus(from: result)
        case let .failure(message):
            refreshStatusMessage = Self.makeRefreshStatus(
                cacheStore: cacheStore,
                feedClient: feedClient,
                errorDescription: message
            )
        }
    }

    private var allKnownHolidaySetIDs: [String] {
        registry.providers.flatMap { $0.descriptor.availableHolidaySets.map(\.id) }
    }

    private func rebuild(from preferences: MenuBarPreferences) {
        let explicitEnabledSets = Set(preferences.enabledHolidayIDs)
        let useExplicitSets = !preferences.enabledHolidayIDs.isEmpty

        availableRegions = registry.providers.map { provider in
            RegionOption(
                id: provider.descriptor.id,
                displayName: provider.descriptor.displayName,
                isEnabled: preferences.activeRegionIDs.contains(provider.descriptor.id),
                holidaySets: provider.descriptor.availableHolidaySets.map { holidaySet in
                    HolidaySetOption(
                        id: holidaySet.id,
                        displayName: holidaySet.displayName,
                        isEnabled: useExplicitSets ? explicitEnabledSets.contains(holidaySet.id) : true
                    )
                }
            )
        }
    }

    private static func makeRefreshStatus(
        cacheStore: HolidayCacheStore,
        feedClient: HolidayFeedClient?,
        errorDescription: String? = nil
    ) -> String {
        if let cachedManifest = try? cacheStore.cachedManifest() {
            if errorDescription == nil {
                return LF("Using cached holiday data v%@", cachedManifest.version)
            }
            return LF("Using cached holiday data v%@, remote refresh failed", cachedManifest.version)
        }

        if errorDescription != nil {
            return L("Remote refresh failed, using bundled holiday data")
        }

        if feedClient == nil {
            return L("No remote holiday source configured")
        }

        return L("Using bundled holiday data")
    }

    private static func makeRefreshStatus(from result: HolidayFeedClient.RefreshResult) -> String {
        switch result.source {
        case .remote:
            if result.didUpdatePayloads {
                return LF("Refreshed remote holiday data v%@", result.manifestVersion)
            }
            return LF("Remote holiday data unchanged v%@", result.manifestVersion)
        case .cache:
            if result.fallbackReason != nil {
                return LF("Using cached holiday data v%@, remote refresh failed", result.manifestVersion)
            }
            return LF("Using cached holiday data v%@", result.manifestVersion)
        }
    }

    static var preview: RegionSettingsViewModel {
        let suiteName = "RegionSettingsViewModel.preview"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        let cacheURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CalendarProPreviewCache", isDirectory: true)
        return RegionSettingsViewModel(
            store: SettingsStore(userDefaults: userDefaults),
            cacheStore: HolidayCacheStore(baseURL: cacheURL)
        )
    }
}
