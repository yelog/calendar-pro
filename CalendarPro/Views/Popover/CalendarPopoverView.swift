import SwiftUI
import EventKit

enum CalendarPopoverEventCountFormatter {
    static func text(isLoadingEvents: Bool, itemCount: Int) -> String {
        if isLoadingEvents {
            return "加载中"
        }

        return "\(itemCount) 项"
    }
}

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
    let emptyStateText: String
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
    let onOpenReminder: (EKReminder) -> Void
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
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(",", modifiers: .command)

            Spacer()

            Button(action: onResetToToday) {
                Label("今日", systemImage: "calendar")
                    .font(.system(size: 12))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut("t", modifiers: .command)

            Spacer()

            Button(action: onQuit) {
                Label("退出", systemImage: "power")
                    .font(.system(size: 12))
                    .contentShape(Rectangle())
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
                    Text(formattedSelectedDate(date))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .lineLimit(1)

                    Spacer(minLength: 12)

                    Text(eventCountText)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize()
                }

                EventListView(
                    items: items,
                    isLoading: isLoadingEvents,
                    emptyStateText: emptyStateText,
                    selectedDate: date,
                    selectedEventIdentifier: selectedEventIdentifier,
                    onSelectEvent: onSelectEvent,
                    onToggleReminder: onToggleReminder,
                    onOpenReminder: onOpenReminder
                )
                .frame(maxHeight: 200)
            }
        }
    }

    private var eventCountText: String {
        CalendarPopoverEventCountFormatter.text(
            isLoadingEvents: isLoadingEvents,
            itemCount: items.count
        )
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
