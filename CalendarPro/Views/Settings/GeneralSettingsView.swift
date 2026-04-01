import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var store: SettingsStore
    private let renderer = ClockRenderService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GroupBox("菜单栏当前效果") {
                    Text(previewText)
                        .font(.system(.body, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                LazyVGrid(columns: summaryColumns, spacing: 14) {
                    SettingsSummaryCard(
                        title: "启用地区",
                        value: activeRegionSummary,
                        caption: "当前共 \(store.menuBarPreferences.activeRegionIDs.count) 个地区处于启用状态",
                        systemImage: "globe"
                    )

                    SettingsSummaryCard(
                        title: "显示项",
                        value: "\(enabledTokenNames.count) 项",
                        caption: enabledTokenNames.isEmpty ? "当前菜单栏没有启用显示项" : enabledTokenNames.joined(separator: "、"),
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

                GroupBox("当前状态") {
                    VStack(alignment: .leading, spacing: 12) {
                        SettingsStatusRow(label: "启用地区", value: activeRegionSummary)
                        SettingsStatusRow(label: "菜单栏分隔符", value: separatorSummary)
                        SettingsStatusRow(label: "已启用显示项", value: enabledTokenNames.isEmpty ? "无" : enabledTokenNames.joined(separator: "、"))
                        SettingsStatusRow(label: "日历面板", value: eventSummary)
                        SettingsStatusRow(label: "开机启动", value: store.launchAtLoginStatus.summaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 24)
        }
    }

    private var summaryColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14)
        ]
    }

    private var previewText: String {
        let now = Date()
        let factory = CalendarDayFactory(calendar: .autoupdatingCurrent, registry: .live)
        let day = try? factory.makeDay(for: now, displayedMonth: now, preferences: store.menuBarPreferences)

        return renderer.render(
            now: now,
            preferences: store.menuBarPreferences,
            supplementalText: MenuBarSupplementalText(
                lunarText: day?.lunarText,
                holidayText: day?.badges.first?.text
            )
        )
    }

    private var activeRegionSummary: String {
        let ids = store.menuBarPreferences.activeRegionIDs
        return ids.isEmpty ? "未启用" : ids.joined(separator: "、")
    }

    private var separatorSummary: String {
        let separator = store.menuBarPreferences.separator
        return separator.isEmpty ? "无分隔符" : "\"\(separator)\""
    }

    private var eventSummary: String {
        let showEvents = store.menuBarPreferences.showEvents ? "日程开" : "日程关"
        let showReminders = store.menuBarPreferences.showReminders ? "提醒开" : "提醒关"
        return "\(showEvents) / \(showReminders)"
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

private struct SettingsStatusRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 84, alignment: .leading)

            Text(value)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }
}
