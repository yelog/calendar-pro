import SwiftUI
import EventKit

enum EventCardTimelineState: Equatable {
    case regular
    case past
    case ongoing
}

private enum EventCardMetadata {
    case meeting(link: MeetingLink, participantCount: Int?)
    case recurringReminder(String)
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
            if timelineState == .ongoing && !item.isCanceled {
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
                    .fill(indicatorColor)
                    .frame(width: 6, height: 6)
                    .padding(.top, 4)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .top, spacing: 8) {
                    Text(timeRangeText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(timeTextColor)

                    Spacer(minLength: 8)

                    if showsDisclosure, let metadata {
                        metadataView(metadata)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(item.title)
                    .font(.system(size: 13, weight: .regular))
                    .lineLimit(2)
                    .strikethrough(item.isCompleted || item.isCanceled)
                    .foregroundStyle(titleColor)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let secondaryText {
                    Text(secondaryText)
                        .font(.system(size: 10))
                        .foregroundStyle(secondaryTextColor)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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

        if let endDate = item.endDate {
            let end = formatter.string(from: endDate)
            return "\(start)-\(end)"
        }

        return start
    }

    private var backgroundColor: Color {
        if item.isCanceled {
            return Color.red.opacity(isSelected ? 0.08 : 0.05)
        }
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
        if item.isCanceled {
            return Color.red.opacity(isSelected ? 0.32 : 0.2)
        }
        if isSelected {
            return Color.accentColor.opacity(0.35)
        }
        if timelineState == .ongoing {
            return Color.accentColor.opacity(0.24)
        }
        return Color.primary.opacity(0.05)
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
        let color = Color(nsColor: item.color)
        return item.isCanceled ? color.opacity(0.4) : color
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

    private var secondaryTextColor: Color {
        if item.isCanceled {
            return Color(nsColor: .tertiaryLabelColor)
        }
        return .secondary.opacity(0.8)
    }

    private var metadataColor: Color {
        if item.isCanceled {
            return Color(nsColor: .tertiaryLabelColor)
        }
        return isSelected ? Color.accentColor : Color(nsColor: .tertiaryLabelColor)
    }

    private var metadata: EventCardMetadata? {
        if let meetingLink = item.meetingLink {
            return .meeting(link: meetingLink, participantCount: item.meetingParticipantCount)
        }

        if let recurrenceText = item.reminderRecurrenceText {
            return .recurringReminder(recurrenceText)
        }

        return nil
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

    @ViewBuilder
    private func metadataView(_ metadata: EventCardMetadata) -> some View {
        switch metadata {
        case .meeting(let link, let participantCount):
            HStack(spacing: 5) {
                meetingPlatformIcon(for: link)

                if let participantCount {
                    HStack(spacing: 2) {
                        Image(systemName: "person.2")
                            .font(.system(size: 9, weight: .medium))
                        Text("\(participantCount)")
                    }
                    .foregroundStyle(metadataColor)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        case .recurringReminder(let recurrenceText):
            HStack(spacing: 4) {
                Image(systemName: "repeat")
                    .font(.system(size: 9, weight: .semibold))
                Text(recurrenceText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(metadataColor)
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    @ViewBuilder
    private func meetingPlatformIcon(for link: MeetingLink) -> some View {
        if link.platform == "Microsoft Teams" {
            TeamsBrandMark()
        } else {
            Image(systemName: link.iconName)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(metadataColor)
        }
    }
}

private struct TeamsBrandMark: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.43, green: 0.47, blue: 0.93))
                .frame(width: 4.6, height: 4.6)
                .offset(x: 4.8, y: 3)

            Circle()
                .fill(Color(red: 0.31, green: 0.36, blue: 0.84))
                .frame(width: 4.4, height: 4.4)
                .offset(x: 5.2, y: -3.1)

            RoundedRectangle(cornerRadius: 2.1, style: .continuous)
                .fill(Color(red: 0.38, green: 0.43, blue: 0.93))
                .frame(width: 6.2, height: 8.2)
                .offset(x: 2.3)

            RoundedRectangle(cornerRadius: 2.4, style: .continuous)
                .fill(Color(red: 0.28, green: 0.32, blue: 0.79))
                .frame(width: 8.1, height: 10.2)
                .offset(x: -1.1)

            Text("T")
                .font(.system(size: 6.3, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .offset(x: -1.1, y: -0.3)
        }
        .frame(width: 14, height: 12)
        .accessibilityHidden(true)
    }
}
