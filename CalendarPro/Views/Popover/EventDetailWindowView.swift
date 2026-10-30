import SwiftUI
import EventKit
import AppKit

private enum EventDetailMeasuredRegion: Hashable {
    case header
    case summary
    case meeting
    case content
    case footer
}

private struct EventDetailRegionHeightsPreferenceKey: PreferenceKey {
    static var defaultValue: [EventDetailMeasuredRegion: CGFloat] { [:] }

    static func reduce(value: inout [EventDetailMeasuredRegion: CGFloat], nextValue: () -> [EventDetailMeasuredRegion: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

struct EventDetailWindowView: View {
    let event: EKEvent
    let onEdit: (EKEvent) -> Void
    let onDelete: (EKEvent) -> Void
    let onClose: () -> Void
    let onPreferredHeightChange: ((CGFloat) -> Void)?
    let onJoinMeeting: (() -> Void)?
    @Environment(\.colorScheme) private var colorScheme

    private let meetingActionOpener = MeetingActionOpener()

    let maximumHeight: CGFloat
    @State private var formatters: Formatters
    @State private var displayedParticipationChoice: EventParticipationChoice?
    @State private var pendingParticipationChoice: EventParticipationChoice?
    @State private var showsParticipationScopeDialog = false
    @State private var responseErrorMessage: String?
    @State private var regionHeights: [EventDetailMeasuredRegion: CGFloat] = [:]

    private struct Formatters {
        let locale: Locale
        let calendar: Calendar
        let dates: DateFormatter
        let times: DateIntervalFormatter

        init(calendar: Calendar) {
            let locale = AppLocalization.locale
            self.locale = locale
            self.calendar = calendar

            let dates = DateFormatter()
            dates.locale = locale
            dates.calendar = calendar
            dates.timeZone = calendar.timeZone
            dates.setLocalizedDateFormatFromTemplate("MMMdEEEE")
            self.dates = dates

            let times = DateIntervalFormatter()
            times.locale = locale
            times.calendar = calendar
            times.timeZone = calendar.timeZone
            times.dateStyle = .none
            times.timeStyle = .short
            self.times = times
        }
    }

    private struct MeetingActionsSnapshot {
        let eventURL: URL?
        let notes: String?
        let location: String?
        let actions: [MeetingAction]
    }

    @State private var meetingActionsSnapshot: MeetingActionsSnapshot?

    init(
        event: EKEvent,
        maximumHeight: CGFloat = 700,
        onEdit: @escaping (EKEvent) -> Void,
        onDelete: @escaping (EKEvent) -> Void,
        onClose: @escaping () -> Void,
        onPreferredHeightChange: ((CGFloat) -> Void)? = nil,
        onJoinMeeting: (() -> Void)? = nil
    ) {
        self.event = event
        self.maximumHeight = maximumHeight
        _formatters = State(initialValue: Formatters(calendar: .autoupdatingCurrent))
        _meetingActionsSnapshot = State(initialValue: MeetingActionsSnapshot(
            eventURL: event.url,
            notes: event.notes,
            location: event.location,
            actions: MeetingActionResolver.resolve(for: event)
        ))
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onClose = onClose
        self.onPreferredHeightChange = onPreferredHeightChange
        self.onJoinMeeting = onJoinMeeting
        _displayedParticipationChoice = State(initialValue: event.currentUserParticipationChoice)
    }

    var body: some View {
        ZStack {
            content

            if showsParticipationScopeDialog {
                participationScopeOverlay
            }
        }
        .alert(L("Unable to Update Response"), isPresented: showsResponseError) {
            Button(L("OK")) {
                responseErrorMessage = nil
            }
        } message: {
            Text(responseErrorMessage ?? L("Unable to Update Response Description"))
        }
    }

    private var content: some View {
        let actions = resolvedMeetingActions
        return VStack(alignment: .leading, spacing: PopoverSurfaceMetrics.sectionSpacing) {
            header
                .background(measure(.header))
            summaryCard
                .background(measure(.summary))
            if !actions.isEmpty {
                MeetingActionsSection(
                    actions: actions,
                    calendarColor: calendarColor,
                    opener: meetingActionOpener,
                    onJoinMeeting: onJoinMeeting
                )
                .background(measure(.meeting))
            }
            detailScrollView
            FooterActions(
                event: event,
                canModify: event.calendar.allowsContentModifications,
                onEdit: {
                    onEdit(event)
                },
                onDelete: {
                    onDelete(event)
                }
            )
            .background(measure(.footer))
        }
        .padding(PopoverSurfaceMetrics.outerPadding)
        .frame(width: PopoverSurfaceMetrics.width, alignment: .topLeading)
        .background(surfaceBackground)
        .onPreferenceChange(EventDetailRegionHeightsPreferenceKey.self, perform: updateMeasuredRegions)
        .disabled(showsParticipationScopeDialog)
        .onChange(of: AppLocalization.locale.identifier) { _, _ in
            formatters = Formatters(calendar: .autoupdatingCurrent)
        }
        .onChange(of: Calendar.autoupdatingCurrent.timeZone.identifier) { _, _ in
            formatters = Formatters(calendar: .autoupdatingCurrent)
        }
        .onChange(of: event.url) { _, _ in refreshMeetingActionsSnapshot() }
        .onChange(of: event.notes) { _, _ in refreshMeetingActionsSnapshot() }
        .onChange(of: event.location) { _, _ in refreshMeetingActionsSnapshot() }
    }

    private var participationScopeOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: PopoverSurfaceMetrics.cornerRadius, style: .continuous)
                .fill(Color.black.opacity(colorScheme == .dark ? 0.42 : 0.24))
                .ignoresSafeArea()
                .onTapGesture {
                    dismissParticipationScopeDialog()
                }

            VStack(alignment: .leading, spacing: 12) {
                Text(L("Apply Response"))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(L("Choose whether to update only this event or the whole series."))
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 8) {
                    if let pendingParticipationChoice {
                        participationScopeButton(title: L("Only This Event"), isPrimary: true) {
                            applyParticipationChoice(pendingParticipationChoice, span: .thisEvent)
                        }

                        participationScopeButton(title: L("Entire Series")) {
                            applyParticipationChoice(pendingParticipationChoice, span: .futureEvents)
                        }
                    }

                    participationScopeButton(title: L("Cancel")) {
                        dismissParticipationScopeDialog()
                    }
                }
                .padding(.top, 4)
            }
            .padding(18)
            .frame(width: min(PopoverSurfaceMetrics.width - 56, 300), alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .shadow(color: .black.opacity(0.22), radius: 18, x: 0, y: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.2), lineWidth: 1)
            )
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
        .zIndex(1)
    }

    private func participationScopeButton(
        title: String,
        isPrimary: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isPrimary ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                )
                .foregroundStyle(isPrimary ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    private var resolvedMeetingActions: [MeetingAction] {
        let snapshot = meetingActionsSnapshot
        guard snapshot?.eventURL == event.url,
              snapshot?.notes == event.notes,
              snapshot?.location == event.location else {
            return MeetingActionResolver.resolve(for: event)
        }
        return snapshot?.actions ?? []
    }

    private var calendarContextPresentation: CalendarContextPresentation {
        event.calendarContextPresentation
    }

    private var calendarColor: Color {
        Color(nsColor: event.calendar.color)
    }

    private var isCanceled: Bool {
        event.isCanceled
    }

    private var canModifyParticipationChoice: Bool {
        if case .editable = participationPresentation {
            return true
        }

        return false
    }

    private var participationPresentation: EventParticipationPresentation {
        event.currentUserParticipationPresentation
    }

    private var showsReadOnlyParticipationNotice: Bool {
        participationPresentation == .readOnly
    }

    private var showsParticipationSection: Bool {
        canModifyParticipationChoice || showsReadOnlyParticipationNotice
    }

    private var showsResponseError: Binding<Bool> {
        Binding(
            get: { responseErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    responseErrorMessage = nil
                }
            }
        )
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L("Event Details"))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)

                if isCanceled {
                    canceledBadge
                }

                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(calendarColor.opacity(isCanceled ? 0.45 : 1))
                        .frame(width: 9, height: 9)
                        .padding(.top, 5)

                    SelectableDetailText(
                        text: event.title ?? L("Untitled"),
                        font: .system(size: 16, weight: .semibold, design: .rounded),
                        foregroundColor: isCanceled ? .secondary : .primary,
                        lineLimit: 2,
                        strikethrough: isCanceled
                    )
                }
            }

            Spacer(minLength: 0)

            if let displayedParticipationChoice, canModifyParticipationChoice {
                EventParticipationStatusBadge(choice: displayedParticipationChoice, style: .detail)
                    .padding(.top, 1)
            }

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
            SelectableDetailText(
                text: dateRangeText,
                font: .system(size: 14, weight: .semibold, design: .rounded),
                foregroundColor: isCanceled ? .secondary : .primary
            )

            SelectableDetailText(
                text: timeSummaryText,
                font: .system(size: 12),
                foregroundColor: isCanceled ? Color(nsColor: .tertiaryLabelColor) : .secondary
            )
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(sectionBackground(tint: summaryCardTint))
    }

    private var detailScrollView: some View {
        ScrollView {
            detailContent
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .frame(height: min(regionHeights[.content] ?? maximumDetailContentHeight, maximumDetailContentHeight))
    }

    private var detailContent: some View {
        VStack(alignment: .leading, spacing: PopoverSurfaceMetrics.sectionSpacing) {
            EventDetailRow(
                icon: "calendar",
                title: L("Calendar"),
                value: calendarContextPresentation.calendarTitle,
                secondaryValue: calendarContextPresentation.accountTitle,
                secondaryLineLimit: 1,
                secondaryTruncationMode: .middle
            )

            if canModifyParticipationChoice {
                ParticipationResponseRow(
                    currentChoice: displayedParticipationChoice,
                    onSelect: handleParticipationSelection
                )
            } else if showsReadOnlyParticipationNotice {
                ReadOnlyParticipationRow()
            }

            if let locationText {
                EventDetailRow(icon: "mappin.and.ellipse", title: L("Location"), value: locationText)
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

            if !showsParticipationSection,
               locationText == nil, event.url == nil, notesText == nil,
               (event.attendees ?? []).isEmpty {
                EmptyDetailState()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 1)
        .background(measure(.content))
    }

    private var surfaceBackground: some View {
        RoundedRectangle(cornerRadius: PopoverSurfaceMetrics.cornerRadius, style: .continuous)
            .fill(PopoverSurfaceMetrics.floatingPanelBaseFill(for: colorScheme))
            .overlay(
                RoundedRectangle(cornerRadius: PopoverSurfaceMetrics.cornerRadius, style: .continuous)
                    .fill(PopoverSurfaceMetrics.floatingPanelTintOverlay(accent: calendarColor, for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: PopoverSurfaceMetrics.cornerRadius, style: .continuous)
                    .stroke(PopoverSurfaceMetrics.floatingPanelBorderColor(for: colorScheme), lineWidth: 1)
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

    private var summaryCardTint: Color {
        isCanceled ? Color.red.opacity(0.08) : calendarColor.opacity(0.12)
    }

    private var canceledBadge: some View {
        Label(L("Canceled"), systemImage: "xmark.circle.fill")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.red)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.red.opacity(0.12))
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
        let endDate = visibleEndDate
        let calendar = Calendar.autoupdatingCurrent

        if calendar.isDate(event.startDate, inSameDayAs: endDate) {
            return formatters.dates.string(from: event.startDate)
        }

        return "\(formatters.dates.string(from: event.startDate)) - \(formatters.dates.string(from: endDate))"
    }

    private var timeSummaryText: String {
        if event.isAllDay {
            return L("All Day")
        }

        return formatters.times.string(from: event.startDate, to: event.endDate)
    }

    private var visibleEndDate: Date {
        CalendarEventScheduleDraft.displayedEndDate(
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            calendar: .autoupdatingCurrent
        ) ?? event.endDate
    }

    private var maximumDetailContentHeight: CGFloat {
        guard maximumHeight.isFinite else { return .infinity }
        let actions = resolvedMeetingActions
        let headerHeight = regionHeights[.header] ?? 0
        let summaryHeight = regionHeights[.summary] ?? 0
        let meetingHeight = actions.isEmpty ? 0 : (regionHeights[.meeting] ?? 0)
        let footerHeight = regionHeights[.footer] ?? 0
        let gaps = actions.isEmpty ? 3 : 4
        let chromeHeight = headerHeight + summaryHeight + meetingHeight + footerHeight
            + PopoverSurfaceMetrics.outerPadding * 2
            + PopoverSurfaceMetrics.sectionSpacing * CGFloat(gaps)
        return max(0, maximumHeight - chromeHeight)
    }

    private func measure(_ region: EventDetailMeasuredRegion) -> some View {
        GeometryReader { proxy in
            Color.clear.preference(key: EventDetailRegionHeightsPreferenceKey.self, value: [region: proxy.size.height])
        }
    }

    private func updateMeasuredRegions(_ measurements: [EventDetailMeasuredRegion: CGFloat]) {
        let actions = resolvedMeetingActions
        var updatedHeights = regionHeights
        for (region, height) in measurements where height.isFinite && height > 0 {
            guard abs((updatedHeights[region] ?? 0) - height) > 1 else { continue }
            updatedHeights[region] = height
        }

        if actions.isEmpty {
            updatedHeights.removeValue(forKey: .meeting)
        }

        guard updatedHeights != regionHeights else { return }
        regionHeights = updatedHeights

        guard let headerHeight = updatedHeights[.header],
              let summaryHeight = updatedHeights[.summary],
              let contentHeight = updatedHeights[.content],
              let footerHeight = updatedHeights[.footer] else {
            return
        }

        let meetingHeight = actions.isEmpty ? 0 : (updatedHeights[.meeting] ?? 0)
        let gaps = actions.isEmpty ? 3 : 4
        let naturalHeight = headerHeight + summaryHeight + meetingHeight + contentHeight + footerHeight
            + PopoverSurfaceMetrics.outerPadding * 2
            + PopoverSurfaceMetrics.sectionSpacing * CGFloat(gaps)
        onPreferredHeightChange?(ceil(naturalHeight))
    }

    private func refreshMeetingActionsSnapshot() {
        meetingActionsSnapshot = MeetingActionsSnapshot(
            eventURL: event.url,
            notes: event.notes,
            location: event.location,
            actions: MeetingActionResolver.resolve(for: event)
        )
    }

    private func handleParticipationSelection(_ choice: EventParticipationChoice) {
        guard choice != displayedParticipationChoice else {
            return
        }

        responseErrorMessage = nil

        if event.isRecurringParticipationSeries {
            pendingParticipationChoice = choice
            showsParticipationScopeDialog = true
            return
        }

        applyParticipationChoice(choice, span: .thisEvent)
    }

    private func dismissParticipationScopeDialog() {
        pendingParticipationChoice = nil
        showsParticipationScopeDialog = false
    }

    private func applyParticipationChoice(_ choice: EventParticipationChoice, span: EKSpan) {
        do {
            try event.updateCurrentUserParticipationChoice(choice, span: span)
            displayedParticipationChoice = choice
            dismissParticipationScopeDialog()
        } catch {
            dismissParticipationScopeDialog()
            responseErrorMessage = error.localizedDescription.nilIfEmpty ?? L("Unable to Update Response Description")
        }
    }
}

private struct HeightReporter: View {
    let onChange: (CGFloat) -> Void

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear {
                    report(proxy.size.height)
                }
                .onChange(of: proxy.size.height) { _, newValue in
                    report(newValue)
                }
        }
        .allowsHitTesting(false)
    }

    private func report(_ height: CGFloat) {
        DispatchQueue.main.async {
            onChange(height)
        }
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
                Text(L("Link"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                SelectableDetailText(
                    text: url.absoluteString,
                    font: .system(size: 12),
                    foregroundColor: .accentColor,
                    lineLimit: 2,
                    underline: true
                )

                OpenURLActionButton(title: L("Open Link"), url: url)
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
                Text(L("Attendees"))
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
                        Text(isExpanded ? L("Collapse") : LF("%d more attendees", attendees.count - defaultVisibleCount))
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
            SelectableDetailText(
                text: participantName(participant),
                font: .system(size: 12),
                lineLimit: 1
            )
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
        return email.isEmpty ? L("Unknown Attendee") : email
    }
}

private struct ParticipationResponseRow: View {
    let currentChoice: EventParticipationChoice?
    let onSelect: (EventParticipationChoice) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color(nsColor: .controlAccentColor).opacity(0.08))
                )

            VStack(alignment: .leading, spacing: 8) {
                Text(L("Response"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(EventParticipationChoice.allCases, id: \.self) { choice in
                        ParticipationChoiceButton(choice: choice, isSelected: currentChoice == choice) {
                            onSelect(choice)
                        }
                    }
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
}

private struct ReadOnlyParticipationRow: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color(nsColor: .controlAccentColor).opacity(0.08))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(L("Response"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(L("This event is read-only"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
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

private struct ParticipationChoiceButton: View {
    let choice: EventParticipationChoice
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbolName)
                    .font(.system(size: 10, weight: .semibold))

                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? selectedForegroundColor : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? selectedBackgroundColor : Color(nsColor: .windowBackgroundColor).opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? selectedBorderColor : Color(nsColor: .separatorColor).opacity(0.16), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var title: String {
        switch choice {
        case .accept:
            return L("Accept")
        case .maybe:
            return L("Maybe")
        case .decline:
            return L("Decline")
        }
    }

    private var symbolName: String {
        switch choice {
        case .accept:
            return "checkmark.circle.fill"
        case .maybe:
            return "questionmark.circle.fill"
        case .decline:
            return "xmark.circle.fill"
        }
    }

    private var selectedForegroundColor: Color {
        switch choice {
        case .accept:
            return Color(red: 0.11, green: 0.55, blue: 0.25)
        case .maybe:
            return Color(red: 0.82, green: 0.48, blue: 0.08)
        case .decline:
            return Color(red: 0.78, green: 0.22, blue: 0.19)
        }
    }

    private var selectedBackgroundColor: Color {
        selectedForegroundColor.opacity(0.12)
    }

    private var selectedBorderColor: Color {
        selectedForegroundColor.opacity(0.26)
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
                Text(L("Notes"))
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
            updateCollapseState()
        }
        .onChange(of: notes) { _, _ in
            updateCollapseState()
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
            Text(isExpanded ? L("Collapse") : L("Expand"))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.accentColor)
        }
        .buttonStyle(.plain)
    }

    private func updateCollapseState() {
        needsCollapse = notes.components(separatedBy: .newlines).count > collapsedLineLimit || notes.count > 200
    }
}

@available(macOS 13.0, *)
private struct SelfSizingTextView: View {
    let notes: String

    var body: some View {
        AttributedTextView(notes: notes)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@available(macOS 13.0, *)
private struct AttributedTextView: NSViewRepresentable {
    let notes: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

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
        guard context.coordinator.notes != notes else { return }

        let attributedString = NSMutableAttributedString(string: notes)
        let fullRange = NSRange(location: 0, length: attributedString.length)

        attributedString.addAttribute(.font, value: NSFont.systemFont(ofSize: 12), range: fullRange)
        attributedString.addAttribute(.foregroundColor, value: NSColor.labelColor, range: fullRange)

        if let detector = context.coordinator.linkDetector {
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
        context.coordinator.notes = notes
        context.coordinator.measuredWidth = nil
        context.coordinator.measuredHeight = nil
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSScrollView, context: Context) -> CGSize? {
        guard let textView = nsView.documentView as? NSTextView else { return nil }
        let width = proposal.width ?? nsView.contentSize.width
        guard width > 0 else { return nil }

        if context.coordinator.measuredWidth == width,
           let measuredHeight = context.coordinator.measuredHeight {
            return CGSize(width: width, height: measuredHeight)
        }

        textView.textContainer?.containerSize = CGSize(width: width, height: .greatestFiniteMagnitude)
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)

        guard let usedRect = textView.layoutManager?.usedRect(for: textView.textContainer!) else {
            return nil
        }

        let measuredHeight = ceil(usedRect.height)
        context.coordinator.measuredWidth = width
        context.coordinator.measuredHeight = measuredHeight
        return CGSize(width: width, height: measuredHeight)
    }

    @MainActor
    final class Coordinator {
        let linkDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        var notes: String?
        var measuredWidth: CGFloat?
        var measuredHeight: CGFloat?
    }
}

private struct EventDetailRow: View {
    let icon: String
    let title: String
    let value: String
    var secondaryValue: String? = nil
    var lineLimit: Int? = 2
    var secondaryLineLimit: Int? = nil
    var secondaryTruncationMode: Text.TruncationMode = .tail

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

                SelectableDetailText(
                    text: value,
                    font: .system(size: 12),
                    lineLimit: lineLimit
                )

                if let secondaryValue {
                    Text(secondaryValue)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(secondaryLineLimit)
                        .truncationMode(secondaryTruncationMode)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                        .help(secondaryValue)
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
}

private struct EmptyDetailState: View {
    var body: some View {
        Text(L("No More Details"))
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

private struct MeetingActionsSection: View {
    let actions: [MeetingAction]
    let calendarColor: Color
    let opener: MeetingActionOpener
    let onJoinMeeting: (() -> Void)?

    var body: some View {
        if let action = actions.first {
            MeetingActionButton(
                action: action,
                calendarColor: calendarColor,
                opener: opener,
                onJoinMeeting: onJoinMeeting
            )
        }
    }
}

private struct MeetingActionButton: View {
    let action: MeetingAction
    let calendarColor: Color
    let opener: MeetingActionOpener
    let onJoinMeeting: (() -> Void)?

    var body: some View {
        Button {
            _ = opener.open(action)
            onJoinMeeting?()
        } label: {
            HStack(spacing: 8) {
                MeetingPlatformMark(platform: action.platform, style: .detail)

                Text(action.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(calendarColor)
            )
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}

private struct FooterActions: View {
    let event: EKEvent
    let canModify: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            if canModify {
                footerButton(title: L("Edit"), systemImage: "pencil", action: onEdit)
                footerButton(title: L("Delete"), systemImage: "trash", isDestructive: true) {
                    confirmDelete()
                }
            }

            footerButton(title: L("Open"), systemImage: "calendar", action: openInCalendar)
        }
    }

    private func confirmDelete() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L("Delete Event?")
        alert.informativeText = L("This action cannot be undone.")
        alert.addButton(withTitle: L("Delete"))
        alert.addButton(withTitle: L("Cancel"))

        if alert.runModal() == .alertFirstButtonReturn {
            onDelete()
        }
    }

    private func openInCalendar() {
        let workspace = NSWorkspace.shared
        if let appURL = workspace.urlForApplication(
            withBundleIdentifier: "com.apple.iCal"
        ) {
            workspace.openApplication(at: appURL, configuration: .init())
        }
    }

    private func footerButton(
        title: String,
        systemImage: String,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(isDestructive ? .red : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
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
