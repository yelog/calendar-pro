import SwiftUI

enum SettingsSidebarItem: String, CaseIterable, Identifiable {
    case general = "通用"
    case menuBar = "菜单栏"
    case events = "日程"
    case region = "地区与节假日"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .menuBar: return "menubar.rectangle"
        case .events: return "calendar.badge.clock"
        case .region: return "globe"
        }
    }

    var title: String { rawValue }
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
        NavigationSplitView {
            List(SettingsSidebarItem.allCases, selection: $selectedItem) { item in
                Label(item.title, systemImage: item.icon)
            }
            .navigationSplitViewColumnWidth(180)
            .listStyle(.sidebar)
        } detail: {
            detailView
        }
        .frame(width: 680, height: 460)
        .onAppear {
            eventService.checkAuthorizationStatus()
            eventService.fetchCalendars()
        }
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
        }
    }
}