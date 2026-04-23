import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                GeneralSettingsSection(L("Launch")) {
                    GeneralSettingsRow(
                        title: L("App Language"),
                        description: L("App Language Description")
                    ) {
                        Picker("", selection: appLanguageBinding) {
                            Text(L("Follow System")).tag(AppLanguage.followSystem)
                            Text(L("Simplified Chinese")).tag(AppLanguage.simplifiedChinese)
                            Text(L("English")).tag(AppLanguage.english)
                        }
                        .labelsHidden()
                        .frame(width: 210)
                    }

                    Divider()

                    GeneralSettingsRow(
                        title: L("Launch at Login"),
                        description: L("Launch at Login Description")
                    ) {
                        Toggle("", isOn: launchAtLoginBinding)
                            .labelsHidden()
                    } detail: {
                        VStack(alignment: .leading, spacing: 6) {
                            if let detail = launchAtLoginDetail {
                                Text(detail)
                            }

                            if let statusMessage = store.launchAtLoginStatusMessage {
                                Text(statusMessage)
                                    .foregroundStyle(.red)
                            }
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }

                GeneralSettingsSection(L("Calendar Display")) {
                    GeneralSettingsRow(
                        title: L("Week Starts On"),
                        description: L("Week Starts On Description")
                    ) {
                        Picker("", selection: weekStartBinding) {
                            Text(L("Monday First")).tag(WeekStart.monday)
                            Text(L("Sunday First")).tag(WeekStart.sunday)
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 210)
                    }

                    Divider()

                    GeneralSettingsRow(
                        title: L("Highlight Weekends"),
                        description: L("Highlight Weekends Description")
                    ) {
                        Toggle("", isOn: highlightWeekendsBinding)
                            .labelsHidden()
                    }
                }

                if LocaleFeatureAvailability.showAlmanacFeatures {
                    GeneralSettingsSection(L("Panel Info")) {
                        GeneralSettingsRow(
                            title: L("Show Weather"),
                            description: L("Show Weather Description")
                        ) {
                            Toggle("", isOn: showWeatherBinding)
                                .labelsHidden()
                        }

                        if store.menuBarPreferences.showWeather {
                            Divider()

                            WeatherLocationSettings(store: store)
                        }

                        Divider()

                        GeneralSettingsRow(
                            title: L("Show Almanac"),
                            description: L("Show Almanac Description")
                        ) {
                            Toggle("", isOn: showAlmanacBinding)
                                .labelsHidden()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 30)
            .padding(.vertical, 24)
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { store.launchAtLoginEnabled },
            set: { store.setLaunchAtLoginEnabled($0) }
        )
    }

    private var appLanguageBinding: Binding<AppLanguage> {
        Binding(
            get: { store.appLanguage },
            set: { store.setAppLanguage($0) }
        )
    }

    private var weekStartBinding: Binding<WeekStart> {
        Binding(
            get: { store.menuBarPreferences.weekStart },
            set: { store.setWeekStart($0) }
        )
    }

    private var highlightWeekendsBinding: Binding<Bool> {
        Binding(
            get: { store.menuBarPreferences.highlightWeekends },
            set: { store.setHighlightWeekends($0) }
        )
    }

    private var showAlmanacBinding: Binding<Bool> {
        Binding(
            get: { store.menuBarPreferences.showAlmanac },
            set: { store.setShowAlmanac($0) }
        )
    }

    private var showWeatherBinding: Binding<Bool> {
        Binding(
            get: { store.menuBarPreferences.showWeather },
            set: { store.setShowWeather($0) }
        )
    }

    private var launchAtLoginDetail: String? {
        store.launchAtLoginStatus.detailText
    }

}

private struct WeatherLocationSettings: View {
    @ObservedObject var store: SettingsStore
    @State private var searchText = ""
    @State private var searchResults: [CitySearchResult] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    private let citySearchService = CitySearchService()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeneralSettingsRow(
                title: L("Location Source"),
                description: L("Location Source Description")
            ) {
                Picker("", selection: locationModeBinding) {
                    Text(L("Automatic")).tag(LocationMode.automatic)
                    Text(L("Manual")).tag(LocationMode.manual)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 210)
            }

            if store.menuBarPreferences.locationMode == .manual {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        TextField(L("Search city…"), text: $searchText)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))
                            .onSubmit { performSearch() }

                        Button {
                            performSearch()
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.bordered)
                        .disabled(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearching)
                    }

                    if isSearching {
                        ProgressView()
                            .controlSize(.small)
                    }

                    if !searchResults.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(searchResults) { result in
                                Button {
                                    store.setManualLocation(result.toWeatherLocation)
                                    searchResults = []
                                    searchText = ""
                                } label: {
                                    HStack {
                                        Text(result.displayName)
                                            .font(.system(size: 12))
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        if isSelected(result) {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundStyle(.blue)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(isSelected(result) ? Color.accentColor.opacity(0.08) : Color.clear)
                                )
                            }
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 2)
                    }

                    if let location = store.menuBarPreferences.manualLocation {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            Text(locationLabel(location))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.leading, 16)
            }
        }
    }

    private func locationLabel(_ location: WeatherLocation) -> String {
        L("Current: %@").replacingOccurrences(of: "%@", with: location.name)
    }

    private func performSearch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        searchTask?.cancel()
        searchTask = Task {
            isSearching = true
            let results = await citySearchService.search(query: query)
            guard !Task.isCancelled else { return }
            isSearching = false
            searchResults = results
        }
    }

    private func isSelected(_ result: CitySearchResult) -> Bool {
        guard let location = store.menuBarPreferences.manualLocation else { return false }
        return abs(result.latitude - location.latitude) < 0.001
            && abs(result.longitude - location.longitude) < 0.001
    }

    private var locationModeBinding: Binding<LocationMode> {
        Binding(
            get: { store.menuBarPreferences.locationMode },
            set: { store.setLocationMode($0) }
        )
    }
}

private struct GeneralSettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.52))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.22), lineWidth: 1)
            )
        }
    }
}

private struct GeneralSettingsRow<Control: View, Detail: View>: View {
    let title: String
    let description: String
    @ViewBuilder let control: Control
    @ViewBuilder let detail: Detail

    init(
        title: String,
        description: String,
        @ViewBuilder control: () -> Control,
        @ViewBuilder detail: () -> Detail = { EmptyView() }
    ) {
        self.title = title
        self.description = description
        self.control = control()
        self.detail = detail()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))

                    Text(description)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 16)

                control
            }

            detail
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
