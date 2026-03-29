import SwiftUI

struct SettingsRootView: View {
    @ObservedObject var store: SettingsStore
    @StateObject private var regionViewModel: RegionSettingsViewModel
    @StateObject private var eventService = EventService()
    
    init(store: SettingsStore) {
        self.store = store
        _regionViewModel = StateObject(
            wrappedValue: RegionSettingsViewModel(
                store: store,
                registry: .live,
                feedClient: HolidayFeedClient.configuredClient()
            )
        )
    }
    
    var body: some View {
        TabView {
            GeneralSettingsView(store: store)
                .tabItem { Text("通用") }
            
            MenuBarSettingsView(store: store)
                .tabItem { Text("菜单栏") }
            
            EventsSettingsView(store: store, eventService: eventService)
                .tabItem { Text("日程") }
            
            RegionSettingsView(viewModel: regionViewModel)
                .tabItem { Text("地区与节假日") }
        }
        .frame(width: 480, height: 380)
        .onAppear {
            eventService.checkAuthorizationStatus()
            eventService.fetchCalendars()
        }
    }
}