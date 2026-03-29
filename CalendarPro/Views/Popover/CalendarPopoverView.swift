import SwiftUI

struct CalendarPopoverView: View {
    let displayedMonth: Date
    let weekdaySymbols: [String]
    let monthDays: [CalendarDay]
    let regionSummary: String
    let onPreviousMonth: () -> Void
    let onNextMonth: () -> Void
    let onResetToToday: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            MonthHeaderView(
                displayedMonth: displayedMonth,
                onPreviousMonth: onPreviousMonth,
                onNextMonth: onNextMonth
            )

            CalendarGridView(
                weekdaySymbols: weekdaySymbols,
                monthDays: monthDays
            )

            Text(regionSummary)
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()
                .padding(.horizontal, -16)

            HStack {
                SettingsLink {
                    Label("设置", systemImage: "gearshape")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(",", modifiers: .command)

                Spacer()

                Button(action: onResetToToday) {
                    Label("今日", systemImage: "calendar")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .keyboardShortcut("t", modifiers: .command)

                Spacer()

                Button(action: onQuit) {
                    Label("退出", systemImage: "power")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(.secondary)
            .padding(.bottom, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: 340, height: 400)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color.accentColor.opacity(0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}
