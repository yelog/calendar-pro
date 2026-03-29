import SwiftUI

struct CalendarPopoverView: View {
    let displayedMonth: Date
    let weekdaySymbols: [String]
    let monthDays: [CalendarDay]
    let regionSummary: String
    let onPreviousMonth: () -> Void
    let onNextMonth: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
        }
        .padding(16)
        .frame(width: 340, height: 320, alignment: .topLeading)
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
