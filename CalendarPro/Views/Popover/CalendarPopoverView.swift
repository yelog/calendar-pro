import SwiftUI
import EventKit

enum CalendarPopoverEventCountFormatter {
    static func text(isLoadingEvents: Bool, itemCount: Int) -> String {
        if isLoadingEvents {
            return String(localized: "Loading")
        }

        return String(localized: "%d items", defaultValue: "\(itemCount) 项")
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
    let weekendIndices: Set<Int>
    let monthDays: [CalendarDay]
    let highlightWeekends: Bool
    let showEvents: Bool
    let emptyStateText: String
    let selectedDate: Date?
    let items: [CalendarItem]
    let selectedEventIdentifier: String?
    let isLoadingEvents: Bool
    let almanac: AlmanacDescriptor?
    let showAlmanac: Bool
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
                highlightWeekends: highlightWeekends,
                weekendIndices: weekendIndices,
                onSelectDate: onSelectDate
            )

            infoStripsSection

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
                Label(String(localized: "Settings"), systemImage: "gearshape")
                    .font(.system(size: 12))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(",", modifiers: .command)

            Spacer()

            Button(action: onResetToToday) {
                Label(String(localized: "Today Nav"), systemImage: "calendar")
                    .font(.system(size: 12))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut("t", modifiers: .command)

            Spacer()

            Button(action: onQuit) {
                Label(String(localized: "Quit"), systemImage: "power")
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

    @ViewBuilder
    private var infoStripsSection: some View {
        if showAlmanac {
            Divider()
                .padding(.horizontal, -PopoverSurfaceMetrics.outerPadding)

            VStack(spacing: 6) {
                if showAlmanac, let almanac {
                    AlmanacStripView(almanac: almanac)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
        formatter.setLocalizedDateFormatFromTemplate("MMMdEEEE")
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
