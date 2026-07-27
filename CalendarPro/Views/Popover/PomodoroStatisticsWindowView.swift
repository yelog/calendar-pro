import SwiftUI

struct PomodoroStatisticsWindowView: View {
    @ObservedObject var statsStore: PomodoroStatsStore
    let onClose: () -> Void

    var body: some View {
        PomodoroStatisticsPanelView(
            todaySummary: statsStore.summary(forRecentDays: 1),
            sevenDaySummary: statsStore.summary(forRecentDays: 7),
            onClose: onClose
        )
        .frame(
            width: PomodoroStatisticsWindowController.panelSize.width,
            height: PomodoroStatisticsWindowController.panelSize.height
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.24), lineWidth: 1)
        }
    }
}
