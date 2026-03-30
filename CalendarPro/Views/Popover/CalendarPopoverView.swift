import SwiftUI
import EventKit

struct CalendarPopoverView: View {
    let displayedMonth: Date
    let displayedYear: Int
    let displayedMonthNumber: Int
    let currentYear: Int
    let currentMonthNumber: Int
    let selectionMode: CalendarPopoverViewModel.SelectionMode
    let weekdaySymbols: [String]
    let monthDays: [CalendarDay]
    let showEvents: Bool
    let selectedDate: Date?
    let items: [CalendarItem]
    let selectedEventIdentifier: String?
    let isLoadingEvents: Bool
    let onPreviousMonth: () -> Void
    let onNextMonth: () -> Void
    let onSelectYear: () -> Void
    let onSelectMonth: () -> Void
    let onSelectYearValue: (Int) -> Void
    let onSelectMonthValue: (Int) -> Void
    let onDismissPicker: () -> Void
    let onSelectDate: (Date) -> Void
    let onSelectEvent: (EKEvent) -> Void
    let onToggleReminder: (EKReminder) -> Void
    let onResetToToday: () -> Void
    let onQuit: () -> Void

    var body: some View {
        mainPanel
            .frame(width: PopoverSurfaceMetrics.width)
            .fixedSize(horizontal: false, vertical: true)
            .background(popoverBackground)
    }

    private var mainPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch selectionMode {
            case .calendar:
                calendarView
            case .year:
                YearPickerView(
                    displayedYear: displayedYear,
                    currentYear: currentYear,
                    onSelectYear: onSelectYearValue,
                    onDismiss: onDismissPicker
                )
            case .month:
                MonthPickerView(
                    displayedYear: displayedYear,
                    displayedMonth: displayedMonthNumber,
                    currentMonth: currentMonthNumber,
                    onSelectMonth: onSelectMonthValue,
                    onDismiss: onDismissPicker,
                    onEnterYearSelection: onSelectYear
                )
            }
        }
        .padding(.horizontal, PopoverSurfaceMetrics.outerPadding)
        .padding(.vertical, 12)
    }

    private var calendarView: some View {
        VStack(alignment: .leading, spacing: 8) {
            MonthHeaderView(
                displayedMonth: displayedMonth,
                onPreviousMonth: onPreviousMonth,
                onNextMonth: onNextMonth,
                onSelectYear: onSelectYear,
                onSelectMonth: onSelectMonth
            )

            CalendarGridView(
                weekdaySymbols: weekdaySymbols,
                monthDays: monthDays,
                onSelectDate: onSelectDate
            )

            eventsSection

            Divider()
                .padding(.horizontal, -PopoverSurfaceMetrics.outerPadding)

            footerButtons
        }
    }

    private var footerButtons: some View {
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

    @ViewBuilder
    private var eventsSection: some View {
        if showEvents, let date = selectedDate {
            Divider()
                .padding(.horizontal, -PopoverSurfaceMetrics.outerPadding)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formattedSelectedDate(date))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))

                        Text(eventSummaryText)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                EventListView(
                    items: items,
                    isLoading: isLoadingEvents,
                    selectedDate: date,
                    selectedEventIdentifier: selectedEventIdentifier,
                    onSelectEvent: onSelectEvent,
                    onToggleReminder: onToggleReminder
                )
                .frame(maxHeight: 200)
            }
        }
    }

    private var eventSummaryText: String {
        if isLoadingEvents {
            return "正在加载日程..."
        }

        if items.isEmpty {
            return "当天无日程"
        }

        let eventCount = items.reduce(into: 0) { count, item in
            if case .event = item {
                count += 1
            }
        }

        if eventCount == 0 {
            return "\(items.count) 条提醒事项"
        }

        if eventCount == items.count {
            return "\(eventCount) 条日程，点击查看详情"
        }

        return "\(items.count) 个项目，其中 \(eventCount) 条日程可查看详情"
    }

    private func formattedSelectedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("M月d日 EEEE")
        return formatter.string(from: date)
    }

    private var popoverBackground: some View {
        LinearGradient(
            colors: [
                Color(nsColor: .windowBackgroundColor),
                Color.accentColor.opacity(0.04)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}