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

struct EventDayTimelineItem: Identifiable {
    let id: String
    let item: CalendarItem
    let startMinutes: Int
    let endMinutes: Int
    let laneIndex: Int
    let laneCount: Int
    let clusterID: String
    let currentProgress: Double?

    var durationMinutes: Int {
        max(endMinutes - startMinutes, 0)
    }

    var isPoint: Bool {
        durationMinutes == 0
    }

    func yPosition(pointsPerMinute: CGFloat) -> CGFloat {
        CGFloat(startMinutes) * pointsPerMinute
    }

    func height(pointsPerMinute: CGFloat) -> CGFloat {
        CGFloat(durationMinutes) * pointsPerMinute
    }
}

private struct EventDayTimelineSpan {
    let item: CalendarItem
    let sourceIndex: Int
    let startMinutes: Int
    let endMinutes: Int

    var effectiveEndMinutes: Int {
        max(endMinutes, startMinutes + 1)
    }
}

struct EventDayTimelineLayout {
    static let minutesPerDay = 24 * 60

    let timedItems: [EventDayTimelineItem]
    let allDayItems: [CalendarItem]
    let untimedItems: [CalendarItem]
    let currentMinutes: Int?
    let initialScrollMinutes: Int?
    let centersInitialScrollTarget: Bool

    var maximumLaneCount: Int {
        max(timedItems.map(\.laneCount).max() ?? 1, 1)
    }

    static func make(
        items: [CalendarItem],
        selectedDate: Date?,
        now: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> EventDayTimelineLayout {
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

        guard let selectedDate else {
            return EventDayTimelineLayout(
                timedItems: [],
                allDayItems: allDayItems,
                untimedItems: untimedItems,
                currentMinutes: nil,
                initialScrollMinutes: nil,
                centersInitialScrollTarget: false
            )
        }

        let dayStart = calendar.startOfDay(for: selectedDate)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)
            ?? dayStart.addingTimeInterval(24 * 60 * 60)
        let currentMinutes = calendar.isDate(selectedDate, inSameDayAs: now)
            ? minuteOfDay(for: now, dayStart: dayStart, dayEnd: dayEnd, calendar: calendar)
            : nil
        let spans = items.enumerated().compactMap { offset, item in
            makeSpan(
                for: item,
                sourceIndex: offset,
                dayStart: dayStart,
                dayEnd: dayEnd,
                calendar: calendar
            )
        }
        .sorted { lhs, rhs in
            if lhs.startMinutes != rhs.startMinutes {
                return lhs.startMinutes < rhs.startMinutes
            }
            if lhs.effectiveEndMinutes != rhs.effectiveEndMinutes {
                return lhs.effectiveEndMinutes > rhs.effectiveEndMinutes
            }
            return lhs.sourceIndex < rhs.sourceIndex
        }

        let positionedItems = makePositionedItems(from: spans, currentMinutes: currentMinutes)
        let initialScrollMinutes: Int?
        let centersInitialScrollTarget: Bool

        if let currentMinutes {
            initialScrollMinutes = currentMinutes
            centersInitialScrollTarget = true
        } else if let firstStart = positionedItems.first?.startMinutes {
            initialScrollMinutes = max(firstStart - 30, 0)
            centersInitialScrollTarget = false
        } else {
            initialScrollMinutes = nil
            centersInitialScrollTarget = false
        }

        return EventDayTimelineLayout(
            timedItems: positionedItems,
            allDayItems: allDayItems,
            untimedItems: untimedItems,
            currentMinutes: currentMinutes,
            initialScrollMinutes: initialScrollMinutes,
            centersInitialScrollTarget: centersInitialScrollTarget
        )
    }

    private static func makeSpan(
        for item: CalendarItem,
        sourceIndex: Int,
        dayStart: Date,
        dayEnd: Date,
        calendar: Calendar
    ) -> EventDayTimelineSpan? {
        switch item {
        case .event(let event):
            guard !event.isAllDay else { return nil }

            if event.endDate <= event.startDate {
                guard event.startDate >= dayStart, event.startDate < dayEnd else {
                    return nil
                }
                let minute = minuteOfDay(
                    for: event.startDate,
                    dayStart: dayStart,
                    dayEnd: dayEnd,
                    calendar: calendar
                )
                return EventDayTimelineSpan(
                    item: item,
                    sourceIndex: sourceIndex,
                    startMinutes: minute,
                    endMinutes: minute
                )
            }

            guard event.startDate < dayEnd, event.endDate > dayStart else {
                return nil
            }

            let clippedStart = max(event.startDate, dayStart)
            let clippedEnd = min(event.endDate, dayEnd)
            let startMinutes = minuteOfDay(
                for: clippedStart,
                dayStart: dayStart,
                dayEnd: dayEnd,
                calendar: calendar
            )
            let endMinutes = minuteOfDay(
                for: clippedEnd,
                dayStart: dayStart,
                dayEnd: dayEnd,
                calendar: calendar
            )

            return EventDayTimelineSpan(
                item: item,
                sourceIndex: sourceIndex,
                startMinutes: startMinutes,
                endMinutes: max(endMinutes, startMinutes)
            )

        case .reminder:
            guard case .timed(let minutes) = item.timelinePlacement(using: calendar) else {
                return nil
            }
            let clampedMinutes = min(max(minutes, 0), minutesPerDay)
            return EventDayTimelineSpan(
                item: item,
                sourceIndex: sourceIndex,
                startMinutes: clampedMinutes,
                endMinutes: clampedMinutes
            )
        }
    }

    private static func makePositionedItems(
        from spans: [EventDayTimelineSpan],
        currentMinutes: Int?
    ) -> [EventDayTimelineItem] {
        makeClusters(from: spans).flatMap { cluster in
            var laneEndMinutes: [Int] = []
            var assignments: [(span: EventDayTimelineSpan, laneIndex: Int)] = []

            for span in cluster {
                let laneIndex: Int
                if let reusableLane = laneEndMinutes.firstIndex(where: { $0 <= span.startMinutes }) {
                    laneIndex = reusableLane
                    laneEndMinutes[reusableLane] = span.effectiveEndMinutes
                } else {
                    laneIndex = laneEndMinutes.count
                    laneEndMinutes.append(span.effectiveEndMinutes)
                }
                assignments.append((span, laneIndex))
            }

            let laneCount = max(laneEndMinutes.count, 1)
            let clusterStart = cluster.map(\.startMinutes).min() ?? 0
            let clusterEnd = cluster.map(\.effectiveEndMinutes).max() ?? clusterStart
            let clusterID = "\(clusterStart)-\(clusterEnd)-\(cluster.map { $0.item.selectionIdentifier }.joined(separator: "|"))"

            return assignments.map { assignment in
                let span = assignment.span
                let currentProgress: Double?
                if let currentMinutes,
                   span.endMinutes > span.startMinutes,
                   currentMinutes >= span.startMinutes,
                   currentMinutes <= span.endMinutes {
                    currentProgress = Double(currentMinutes - span.startMinutes)
                        / Double(span.endMinutes - span.startMinutes)
                } else {
                    currentProgress = nil
                }

                return EventDayTimelineItem(
                    id: span.item.selectionIdentifier,
                    item: span.item,
                    startMinutes: span.startMinutes,
                    endMinutes: span.endMinutes,
                    laneIndex: assignment.laneIndex,
                    laneCount: laneCount,
                    clusterID: clusterID,
                    currentProgress: currentProgress
                )
            }
        }
    }

    private static func makeClusters(from spans: [EventDayTimelineSpan]) -> [[EventDayTimelineSpan]] {
        var clusters: [[EventDayTimelineSpan]] = []
        var currentCluster: [EventDayTimelineSpan] = []
        var currentStartMinutes: Int?
        var currentEndMinutes: Int?

        for span in spans {
            guard let clusterStart = currentStartMinutes,
                  let clusterEnd = currentEndMinutes else {
                currentCluster = [span]
                currentStartMinutes = span.startMinutes
                currentEndMinutes = span.effectiveEndMinutes
                continue
            }

            if span.startMinutes == clusterStart || span.startMinutes < clusterEnd {
                currentCluster.append(span)
                currentEndMinutes = max(clusterEnd, span.effectiveEndMinutes)
            } else {
                clusters.append(currentCluster)
                currentCluster = [span]
                currentStartMinutes = span.startMinutes
                currentEndMinutes = span.effectiveEndMinutes
            }
        }

        if !currentCluster.isEmpty {
            clusters.append(currentCluster)
        }

        return clusters
    }

    private static func minuteOfDay(
        for date: Date,
        dayStart: Date,
        dayEnd: Date,
        calendar: Calendar
    ) -> Int {
        if date <= dayStart {
            return 0
        }
        if date >= dayEnd {
            return minutesPerDay
        }

        let components = calendar.dateComponents([.hour, .minute], from: date)
        return min(max((components.hour ?? 0) * 60 + (components.minute ?? 0), 0), minutesPerDay)
    }
}

struct EventListView: View {
    private enum Metrics {
        static let timeLaneWidth: CGFloat = 46
        static let contentSpacing: CGFloat = 8
        static let markerDotSize: CGFloat = 8
        static let markerChipHeight: CGFloat = 18
        static let markerChipHorizontalPadding: CGFloat = 6
        static let markerChipCornerRadius: CGFloat = 6
        static let pointsPerMinute: CGFloat = 1
        static let dayTimelineHeight: CGFloat = CGFloat(EventDayTimelineLayout.minutesPerDay) * pointsPerMinute
        static let halfHourMinutes = 30
        static let pointItemHeight: CGFloat = 24
        static let dayLaneMinimumWidth: CGFloat = 72
        static let dayLaneSpacing: CGFloat = 3
        static let majorGridLineOpacity = 0.26
        static let minorGridLineOpacity = 0.12
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
                ScrollView(.vertical) {
                    dayTimelineContent
                }
                .onAppear {
                    timeRefreshCoordinator.refreshNow()
                    scrollToInitialTimelineContext(using: proxy)
                }
                .onChange(of: selectedDate) { _, _ in
                    scrollToInitialTimelineContext(using: proxy)
                }
                .onChange(of: items.map(\.selectionIdentifier)) { _, _ in
                    scrollToInitialTimelineContext(using: proxy)
                }
            }
        }
    }

    private var dayTimelineContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !dayTimelineLayout.allDayItems.isEmpty {
                auxiliarySection(title: L("All Day"), items: dayTimelineLayout.allDayItems)
            }

            if !dayTimelineLayout.untimedItems.isEmpty {
                auxiliarySection(title: L("No Time"), items: dayTimelineLayout.untimedItems)
            }

            if !dayTimelineLayout.timedItems.isEmpty {
                dayTimelineCanvas(for: dayTimelineLayout)
            }
        }
    }

    private var currentTime: Date {
        timeRefreshCoordinator.currentDate
    }

    private var dayTimelineLayout: EventDayTimelineLayout {
        EventDayTimelineLayout.make(
            items: items,
            selectedDate: selectedDate,
            now: currentTime,
            calendar: .autoupdatingCurrent
        )
    }

    private func dayTimelineCanvas(for layout: EventDayTimelineLayout) -> some View {
        ZStack(alignment: .topLeading) {
            HStack(alignment: .top, spacing: Metrics.contentSpacing) {
                dayTimelineTimeScale(for: layout)

                GeometryReader { proxy in
                    let containerWidth = max(proxy.size.width, 1)
                    let minimumContentWidth = dayTimelineMinimumContentWidth(for: layout.maximumLaneCount)
                    let contentWidth = max(containerWidth, minimumContentWidth)

                    ScrollView(.horizontal, showsIndicators: false) {
                        dayTimelineGrid(
                            for: layout,
                            containerWidth: containerWidth,
                            contentWidth: contentWidth
                        )
                    }
                }
            }

            initialScrollAnchorLayer(for: layout)
        }
        .frame(height: Metrics.dayTimelineHeight)
    }

    private func dayTimelineTimeScale(for layout: EventDayTimelineLayout) -> some View {
        ZStack(alignment: .topTrailing) {
            ForEach(0..<24, id: \.self) { hour in
                Text(timeText(minutes: hour * 60))
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    .monospacedDigit()
                    .frame(width: Metrics.timeLaneWidth, height: 14, alignment: .trailing)
                    .offset(y: clampedDayLabelOffset(for: CGFloat(hour * 60)))
            }

            if let currentMinutes = layout.currentMinutes {
                markerTimeChip
                    .frame(width: Metrics.timeLaneWidth, alignment: .trailing)
                    .offset(
                        y: clampedDayLabelOffset(
                            for: CGFloat(currentMinutes),
                            labelHeight: Metrics.markerChipHeight
                        )
                    )
            }
        }
        .frame(width: Metrics.timeLaneWidth, height: Metrics.dayTimelineHeight, alignment: .topTrailing)
    }

    private func dayTimelineGrid(
        for layout: EventDayTimelineLayout,
        containerWidth: CGFloat,
        contentWidth: CGFloat
    ) -> some View {
        ZStack(alignment: .topLeading) {
            dayTimelineGridLines(width: contentWidth)

            ForEach(layout.timedItems) { positionedItem in
                dayTimelineItemButton(
                    positionedItem,
                    containerWidth: containerWidth
                )
            }

            if let currentMinutes = layout.currentMinutes {
                let markerY = CGFloat(currentMinutes) * Metrics.pointsPerMinute

                Rectangle()
                    .fill(Color.red.opacity(0.78))
                    .frame(width: contentWidth, height: 1)
                    .offset(y: markerY)

                Circle()
                    .fill(Color.red)
                    .frame(width: Metrics.markerDotSize, height: Metrics.markerDotSize)
                    .offset(
                        x: -(Metrics.markerDotSize / 2),
                        y: markerY - (Metrics.markerDotSize / 2)
                    )
            }
        }
        .frame(width: contentWidth, height: Metrics.dayTimelineHeight, alignment: .topLeading)
    }

    private func dayTimelineGridLines(width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(0...24, id: \.self) { hour in
                Rectangle()
                    .fill(Color(nsColor: .separatorColor).opacity(Metrics.majorGridLineOpacity))
                    .frame(width: width, height: 1)
                    .offset(y: CGFloat(hour * 60) * Metrics.pointsPerMinute)
            }

            ForEach(0..<24, id: \.self) { hour in
                Rectangle()
                    .fill(Color(nsColor: .separatorColor).opacity(Metrics.minorGridLineOpacity))
                    .frame(width: width, height: 1)
                    .offset(
                        y: CGFloat(hour * 60 + Metrics.halfHourMinutes) * Metrics.pointsPerMinute
                    )
            }
        }
        .allowsHitTesting(false)
    }

    private func dayTimelineItemButton(
        _ positionedItem: EventDayTimelineItem,
        containerWidth: CGFloat
    ) -> some View {
        let laneCount = max(positionedItem.laneCount, 1)
        let clusterWidth = max(containerWidth, dayTimelineMinimumContentWidth(for: laneCount))
        let totalSpacing = CGFloat(max(laneCount - 1, 0)) * Metrics.dayLaneSpacing
        let laneWidth = max(
            Metrics.dayLaneMinimumWidth,
            (clusterWidth - totalSpacing) / CGFloat(laneCount)
        )
        let x = CGFloat(positionedItem.laneIndex) * (laneWidth + Metrics.dayLaneSpacing)
        let semanticY = positionedItem.yPosition(pointsPerMinute: Metrics.pointsPerMinute)
        let renderedHeight = positionedItem.isPoint
            ? Metrics.pointItemHeight
            : positionedItem.height(pointsPerMinute: Metrics.pointsPerMinute)
        let visualY = positionedItem.isPoint
            ? semanticY - (Metrics.pointItemHeight / 2)
            : semanticY
        let clampedY = min(
            max(visualY, 0),
            max(Metrics.dayTimelineHeight - renderedHeight, 0)
        )
        let item = positionedItem.item

        return Button {
            switch item {
            case .event(let event):
                onSelectEvent(event)
            case .reminder(let reminder):
                onOpenReminder(reminder)
            }
        } label: {
            EventDayTimelineCardView(
                item: item,
                isSelected: selectedEventIdentifier == item.selectionIdentifier,
                timelineState: timelineState(for: item),
                currentProgress: positionedItem.currentProgress,
                renderedHeight: renderedHeight,
                isPoint: positionedItem.isPoint,
                onToggleReminder: onToggleReminder
            )
        }
        .buttonStyle(.plain)
        .frame(width: laneWidth, height: renderedHeight)
        .contentShape(Rectangle())
        .offset(x: x, y: clampedY)
        .zIndex(positionedItem.currentProgress == nil ? 1 : 2)
    }

    private func dayTimelineMinimumContentWidth(for laneCount: Int) -> CGFloat {
        let count = max(laneCount, 1)
        let spacing = CGFloat(max(count - 1, 0)) * Metrics.dayLaneSpacing
        return CGFloat(count) * Metrics.dayLaneMinimumWidth + spacing
    }

    private func clampedDayLabelOffset(
        for centerY: CGFloat,
        labelHeight: CGFloat = 14
    ) -> CGFloat {
        min(
            max(centerY - (labelHeight / 2), 0),
            max(Metrics.dayTimelineHeight - labelHeight, 0)
        )
    }

    @ViewBuilder
    private func initialScrollAnchorLayer(for layout: EventDayTimelineLayout) -> some View {
        if let targetMinutes = layout.initialScrollMinutes {
            let targetY = CGFloat(targetMinutes) * Metrics.pointsPerMinute

            VStack(spacing: 0) {
                Color.clear
                    .frame(height: targetY)

                Color.clear
                    .frame(height: 1)
                    .id(dayTimelineScrollAnchorID(minutes: targetMinutes))

                Color.clear
                    .frame(height: max(Metrics.dayTimelineHeight - targetY - 1, 0))
            }
            .allowsHitTesting(false)
        }
    }

    private func dayTimelineScrollAnchorID(minutes: Int) -> String {
        "day-timeline-minute-\(minutes)"
    }

    private func scrollToInitialTimelineContext(using proxy: ScrollViewProxy) {
        guard let targetMinutes = dayTimelineLayout.initialScrollMinutes else {
            return
        }
        let anchor: UnitPoint = dayTimelineLayout.centersInitialScrollTarget ? .center : .top
        let targetID = dayTimelineScrollAnchorID(minutes: targetMinutes)

        DispatchQueue.main.async {
            proxy.scrollTo(targetID, anchor: anchor)
        }
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


    private var formattedCurrentTime: String {
        let formatter = DateFormatter()
        formatter.locale = AppLocalization.locale
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: currentTime)
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

private struct EventDayTimelineCardView: View {
    private enum Density {
        case full
        case compact
        case minimal
    }

    let item: CalendarItem
    let isSelected: Bool
    let timelineState: EventCardTimelineState
    let currentProgress: Double?
    let renderedHeight: CGFloat
    let isPoint: Bool
    let onToggleReminder: (EKReminder) -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        content
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
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(railColor)
                    .frame(width: density == .minimal ? 2 : 3)
                    .padding(.vertical, min(4, renderedHeight / 4))
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .opacity(contentOpacity)
            .help(accessibilityText)
            .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder
    private var content: some View {
        switch density {
        case .full:
            HStack(alignment: .top, spacing: 6) {
                marker
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(timeRangeText)
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(timeTextColor)
                        .monospacedDigit()
                        .lineLimit(1)

                    Text(item.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(titleColor)
                        .lineLimit(renderedHeight >= 68 ? 2 : 1)
                        .strikethrough(item.isCompleted || item.isCanceled)

                    if renderedHeight >= 62, let secondaryText {
                        Text(secondaryText)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 5)

        case .compact:
            HStack(alignment: .top, spacing: 5) {
                marker
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 1) {
                    Text(timeRangeText)
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .foregroundStyle(timeTextColor)
                        .monospacedDigit()
                        .lineLimit(1)

                    Text(item.title)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(titleColor)
                        .lineLimit(1)
                        .strikethrough(item.isCompleted || item.isCanceled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)

        case .minimal:
            HStack(alignment: .center, spacing: 4) {
                marker

                Text(item.title)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(titleColor)
                    .lineLimit(1)
                    .strikethrough(item.isCompleted || item.isCanceled)
            }
            .padding(.horizontal, 5)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var marker: some View {
        if let reminder = item.ekReminder {
            Button {
                onToggleReminder(reminder)
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: density == .minimal ? 9 : 10, weight: .semibold))
                    .foregroundStyle(item.isCompleted ? itemAccentColor : .secondary)
            }
            .buttonStyle(.plain)
        } else {
            Circle()
                .fill(indicatorColor)
                .frame(width: density == .minimal ? 4 : 5, height: density == .minimal ? 4 : 5)
        }
    }

    @ViewBuilder
    private var progressFill: some View {
        if let currentProgress, !isPoint {
            GeometryReader { proxy in
                Rectangle()
                    .fill(Color.red.opacity(colorScheme == .dark ? 0.18 : 0.11))
                    .frame(height: proxy.size.height * CGFloat(clampedProgress(currentProgress)))
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
    }

    @ViewBuilder
    private var progressLine: some View {
        if let currentProgress, !isPoint {
            GeometryReader { proxy in
                Rectangle()
                    .fill(Color.red.opacity(0.72))
                    .frame(height: 1)
                    .offset(
                        y: min(
                            proxy.size.height * CGFloat(clampedProgress(currentProgress)),
                            max(proxy.size.height - 1, 0)
                        )
                    )
            }
        }
    }

    private var density: Density {
        if isPoint || renderedHeight < 24 {
            return .minimal
        }
        if renderedHeight < 44 {
            return .compact
        }
        return .full
    }

    private var cornerRadius: CGFloat {
        max(min(8, renderedHeight / 3), 1)
    }

    private var timeRangeText: String {
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
            let elapsedPercent = Int((clampedProgress(currentProgress) * 100).rounded())
            return "\(timeRangeText), \(item.title), \(elapsedPercent)%"
        }
        return "\(timeRangeText), \(item.title)"
    }

    private func clampedProgress(_ progress: Double) -> Double {
        min(max(progress, 0), 1)
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
