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
    @Environment(\.colorScheme) private var colorScheme

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
    let weather: WeatherDescriptor?
    let isLoadingWeather: Bool
    let showWeather: Bool
    let isWeatherDetailPresented: Bool
    let isLoadingWeatherDetails: Bool
    let pomodoroState: PomodoroTimerController.State
    let pomodoroPreferences: PomodoroPreferences
    let showVacationGuideButton: Bool
    let isVacationGuideEnabled: Bool
    let vacationGuideDisabledReason: String?
    let canCreateEvent: Bool
    let canCreateReminder: Bool
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
    let onCreateItem: () -> Void
    let onOpenWeatherDetails: () -> Void
    let onOpenVacationGuide: () -> Void
    let onResetToToday: () -> Void
    let onStartPomodoroFocus: () -> Void
    let onPausePomodoro: () -> Void
    let onResumePomodoro: () -> Void
    let onSkipPomodoro: () -> Void
    let onEndPomodoro: () -> Void
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

            selectedDayInfoSection

            infoStripsSection

            if pomodoroPreferences.isEnabled {
                PomodoroStripView(
                    state: pomodoroState,
                    onStartFocus: onStartPomodoroFocus,
                    onPause: onPausePomodoro,
                    onResume: onResumePomodoro,
                    onSkip: onSkipPomodoro,
                    onEnd: onEndPomodoro
                )
            }

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
                    Text(L("Events"))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .lineLimit(1)

                    Spacer(minLength: 12)

                    Text(eventCountText)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize()

                    creationButton
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
    private var selectedDayInfoSection: some View {
        if let selectedDate, !selectedDayMetadataChips.isEmpty {
            HStack(alignment: .center, spacing: 8) {
                Text(selectedDaySummaryTitle(for: selectedDate))
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                HStack(spacing: 4) {
                    ForEach(selectedDayMetadataChips) { chip in
                        selectedDayMetadataChip(chip)
                    }
                }
                .layoutPriority(1)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, -3)
            .padding(.bottom, 0)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(selectedDayMetadataAccessibilityText))
            .accessibilityIdentifier("calendar-popover-selected-day-metadata")
        }
    }

    private func selectedDayMetadataChip(_ chip: CalendarDayDisplayMetadata.Chip) -> some View {
        Text(chip.text)
            .font(.system(size: chip.style == .status ? 9.5 : 10, weight: .medium, design: .rounded))
            .foregroundStyle(selectedDayMetadataForegroundColor(for: chip.style))
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, chip.style == .status ? 5 : 6)
            .frame(height: chip.style == .status ? 17 : 19)
            .layoutPriority(chip.style == .status ? 0 : 1)
            .background {
                Capsule()
                    .fill(selectedDayMetadataFillColor(for: chip.style))
            }
            .overlay {
                Capsule()
                    .strokeBorder(selectedDayMetadataBorderColor(for: chip.style), lineWidth: 0.5)
            }
    }

    @ViewBuilder
    private var creationButton: some View {
        if canCreateEvent || canCreateReminder {
            Button {
                onCreateItem()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(L("Add"))
            .accessibilityIdentifier("calendar-popover-add-item-button")
        }
    }

    @ViewBuilder
    private var infoStripsSection: some View {
        if shouldShowWeatherStrip || shouldShowAlmanacStrip {
            Divider()
                .padding(.horizontal, -PopoverSurfaceMetrics.outerPadding)
                .opacity(0.55)

            VStack(spacing: 5) {
                if shouldShowWeatherStrip {
                    WeatherStripView(
                        weather: weather,
                        isLoading: isLoadingWeather,
                        requestedDate: selectedDate ?? timeRefreshCoordinator.currentDate,
                        isDetailPresented: isWeatherDetailPresented,
                        isDetailLoading: isLoadingWeatherDetails,
                        onOpenDetails: onOpenWeatherDetails
                    )
                }

                if shouldShowAlmanacStrip, let almanac {
                    AlmanacStripView(almanac: almanac)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var shouldShowWeatherStrip: Bool {
        showWeather && (isLoadingWeather || (weather?.hasContent ?? false))
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

    private var selectedCalendarDay: CalendarDay? {
        guard let selectedDate else { return nil }
        return monthDays.first { Calendar.autoupdatingCurrent.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var selectedDayMetadataChips: [CalendarDayDisplayMetadata.Chip] {
        guard let selectedCalendarDay else { return [] }
        return CalendarDayDisplayMetadata.selectedDayMetadataChips(
            for: selectedCalendarDay,
            offText: L("OFF"),
            workText: L("WRK")
        )
    }

    private var selectedDayMetadataAccessibilityText: String {
        var components: [String] = []
        if let selectedDate {
            components.append(selectedDaySummaryTitle(for: selectedDate))
        }
        components.append(contentsOf: selectedDayMetadataChips.map(\.text))
        return components.joined(separator: ", ")
    }

    private func selectedDayMetadataForegroundColor(for style: CalendarDayDisplayMetadata.Chip.Style) -> Color {
        switch style {
        case .primary:
            return colorScheme == .dark
                ? Color(red: 1.0, green: 0.64, blue: 0.64)
                : Color(red: 0.70, green: 0.20, blue: 0.23)
        case .supplemental:
            return colorScheme == .dark
                ? Color(red: 1.0, green: 0.70, blue: 0.46)
                : Color(red: 0.58, green: 0.32, blue: 0.08)
        case .status:
            return colorScheme == .dark
                ? Color(red: 1.0, green: 0.68, blue: 0.70)
                : Color(red: 0.74, green: 0.19, blue: 0.25)
        }
    }

    private func selectedDayMetadataFillColor(for style: CalendarDayDisplayMetadata.Chip.Style) -> Color {
        switch style {
        case .primary:
            return Color(red: 1.0, green: 0.24, blue: 0.30).opacity(colorScheme == .dark ? 0.13 : 0.07)
        case .supplemental:
            return Color(red: 1.0, green: 0.58, blue: 0.18).opacity(colorScheme == .dark ? 0.12 : 0.07)
        case .status:
            return Color(red: 1.0, green: 0.22, blue: 0.30).opacity(colorScheme == .dark ? 0.16 : 0.08)
        }
    }

    private func selectedDayMetadataBorderColor(for style: CalendarDayDisplayMetadata.Chip.Style) -> Color {
        switch style {
        case .primary:
            return Color(red: 0.88, green: 0.20, blue: 0.26).opacity(colorScheme == .dark ? 0.24 : 0.15)
        case .supplemental:
            return Color(red: 0.86, green: 0.42, blue: 0.04).opacity(colorScheme == .dark ? 0.22 : 0.14)
        case .status:
            return Color(red: 0.88, green: 0.18, blue: 0.26).opacity(colorScheme == .dark ? 0.26 : 0.16)
        }
    }

    private func selectedDaySummaryTitle(for date: Date) -> String {
        CalendarDayDisplayMetadata.selectedDaySummaryTitle(
            for: date,
            calendar: Calendar.autoupdatingCurrent,
            locale: AppLocalization.locale
        )
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
