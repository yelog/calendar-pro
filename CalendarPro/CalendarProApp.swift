import SwiftUI

@main
struct CalendarProApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsRootView(store: appDelegate.settingsStore, eventService: appDelegate.eventService)
        }
    }
}
