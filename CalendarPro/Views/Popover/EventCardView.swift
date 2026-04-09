import SwiftUI
import EventKit

enum EventCardTimelineState: Equatable {
    case regular
    case past
    case ongoing
}

extension EKEvent {
    var selectionIdentifier: String {
        if let eventIdentifier {
            return eventIdentifier
        }

        return [
            calendar?.calendarIdentifier ?? "unknown-calendar",
            title ?? "untitled",
            String(startDate.timeIntervalSinceReferenceDate),
            String(endDate.timeIntervalSinceReferenceDate)
        ].joined(separator: "|")
    }
}

struct EventCardView: View {
    let item: CalendarItem
    let isSelected: Bool
    let showsDisclosure: Bool
    let timelineState: EventCardTimelineState
    var onToggleReminder: ((EKReminder) -> Void)?

    init(item: CalendarItem, isSelected: Bool = false, showsDisclosure: Bool = true, timelineState: EventCardTimelineState = .regular, onToggleReminder: ((EKReminder) -> Void)? = nil) {
        self.item = item
        self.isSelected = isSelected
        self.showsDisclosure = showsDisclosure
        self.timelineState = timelineState
        self.onToggleReminder = onToggleReminder
    }

    init(event: EKEvent, isSelected: Bool) {
        self.init(item: .event(event), isSelected: isSelected)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if timelineState == .ongoing {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color(nsColor: item.color))
                    .frame(width: 3)
                    .padding(.vertical, 2)
            }

            if item.isReminder {
                reminderCheckbox
                    .padding(.top, 2)
            } else {
                Circle()
                    .fill(Color(nsColor: item.color))
                    .frame(width: 6, height: 6)
                    .padding(.top, 4)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(timeRangeText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                
                Text(item.title)
                    .font(.system(size: 13, weight: .regular))
                    .lineLimit(2)
                    .strikethrough(item.isCompleted)
                    .foregroundStyle(item.isCompleted ? .secondary : .primary)

                if let secondaryText {
                    Text(secondaryText)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary.opacity(0.8))
                        .lineLimit(1)
                }
            }
            
            Spacer()

            if showsDisclosure {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : Color(nsColor: .tertiaryLabelColor))
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(backgroundColor)
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(borderColor, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .opacity(contentOpacity)
    }
    
    private var timeRangeText: String {
        if item.isAllDay {
            return String(localized: "All Day")
        }

        guard let startDate = item.timelineDate else {
            return String(localized: "No Time")
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short

        let start = formatter.string(from: startDate)

        if let endDate = item.endDate {
            let end = formatter.string(from: endDate)
            return "\(start)-\(end)"
        }

        return start
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.12)
        }
        if timelineState == .ongoing {
            return Color.accentColor.opacity(0.08)
        }
        if timelineState == .past {
            return Color(nsColor: .controlBackgroundColor).opacity(0.75)
        }
        return Color(nsColor: .controlBackgroundColor)
    }

    private var borderColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.35)
        }
        if timelineState == .ongoing {
            return Color.accentColor.opacity(0.24)
        }
        return Color.primary.opacity(0.05)
    }

    private var contentOpacity: Double {
        if timelineState == .past, !isSelected {
            return 0.78
        }
        return 1
    }

    private var secondaryText: String? {
        if let location = item.location, !location.isEmpty {
            return location
        }

        let sourceTitle = item.sourceTitle
        return sourceTitle.isEmpty ? nil : sourceTitle
    }

    private var reminderCheckbox: some View {
        Button {
            if let reminder = item.ekReminder {
                onToggleReminder?(reminder)
            }
        } label: {
            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14))
                .foregroundStyle(item.isCompleted ? Color(nsColor: item.color) : .secondary)
        }
        .buttonStyle(.plain)
    }
}
