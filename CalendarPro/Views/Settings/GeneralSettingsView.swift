import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var store: SettingsStore
    @State private var availableWidth: CGFloat = .zero

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                LazyVGrid(columns: summaryColumns(for: availableWidth), spacing: 14) {
                    SettingsSummaryCard(
                        title: "启用地区",
                        value: activeRegionSummary,
                        caption: "当前共 \(store.menuBarPreferences.activeRegionIDs.count) 个地区处于启用状态",
                        systemImage: "globe"
                    )

                    SettingsSummaryCard(
                        title: "显示项",
                        value: "\(enabledTokenNames.count) 项",
                        caption: displayItemsCaption,
                        systemImage: "textformat"
                    )

                    SettingsSummaryCard(
                        title: "日程与提醒",
                        value: eventSummary,
                        caption: "决定面板中是否展示日程与提醒事项",
                        systemImage: "calendar"
                    )

                    SettingsSummaryCard(
                        title: "每周起始",
                        value: weekStartSummary,
                        caption: "影响月历面板中的星期排列方式",
                        systemImage: "rectangle.grid.2x2"
                    )

                    SettingsSummaryCard(
                        title: "开机启动",
                        value: store.launchAtLoginStatus.summaryText,
                        caption: launchAtLoginSummaryCaption,
                        systemImage: "power.circle"
                    )
                }

                GroupBox("启动行为") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("开机自动启动 Calendar Pro", isOn: launchAtLoginBinding)

                        Text("开机并登录当前用户后自动启动，修改后立即生效。")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if let detail = launchAtLoginDetail {
                            Text(detail)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if let statusMessage = store.launchAtLoginStatusMessage {
                            Text(statusMessage)
                                .font(.system(size: 11))
                                .foregroundStyle(.red)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("日历显示") {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("每周起始日", selection: weekStartBinding) {
                            Text("周一在前").tag(WeekStart.monday)
                            Text("周日在前").tag(WeekStart.sunday)
                        }
                        .pickerStyle(.segmented)

                        Text("设置月历面板中星期的排列顺序，修改后立即生效。")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Divider()

                        Toggle("周末高亮显示", isOn: highlightWeekendsBinding)

                        Text("开启后，周六、周日的日期数字及标题显示为红色，便于区分休息日。")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("面板信息") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("显示黄历宜忌", isOn: showAlmanacBinding)

                        Text("开启后，在日历面板中显示当日宜忌。基于传统历法本地计算，无需网络。")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 30)
            .padding(.vertical, 24)
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: GeneralSettingsContentWidthKey.self, value: proxy.size.width)
                }
            }
        }
        .onPreferenceChange(GeneralSettingsContentWidthKey.self) { availableWidth = $0 }
    }

    private func summaryColumns(for width: CGFloat) -> [GridItem] {
        let columnCount = width > 0 && width < 500 ? 1 : 2
        return Array(
            repeating: GridItem(.flexible(), spacing: 14, alignment: .top),
            count: columnCount
        )
    }

    private var activeRegionSummary: String {
        let ids = store.menuBarPreferences.activeRegionIDs
        return ids.isEmpty ? "未启用" : ids.joined(separator: "、")
    }

    private var displayItemsCaption: String {
        if enabledTokenNames.isEmpty {
            return "当前菜单栏没有启用显示项"
        }
        let separator = store.menuBarPreferences.separator
        let separatorText = separator.isEmpty ? "" : "，分隔符 \"\(separator)\""
        return enabledTokenNames.joined(separator: "、") + separatorText
    }

    private var eventSummary: String {
        store.menuBarPreferences.eventsSummaryText
    }

    private var weekStartSummary: String {
        switch store.menuBarPreferences.weekStart {
        case .sunday:
            return "周日"
        case .monday:
            return "周一"
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { store.launchAtLoginEnabled },
            set: { store.setLaunchAtLoginEnabled($0) }
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

    private var launchAtLoginSummaryCaption: String {
        launchAtLoginDetail ?? "控制开机后是否自动启动应用"
    }

    private var launchAtLoginDetail: String? {
        store.launchAtLoginStatus.detailText
    }

    private var enabledTokenNames: [String] {
        store.menuBarPreferences.tokens
            .filter(\.isEnabled)
            .sorted { $0.order < $1.order }
            .map { tokenPreference in
                switch tokenPreference.token {
                case .date:
                    "日期"
                case .time:
                    "时间"
                case .weekday:
                    "星期"
                case .lunar:
                    "农历"
                case .holiday:
                    "节假日"
                }
            }
    }
}

private struct GeneralSettingsContentWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = .zero

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct SettingsSummaryCard: View {
    let title: String
    let value: String
    let caption: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(Color.accentColor.opacity(0.10))
                )

            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 20, weight: .semibold))
                .textSelection(.enabled)

            Text(caption)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.28), lineWidth: 1)
        )
    }
}
