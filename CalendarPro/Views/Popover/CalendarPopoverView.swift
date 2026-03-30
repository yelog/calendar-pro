import SwiftUI
import EventKit

struct CalendarPopoverView: View {
    let displayedMonth: Date
    let weekdaySymbols: [String]
    let monthDays: [CalendarDay]
    let showEvents: Bool
    let selectedDate: Date?
    let events: [EKEvent]
    let isLoadingEvents: Bool
    let onPreviousMonth: () -> Void
    let onNextMonth: () -> Void
    let onSelectDate: (Date) -> Void
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
                monthDays: monthDays,
                onSelectDate: onSelectDate
            )
            
            if showEvents, let date = selectedDate {
                Divider()
                    .padding(.horizontal, -16)
                
                EventListView(events: events, isLoading: isLoadingEvents)
                    .frame(maxHeight: 200)
            }
            
            Divider()
                .padding(.horizontal, -16)
            
            HStack {
                Button {
                    NSApp.sendAction(#selector(AppDelegate.openSettings), to: nil, from: nil)
                } label: {
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
        .frame(width: 340)
        .fixedSize(horizontal: false, vertical: true)
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