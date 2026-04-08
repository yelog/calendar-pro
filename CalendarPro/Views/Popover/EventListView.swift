import SwiftUI
import EventKit

enum EventTimelineMarkerPosition: Equatable {
    case beforeGroup
    case withinItem(selectionIdentifier: String, progress: Double)
    case afterGroup
}

struct EventTimelineMarker: Equatable {
    let groupID: String
    let position: EventTimelineMarkerPosition
}

struct EventTimelineGroup: Identifiable {
    let id: String
    let displayTime: String
    let startMinutes: Int
    let items: [CalendarItem]
    let containsOngoingItem: Bool
    let isPast: Bool
    let isFuture: Bool
}

private struct EventTimelineItemBoundsPreferenceKey: PreferenceKey {
    static let defaultValue: [String: Anchor<CGRect>] = [:]

    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct EventTimelineSnapshot {
    let timedGroups: [EventTimelineGroup]
    let allDayItems: [CalendarItem]
    let untimedItems: [CalendarItem]
    let marker: EventTimelineMarker?
    let scrollTargetGroupID: String?
    let shouldAnchorBottom: Bool

    static func make(
        items: [CalendarItem],
        selectedDate: Date?,
        now: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> EventTimelineSnapshot {
        let timedGroups = makeTimedGroups(items: items, now: now, calendar: calendar)
        let allDayItems = items.filter(\.isAllDay)
        let untimedItems = items.filter { item in
            if item.isAllDay {
                return false
            }
            if case .timed = item.timelinePlacement(using: calendar) {
                return false
            }
            return true
        }

        guard let selectedDate,
              calendar.isDate(selectedDate, inSameDayAs: now),
              !timedGroups.isEmpty else {
            return EventTimelineSnapshot(
                timedGroups: timedGroups,
                allDayItems: allDayItems,
                untimedItems: untimedItems,
                marker: nil,
                scrollTargetGroupID: nil,
                shouldAnchorBottom: false
            )
        }

        if let ongoingGroup = timedGroups.first(where: \.containsOngoingItem) {
            let shouldAnchorBottom = timedGroups.last?.id == ongoingGroup.id
            let markerPosition: EventTimelineMarkerPosition

            if let ongoingItem = ongoingGroup.items.first(where: { $0.timelineProgress(at: now, calendar: calendar) != nil }) {
                let progress = ongoingItem.timelineProgress(at: now, calendar: calendar) ?? 0.5
                markerPosition = .withinItem(
                    selectionIdentifier: ongoingItem.selectionIdentifier,
                    progress: progress
                )
            } else {
                markerPosition = .beforeGroup
            }

            return EventTimelineSnapshot(
                timedGroups: timedGroups,
                allDayItems: allDayItems,
                untimedItems: untimedItems,
                marker: EventTimelineMarker(groupID: ongoingGroup.id, position: markerPosition),
                scrollTargetGroupID: ongoingGroup.id,
                shouldAnchorBottom: shouldAnchorBottom
            )
        }

        let currentMinutes = minutes(for: now, calendar: calendar)

        if let nextGroup = timedGroups.first(where: { $0.startMinutes >= currentMinutes }) {
            let shouldAnchorBottom = timedGroups.last?.id == nextGroup.id
            return EventTimelineSnapshot(
                timedGroups: timedGroups,
                allDayItems: allDayItems,
                untimedItems: untimedItems,
                marker: EventTimelineMarker(groupID: nextGroup.id, position: .beforeGroup),
                scrollTargetGroupID: nextGroup.id,
                shouldAnchorBottom: shouldAnchorBottom
            )
        }

        guard let lastGroup = timedGroups.last else {
            return EventTimelineSnapshot(
                timedGroups: timedGroups,
                allDayItems: allDayItems,
                untimedItems: untimedItems,
                marker: nil,
                scrollTargetGroupID: nil,
                shouldAnchorBottom: false
            )
        }

        return EventTimelineSnapshot(
            timedGroups: timedGroups,
            allDayItems: allDayItems,
            untimedItems: untimedItems,
            marker: EventTimelineMarker(groupID: lastGroup.id, position: .afterGroup),
            scrollTargetGroupID: lastGroup.id,
            shouldAnchorBottom: true
        )
    }

    private static func makeTimedGroups(items: [CalendarItem], now: Date, calendar: Calendar) -> [EventTimelineGroup] {
        var groupedItems: [Int: [CalendarItem]] = [:]
        var orderedMinutes: [Int] = []

        for item in items {
            guard case .timed(let minutes) = item.timelinePlacement(using: calendar) else {
                continue
            }

            if groupedItems[minutes] == nil {
                orderedMinutes.append(minutes)
                groupedItems[minutes] = []
            }

            groupedItems[minutes, default: []].append(item)
        }

        return orderedMinutes.sorted().compactMap { minutes in
            guard let items = groupedItems[minutes], !items.isEmpty else { return nil }

            let statuses = items.compactMap { $0.timelineStatus(at: now, calendar: calendar) }
            let containsOngoingItem = statuses.contains(.ongoing)
            let isPast = !containsOngoingItem && !statuses.isEmpty && statuses.allSatisfy { $0 == .past }
            let isFuture = !containsOngoingItem && !statuses.isEmpty && statuses.allSatisfy { $0 == .future }

            return EventTimelineGroup(
                id: Self.format(minutes: minutes),
                displayTime: Self.format(minutes: minutes),
                startMinutes: minutes,
                items: items,
                containsOngoingItem: containsOngoingItem,
                isPast: isPast,
                isFuture: isFuture
            )
        }
    }

    private static func format(minutes: Int) -> String {
        let hour = minutes / 60
        let minute = minutes % 60
        return String(format: "%02d:%02d", hour, minute)
    }

    private static func minutes(for date: Date, calendar: Calendar) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}

struct EventListView: View {
    private struct WithinItemMarkerPlacement {
        let frame: CGRect
        let y: CGFloat
    }

    private enum Metrics {
        static let timeLaneWidth: CGFloat = 46
        static let railLaneWidth: CGFloat = 12
        static let laneSpacing: CGFloat = 6
        static let contentSpacing: CGFloat = 6
        static let timelineColumnWidth: CGFloat = timeLaneWidth + laneSpacing + railLaneWidth
        static let markerDotSize: CGFloat = 8
        static let markerChipHeight: CGFloat = 18
        static let markerChipHorizontalPadding: CGFloat = 6
        static let markerMinimumInset: CGFloat = 12
        static let markerChipCornerRadius: CGFloat = 6
        static let markerConnectorHeight: CGFloat = 1
        static let markerEntryWidth: CGFloat = 10
        static let markerEntryHeight: CGFloat = 2
        static let markerEntryOutsideOffset: CGFloat = 4
    }

    let items: [CalendarItem]
    let isLoading: Bool
    let emptyStateText: String
    let selectedDate: Date?
    let selectedEventIdentifier: String?
    let onSelectEvent: (EKEvent) -> Void
    let onToggleReminder: (EKReminder) -> Void
    let onOpenReminder: (EKReminder) -> Void

    @State private var currentTime = Date()
    private let timer = Timer.publish(every: 60, tolerance: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        if isLoading {
            HStack {
                Spacer()
                ProgressView()
                    .scaleEffect(0.7)
                Spacer()
            }
            .frame(height: 60)
        } else if items.isEmpty {
            Text(emptyStateText)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    timelineContent
                }
                .onAppear {
                    currentTime = Date()
                    scrollToActiveGroup(using: proxy)
                }
                .onChange(of: selectedDate) { _, _ in
                    scrollToActiveGroup(using: proxy)
                }
                .onChange(of: items.map(\.selectionIdentifier)) { _, _ in
                    scrollToActiveGroup(using: proxy)
                }
                .onReceive(timer) { value in
                    currentTime = value
                }
            }
        }
    }

    private var timelineContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(timelineSnapshot.timedGroups.enumerated()), id: \.element.id) { index, group in
                timedGroupView(
                    group,
                    isFirst: index == timelineSnapshot.timedGroups.startIndex,
                    isLast: index == timelineSnapshot.timedGroups.index(before: timelineSnapshot.timedGroups.endIndex),
                    markerPosition: markerPosition(for: group.id)
                )
                .id(group.id)
            }

            if !timelineSnapshot.allDayItems.isEmpty {
                auxiliarySection(title: "全天", items: timelineSnapshot.allDayItems)
            }

            if !timelineSnapshot.untimedItems.isEmpty {
                auxiliarySection(title: "未指定时间", items: timelineSnapshot.untimedItems)
            }
        }
        .overlayPreferenceValue(EventTimelineItemBoundsPreferenceKey.self) { anchors in
            GeometryReader { proxy in
                if let placement = withinItemMarkerPlacement(using: anchors, in: proxy) {
                    withinItemMarkerOverlay(placement: placement)
                }
            }
        }
    }

    private var timelineSnapshot: EventTimelineSnapshot {
        EventTimelineSnapshot.make(
            items: items,
            selectedDate: selectedDate,
            now: currentTime,
            calendar: .autoupdatingCurrent
        )
    }

    private func timedGroupView(
        _ group: EventTimelineGroup,
        isFirst: Bool,
        isLast: Bool,
        markerPosition: EventTimelineMarkerPosition?
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if markerPosition == .beforeGroup {
                nowMarkerView
            }

            HStack(alignment: .top, spacing: Metrics.contentSpacing) {
                timelineColumn(for: group, isFirst: isFirst)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(group.items) { item in
                        itemButton(item, timelineState: timelineState(for: item))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if markerPosition == .afterGroup, isLast {
                nowMarkerView
            }
        }
    }

    private func timelineColumn(for group: EventTimelineGroup, isFirst: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: Metrics.laneSpacing) {
                Text(group.displayTime)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(timeLabelColor(for: group))
                    .frame(width: Metrics.timeLaneWidth, alignment: .trailing)

                Color.clear
                    .frame(width: Metrics.railLaneWidth, height: 1)
            }

            HStack(alignment: .top, spacing: Metrics.laneSpacing) {
                Color.clear
                    .frame(width: Metrics.timeLaneWidth, height: 1)

                ZStack(alignment: .top) {
                    Rectangle()
                        .fill(Color(nsColor: .separatorColor).opacity(0.25))
                        .frame(width: 1)

                    timelineNode(for: group)
                        .padding(.top, isFirst ? 0 : 2)
                }
                .frame(width: Metrics.railLaneWidth)
                .frame(maxHeight: .infinity)
            }
        }
        .frame(width: Metrics.timelineColumnWidth, alignment: .topLeading)
    }

    @ViewBuilder
    private func timelineNode(for group: EventTimelineGroup) -> some View {
        let referenceItem = group.items.first(where: { !$0.isReminder }) ?? group.items.first
        let nodeColor = Color(nsColor: referenceItem?.color ?? .secondaryLabelColor)

        if group.items.allSatisfy(\.isReminder) {
            if group.items.allSatisfy(\.isCompleted) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(nodeColor)
            } else {
                Circle()
                    .stroke(nodeColor, lineWidth: 1.6)
                    .frame(width: 8, height: 8)
                    .background(Color(nsColor: .windowBackgroundColor), in: Circle())
            }
        } else {
            Circle()
                .fill(nodeColor)
                .frame(width: 8, height: 8)
        }
    }

    private var nowMarkerView: some View {
        HStack(alignment: .center, spacing: Metrics.contentSpacing) {
            HStack(alignment: .center, spacing: Metrics.laneSpacing) {
                markerTimeChip
                    .frame(width: Metrics.timeLaneWidth, alignment: .trailing)

                Circle()
                    .fill(Color.red)
                    .frame(width: Metrics.markerDotSize, height: Metrics.markerDotSize)
                    .frame(width: Metrics.railLaneWidth)
            }
            .frame(width: Metrics.timelineColumnWidth, alignment: .leading)

            Rectangle()
                .fill(Color.red.opacity(0.7))
                .frame(height: Metrics.markerConnectorHeight)
        }
        .padding(.vertical, 2)
    }

    private func auxiliarySection(title: String, items: [CalendarItem]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(items) { item in
                    itemButton(item, timelineState: .regular)
                }
            }
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private func itemButton(_ item: CalendarItem, timelineState: EventCardTimelineState) -> some View {
        switch item {
        case .event(let event):
            Button {
                onSelectEvent(event)
            } label: {
                EventCardView(
                    item: item,
                    isSelected: selectedEventIdentifier == event.selectionIdentifier,
                    showsDisclosure: true,
                    timelineState: timelineState
                )
            }
            .buttonStyle(.plain)
            .anchorPreference(key: EventTimelineItemBoundsPreferenceKey.self, value: .bounds) {
                [item.selectionIdentifier: $0]
            }
        case .reminder(let reminder):
            Button {
                onOpenReminder(reminder)
            } label: {
                EventCardView(
                    item: item,
                    isSelected: selectedEventIdentifier == CalendarItem.reminder(reminder).selectionIdentifier,
                    showsDisclosure: true,
                    timelineState: timelineState,
                    onToggleReminder: onToggleReminder
                )
            }
            .buttonStyle(.plain)
            .anchorPreference(key: EventTimelineItemBoundsPreferenceKey.self, value: .bounds) {
                [item.selectionIdentifier: $0]
            }
        }
    }

    private func timelineState(for item: CalendarItem) -> EventCardTimelineState {
        guard let status = item.timelineStatus(at: currentTime, calendar: .autoupdatingCurrent) else {
            return .regular
        }

        switch status {
        case .past:
            return .past
        case .ongoing:
            return .ongoing
        case .future:
            return .regular
        }
    }

    private func markerPosition(for groupID: String) -> EventTimelineMarkerPosition? {
        guard let marker = timelineSnapshot.marker, marker.groupID == groupID else {
            return nil
        }
        return marker.position
    }

    private func withinItemMarkerPlacement(
        using anchors: [String: Anchor<CGRect>],
        in proxy: GeometryProxy
    ) -> WithinItemMarkerPlacement? {
        guard let marker = timelineSnapshot.marker else { return nil }
        guard case let .withinItem(selectionIdentifier, progress) = marker.position else {
            return nil
        }
        guard let anchor = anchors[selectionIdentifier] else {
            return nil
        }
        let frame = proxy[anchor]
        let y = markerY(for: frame, progress: progress)
        return WithinItemMarkerPlacement(frame: frame, y: y)
    }

    private func scrollToActiveGroup(using proxy: ScrollViewProxy) {
        guard let targetID = timelineSnapshot.scrollTargetGroupID else { return }
        let anchor: UnitPoint = timelineSnapshot.shouldAnchorBottom ? .bottom : .top

        DispatchQueue.main.async {
            proxy.scrollTo(targetID, anchor: anchor)
        }
    }

    private func timeLabelColor(for group: EventTimelineGroup) -> Color {
        if group.containsOngoingItem {
            return .red
        }
        if group.isPast {
            return Color(nsColor: .tertiaryLabelColor)
        }
        return .secondary
    }

    private var formattedCurrentTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: currentTime)
    }

    private func markerY(for frame: CGRect, progress: Double) -> CGFloat {
        let clampedProgress = min(max(progress, 0), 1)
        let inset = min(Metrics.markerMinimumInset, frame.height / 2)
        let usableHeight = max(frame.height - inset * 2, 0)
        return frame.minY + inset + usableHeight * clampedProgress
    }

    private func withinItemMarkerOverlay(placement: WithinItemMarkerPlacement) -> some View {
        let railCenterX = Metrics.timeLaneWidth + Metrics.laneSpacing + (Metrics.railLaneWidth / 2)
        let cardLeadingX = placement.frame.minX
        let entryLeadingX = max(railCenterX, cardLeadingX - Metrics.markerEntryOutsideOffset)
        let connectorWidth = max(0, entryLeadingX - railCenterX)

        return ZStack(alignment: .topLeading) {
            markerTimeChip
                .frame(width: Metrics.timeLaneWidth, alignment: .trailing)
                .offset(y: placement.y - (Metrics.markerChipHeight / 2))

            Circle()
                .fill(Color.red)
                .frame(width: Metrics.markerDotSize, height: Metrics.markerDotSize)
                .offset(
                    x: railCenterX - (Metrics.markerDotSize / 2),
                    y: placement.y - (Metrics.markerDotSize / 2)
                )

            if connectorWidth > 0 {
                Rectangle()
                    .fill(Color.red.opacity(0.7))
                    .frame(width: connectorWidth, height: Metrics.markerConnectorHeight)
                    .offset(
                        x: railCenterX,
                        y: placement.y
                    )
            }

            Capsule()
                .fill(Color.red.opacity(0.85))
                .frame(width: Metrics.markerEntryWidth, height: Metrics.markerEntryHeight)
                .offset(
                    x: cardLeadingX - Metrics.markerEntryOutsideOffset,
                    y: placement.y - (Metrics.markerEntryHeight / 2)
                )
        }
        .allowsHitTesting(false)
    }

    private var markerTimeChip: some View {
        Text(formattedCurrentTime)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(.red)
            .monospacedDigit()
            .padding(.horizontal, Metrics.markerChipHorizontalPadding)
            .frame(height: Metrics.markerChipHeight)
            .background(
                Color(nsColor: .windowBackgroundColor).opacity(0.94),
                in: RoundedRectangle(cornerRadius: Metrics.markerChipCornerRadius, style: .continuous)
            )
    }
}
