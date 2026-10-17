import SwiftUI
import EventKit

// Collapsible "All Events" popover section. UpcomingSnapshot groups the
// unified CalendarItem list by day (pure function, unit-testable);
// UpcomingEventsSection renders the collapsible header, day headers and
// items, and wires count-based paging (bottom sentinel auto-loads the next
// future page, the top entry row loads past pages, pagination resets and
// scroll-to-top are driven by the reset generation).
// Inputs: [CalendarItem] assembled per page by RootPopoverView, current
// time (TimeRefreshCoordinator), paging-exhaustion and reset-generation flags.
// Outputs: day-ascending snapshot struct / the section view inside the popover.
// Depends on: EventKit (EKEvent/EKReminder), SwiftUI, AppLocalization (L/LF).

struct UpcomingDayGroup: Identifiable {
    let id: String
    let dayStart: Date
    let headerText: String
    let items: [CalendarItem]
}

struct UpcomingSnapshot {
    let dayGroups: [UpcomingDayGroup]
    let totalItemCount: Int

    /// Groups items by day ascending; all-day items come first within a day.
    static func make(
        items: [CalendarItem],
        now: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> UpcomingSnapshot {
        let placedEntries = items.compactMap { item -> (date: Date, item: CalendarItem)? in
            guard let startDate = item.startDate else { return nil }
            return (startDate, item)
        }

        let sortedEntries = placedEntries.sorted { lhs, rhs in
            let lhsDay = calendar.startOfDay(for: lhs.date)
            let rhsDay = calendar.startOfDay(for: rhs.date)
            if lhsDay != rhsDay {
                return lhsDay < rhsDay
            }
            if lhs.item.isAllDay != rhs.item.isAllDay {
                return lhs.item.isAllDay
            }
            return lhs.date < rhs.date
        }

        var grouped: [(dayStart: Date, items: [CalendarItem])] = []
        for entry in sortedEntries {
            let dayStart = calendar.startOfDay(for: entry.date)
            if let lastIndex = grouped.indices.last,
               calendar.isDate(grouped[lastIndex].dayStart, inSameDayAs: dayStart) {
                grouped[lastIndex].items.append(entry.item)
            } else {
                grouped.append((dayStart, [entry.item]))
            }
        }

        let dayGroups = grouped.map { group in
            UpcomingDayGroup(
                id: String(group.dayStart.timeIntervalSinceReferenceDate),
                dayStart: group.dayStart,
                headerText: dayHeaderText(for: group.dayStart, now: now, calendar: calendar),
                items: group.items
            )
        }

        return UpcomingSnapshot(
            dayGroups: dayGroups,
            totalItemCount: dayGroups.reduce(0) { $0 + $1.items.count }
        )
    }

    private static func dayHeaderText(
        for dayStart: Date,
        now: Date,
        calendar: Calendar
    ) -> String {
        if calendar.isDate(dayStart, inSameDayAs: now) {
            return L("All Today")
        }

        if let yesterday = calendar.date(
            byAdding: .day,
            value: -1,
            to: calendar.startOfDay(for: now)
        ), calendar.isDate(dayStart, inSameDayAs: yesterday) {
            return L("All Yesterday")
        }

        if let tomorrow = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: now)
        ), calendar.isDate(dayStart, inSameDayAs: tomorrow) {
            return L("All Tomorrow")
        }

        let formatter = DateFormatter()
        formatter.locale = AppLocalization.locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = DateFormatter.dateFormat(
            fromTemplate: "Md",
            options: 0,
            locale: AppLocalization.locale
        )
        return formatter.string(from: dayStart)
    }
}

struct UpcomingEventsSection: View {
    private enum Metrics {
        // Content area only (header row excluded); matches the board branch
        // cap so expanding the section never stretches the whole popover
        static let expandedMaxHeight: CGFloat = 240
        // Scroll-to-top anchor id (view-internal only)
        static let topAnchorID = "upcomingEventsTopAnchor"
    }

    let items: [CalendarItem]
    let isLoadingPast: Bool
    let isLoadingFuture: Bool
    let hasMorePast: Bool
    let hasMoreFuture: Bool
    let defaultExpanded: Bool
    // Bumped on every pagination reset; the section scrolls back to its top
    // anchor because data resets leave stale scroll offsets behind
    let resetGeneration: Int
    // Bumped by PopoverController on every show; drives the expansion reset
    // on popover reopen (view instances survive reuse, onAppear does not)
    let presentationGeneration: Int
    let timeRefreshCoordinator: TimeRefreshCoordinator
    let selectedEventIdentifier: String?
    let onLoadMorePast: () -> Void
    let onLoadMoreFuture: () -> Void
    let onSelectEvent: (EKEvent) -> Void
    let onOpenReminder: (EKReminder) -> Void
    let onToggleReminder: (EKReminder) -> Void

    // Expansion state lives in the view: initialized from the default-expanded
    // setting and re-applied on every popover presentation generation bump
    // (view instances survive popover reuse, so State initial values only
    // apply on first creation)
    @State private var isExpanded: Bool

    /// Explicit initializer: inputs are passed through CalendarPopoverView;
    /// `defaultExpanded` seeds the collapse state.
    init(
        items: [CalendarItem],
        isLoadingPast: Bool,
        isLoadingFuture: Bool,
        hasMorePast: Bool,
        hasMoreFuture: Bool,
        defaultExpanded: Bool,
        resetGeneration: Int,
        presentationGeneration: Int,
        timeRefreshCoordinator: TimeRefreshCoordinator,
        selectedEventIdentifier: String?,
        onLoadMorePast: @escaping () -> Void,
        onLoadMoreFuture: @escaping () -> Void,
        onSelectEvent: @escaping (EKEvent) -> Void,
        onOpenReminder: @escaping (EKReminder) -> Void,
        onToggleReminder: @escaping (EKReminder) -> Void
    ) {
        self.items = items
        self.isLoadingPast = isLoadingPast
        self.isLoadingFuture = isLoadingFuture
        self.hasMorePast = hasMorePast
        self.hasMoreFuture = hasMoreFuture
        self.defaultExpanded = defaultExpanded
        self.resetGeneration = resetGeneration
        self.presentationGeneration = presentationGeneration
        self.timeRefreshCoordinator = timeRefreshCoordinator
        self.selectedEventIdentifier = selectedEventIdentifier
        self.onLoadMorePast = onLoadMorePast
        self.onLoadMoreFuture = onLoadMoreFuture
        self.onSelectEvent = onSelectEvent
        self.onOpenReminder = onOpenReminder
        self.onToggleReminder = onToggleReminder
        _isExpanded = State(initialValue: defaultExpanded)
    }

    var body: some View {
        // Single evaluation in body: header count and expanded content share
        // one grouping result, so repeated computed-property access cannot
        // re-sort and re-group per access
        let snapshot = UpcomingSnapshot.make(
            items: items,
            now: timeRefreshCoordinator.currentDate,
            calendar: .autoupdatingCurrent
        )

        return VStack(alignment: .leading, spacing: 8) {
            headerButton(countText: countText(for: snapshot))

            if isExpanded {
                expandedContent(snapshot)
                    .frame(maxHeight: Metrics.expandedMaxHeight)
            }
        }
        // Popover reopen: re-apply the default-expanded setting via the
        // presentation generation (view instances survive popover reuse);
        // pagination resets arrive through RootPopoverView and reach this
        // view as resetGeneration changes
        .onChange(of: presentationGeneration) { _, _ in
            isExpanded = defaultExpanded
        }
    }

    private func headerButton(countText: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))

                Text(L("All Events"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .lineLimit(1)

                Spacer(minLength: 12)

                Text(countText)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("calendar-popover-upcoming-toggle")
    }

    private func countText(for snapshot: UpcomingSnapshot) -> String {
        if isLoadingPast || isLoadingFuture {
            return L("Loading")
        }
        return LF("%d items", snapshot.totalItemCount)
    }

    /// Expanded content: day-grouped scrolling list with count-based paging
    /// (bottom sentinel auto-loads the next future page; past pages load via
    /// the explicit top entry row). The empty-state text stays inside the
    /// ScrollView so the past-direction entry row remains reachable when the
    /// future window is empty.
    @ViewBuilder
    private func expandedContent(_ snapshot: UpcomingSnapshot) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                // LazyVStack over VStack: a plain VStack materializes every
                // child at once, so the bottom sentinel's onAppear would fire
                // the moment the section expands; lazy rendering keeps it a
                // real "scrolled near the bottom" signal
                LazyVStack(alignment: .leading, spacing: 10) {
                    topRow

                    if items.isEmpty, !(isLoadingPast || isLoadingFuture) {
                        emptyStateRow
                    } else {
                        ForEach(snapshot.dayGroups) { group in
                            dayGroupView(group)
                        }
                    }

                    if isLoadingFuture {
                        progressRow
                    } else if hasMoreFuture {
                        loadFutureTrigger
                    }
                }
                .padding(.vertical, 1)
            }
            .onChange(of: resetGeneration) { _, _ in
                // Data resets leave the stale scroll offset behind; scroll
                // back to the top anchor explicitly
                proxy.scrollTo(Metrics.topAnchorID, anchor: .top)
            }
        }
    }

    private var emptyStateRow: some View {
        Text(L("No Events"))
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
    }

    /// List top: the scroll-to-top anchor plus the past-direction row
    /// (progress while loading, otherwise the explicit load-earlier entry
    /// row; rendered only while past pages remain).
    /// macOS ScrollView has no rubber-band overscroll, so the previous
    /// pull-down probe never fired on real hardware — past-direction loading
    /// goes through this clickable row instead of a gesture.
    @ViewBuilder
    private var topRow: some View {
        // scrollTo target for reset-driven scroll-to-top
        Color.clear
            .frame(height: 0)
            .id(Metrics.topAnchorID)

        if isLoadingPast {
            progressRow
        } else if hasMorePast {
            loadEarlierRow
        }
    }

    /// Explicit entry row for loading one past page; replaced by the
    /// progress row while loading and dropped once the past end is
    /// exhausted. Plain Button keeps mouse, trackpad and full-keyboard-access
    /// activation on the same control.
    private var loadEarlierRow: some View {
        Button {
            onLoadMorePast()
        } label: {
            HStack(spacing: 4) {
                Spacer()

                Image(systemName: "chevron.up")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(L("Load Earlier Events"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("calendar-popover-upcoming-load-earlier")
    }

    private var progressRow: some View {
        HStack {
            Spacer()
            ProgressView()
                .scaleEffect(0.7)
            Spacer()
        }
        .padding(.vertical, 4)
    }

    // Bottom sentinel: appearing triggers the next future page. It sits out
    // of the hierarchy while loading or exhausted (mutually exclusive with
    // progressRow), so it cannot double-fire; re-insertion after a load lets
    // short pages chain until the viewport fills or the end is reached.
    private var loadFutureTrigger: some View {
        Color.clear
            .frame(height: 1)
            .onAppear {
                guard !isLoadingFuture, hasMoreFuture else { return }
                onLoadMoreFuture()
            }
    }

    private func dayGroupView(_ group: UpcomingDayGroup) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(group.headerText)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(group.items) { item in
                    itemButton(item)
                }
            }
        }
    }

    @ViewBuilder
    private func itemButton(_ item: CalendarItem) -> some View {
        switch item {
        case .event(let event):
            Button {
                onSelectEvent(event)
            } label: {
                EventCardView(
                    item: item,
                    isSelected: selectedEventIdentifier == event.selectionIdentifier
                )
            }
            .buttonStyle(.plain)
        case .reminder(let reminder):
            Button {
                onOpenReminder(reminder)
            } label: {
                EventCardView(
                    item: item,
                    isSelected: selectedEventIdentifier == item.selectionIdentifier,
                    onToggleReminder: onToggleReminder
                )
            }
            .buttonStyle(.plain)
        }
    }
}
