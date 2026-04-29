import SwiftUI
import EventKit

enum CalendarItemComposerMode {
    case create(kind: CalendarItemCreationKind, selectedDate: Date)
    case editEvent(EKEvent)
    case editReminder(EKReminder)
}

struct CalendarItemComposerView: View {
    let mode: CalendarItemComposerMode
    let selectedDate: Date
    let eventCalendars: [EKCalendar]
    let reminderCalendars: [EKCalendar]
    let onSaveEvent: (CalendarEventCreationRequest) throws -> Void
    let onSaveReminder: (ReminderCreationRequest) throws -> Void
    let onClose: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedKind: CalendarItemCreationKind
    @State private var title: String = ""
    @State private var selectedEventCalendarIdentifier: String
    @State private var selectedReminderCalendarIdentifier: String
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
        mode: CalendarItemComposerMode,
        eventCalendars: [EKCalendar],
        reminderCalendars: [EKCalendar],
        onSaveEvent: @escaping (CalendarEventCreationRequest) throws -> Void,
        onSaveReminder: @escaping (ReminderCreationRequest) throws -> Void,
        onClose: @escaping () -> Void
    ) {
        self.mode = mode
        self.eventCalendars = eventCalendars
        self.reminderCalendars = reminderCalendars
        self.onSaveEvent = onSaveEvent
        self.onSaveReminder = onSaveReminder
        self.onClose = onClose

        let initialValues = Self.initialValues(
            for: mode,
            eventCalendars: eventCalendars,
            reminderCalendars: reminderCalendars
        )
        self.selectedDate = initialValues.selectedDate

        _selectedKind = State(initialValue: initialValues.kind)
        _title = State(initialValue: initialValues.title)
        _selectedEventCalendarIdentifier = State(initialValue: initialValues.eventCalendarIdentifier)
        _selectedReminderCalendarIdentifier = State(initialValue: initialValues.reminderCalendarIdentifier)
        _startDate = State(initialValue: initialValues.startDate)
        _endDate = State(initialValue: initialValues.endDate)
        _isAllDay = State(initialValue: initialValues.isAllDay)
        _dueDate = State(initialValue: initialValues.dueDate)
        _reminderIncludesTime = State(initialValue: initialValues.reminderIncludesTime)
        _notes = State(initialValue: initialValues.notes)
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
        .onChange(of: selectedKind) { _, _ in
            validationMessage = nil
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(headerTitle)
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
            if showsKindPicker {
                Picker(L("Type"), selection: $selectedKind) {
                    ForEach(availableKinds, id: \.self) { kind in
                        Text(kind == .event ? L("Event") : L("Reminder"))
                            .tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            TextField(L("Title"), text: $title)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .title)
                .accessibilityIdentifier("calendar-item-composer-title-field")

            if selectedKind == .event {
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
            calendarPicker(
                title: L("Calendar"),
                calendars: eventCalendars,
                selection: $selectedEventCalendarIdentifier
            )

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
            calendarPicker(
                title: L("List"),
                calendars: reminderCalendars,
                selection: $selectedReminderCalendarIdentifier
            )

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
                    Text(saveButtonTitle)
                        .frame(minWidth: 42)
                }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(isSaving || selectedCalendarIdentifier.isEmpty)
        }
    }

    private func calendarPicker(
        title: String,
        calendars: [EKCalendar],
        selection: Binding<String>
    ) -> some View {
        Picker(title, selection: selection) {
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

    private var availableKinds: [CalendarItemCreationKind] {
        if isEditing {
            return [selectedKind]
        }

        var kinds: [CalendarItemCreationKind] = []
        if !eventCalendars.isEmpty {
            kinds.append(.event)
        }
        if !reminderCalendars.isEmpty {
            kinds.append(.reminder)
        }
        return kinds
    }

    private var isEditing: Bool {
        switch mode {
        case .create:
            return false
        case .editEvent, .editReminder:
            return true
        }
    }

    private var showsKindPicker: Bool {
        !isEditing && availableKinds.count > 1
    }

    private var headerTitle: String {
        switch mode {
        case .create:
            return L("New Item")
        case .editEvent:
            return L("Edit Event")
        case .editReminder:
            return L("Edit Reminder")
        }
    }

    private var saveButtonTitle: String {
        isEditing ? L("Update") : L("Save")
    }

    private var selectedCalendarIdentifier: String {
        switch selectedKind {
        case .event:
            return selectedEventCalendarIdentifier
        case .reminder:
            return selectedReminderCalendarIdentifier
        }
    }

    private struct InitialValues {
        let kind: CalendarItemCreationKind
        let selectedDate: Date
        let title: String
        let eventCalendarIdentifier: String
        let reminderCalendarIdentifier: String
        let startDate: Date
        let endDate: Date
        let isAllDay: Bool
        let dueDate: Date
        let reminderIncludesTime: Bool
        let notes: String
    }

    private static func initialValues(
        for mode: CalendarItemComposerMode,
        eventCalendars: [EKCalendar],
        reminderCalendars: [EKCalendar]
    ) -> InitialValues {
        let eventCalendarID = eventCalendars.first?.calendarIdentifier ?? ""
        let reminderCalendarID = reminderCalendars.first?.calendarIdentifier ?? ""

        switch mode {
        case .create(let kind, let selectedDate):
            let eventRequest = CalendarEventCreationRequest.makeDefault(
                selectedDate: selectedDate,
                calendarIdentifier: eventCalendarID
            )
            let reminderRequest = ReminderCreationRequest.makeDefault(
                selectedDate: selectedDate,
                calendarIdentifier: reminderCalendarID
            )

            return InitialValues(
                kind: kind,
                selectedDate: selectedDate,
                title: "",
                eventCalendarIdentifier: eventCalendarID,
                reminderCalendarIdentifier: reminderCalendarID,
                startDate: eventRequest.startDate,
                endDate: eventRequest.endDate,
                isAllDay: eventRequest.isAllDay,
                dueDate: reminderRequest.dueDate,
                reminderIncludesTime: reminderRequest.includesTime,
                notes: ""
            )
        case .editEvent(let event):
            let eventRequest = CalendarEventCreationRequest.makeEditing(event)
            let reminderRequest = ReminderCreationRequest.makeDefault(
                selectedDate: event.startDate,
                calendarIdentifier: reminderCalendarID
            )

            return InitialValues(
                kind: .event,
                selectedDate: event.startDate,
                title: eventRequest.title,
                eventCalendarIdentifier: eventRequest.calendarIdentifier,
                reminderCalendarIdentifier: reminderCalendarID,
                startDate: eventRequest.startDate,
                endDate: eventRequest.endDate,
                isAllDay: eventRequest.isAllDay,
                dueDate: reminderRequest.dueDate,
                reminderIncludesTime: reminderRequest.includesTime,
                notes: eventRequest.notes ?? ""
            )
        case .editReminder(let reminder):
            let reminderRequest = ReminderCreationRequest.makeEditing(reminder)
            let eventRequest = CalendarEventCreationRequest.makeDefault(
                selectedDate: reminderRequest.dueDate,
                calendarIdentifier: eventCalendarID
            )

            return InitialValues(
                kind: .reminder,
                selectedDate: reminderRequest.dueDate,
                title: reminderRequest.title,
                eventCalendarIdentifier: eventCalendarID,
                reminderCalendarIdentifier: reminderRequest.calendarIdentifier,
                startDate: eventRequest.startDate,
                endDate: eventRequest.endDate,
                isAllDay: eventRequest.isAllDay,
                dueDate: reminderRequest.dueDate,
                reminderIncludesTime: reminderRequest.includesTime,
                notes: reminderRequest.notes ?? ""
            )
        }
    }

    private func save() {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTitle.isEmpty else {
            validationMessage = L("Title is required.")
            return
        }

        guard !selectedCalendarIdentifier.isEmpty else {
            validationMessage = selectedKind == .event
                ? L("No writable calendar is available.")
                : L("No writable reminder list is available.")
            return
        }

        isSaving = true
        validationMessage = nil

        do {
            switch selectedKind {
            case .event:
                var request = CalendarEventCreationRequest(
                    title: normalizedTitle,
                    calendarIdentifier: selectedEventCalendarIdentifier,
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
                        calendarIdentifier: selectedReminderCalendarIdentifier,
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
