import SwiftUI

struct RegionSettingsView: View {
    @ObservedObject var viewModel: RegionSettingsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("节假日数据") {
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
                                    Text("手动刷新")
                                }
                            }
                            .disabled(!viewModel.canRefreshRemoteFeed || viewModel.isRefreshingFeed)

                            Text(viewModel.canRefreshRemoteFeed ? "远程更新失败时会回退到缓存。" : "需要配置远程 manifest 地址后才可手动刷新。")
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
                                "启用 \(region.displayName)",
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
            .padding(20)
        }
    }
}
