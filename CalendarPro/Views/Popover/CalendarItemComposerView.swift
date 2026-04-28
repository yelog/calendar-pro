import SwiftUI
import EventKit

struct CalendarItemComposerView: View {
    let kind: CalendarItemCreationKind
    let selectedDate: Date
    let eventCalendars: [EKCalendar]
    let reminderCalendars: [EKCalendar]
    let onSaveEvent: (CalendarEventCreationRequest) throws -> Void
    let onSaveReminder: (ReminderCreationRequest) throws -> Void
    let onClose: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var title: String = ""
    @State private var selectedCalendarIdentifier: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var isAllDay: Bool = false
    @State private var dueDate: Date
    @State private var reminderIncludesTime: Bool = true
    @State private var notes: String = ""
    @State private var validationMessage: String?
    @State private var isSaving = false
    @FocusState private var focusedField: FocusedField?

    private enum FocusedField {
        case title
    }

    init(
        kind: CalendarItemCreationKind,
        selectedDate: Date,
        eventCalendars: [EKCalendar],
        reminderCalendars: [EKCalendar],
        onSaveEvent: @escaping (CalendarEventCreationRequest) throws -> Void,
        onSaveReminder: @escaping (ReminderCreationRequest) throws -> Void,
        onClose: @escaping () -> Void
    ) {
        self.kind = kind
        self.selectedDate = selectedDate
        self.eventCalendars = eventCalendars
        self.reminderCalendars = reminderCalendars
        self.onSaveEvent = onSaveEvent
        self.onSaveReminder = onSaveReminder
        self.onClose = onClose

        let eventCalendarID = eventCalendars.first?.calendarIdentifier ?? ""
        let reminderCalendarID = reminderCalendars.first?.calendarIdentifier ?? ""
        let fallbackCalendarID = kind == .event ? eventCalendarID : reminderCalendarID
        let eventRequest = CalendarEventCreationRequest.makeDefault(
            selectedDate: selectedDate,
            calendarIdentifier: eventCalendarID
        )
        let reminderRequest = ReminderCreationRequest.makeDefault(
            selectedDate: selectedDate,
            calendarIdentifier: reminderCalendarID
        )

        _selectedCalendarIdentifier = State(initialValue: fallbackCalendarID)
        _startDate = State(initialValue: eventRequest.startDate)
        _endDate = State(initialValue: eventRequest.endDate)
        _dueDate = State(initialValue: reminderRequest.dueDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PopoverSurfaceMetrics.sectionSpacing) {
            header
            content
            footer
        }
        .padding(PopoverSurfaceMetrics.outerPadding)
        .frame(width: PopoverSurfaceMetrics.width, alignment: .topLeading)
        .background(surfaceBackground)
        .onAppear {
            DispatchQueue.main.async {
                focusedField = .title
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(kind == .event ? L("New Event") : L("New Reminder"))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                Text(formattedSelectedDate)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
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
            .accessibilityIdentifier("calendar-item-composer-close-button")
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField(L("Title"), text: $title)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .title)
                .accessibilityIdentifier("calendar-item-composer-title-field")

            if kind == .event {
                eventFields
            } else {
                reminderFields
            }

            TextEditor(text: $notes)
                .font(.system(size: 12))
                .frame(minHeight: 68)
                .scrollContentBackground(.hidden)
                .background(sectionBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(alignment: .topLeading) {
                    if notes.isEmpty {
                        Text(L("Notes"))
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                }

            if let validationMessage {
                Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(sectionBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var eventFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            calendarPicker(title: L("Calendar"), calendars: eventCalendars)

            Toggle(L("All Day"), isOn: $isAllDay)
                .font(.system(size: 12))

            DatePicker(L("Date"), selection: $startDate, displayedComponents: .date)
                .font(.system(size: 12))
                .onChange(of: startDate) { oldValue, newValue in
                    let delta = newValue.timeIntervalSince(oldValue)
                    endDate = endDate.addingTimeInterval(delta)
                    ensureEndDateAfterStart()
                }

            if !isAllDay {
                HStack(spacing: 8) {
                    DatePicker(L("Start"), selection: $startDate, displayedComponents: .hourAndMinute)
                    DatePicker(L("End"), selection: $endDate, displayedComponents: .hourAndMinute)
                        .onChange(of: endDate) { _, _ in
                            ensureEndDateAfterStart()
                        }
                }
                .font(.system(size: 12))
            }
        }
    }

    private var reminderFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            calendarPicker(title: L("List"), calendars: reminderCalendars)

            DatePicker(L("Date"), selection: $dueDate, displayedComponents: .date)
                .font(.system(size: 12))

            Toggle(L("Include Time"), isOn: $reminderIncludesTime)
                .font(.system(size: 12))

            if reminderIncludesTime {
                DatePicker(L("Time"), selection: $dueDate, displayedComponents: .hourAndMinute)
                    .font(.system(size: 12))
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button(L("Cancel"), action: onClose)
                .keyboardShortcut(.cancelAction)

            Spacer(minLength: 0)

            Button {
                save()
            } label: {
                if isSaving {
                    ProgressView()
                        .scaleEffect(0.65)
                        .frame(width: 42)
                } else {
                    Text(L("Save"))
                        .frame(minWidth: 42)
                }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(isSaving || selectedCalendarIdentifier.isEmpty)
        }
    }

    private func calendarPicker(title: String, calendars: [EKCalendar]) -> some View {
        Picker(title, selection: $selectedCalendarIdentifier) {
            ForEach(calendars, id: \.calendarIdentifier) { calendar in
                Text(calendarPickerDisplayText(for: calendar))
                .tag(calendar.calendarIdentifier)
            }
        }
        .font(.system(size: 12))
    }

    private func calendarPickerDisplayText(for calendar: EKCalendar) -> String {
        let presentation = calendar.calendarContextPresentation
        guard let accountTitle = presentation.accountTitle else {
            return presentation.calendarTitle
        }
        return "\(presentation.calendarTitle) · \(accountTitle)"
    }

    private func save() {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTitle.isEmpty else {
            validationMessage = L("Title is required.")
            return
        }

        guard !selectedCalendarIdentifier.isEmpty else {
            validationMessage = kind == .event
                ? L("No writable calendar is available.")
                : L("No writable reminder list is available.")
            return
        }

        isSaving = true
        validationMessage = nil

        do {
            switch kind {
            case .event:
                var request = CalendarEventCreationRequest(
                    title: normalizedTitle,
                    calendarIdentifier: selectedCalendarIdentifier,
                    startDate: startDate,
                    endDate: endDate,
                    isAllDay: isAllDay,
                    notes: notes
                )
                if isAllDay {
                    request.startDate = Calendar.autoupdatingCurrent.startOfDay(for: startDate)
                    request.endDate = Calendar.autoupdatingCurrent.date(
                        byAdding: .day,
                        value: 1,
                        to: request.startDate
                    ) ?? request.startDate
                }
                try onSaveEvent(request)
            case .reminder:
                try onSaveReminder(
                    ReminderCreationRequest(
                        title: normalizedTitle,
                        calendarIdentifier: selectedCalendarIdentifier,
                        dueDate: dueDate,
                        includesTime: reminderIncludesTime,
                        notes: notes
                    )
                )
            }
            onClose()
        } catch {
            validationMessage = error.localizedDescription
        }

        isSaving = false
    }

    private func ensureEndDateAfterStart() {
        guard endDate <= startDate else { return }
        endDate = Calendar.autoupdatingCurrent.date(byAdding: .hour, value: 1, to: startDate) ?? startDate
    }

    private var formattedSelectedDate: String {
        let formatter = DateFormatter()
        formatter.locale = AppLocalization.locale
        formatter.setLocalizedDateFormatFromTemplate("MMMdEEEE")
        return formatter.string(from: selectedDate)
    }

    private var surfaceBackground: some View {
        RoundedRectangle(cornerRadius: PopoverSurfaceMetrics.cornerRadius, style: .continuous)
            .fill(PopoverSurfaceMetrics.floatingPanelBaseFill(for: colorScheme))
            .overlay(
                RoundedRectangle(cornerRadius: PopoverSurfaceMetrics.cornerRadius, style: .continuous)
                    .fill(PopoverSurfaceMetrics.floatingPanelTintOverlay(accent: .accentColor, for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: PopoverSurfaceMetrics.cornerRadius, style: .continuous)
                    .stroke(PopoverSurfaceMetrics.floatingPanelBorderColor(for: colorScheme), lineWidth: 1)
            )
    }

    private var sectionBackground: Color {
        Color(nsColor: .controlBackgroundColor).opacity(0.88)
    }
}
