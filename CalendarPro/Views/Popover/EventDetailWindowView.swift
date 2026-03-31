import SwiftUI
import EventKit

struct EventDetailWindowView: View {
    let event: EKEvent
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PopoverSurfaceMetrics.sectionSpacing) {
            header
            summaryCard
            if let meetingLink {
                JoinMeetingButton(meetingLink: meetingLink, calendarColor: calendarColor)
            }
            detailScrollView
            FooterActions(event: event)
        }
        .padding(PopoverSurfaceMetrics.outerPadding)
        .frame(width: PopoverSurfaceMetrics.width, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(surfaceBackground)
    }

    private var meetingLink: MeetingLink? {
        MeetingLinkDetector.detect(in: event)
    }

    private var calendarColor: Color {
        Color(nsColor: event.calendar.color)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("日程详情")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)

                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(calendarColor)
                        .frame(width: 9, height: 9)
                        .padding(.top, 5)

                    Text(event.title ?? "无标题")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.92))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("event-detail-close-button")
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(dateRangeText)
                .font(.system(size: 14, weight: .semibold, design: .rounded))

            Text(timeSummaryText)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(sectionBackground(tint: calendarColor.opacity(0.12)))
    }

    private var detailScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PopoverSurfaceMetrics.sectionSpacing) {
                EventDetailRow(icon: "calendar", title: "所属日历", value: event.calendar.title)

                if let locationText {
                    EventDetailRow(icon: "mappin.and.ellipse", title: "地点", value: locationText)
                }

                if let attendees = event.attendees, !attendees.isEmpty {
                    AttendeesDetailRow(attendees: attendees)
                }

                if let url = event.url {
                    LinkDetailRow(url: url)
                }

                if let notesText {
                    NotesDetailRow(notes: notesText)
                }

                if locationText == nil, event.url == nil, notesText == nil,
                   (event.attendees ?? []).isEmpty {
                    EmptyDetailState()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var surfaceBackground: some View {
        RoundedRectangle(cornerRadius: PopoverSurfaceMetrics.cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(nsColor: .windowBackgroundColor),
                        calendarColor.opacity(0.06)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: PopoverSurfaceMetrics.cornerRadius, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.18), lineWidth: 1)
            )
    }

    private func sectionBackground(tint: Color = .clear) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.92))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.12), lineWidth: 1)
            )
    }

    private var locationText: String? {
        event.location?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }

    private var notesText: String? {
        event.notes?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }

    private var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("M月d日 EEEE")

        let endDate = visibleEndDate
        let calendar = Calendar.autoupdatingCurrent

        if calendar.isDate(event.startDate, inSameDayAs: endDate) {
            return formatter.string(from: event.startDate)
        }

        return "\(formatter.string(from: event.startDate)) - \(formatter.string(from: endDate))"
    }

    private var timeSummaryText: String {
        if event.isAllDay {
            return "全天"
        }

        let intervalFormatter = DateIntervalFormatter()
        intervalFormatter.locale = .autoupdatingCurrent
        intervalFormatter.dateStyle = .none
        intervalFormatter.timeStyle = .short
        return intervalFormatter.string(from: event.startDate, to: event.endDate)
    }

    private var visibleEndDate: Date {
        if event.isAllDay {
            return event.endDate.addingTimeInterval(-1)
        }
        return event.endDate
    }
}

private struct LinkDetailRow: View {
    let url: URL

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "link")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color(nsColor: .controlAccentColor).opacity(0.08))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text("链接")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                Link(destination: url) {
                    Text(url.absoluteString)
                        .font(.system(size: 12))
                        .foregroundColor(.accentColor)
                        .underline()
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .buttonStyle(.plain)
                .help(url.absoluteString)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.88))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.12), lineWidth: 1)
                )
        )
    }
}

private struct AttendeesDetailRow: View {
    let attendees: [EKParticipant]
    @State private var isExpanded = false

    private let defaultVisibleCount = 3

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "person.2")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color(nsColor: .controlAccentColor).opacity(0.08))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text("参会人")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                ForEach(Array(visibleAttendees.enumerated()), id: \.offset) { _, participant in
                    attendeeRow(participant)
                }

                if attendees.count > defaultVisibleCount {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Text(isExpanded ? "收起" : "还有 \(attendees.count - defaultVisibleCount) 人...")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.88))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.12), lineWidth: 1)
                )
        )
    }

    private var visibleAttendees: [EKParticipant] {
        if isExpanded || attendees.count <= defaultVisibleCount {
            return attendees
        }
        return Array(attendees.prefix(defaultVisibleCount))
    }

    private func attendeeRow(_ participant: EKParticipant) -> some View {
        HStack(spacing: 6) {
            statusIcon(for: participant.participantStatus)
            Text(participantName(participant))
                .font(.system(size: 12))
                .lineLimit(1)
        }
    }

    private func statusIcon(for status: EKParticipantStatus) -> some View {
        Group {
            switch status {
            case .accepted:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .declined:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            case .tentative:
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(.orange)
            default:
                Image(systemName: "circle")
                    .foregroundColor(.secondary)
            }
        }
        .font(.system(size: 11))
    }

    private func participantName(_ participant: EKParticipant) -> String {
        if let name = participant.name, !name.isEmpty {
            return name
        }
        let email = (participant.url as NSURL).resourceSpecifier ?? ""
        return email.isEmpty ? "未知参会人" : email
    }
}

private struct NotesDetailRow: View {
    let notes: String
    @State private var isExpanded = true
    @State private var needsCollapse = false

    private let collapsedLineLimit = 4

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "note.text")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color(nsColor: .controlAccentColor).opacity(0.08))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text("备注")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                if isExpanded {
                    expandedContent
                } else {
                    collapsedContent
                }

                if needsCollapse {
                    toggleButton
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.88))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.12), lineWidth: 1)
                )
        )
        .onAppear {
            needsCollapse = notes.components(separatedBy: .newlines).count > collapsedLineLimit
                || notes.count > 200
        }
    }

    private var collapsedContent: some View {
        ZStack(alignment: .bottomLeading) {
            Text(notes)
                .font(.system(size: 12))
                .lineLimit(collapsedLineLimit)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

            if needsCollapse {
                LinearGradient(
                    colors: [
                        Color(nsColor: .controlBackgroundColor).opacity(0),
                        Color(nsColor: .controlBackgroundColor).opacity(0.95),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 20)
                .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    private var expandedContent: some View {
        if #available(macOS 13.0, *) {
            SelfSizingTextView(notes: notes)
        } else {
            Text(notes)
                .font(.system(size: 12))
                .textSelection(.enabled)
        }
    }

    private var toggleButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            Text(isExpanded ? "收起" : "展开")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.accentColor)
        }
        .buttonStyle(.plain)
    }
}

@available(macOS 13.0, *)
private struct SelfSizingTextView: View {
    let notes: String
    @State private var textHeight: CGFloat = 40

    var body: some View {
        AttributedTextView(notes: notes, textHeight: $textHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: textHeight)
    }
}

@available(macOS 13.0, *)
private struct AttributedTextView: NSViewRepresentable {
    let notes: String
    @Binding var textHeight: CGFloat

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainerInset = .zero
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultHigh, for: .vertical)

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.autoresizingMask = [.width]
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        let attributedString = NSMutableAttributedString(string: notes)
        let fullRange = NSRange(location: 0, length: attributedString.length)

        attributedString.addAttribute(.font, value: NSFont.systemFont(ofSize: 12), range: fullRange)
        attributedString.addAttribute(.foregroundColor, value: NSColor.labelColor, range: fullRange)

        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let matches = detector.matches(in: notes, options: [], range: fullRange)
            for match in matches {
                if let url = match.url {
                    attributedString.addAttribute(.link, value: url, range: match.range)
                    attributedString.addAttribute(.foregroundColor, value: NSColor.controlAccentColor, range: match.range)
                    attributedString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: match.range)
                }
            }
        }

        textView.textStorage?.setAttributedString(attributedString)

        DispatchQueue.main.async {
            let width = scrollView.contentSize.width
            guard width > 0 else { return }
            textView.textContainer?.containerSize = CGSize(width: width, height: .greatestFiniteMagnitude)
            textView.layoutManager?.ensureLayout(for: textView.textContainer!)
            if let usedRect = textView.layoutManager?.usedRect(for: textView.textContainer!) {
                let newHeight = ceil(usedRect.height)
                if abs(self.textHeight - newHeight) > 1 {
                    self.textHeight = newHeight
                }
            }
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSScrollView, context: Context) -> CGSize? {
        guard let textView = nsView.documentView as? NSTextView else { return nil }
        let width = proposal.width ?? nsView.bounds.width
        guard width > 0 else { return nil }

        textView.textContainer?.containerSize = CGSize(width: width, height: .greatestFiniteMagnitude)
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)

        guard let usedRect = textView.layoutManager?.usedRect(for: textView.textContainer!) else {
            return nil
        }

        return CGSize(width: width, height: ceil(usedRect.height))
    }
}

private struct EventDetailRow: View {
    let icon: String
    let title: String
    let value: String
    var lineLimit: Int? = 2

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color(nsColor: .controlAccentColor).opacity(0.08))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.system(size: 12))
                    .lineLimit(lineLimit)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.88))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.12), lineWidth: 1)
                )
        )
    }
}

private struct EmptyDetailState: View {
    var body: some View {
        Text("暂无更多详情")
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.7))
            )
    }
}

private struct JoinMeetingButton: View {
    let meetingLink: MeetingLink
    let calendarColor: Color

    var body: some View {
        Button {
            NSWorkspace.shared.open(meetingLink.url)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: meetingLink.iconName)
                    .font(.system(size: 13, weight: .semibold))

                Text("加入\(meetingLink.platform)会议")
                    .font(.system(size: 13, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(calendarColor)
            )
            .foregroundColor(.white)
        }
        .buttonStyle(.plain)
    }
}

private struct FooterActions: View {
    let event: EKEvent

    var body: some View {
        Button {
            let timestamp = event.startDate.timeIntervalSinceReferenceDate
            if let calURL = URL(string: "calshow:\(timestamp)") {
                NSWorkspace.shared.open(calURL)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 11, weight: .semibold))
                Text("在日历中打开")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color(nsColor: .separatorColor).opacity(0.12), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private extension URL {
    var isValidURL: Bool {
        guard let scheme = scheme else { return false }
        return scheme.hasPrefix("http") || scheme.hasPrefix("https") || scheme.hasPrefix("mailto")
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
