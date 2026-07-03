import SwiftUI
import EventKit

enum EventTimelineMarkerPosition: Equatable {
    case beforeGroup
    case withinItem(selectionIdentifier: String, progress: Double)
    case withinGroup(progress: Double)
    case afterGroup
}

struct EventTimelineMarker: Equatable {
    let groupID: String
    let position: EventTimelineMarkerPosition
}

enum EventTimelineOverlapKind: Equatable {
    case identical
    case partial
}

struct EventTimelineOverlapSummary: Equatable {
    let kind: EventTimelineOverlapKind
    let itemCount: Int
    let maximumConcurrentItemCount: Int
    let overlapMinutes: Int
}

struct EventTimelineGroup: Identifiable {
    let id: String
    let displayTime: String
    let startMinutes: Int
    let endMinutes: Int
    let items: [CalendarItem]
    let laneItems: [EventTimelineLaneItem]
    let laneCount: Int
    let overlapSummary: EventTimelineOverlapSummary?
    let containsOngoingItem: Bool
    let isPast: Bool
    let isFuture: Bool
}

struct EventTimelineLaneItem: Identifiable {
    let id: String
    let selectionIdentifier: String
    let item: CalendarItem
    let laneIndex: Int
    let laneCount: Int
    let startMinutes: Int
    let endMinutes: Int
    let startRatio: Double
    let endRatio: Double
    let currentProgress: Double?
}

private struct EventTimelineItemSpan {
    let item: CalendarItem
    let sourceIndex: Int
    let startMinutes: Int
    let endMinutes: Int
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

    static func activeTimedItemInfo(
        items: [CalendarItem],
        selectedDate: Date?,
        now: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> (activeIndex: Int?, timedCount: Int) {
        let timedItems = items.compactMap { item -> (CalendarItem, Int)? in
            guard case .timed(let mins) = item.timelinePlacement(using: calendar) else {
                return nil
            }
            return (item, mins)
        }

        let timedCount = timedItems.count

        guard let selectedDate,
              calendar.isDate(selectedDate, inSameDayAs: now),
              timedCount > 0 else {
            return (nil, timedCount)
        }

        let currentMinutes = Self.minutes(for: now, calendar: calendar)

        for (index, pair) in timedItems.enumerated() {
            if pair.0.timelineStatus(at: now, calendar: calendar) == .ongoing {
                return (index + 1, timedCount)
            }
        }

        for (index, pair) in timedItems.enumerated() {
            if pair.1 >= currentMinutes {
                return (index + 1, timedCount)
            }
        }

        return (timedCount, timedCount)
    }

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

            if ongoingGroup.overlapSummary != nil, ongoingGroup.endMinutes > ongoingGroup.startMinutes {
                let currentMinutes = minutes(for: now, calendar: calendar)
                let progress = Double(currentMinutes - ongoingGroup.startMinutes) / Double(ongoingGroup.endMinutes - ongoingGroup.startMinutes)
                markerPosition = .withinGroup(progress: min(max(progress, 0), 1))
            } else if let ongoingItem = ongoingGroup.items.first(where: { $0.timelineProgress(at: now, calendar: calendar) != nil }) {
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
        let spans = items.enumerated().compactMap { offset, item -> EventTimelineItemSpan? in
            guard case .timed(let minutes) = item.timelinePlacement(using: calendar) else {
                return nil
            }
            return EventTimelineItemSpan(
                item: item,
                sourceIndex: offset,
                startMinutes: minutes,
                endMinutes: endMinutes(for: item, startMinutes: minutes, calendar: calendar)
            )
        }
        .sorted { lhs, rhs in
            if lhs.startMinutes != rhs.startMinutes {
                return lhs.startMinutes < rhs.startMinutes
            }
            if lhs.endMinutes != rhs.endMinutes {
                return lhs.endMinutes < rhs.endMinutes
            }
            return lhs.sourceIndex < rhs.sourceIndex
        }

        let clusteredSpans = makeSpanClusters(from: spans)

        return clusteredSpans.map { spans in
            let items = spans.map(\.item)
            let startMinutes = spans.map(\.startMinutes).min() ?? 0
            let endMinutes = spans.map(\.endMinutes).max() ?? startMinutes
            let overlapSummary = overlapSummary(for: spans)
            let laneItems = laneItems(
                for: spans,
                groupStartMinutes: startMinutes,
                groupEndMinutes: endMinutes,
                now: now,
                calendar: calendar
            )
            let laneCount = max(laneItems.map(\.laneCount).max() ?? 1, 1)

            let statuses = items.compactMap { $0.timelineStatus(at: now, calendar: calendar) }
            let containsOngoingItem = statuses.contains(.ongoing)
            let isPast = !containsOngoingItem && !statuses.isEmpty && statuses.allSatisfy { $0 == .past }
            let isFuture = !containsOngoingItem && !statuses.isEmpty && statuses.allSatisfy { $0 == .future }

            return EventTimelineGroup(
                id: groupID(startMinutes: startMinutes, endMinutes: endMinutes, spans: spans, overlapSummary: overlapSummary),
                displayTime: displayTime(startMinutes: startMinutes, endMinutes: endMinutes, overlapSummary: overlapSummary),
                startMinutes: startMinutes,
                endMinutes: endMinutes,
                items: items,
                laneItems: laneItems,
                laneCount: laneCount,
                overlapSummary: overlapSummary,
                containsOngoingItem: containsOngoingItem,
                isPast: isPast,
                isFuture: isFuture
            )
        }
    }

    private static func makeSpanClusters(from spans: [EventTimelineItemSpan]) -> [[EventTimelineItemSpan]] {
        var clusters: [[EventTimelineItemSpan]] = []
        var currentCluster: [EventTimelineItemSpan] = []
        var currentStartMinutes: Int?
        var currentEndMinutes: Int?

        for span in spans {
            guard let startMinutes = currentStartMinutes,
                  let endMinutes = currentEndMinutes else {
                currentCluster = [span]
                currentStartMinutes = span.startMinutes
                currentEndMinutes = span.endMinutes
                continue
            }

            let sharesStart = span.startMinutes == startMinutes
            let overlapsCurrentDuration = endMinutes > startMinutes && span.startMinutes < endMinutes

            if sharesStart || overlapsCurrentDuration {
                currentCluster.append(span)
                currentEndMinutes = max(endMinutes, span.endMinutes)
            } else {
                clusters.append(currentCluster)
                currentCluster = [span]
                currentStartMinutes = span.startMinutes
                currentEndMinutes = span.endMinutes
            }
        }

        if !currentCluster.isEmpty {
            clusters.append(currentCluster)
        }

        return clusters
    }

    private static func laneItems(
        for spans: [EventTimelineItemSpan],
        groupStartMinutes: Int,
        groupEndMinutes: Int,
        now: Date,
        calendar: Calendar
    ) -> [EventTimelineLaneItem] {
        let duration = max(groupEndMinutes - groupStartMinutes, 1)
        var laneEndMinutes: [Int] = []
        var assignments: [(span: EventTimelineItemSpan, laneIndex: Int)] = []

        for span in spans {
            let laneIndex: Int
            if let reusableIndex = laneEndMinutes.firstIndex(where: { $0 <= span.startMinutes }) {
                laneIndex = reusableIndex
                laneEndMinutes[reusableIndex] = max(span.endMinutes, span.startMinutes + 1)
            } else {
                laneIndex = laneEndMinutes.count
                laneEndMinutes.append(max(span.endMinutes, span.startMinutes + 1))
            }
            assignments.append((span, laneIndex))
        }

        let laneCount = max(laneEndMinutes.count, 1)

        return assignments.map { assignment in
            let span = assignment.span
            let clampedStart = min(max(span.startMinutes, groupStartMinutes), groupEndMinutes)
            let clampedEnd = min(max(span.endMinutes, clampedStart + 1), groupEndMinutes)
            let startRatio = Double(clampedStart - groupStartMinutes) / Double(duration)
            let endRatio = Double(clampedEnd - groupStartMinutes) / Double(duration)

            return EventTimelineLaneItem(
                id: span.item.selectionIdentifier,
                selectionIdentifier: span.item.selectionIdentifier,
                item: span.item,
                laneIndex: assignment.laneIndex,
                laneCount: laneCount,
                startMinutes: span.startMinutes,
                endMinutes: span.endMinutes,
                startRatio: min(max(startRatio, 0), 1),
                endRatio: min(max(endRatio, 0), 1),
                currentProgress: span.item.timelineProgress(at: now, calendar: calendar)
            )
        }
    }

    private static func overlapSummary(for spans: [EventTimelineItemSpan]) -> EventTimelineOverlapSummary? {
        let durationSpans = spans.filter { $0.endMinutes > $0.startMinutes }
        guard durationSpans.count > 1 else { return nil }

        let metrics = overlapMetrics(for: durationSpans)
        guard metrics.overlapMinutes > 0 else { return nil }

        let firstSpan = durationSpans[0]
        let hasIdenticalDuration = durationSpans.allSatisfy {
            $0.startMinutes == firstSpan.startMinutes && $0.endMinutes == firstSpan.endMinutes
        }

        return EventTimelineOverlapSummary(
            kind: hasIdenticalDuration ? .identical : .partial,
            itemCount: spans.count,
            maximumConcurrentItemCount: metrics.maximumConcurrentItemCount,
            overlapMinutes: metrics.overlapMinutes
        )
    }

    private static func overlapMetrics(for spans: [EventTimelineItemSpan]) -> (maximumConcurrentItemCount: Int, overlapMinutes: Int) {
        let boundaries = spans.flatMap { span in
            [
                (minute: span.startMinutes, delta: 1),
                (minute: span.endMinutes, delta: -1)
            ]
        }
        .sorted { lhs, rhs in
            if lhs.minute != rhs.minute {
                return lhs.minute < rhs.minute
            }
            return lhs.delta < rhs.delta
        }

        var activeCount = 0
        var maximumConcurrentItemCount = 0
        var overlapMinutes = 0
        var lastMinute: Int?
        var index = 0

        while index < boundaries.count {
            let minute = boundaries[index].minute
            if let lastMinute, minute > lastMinute, activeCount >= 2 {
                overlapMinutes += minute - lastMinute
            }

            var delta = 0
            while index < boundaries.count, boundaries[index].minute == minute {
                delta += boundaries[index].delta
                index += 1
            }

            activeCount += delta
            maximumConcurrentItemCount = max(maximumConcurrentItemCount, activeCount)
            lastMinute = minute
        }

        return (maximumConcurrentItemCount, overlapMinutes)
    }

    private static func groupID(
        startMinutes: Int,
        endMinutes: Int,
        spans: [EventTimelineItemSpan],
        overlapSummary: EventTimelineOverlapSummary?
    ) -> String {
        guard overlapSummary != nil else {
            return format(minutes: startMinutes)
        }

        let identifiers = spans
            .map(\.item.selectionIdentifier)
            .joined(separator: "|")
        return "\(format(minutes: startMinutes))-\(format(minutes: endMinutes))-\(identifiers)"
    }

    private static func displayTime(
        startMinutes: Int,
        endMinutes: Int,
        overlapSummary: EventTimelineOverlapSummary?
    ) -> String {
        guard overlapSummary != nil, endMinutes > startMinutes else {
            return format(minutes: startMinutes)
        }
        return "\(format(minutes: startMinutes))-\(format(minutes: endMinutes))"
    }

    private static func endMinutes(for item: CalendarItem, startMinutes: Int, calendar: Calendar) -> Int {
        guard let endDate = item.endDate else {
            return startMinutes
        }

        let endMinutes = minutes(for: endDate, calendar: calendar)
        return endMinutes > startMinutes ? endMinutes : startMinutes + 1
    }

    private static func format(minutes: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLocalization.locale
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        var components = DateComponents()
        components.hour = minutes / 60
        components.minute = minutes % 60
        let date = Calendar(identifier: .gregorian).date(from: components) ?? Date()
        return formatter.string(from: date)
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
        static let contentSpacing: CGFloat = 8
        static let timelineColumnWidth: CGFloat = timeLaneWidth + laneSpacing + railLaneWidth
        static let markerDotSize: CGFloat = 8
        static let markerChipHeight: CGFloat = 18
        static let markerChipHorizontalPadding: CGFloat = 6
        static let markerMinimumInset: CGFloat = 12
        static let markerChipCornerRadius: CGFloat = 6
        static let markerConnectorHeight: CGFloat = 1
        static let markerLineTrailingInset: CGFloat = 10
        static let overlapGridMinimumHeight: CGFloat = 82
        static let overlapGridMaximumHeight: CGFloat = 180
        static let overlapMinuteHeight: CGFloat = 2.2
        static let overlapLaneSpacing: CGFloat = 6
        static let overlapLaneMinimumWidth: CGFloat = 72
        static let overlapCardMinimumHeight: CGFloat = 46
        static let overlapTimeTickWidth: CGFloat = 5
        static let overlapNowLineHeight: CGFloat = 1
    }

    let items: [CalendarItem]
    let isLoading: Bool
    let emptyStateText: String
    let selectedDate: Date?
    let selectedEventIdentifier: String?
    @ObservedObject var timeRefreshCoordinator: TimeRefreshCoordinator
    let onSelectEvent: (EKEvent) -> Void
    let onToggleReminder: (EKReminder) -> Void
    let onOpenReminder: (EKReminder) -> Void

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
                    timeRefreshCoordinator.refreshNow()
                    scrollToActiveGroup(using: proxy)
                }
                .onChange(of: selectedDate) { _, _ in
                    scrollToActiveGroup(using: proxy)
                }
                .onChange(of: items.map(\.selectionIdentifier)) { _, _ in
                    scrollToActiveGroup(using: proxy)
                }
            }
        }
    }

    private var timelineContent: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                auxiliarySection(title: L("All Day"), items: timelineSnapshot.allDayItems)
            }

            if !timelineSnapshot.untimedItems.isEmpty {
                auxiliarySection(title: L("No Time"), items: timelineSnapshot.untimedItems)
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

    private var currentTime: Date {
        timeRefreshCoordinator.currentDate
    }

    private func timedGroupView(
        _ group: EventTimelineGroup,
        isFirst: Bool,
        isLast: Bool,
        markerPosition: EventTimelineMarkerPosition?
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if markerPosition == .beforeGroup {
                nowMarkerView
            }

            if group.overlapSummary != nil {
                overlapGroupView(group, markerPosition: markerPosition)
            } else {
                HStack(alignment: .top, spacing: Metrics.contentSpacing) {
                    timelineColumn(for: group, isFirst: isFirst)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(group.items) { item in
                            itemButton(item, timelineState: timelineState(for: item))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if markerPosition == .afterGroup, isLast {
                nowMarkerView
            }
        }
    }

    private func overlapGroupView(_ group: EventTimelineGroup, markerPosition: EventTimelineMarkerPosition?) -> some View {
        let markerProgress = groupMarkerProgress(from: markerPosition)
        let gridHeight = overlapGridHeight(for: group)

        return HStack(alignment: .top, spacing: Metrics.contentSpacing) {
            overlapTimeScale(for: group, markerProgress: markerProgress, height: gridHeight)

            overlapLaneGrid(for: group, markerProgress: markerProgress, height: gridHeight)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func groupMarkerProgress(from markerPosition: EventTimelineMarkerPosition?) -> Double? {
        guard case .withinGroup(let progress) = markerPosition else {
            return nil
        }
        return min(max(progress, 0), 1)
    }

    private func overlapGridHeight(for group: EventTimelineGroup) -> CGFloat {
        let duration = max(group.endMinutes - group.startMinutes, 1)
        let naturalHeight = CGFloat(duration) * Metrics.overlapMinuteHeight
        return min(max(naturalHeight, Metrics.overlapGridMinimumHeight), Metrics.overlapGridMaximumHeight)
    }

    private func overlapTimeScale(
        for group: EventTimelineGroup,
        markerProgress: Double?,
        height: CGFloat
    ) -> some View {
        let ticks = overlapTimeTicks(for: group)
        let railCenterX = Metrics.timeLaneWidth + Metrics.laneSpacing + (Metrics.railLaneWidth / 2)

        return GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Color(nsColor: .separatorColor).opacity(0.28))
                    .frame(width: 1, height: proxy.size.height)
                    .offset(x: railCenterX)

                ForEach(ticks, id: \.self) { minute in
                    let y = overlapYPosition(for: minute, in: group, height: proxy.size.height)

                    Text(timeText(minutes: minute))
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(timeLabelColor(for: group))
                        .monospacedDigit()
                        .frame(width: Metrics.timeLaneWidth, alignment: .trailing)
                        .offset(y: clampedLabelOffset(for: y, labelHeight: 14, height: proxy.size.height))

                    Rectangle()
                        .fill(Color(nsColor: .separatorColor).opacity(0.42))
                        .frame(width: Metrics.overlapTimeTickWidth, height: 1)
                        .offset(x: railCenterX - (Metrics.overlapTimeTickWidth / 2), y: y)
                }

                if let markerProgress {
                    let y = proxy.size.height * CGFloat(markerProgress)

                    markerTimeChip
                        .frame(width: Metrics.timeLaneWidth, alignment: .trailing)
                        .offset(y: clampedLabelOffset(for: y, labelHeight: Metrics.markerChipHeight, height: proxy.size.height))

                    Circle()
                        .fill(Color.red)
                        .frame(width: Metrics.markerDotSize, height: Metrics.markerDotSize)
                        .offset(
                            x: railCenterX - (Metrics.markerDotSize / 2),
                            y: y - (Metrics.markerDotSize / 2)
                        )
                }
            }
        }
        .frame(width: Metrics.timelineColumnWidth, height: height)
    }

    private func overlapLaneGrid(
        for group: EventTimelineGroup,
        markerProgress: Double?,
        height: CGFloat
    ) -> some View {
        GeometryReader { proxy in
            let laneCount = max(group.laneCount, 1)
            let contentWidth = overlapGridContentWidth(containerWidth: proxy.size.width, laneCount: laneCount)
            let laneWidth = overlapLaneWidth(contentWidth: contentWidth, laneCount: laneCount)
            let ticks = overlapTimeTicks(for: group)

            ScrollView(.horizontal, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    ForEach(ticks, id: \.self) { minute in
                        let y = overlapYPosition(for: minute, in: group, height: height)

                        Rectangle()
                            .fill(Color(nsColor: .separatorColor).opacity(0.18))
                            .frame(width: contentWidth, height: 1)
                            .offset(y: y)
                    }

                    ForEach(group.laneItems) { laneItem in
                        let y = height * CGFloat(laneItem.startRatio)
                        let itemHeight = max(
                            Metrics.overlapCardMinimumHeight,
                            height * CGFloat(max(laneItem.endRatio - laneItem.startRatio, 0.02))
                        )
                        let x = CGFloat(laneItem.laneIndex) * (laneWidth + Metrics.overlapLaneSpacing)

                        overlapLaneButton(laneItem, itemHeight: itemHeight)
                            .frame(width: laneWidth, height: itemHeight)
                            .offset(x: x, y: min(y, max(height - itemHeight, 0)))
                    }

                    if let markerProgress {
                        Rectangle()
                            .fill(Color.red.opacity(0.78))
                            .frame(width: contentWidth, height: Metrics.overlapNowLineHeight)
                            .offset(y: height * CGFloat(markerProgress))
                    }
                }
                .frame(width: contentWidth, height: height, alignment: .topLeading)
            }
        }
        .frame(height: height)
    }

    private func overlapLaneButton(_ laneItem: EventTimelineLaneItem, itemHeight: CGFloat) -> some View {
        let item = laneItem.item

        return Button {
            switch item {
            case .event(let event):
                onSelectEvent(event)
            case .reminder(let reminder):
                onOpenReminder(reminder)
            }
        } label: {
            OverlapLaneCardView(
                item: item,
                isSelected: selectedEventIdentifier == item.selectionIdentifier,
                timelineState: timelineState(for: item),
                currentProgress: laneItem.currentProgress,
                isCondensed: itemHeight < 58
            )
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func overlapGridContentWidth(containerWidth: CGFloat, laneCount: Int) -> CGFloat {
        let totalSpacing = CGFloat(max(laneCount - 1, 0)) * Metrics.overlapLaneSpacing
        let minimumWidth = CGFloat(laneCount) * Metrics.overlapLaneMinimumWidth + totalSpacing
        return max(containerWidth, minimumWidth)
    }

    private func overlapLaneWidth(contentWidth: CGFloat, laneCount: Int) -> CGFloat {
        let totalSpacing = CGFloat(max(laneCount - 1, 0)) * Metrics.overlapLaneSpacing
        return max(Metrics.overlapLaneMinimumWidth, (contentWidth - totalSpacing) / CGFloat(max(laneCount, 1)))
    }

    private func overlapTimeTicks(for group: EventTimelineGroup) -> [Int] {
        var ticks = Set([group.startMinutes, group.endMinutes])
        group.laneItems.forEach { laneItem in
            ticks.insert(laneItem.startMinutes)
            ticks.insert(laneItem.endMinutes)
        }

        let sortedTicks = ticks.sorted()
        guard sortedTicks.count > 4 else {
            return sortedTicks
        }

        var filteredTicks: [Int] = []
        for tick in sortedTicks {
            if tick == group.startMinutes || tick == group.endMinutes {
                filteredTicks.append(tick)
            } else if let last = filteredTicks.last, tick - last >= 15 {
                filteredTicks.append(tick)
            }
        }

        if filteredTicks.last != group.endMinutes {
            filteredTicks.append(group.endMinutes)
        }

        return filteredTicks
    }

    private func overlapYPosition(for minute: Int, in group: EventTimelineGroup, height: CGFloat) -> CGFloat {
        let duration = max(group.endMinutes - group.startMinutes, 1)
        let progress = Double(minute - group.startMinutes) / Double(duration)
        return height * CGFloat(min(max(progress, 0), 1))
    }

    private func clampedLabelOffset(for centerY: CGFloat, labelHeight: CGFloat, height: CGFloat) -> CGFloat {
        min(max(centerY - (labelHeight / 2), 0), max(height - labelHeight, 0))
    }

    private func timelineColumn(for group: EventTimelineGroup, isFirst: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: Metrics.laneSpacing) {
                Text(timelineLabel(for: group))
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

    private func timelineLabel(for group: EventTimelineGroup) -> String {
        guard group.overlapSummary != nil else {
            return group.displayTime
        }
        return timeText(minutes: group.startMinutes)
    }

    private func timeText(minutes: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLocalization.locale
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        var components = DateComponents()
        components.hour = minutes / 60
        components.minute = minutes % 60
        let date = Calendar(identifier: .gregorian).date(from: components) ?? Date()
        return formatter.string(from: date)
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
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
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
        formatter.locale = AppLocalization.locale
        formatter.dateStyle = .none
        formatter.timeStyle = .short
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
        let lineEndX = max(railCenterX, placement.frame.maxX - Metrics.markerLineTrailingInset)
        let connectorWidth = max(0, lineEndX - railCenterX)

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

private struct OverlapLaneCardView: View {
    let item: CalendarItem
    let isSelected: Bool
    let timelineState: EventCardTimelineState
    let currentProgress: Double?
    let isCondensed: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            marker
                .padding(.top, 3)

            VStack(alignment: .leading, spacing: isCondensed ? 2 : 3) {
                Text(timeRangeText)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(timeTextColor)
                    .monospacedDigit()
                    .lineLimit(1)

                Text(item.title)
                    .font(.system(size: isCondensed ? 10 : 11, weight: .semibold))
                    .foregroundStyle(titleColor)
                    .lineLimit(isCondensed ? 1 : 2)
                    .strikethrough(item.isCompleted || item.isCanceled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !isCondensed, let secondaryText {
                    Text(secondaryText)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            ZStack(alignment: .top) {
                baseCardColor
                progressFill
                backgroundTintColor
            }
        }
        .overlay(alignment: .top) {
            progressLine
        }
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(railColor)
                .frame(width: 3)
                .padding(.vertical, 5)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .opacity(contentOpacity)
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder
    private var marker: some View {
        if item.isReminder {
            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(itemAccentColor)
        } else {
            Circle()
                .fill(indicatorColor)
                .frame(width: 5, height: 5)
        }
    }

    @ViewBuilder
    private var progressFill: some View {
        if let currentProgress {
            GeometryReader { proxy in
                Rectangle()
                    .fill(Color.red.opacity(colorScheme == .dark ? 0.18 : 0.12))
                    .frame(height: proxy.size.height * CGFloat(min(max(currentProgress, 0), 1)))
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
    }

    @ViewBuilder
    private var progressLine: some View {
        if let currentProgress {
            GeometryReader { proxy in
                Rectangle()
                    .fill(Color.red.opacity(0.76))
                    .frame(height: 1)
                    .offset(y: proxy.size.height * CGFloat(min(max(currentProgress, 0), 1)))
            }
        }
    }

    private var timeRangeText: String {
        if item.isAllDay {
            return L("All Day")
        }

        guard let startDate = item.timelineDate else {
            return L("No Time")
        }

        let formatter = DateFormatter()
        formatter.locale = AppLocalization.locale
        formatter.dateStyle = .none
        formatter.timeStyle = .short

        let start = formatter.string(from: startDate)
        guard let endDate = item.endDate else {
            return start
        }

        return "\(start)-\(formatter.string(from: endDate))"
    }

    private var secondaryText: String? {
        if let location = item.location, !location.isEmpty {
            return location
        }

        let sourceTitle = item.sourceTitle
        return sourceTitle.isEmpty ? nil : sourceTitle
    }

    private var accessibilityText: String {
        if let currentProgress {
            let elapsedPercent = Int((min(max(currentProgress, 0), 1) * 100).rounded())
            return "\(timeRangeText), \(item.title), \(elapsedPercent)%"
        }
        return "\(timeRangeText), \(item.title)"
    }

    private var backgroundTintColor: Color {
        if item.isCanceled {
            return Color.red.opacity(isSelected ? 0.08 : 0.05)
        }
        if isSelected {
            return itemAccentColor.opacity(colorScheme == .dark ? 0.24 : 0.16)
        }
        if timelineState == .ongoing {
            return itemAccentColor.opacity(colorScheme == .dark ? 0.18 : 0.12)
        }
        if timelineState == .past {
            return Color(nsColor: .windowBackgroundColor).opacity(0.18)
        }
        return itemAccentColor.opacity(colorScheme == .dark ? 0.1 : 0.065)
    }

    private var borderColor: Color {
        if item.isCanceled {
            return Color.red.opacity(isSelected ? 0.32 : 0.2)
        }
        if isSelected {
            return itemAccentColor.opacity(colorScheme == .dark ? 0.58 : 0.46)
        }
        if timelineState == .ongoing {
            return itemAccentColor.opacity(colorScheme == .dark ? 0.44 : 0.34)
        }
        return itemAccentColor.opacity(colorScheme == .dark ? 0.2 : 0.16)
    }

    private var contentOpacity: Double {
        if item.isCanceled {
            return isSelected ? 0.96 : 0.88
        }
        if timelineState == .past, !isSelected {
            return 0.78
        }
        return 1
    }

    private var indicatorColor: Color {
        item.isCanceled ? itemAccentColor.opacity(0.4) : itemAccentColor
    }

    private var itemAccentColor: Color {
        Color(nsColor: item.color)
    }

    private var baseCardColor: Color {
        Color(nsColor: .controlBackgroundColor)
    }

    private var railColor: Color {
        if item.isCanceled {
            return itemAccentColor.opacity(0.45)
        }
        if timelineState == .past, !isSelected {
            return itemAccentColor.opacity(0.62)
        }
        return itemAccentColor
    }

    private var timeTextColor: Color {
        item.isCanceled ? Color(nsColor: .tertiaryLabelColor) : .secondary
    }

    private var titleColor: Color {
        if item.isCompleted || item.isCanceled {
            return .secondary
        }
        return .primary
    }
}
