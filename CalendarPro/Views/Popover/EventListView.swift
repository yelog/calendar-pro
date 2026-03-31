import SwiftUI
import EventKit

struct EventListView: View {
    let items: [CalendarItem]
    let isLoading: Bool
    let selectedDate: Date?
    let selectedEventIdentifier: String?
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
            Text("当天无日程")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        } else {
            let groups = groupedByTime
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(groups) { group in
                            if group.items.count == 1 {
                                singleItemView(group.items[0])
                                    .id(group.id)
                            } else {
                                groupedCardView(group)
                                    .id(group.id)
                            }
                        }
                    }
                }
                .onAppear {
                    if let targetID = activeGroupID(in: groups) {
                        let anchor: UnitPoint = isScrollingToLastGroup(in: groups, targetID: targetID) ? .bottom : .top
                        proxy.scrollTo(targetID, anchor: anchor)
                    }
                }
            }
        }
    }

    // MARK: - Auto-scroll target

    /// Returns the group ID to scroll to: the ongoing event group, or the next upcoming group.
    /// Only applies when viewing today's events.
    private func activeGroupID(in groups: [TimeGroup]) -> String? {
        guard let selectedDate, Calendar.current.isDateInToday(selectedDate) else {
            return nil
        }

        let now = Date()
        let cal = Calendar.current
        let nowMinutes = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)

        // 1. Look for a group with an ongoing event (start <= now <= end)
        for group in groups {
            for item in group.items {
                if let start = item.startDate, let end = item.endDate,
                   start <= now, now <= end {
                    return group.id
                }
            }
        }

        // 2. Find the first group whose time-of-day >= now
        for group in groups {
            guard group.key != "allDay", group.key != "noTime" else { continue }
            let parts = group.key.split(separator: ":")
            guard parts.count == 2,
                  let hour = Int(parts[0]),
                  let minute = Int(parts[1]) else { continue }
            if hour * 60 + minute >= nowMinutes {
                return group.id
            }
        }

        // 3. No ongoing or future events - scroll to last timed group (most recent past)
        let timedGroups = groups.filter { $0.key != "allDay" && $0.key != "noTime" }
        if let lastGroup = timedGroups.last {
            return lastGroup.id
        }

        return nil
    }

    private func isScrollingToLastGroup(in groups: [TimeGroup], targetID: String) -> Bool {
        let timedGroups = groups.filter { $0.key != "allDay" && $0.key != "noTime" }
        guard let lastGroup = timedGroups.last else { return false }
        return targetID == lastGroup.id
    }

    // MARK: - Single item (existing card style)

    @ViewBuilder
    private func singleItemView(_ item: CalendarItem) -> some View {
        switch item {
        case .event(let event):
            Button {
                onSelectEvent(event)
            } label: {
                EventCardView(
                    item: item,
                    isSelected: selectedEventIdentifier == event.selectionIdentifier,
                    showsDisclosure: true
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
                    onToggleReminder: onToggleReminder
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Grouped card (multiple items sharing the same start time)

    private func groupedCardView(_ group: TimeGroup) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(group.timeText)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            ForEach(group.items) { item in
                switch item {
                case .event(let event):
                    Button {
                        onSelectEvent(event)
                    } label: {
                        compactItemRow(
                            item: item,
                            isSelected: selectedEventIdentifier == event.selectionIdentifier,
                            showsDisclosure: true
                        )
                    }
                    .buttonStyle(.plain)
                case .reminder(let reminder):
                    Button {
                        onOpenReminder(reminder)
                    } label: {
                        compactItemRow(
                            item: item,
                            isSelected: selectedEventIdentifier == CalendarItem.reminder(reminder).selectionIdentifier,
                            showsDisclosure: true
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func compactItemRow(item: CalendarItem, isSelected: Bool, showsDisclosure: Bool) -> some View {
        HStack(spacing: 6) {
            if item.isReminder {
                Button {
                    if let reminder = item.ekReminder {
                        onToggleReminder(reminder)
                    }
                } label: {
                    Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 12))
                        .foregroundStyle(item.isCompleted ? Color(nsColor: item.color) : .secondary)
                }
                .buttonStyle(.plain)
            } else {
                Circle()
                    .fill(Color(nsColor: item.color))
                    .frame(width: 6, height: 6)
            }

            Text(item.title)
                .font(.system(size: 13, weight: .regular))
                .lineLimit(1)
                .strikethrough(item.isCompleted)
                .foregroundStyle(item.isCompleted ? .secondary : .primary)

            Spacer()

            if showsDisclosure {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : Color(nsColor: .tertiaryLabelColor))
            }
        }
        .contentShape(Rectangle())
    }

    // MARK: - Grouping Logic

    private var groupedByTime: [TimeGroup] {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        var groups: [TimeGroup] = []
        var keyToIndex: [String: Int] = [:]

        for item in items {
            let key: String
            if item.isAllDay {
                key = "allDay"
            } else if let startDate = item.startDate {
                key = formatter.string(from: startDate)
            } else {
                key = "noTime"
            }

            if let index = keyToIndex[key] {
                groups[index].items.append(item)
            } else {
                keyToIndex[key] = groups.count
                groups.append(TimeGroup(key: key, items: [item]))
            }
        }

        return groups
    }
}

// MARK: - TimeGroup

private struct TimeGroup: Identifiable {
    let key: String
    var items: [CalendarItem]

    var id: String { key }

    var timeText: String {
        if key == "allDay" { return "全天" }
        if key == "noTime" { return "" }
        return key
    }
}
