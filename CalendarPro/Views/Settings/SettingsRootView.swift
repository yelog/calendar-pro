import SwiftUI

struct SettingsRootView: View {
    @ObservedObject var store: SettingsStore
    @ObservedObject var eventService: EventService
    @StateObject private var regionViewModel: RegionSettingsViewModel
    
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
        .frame(width: 680, height: 460)
        .onAppear {
            eventService.checkAuthorizationStatus()
            eventService.fetchCalendars()
        }
    }
}