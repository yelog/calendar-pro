import SwiftUI

@main
struct CalendarProApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // 设置窗口由 AppDelegate.openSettings() 手动管理，
        // 避免 SwiftUI Settings 场景自行控制窗口位置。
        Settings { EmptyView() }
    }
}
