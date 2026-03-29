import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Calendar Pro")
                .font(.title2.weight(.semibold))

            Text("原生 macOS 菜单栏日历，支持月历面板、农历、地区化节假日和调休展示。")
                .foregroundStyle(.secondary)

            GroupBox("当前状态") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("启用地区：\(store.menuBarPreferences.activeRegionIDs.joined(separator: "、"))")
                    Text("菜单栏分隔符：\"\(store.menuBarPreferences.separator)\"")
                    Text("已启用显示项：\(enabledTokenNames.joined(separator: "、"))")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()
        }
        .padding(20)
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
