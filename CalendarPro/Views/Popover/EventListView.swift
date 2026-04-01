import SwiftUI
import EventKit

enum EventTimelineMarkerPosition: Equatable {
    case beforeGroup
    case withinGroup
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
            return EventTimelineSnapshot(
                timedGroups: timedGroups,
                allDayItems: allDayItems,
                untimedItems: untimedItems,
                marker: EventTimelineMarker(groupID: ongoingGroup.id, position: .withinGroup),
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
                }
                .onAppear {
                    currentTime = Date()
                    scrollToActiveGroup(using: proxy)
                }
                .onChange(of: selectedDate) { _, _ in
                    scrollToActiveGroup(using: proxy)
                }
                .onChange(of: items.map(\.id)) { _, _ in
                    scrollToActiveGroup(using: proxy)
                }
                .onReceive(timer) { value in
                    currentTime = value
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
            if markerPosition == .beforeGroup || markerPosition == .withinGroup {
                nowMarkerView
            }

            HStack(alignment: .top, spacing: 10) {
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
        VStack(alignment: .trailing, spacing: 6) {
            Text(group.displayTime)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(timeLabelColor(for: group))

            ZStack(alignment: .top) {
                Rectangle()
                    .fill(Color(nsColor: .separatorColor).opacity(0.25))
                    .frame(width: 1)

                timelineNode(for: group)
                    .padding(.top, isFirst ? 0 : 2)
            }
            .frame(width: 12)
            .frame(maxHeight: .infinity)
        }
        .frame(width: 42, alignment: .topTrailing)
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
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .trailing, spacing: 3) {
                Text(formattedCurrentTime)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.red)
                    .monospacedDigit()

                Circle()
                    .fill(Color.red)
                    .frame(width: 6, height: 6)
            }
            .frame(width: 42, alignment: .trailing)

            Rectangle()
                .fill(Color.red.opacity(0.7))
                .frame(height: 1)
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
}
