import SwiftUI

struct RegionSettingsView: View {
    @ObservedObject var viewModel: RegionSettingsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox(String(localized: "Holiday Data")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(viewModel.refreshStatusMessage)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            Button {
                                Task {
                                    await viewModel.refreshHolidayFeed()
                                }
                            } label: {
                                if viewModel.isRefreshingFeed {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Text(String(localized: "Manual Refresh"))
                                }
                            }
                            .disabled(!viewModel.canRefreshRemoteFeed || viewModel.isRefreshingFeed)

                            Text(viewModel.canRefreshRemoteFeed ? String(localized: "Cache fallback") : String(localized: "No remote configured"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                ForEach(viewModel.availableRegions) { region in
                    GroupBox(region.displayName) {
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle(
                                String(format: String(localized: "Enable %@"), region.displayName),
                                isOn: Binding(
                                    get: { region.isEnabled },
                                    set: { viewModel.setRegionEnabled($0, regionID: region.id) }
                                )
                            )

                            if region.isEnabled {
                                Divider()

                                ForEach(region.holidaySets) { holidaySet in
                                    Toggle(
                                        holidaySet.displayName,
                                        isOn: Binding(
                                            get: { holidaySet.isEnabled },
                                            set: { viewModel.setHolidaySetEnabled($0, holidaySetID: holidaySet.id) }
                                        )
                                    )
                                    .toggleStyle(.checkbox)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 24)
        }
    }
}
