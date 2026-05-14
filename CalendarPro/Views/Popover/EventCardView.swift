import SwiftUI
import EventKit

enum EventCardTimelineState: Equatable {
    case regular
    case past
    case ongoing
}

private enum EventCardMetadata {
    case participation(EventParticipationChoice)
    case meeting(link: MeetingLink, participantCount: Int?)
    case recurringReminder(String)
}

struct EventCardView: View {
    let item: CalendarItem
    let isSelected: Bool
    let showsDisclosure: Bool
    let timelineState: EventCardTimelineState
    var onToggleReminder: ((EKReminder) -> Void)?
    @Environment(\.colorScheme) private var colorScheme

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
        HStack(alignment: .top, spacing: 10) {
            if item.isReminder {
                reminderCheckbox
                    .padding(.top, 1)
            } else {
                Circle()
                    .fill(indicatorColor)
                    .frame(width: 5, height: 5)
                    .padding(.top, 6)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 8) {
                    Text(timeRangeText)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(timeTextColor)

                    Spacer(minLength: 8)

                    if showsDisclosure, !metadataItems.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(Array(metadataItems.enumerated()), id: \.offset) { _, metadata in
                                metadataView(metadata)
                            }
                        }
                        .opacity(metadataOpacity)
                        .fixedSize(horizontal: true, vertical: false)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(item.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(2)
                    .strikethrough(item.isCompleted || item.isCanceled)
                    .foregroundStyle(titleColor)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let secondaryText {
                    Text(secondaryText)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(secondaryTextColor)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, 14)
        .padding(.trailing, 12)
        .padding(.vertical, 10)
        .background {
            ZStack {
                baseCardColor
                backgroundTintColor
            }
        }
        .overlay(alignment: .leading) {
            calendarColorRail
        }
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

    private var backgroundTintColor: Color {
        if item.isCanceled {
            return Color.red.opacity(isSelected ? 0.08 : 0.05)
        }
        if isSelected {
            return itemAccentColor.opacity(colorScheme == .dark ? 0.22 : 0.14)
        }
        if timelineState == .ongoing {
            return itemAccentColor.opacity(colorScheme == .dark ? 0.16 : 0.1)
        }
        if timelineState == .past {
            return Color(nsColor: .windowBackgroundColor).opacity(0.18)
        }
        return itemAccentColor.opacity(colorScheme == .dark ? 0.08 : 0.055)
    }

    private var borderColor: Color {
        if item.isCanceled {
            return Color.red.opacity(isSelected ? 0.32 : 0.2)
        }
        if isSelected {
            return itemAccentColor.opacity(colorScheme == .dark ? 0.55 : 0.42)
        }
        if timelineState == .ongoing {
            return itemAccentColor.opacity(colorScheme == .dark ? 0.42 : 0.3)
        }
        return itemAccentColor.opacity(colorScheme == .dark ? 0.18 : 0.14)
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

    private var calendarColorRail: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(railColor)
            .frame(width: 4)
            .padding(.vertical, 6)
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
        return isSelected ? itemAccentColor.opacity(0.9) : Color(nsColor: .tertiaryLabelColor)
    }

    private var metadataOpacity: Double {
        isSelected ? 0.9 : 0.72
    }

    private var metadataItems: [EventCardMetadata] {
        var items: [EventCardMetadata] = []

        if let participationChoice = item.currentUserParticipationChoice {
            items.append(.participation(participationChoice))
        }

        if let meetingLink = item.meetingLink {
            items.append(.meeting(link: meetingLink, participantCount: item.meetingParticipantCount))
        }

        if items.isEmpty, let recurrenceText = item.reminderRecurrenceText {
            items.append(.recurringReminder(recurrenceText))
        }

        return items
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
                .foregroundStyle(item.isCompleted ? itemAccentColor : .secondary)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func metadataView(_ metadata: EventCardMetadata) -> some View {
        switch metadata {
        case .participation(let choice):
            EventParticipationStatusBadge(choice: choice, style: .compactIcon)
        case .meeting(let link, let participantCount):
            HStack(spacing: 5) {
                MeetingPlatformMark(platform: link.platform, style: .compact)
                    .foregroundStyle(metadataColor)

                if let participantCount {
                    HStack(spacing: 2) {
                        Image(systemName: "person.2")
                            .font(.system(size: 9, weight: .medium))
                        Text(verbatim: "\(participantCount)")
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
}

enum EventParticipationBadgeStyle {
    case compactIcon
    case detail

    var font: Font {
        switch self {
        case .compactIcon:
            return .system(size: 10, weight: .semibold)
        case .detail:
            return .system(size: 11, weight: .semibold)
        }
    }

    var iconFont: Font {
        switch self {
        case .compactIcon:
            return .system(size: 9, weight: .semibold)
        case .detail:
            return .system(size: 10, weight: .semibold)
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .compactIcon:
            return 0
        case .detail:
            return 8
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .compactIcon:
            return 0
        case .detail:
            return 4
        }
    }

    var showsTitle: Bool {
        switch self {
        case .compactIcon:
            return false
        case .detail:
            return true
        }
    }

    var iconFrameSize: CGFloat {
        switch self {
        case .compactIcon:
            return 16
        case .detail:
            return 0
        }
    }
}

struct EventParticipationStatusBadge: View {
    let choice: EventParticipationChoice
    let style: EventParticipationBadgeStyle

    var body: some View {
        Group {
            if style.showsTitle {
                HStack(spacing: 4) {
                    Image(systemName: choice.badgeSymbolName)
                        .font(style.iconFont)

                    Text(choice.badgeTitle)
                        .font(style.font)
                        .lineLimit(1)
                }
                .padding(.horizontal, style.horizontalPadding)
                .padding(.vertical, style.verticalPadding)
                .background(
                    Capsule(style: .continuous)
                        .fill(choice.badgeBackgroundColor)
                )
            } else {
                Image(systemName: choice.badgeSymbolName)
                    .font(style.iconFont)
                    .frame(width: style.iconFrameSize, height: style.iconFrameSize)
                    .background(
                        Circle()
                            .fill(choice.badgeBackgroundColor)
                    )
            }
        }
        .foregroundStyle(choice.badgeForegroundColor)
        .fixedSize(horizontal: true, vertical: false)
    }
}

private extension EventParticipationChoice {
    var badgeTitle: String {
        switch self {
        case .accept:
            return L("Accepted")
        case .maybe:
            return L("Maybe")
        case .decline:
            return L("Declined")
        }
    }

    var badgeSymbolName: String {
        switch self {
        case .accept:
            return "checkmark.circle.fill"
        case .maybe:
            return "questionmark.circle.fill"
        case .decline:
            return "xmark.circle.fill"
        }
    }

    var badgeForegroundColor: Color {
        switch self {
        case .accept:
            return Color(red: 0.11, green: 0.55, blue: 0.25)
        case .maybe:
            return Color(red: 0.82, green: 0.48, blue: 0.08)
        case .decline:
            return Color(red: 0.78, green: 0.22, blue: 0.19)
        }
    }

    var badgeBackgroundColor: Color {
        switch self {
        case .accept:
            return Color(red: 0.11, green: 0.55, blue: 0.25).opacity(0.12)
        case .maybe:
            return Color(red: 0.82, green: 0.48, blue: 0.08).opacity(0.14)
        case .decline:
            return Color(red: 0.78, green: 0.22, blue: 0.19).opacity(0.12)
        }
    }
}

enum MeetingPlatformMarkStyle {
    case compact
    case detail

    var frameWidth: CGFloat {
        switch self {
        case .compact: return 14
        case .detail: return 18
        }
    }

    var frameHeight: CGFloat {
        switch self {
        case .compact: return 12
        case .detail: return 16
        }
    }

    var monogramFontSize: CGFloat {
        switch self {
        case .compact: return 6.3
        case .detail: return 7.5
        }
    }

    var symbolFont: Font {
        switch self {
        case .compact:
            return .system(size: 9, weight: .semibold)
        case .detail:
            return .system(size: 13, weight: .semibold)
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .compact: return 3.4
        case .detail: return 4.5
        }
    }

    var scale: CGFloat {
        switch self {
        case .compact: return 1
        case .detail: return 1.18
        }
    }
}

struct MeetingPlatformMark: View {
    let platform: MeetingPlatform
    let style: MeetingPlatformMarkStyle

    var body: some View {
        switch platform {
        case .microsoftTeams:
            TeamsBrandMark(style: style)
        case .tencentMeeting:
            MeetingMonogramMark(text: "TM", background: Color(red: 0.11, green: 0.51, blue: 0.98), style: style)
        case .feishu:
            MeetingMonogramMark(text: "F", background: Color(red: 0.18, green: 0.54, blue: 0.96), style: style)
        case .zoom:
            MeetingMonogramMark(text: "Z", background: Color(red: 0.16, green: 0.46, blue: 0.95), style: style)
        case .googleMeet:
            MeetingMonogramMark(text: "G", background: Color(red: 0.20, green: 0.66, blue: 0.33), style: style)
        case .webex:
            MeetingMonogramMark(text: "W", background: Color(red: 0.00, green: 0.68, blue: 0.71), style: style)
        default:
            Image(systemName: platform.symbolName)
                .font(style.symbolFont)
                .frame(width: style.frameWidth, height: style.frameHeight)
                .accessibilityHidden(true)
        }
    }
}

private struct MeetingMonogramMark: View {
    let text: String
    let background: Color
    let style: MeetingPlatformMarkStyle

    var body: some View {
        RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
            .fill(background)
            .overlay {
                Text(verbatim: text)
                    .font(.system(size: style.monogramFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            .frame(width: style.frameWidth, height: style.frameHeight)
            .accessibilityHidden(true)
    }
}

private struct TeamsBrandMark: View {
    let style: MeetingPlatformMarkStyle

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.43, green: 0.47, blue: 0.93))
                .frame(width: 4.6 * style.scale, height: 4.6 * style.scale)
                .offset(x: 4.8 * style.scale, y: 3 * style.scale)

            Circle()
                .fill(Color(red: 0.31, green: 0.36, blue: 0.84))
                .frame(width: 4.4 * style.scale, height: 4.4 * style.scale)
                .offset(x: 5.2 * style.scale, y: -3.1 * style.scale)

            RoundedRectangle(cornerRadius: 2.1, style: .continuous)
                .fill(Color(red: 0.38, green: 0.43, blue: 0.93))
                .frame(width: 6.2 * style.scale, height: 8.2 * style.scale)
                .offset(x: 2.3 * style.scale)

            RoundedRectangle(cornerRadius: 2.4, style: .continuous)
                .fill(Color(red: 0.28, green: 0.32, blue: 0.79))
                .frame(width: 8.1 * style.scale, height: 10.2 * style.scale)
                .offset(x: -1.1 * style.scale)

            Text(verbatim: "T")
                .font(.system(size: style.monogramFontSize, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .offset(x: -1.1 * style.scale, y: -0.3 * style.scale)
        }
        .frame(width: style.frameWidth, height: style.frameHeight)
        .accessibilityHidden(true)
    }
}
