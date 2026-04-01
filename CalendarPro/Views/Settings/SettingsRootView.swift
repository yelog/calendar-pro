import SwiftUI

enum SettingsSidebarItem: String, CaseIterable, Identifiable {
    case general = "通用"
    case menuBar = "菜单栏"
    case events = "日程"
    case region = "地区与节假日"
    case about = "关于"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .menuBar: return "menubar.rectangle"
        case .events: return "calendar.badge.clock"
        case .region: return "globe"
        case .about: return "info.circle.fill"
        }
    }

    var title: String { rawValue }

    var sidebarDescription: String {
        switch self {
        case .general:
            return "查看当前配置摘要"
        case .menuBar:
            return "调整菜单栏文本与顺序"
        case .events:
            return "管理日历与提醒事项来源"
        case .region:
            return "配置地区与节假日数据"
        case .about:
            return "版本信息与检查更新"
        }
    }

    var detailDescription: String {
        switch self {
        case .general:
            return "集中查看当前设置概览，确认菜单栏、日程和地区能力的启用状态。"
        case .menuBar:
            return "调整菜单栏显示项、分隔符、排序与样式，实时预览最终显示效果。"
        case .events:
            return "管理日历与提醒事项访问权限，并选择要在面板中显示的数据来源。"
        case .region:
            return "选择节假日地区数据集，必要时手动刷新远程节假日清单。"
        case .about:
            return "查看应用版本、作者信息，以及检查软件更新。"
        }
    }
}

struct SettingsRootView: View {
    @ObservedObject var store: SettingsStore
    @ObservedObject var eventService: EventService
    @StateObject private var regionViewModel: RegionSettingsViewModel
    @State private var selectedItem: SettingsSidebarItem = .general

    init(store: SettingsStore, eventService: EventService) {
        self.store = store
        self.eventService = eventService
        _regionViewModel = StateObject(
            wrappedValue: RegionSettingsViewModel(
                store: store,
                registry: .live,
                feedClient: HolidayFeedClient.configuredClient()
            )
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            detailPanel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SettingsWindowPalette.windowBackground)
        .onAppear {
            eventService.checkAuthorizationStatus()
            eventService.fetchCalendars()
            if eventService.remindersAuthorized {
                eventService.fetchReminderCalendars()
            }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("设置")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text("Calendar Pro")
                    .font(.system(size: 24, weight: .semibold))

                Text("原生 macOS 菜单栏日历、日程与地区化节假日配置。")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 8) {
                ForEach(SettingsSidebarItem.allCases) { item in
                    Button {
                        selectedItem = item
                    } label: {
                        SettingsSidebarButton(item: item, isSelected: item == selectedItem)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            Text("设置会自动保存，修改后立即生效。")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 22)
        .frame(width: 248)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(SettingsWindowPalette.windowBackground)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(SettingsWindowPalette.separator)
                .frame(width: 1)
        }
    }

    private var detailPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text(selectedItem.title)
                    .font(.system(size: 28, weight: .semibold))

                Text(selectedItem.detailDescription)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 30)
            .padding(.top, 28)
            .padding(.bottom, 18)

            Rectangle()
                .fill(SettingsWindowPalette.separator)
                .frame(height: 1)

            detailView
                .id(selectedItem)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .animation(.easeInOut(duration: 0.16), value: selectedItem)
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedItem {
        case .general:
            GeneralSettingsView(store: store)
        case .menuBar:
            MenuBarSettingsView(store: store)
        case .events:
            EventsSettingsView(store: store, eventService: eventService)
        case .region:
            RegionSettingsView(viewModel: regionViewModel)
        case .about:
            AboutSettingsView()
        }
    }
}

private enum SettingsWindowPalette {
    static var windowBackground: Color { Color(nsColor: .windowBackgroundColor) }
    static var separator: Color { Color(nsColor: .separatorColor).opacity(0.18) }
    static var selectedFill: Color { Color.accentColor.opacity(0.10) }
    static var selectedStroke: Color { Color.accentColor.opacity(0.16) }
    static var iconSelectedFill: Color { Color.accentColor.opacity(0.13) }
    static var iconUnselectedFill: Color { Color.primary.opacity(0.045) }
}

private struct SettingsSidebarButton: View {
    let item: SettingsSidebarItem
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(
                            isSelected
                                ? SettingsWindowPalette.iconSelectedFill
                                : SettingsWindowPalette.iconUnselectedFill
                        )
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(item.sidebarDescription)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    isSelected
                        ? SettingsWindowPalette.selectedFill
                        : Color.clear
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    isSelected
                        ? SettingsWindowPalette.selectedStroke
                        : Color.clear,
                    lineWidth: isSelected ? 1 : 0
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
