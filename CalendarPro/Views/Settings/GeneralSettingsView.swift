import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                GeneralSettingsSection("启动") {
                    GeneralSettingsRow(
                        title: "开机自动启动",
                        description: "登录当前用户后自动启动 Calendar Pro，修改后立即生效。"
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

                GeneralSettingsSection("日历显示") {
                    GeneralSettingsRow(
                        title: "每周起始日",
                        description: "设置月历面板中星期的排列顺序。"
                    ) {
                        Picker("", selection: weekStartBinding) {
                            Text("周一在前").tag(WeekStart.monday)
                            Text("周日在前").tag(WeekStart.sunday)
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 210)
                    }

                    Divider()

                    GeneralSettingsRow(
                        title: "周末高亮显示",
                        description: "将周六、周日的日期数字及标题显示为红色，便于快速区分休息日。"
                    ) {
                        Toggle("", isOn: highlightWeekendsBinding)
                            .labelsHidden()
                    }
                }

                if LocaleFeatureAvailability.showAlmanacFeatures {
                    GeneralSettingsSection("面板信息") {
                        GeneralSettingsRow(
                            title: "显示黄历宜忌",
                            description: "在日历面板中显示当日宜忌，基于本地历法计算，无需网络。"
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

    private var launchAtLoginDetail: String? {
        store.launchAtLoginStatus.detailText
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
