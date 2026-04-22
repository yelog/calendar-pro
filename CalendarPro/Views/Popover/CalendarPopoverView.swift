import SwiftUI
import EventKit

enum CalendarPopoverEventCountFormatter {
    static func text(
        isLoadingEvents: Bool,
        itemCount: Int,
        activeTimedItemIndex: Int? = nil,
        timedItemCount: Int = 0
    ) -> String {
        if isLoadingEvents {
            return L("Loading")
        }

        if let activeIndex = activeTimedItemIndex, timedItemCount > 0 {
            return LF("Item %1$d of %2$d", activeIndex, timedItemCount)
        }

        return LF("%d items", itemCount)
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
    let timeRefreshCoordinator: TimeRefreshCoordinator
    let almanac: AlmanacDescriptor?
    let showAlmanac: Bool
    let showVacationGuideButton: Bool
    let isVacationGuideEnabled: Bool
    let vacationGuideDisabledReason: String?
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
    let onOpenVacationGuide: () -> Void
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
                showVacationGuideButton: showVacationGuideButton,
                isVacationGuideEnabled: isVacationGuideEnabled,
                vacationGuideDisabledReason: vacationGuideDisabledReason,
                onPreviousMonth: onPreviousMonth,
                onNextMonth: onNextMonth,
                onSelectYear: onSelectYear,
                onSelectMonth: onSelectMonth,
                onOpenVacationGuide: onOpenVacationGuide,
                onResetToToday: onResetToToday
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
                Label(L("Settings"), systemImage: "gearshape")
                    .font(.system(size: 12))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(",", modifiers: .command)

            Spacer()

            Button(action: onQuit) {
                Label(L("Quit"), systemImage: "power")
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
                    timeRefreshCoordinator: timeRefreshCoordinator,
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
        if shouldShowAlmanacStrip, let almanac {
            Divider()
                .padding(.horizontal, -PopoverSurfaceMetrics.outerPadding)

            VStack(spacing: 6) {
                AlmanacStripView(almanac: almanac)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var shouldShowAlmanacStrip: Bool {
        showAlmanac && (almanac?.hasContent ?? false)
    }

    private var eventCountText: String {
        let activeInfo = EventTimelineSnapshot.activeTimedItemInfo(
            items: items,
            selectedDate: selectedDate,
            now: timeRefreshCoordinator.currentDate
        )
        return CalendarPopoverEventCountFormatter.text(
            isLoadingEvents: isLoadingEvents,
            itemCount: items.count,
            activeTimedItemIndex: activeInfo.activeIndex,
            timedItemCount: activeInfo.timedCount
        )
    }

    private func formattedSelectedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLocalization.locale
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
