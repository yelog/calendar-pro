import SwiftUI
import EventKit

struct EventListView: View {
    let items: [CalendarItem]
    let isLoading: Bool
    let selectedEventIdentifier: String?
    let onSelectEvent: (EKEvent) -> Void

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
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(groupedByTime) { group in
                        if group.items.count == 1 {
                            singleItemView(group.items[0])
                        } else {
                            groupedCardView(group)
                        }
                    }
                }
            }
        }
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
        case .reminder:
            EventCardView(
                item: item,
                isSelected: false,
                showsDisclosure: false
            )
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
                case .reminder:
                    compactItemRow(item: item, isSelected: false, showsDisclosure: false)
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
            Circle()
                .fill(Color(nsColor: item.color))
                .frame(width: 6, height: 6)

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
