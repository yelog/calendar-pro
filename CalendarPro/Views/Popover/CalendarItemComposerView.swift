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
            eventScheduleFields

            calendarPicker(
                title: L("Calendar"),
                calendars: eventCalendars,
                selection: $selectedEventCalendarIdentifier
            )
        }
    }

    private var eventScheduleFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(L("All Day"), isOn: $isAllDay)
                .font(.system(size: 12))

            CalendarComposerDateButton(
                title: L("Date"),
                date: $startDate
            )
                .onChange(of: startDate) { oldValue, newValue in
                    let delta = newValue.timeIntervalSince(oldValue)
                    endDate = endDate.addingTimeInterval(delta)
                    ensureEndDateAfterStart()
                }

            if !isAllDay {
                HStack(spacing: 8) {
                    CalendarComposerTimeButton(
                        title: L("Start"),
                        date: $startDate,
                        referenceDate: startDate
                    )
                    CalendarComposerTimeButton(
                        title: L("End"),
                        date: $endDate,
                        referenceDate: startDate
                    )
                        .onChange(of: endDate) { _, _ in
                            ensureEndDateAfterStart()
                        }
                }
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

            CalendarComposerDateButton(
                title: L("Date"),
                date: $dueDate
            )

            Toggle(L("Include Time"), isOn: $reminderIncludesTime)
                .font(.system(size: 12))

            if reminderIncludesTime {
                CalendarComposerTimeButton(
                    title: L("Time"),
                    date: $dueDate,
                    referenceDate: dueDate
                )
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

private struct CalendarComposerDateButton: View {
    let title: String
    @Binding var date: Date
    @State private var isShowingPicker = false

    var body: some View {
        Button {
            isShowingPicker.toggle()
        } label: {
            CalendarComposerFieldChrome(
                title: title,
                value: Self.dateFormatter.string(from: date),
                systemImage: "calendar"
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isShowingPicker, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                CalendarComposerMonthPicker(date: $date) {
                    isShowingPicker = false
                }

                HStack {
                    Button(L("Today")) {
                        date = date.settingDate(toMatch: Date())
                        isShowingPicker = false
                    }

                    Spacer(minLength: 0)
                }
            }
            .padding(12)
            .frame(width: 300)
        }
        .accessibilityLabel(title)
        .accessibilityValue(Self.dateFormatter.string(from: date))
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = AppLocalization.locale
        formatter.setLocalizedDateFormatFromTemplate("MMMdEEEE")
        return formatter
    }()
}

private struct CalendarComposerMonthPicker: View {
    @Binding var date: Date
    let onSelectDate: () -> Void
    @State private var visibleMonth: Date

    private let calendar = Calendar.autoupdatingCurrent
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    init(date: Binding<Date>, onSelectDate: @escaping () -> Void) {
        _date = date
        self.onSelectDate = onSelectDate
        _visibleMonth = State(initialValue: Calendar.autoupdatingCurrent.startOfMonth(for: date.wrappedValue))
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Text(Self.monthFormatter.string(from: visibleMonth))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))

                Spacer(minLength: 0)

                Button {
                    visibleMonth = calendar.date(byAdding: .month, value: -1, to: visibleMonth) ?? visibleMonth
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L("Previous Month"))

                Button {
                    visibleMonth = calendar.startOfMonth(for: Date())
                } label: {
                    Circle()
                        .fill(Color.secondary.opacity(0.7))
                        .frame(width: 7, height: 7)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L("Today"))

                Button {
                    visibleMonth = calendar.date(byAdding: .month, value: 1, to: visibleMonth) ?? visibleMonth
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L("Next Month"))
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(monthDays, id: \.self) { day in
                    Button {
                        date = date.settingDate(toMatch: day)
                        visibleMonth = calendar.startOfMonth(for: day)
                        onSelectDate()
                    } label: {
                        Text("\(calendar.component(.day, from: day))")
                            .font(.system(size: 13, weight: isSelected(day) ? .semibold : .medium, design: .rounded))
                            .foregroundStyle(dayForeground(for: day))
                            .frame(maxWidth: .infinity)
                            .frame(height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(dayBackground(for: day))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Self.fullDateFormatter.string(from: day))
                }
            }
        }
        .frame(width: 276)
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let startIndex = max(0, calendar.firstWeekday - 1)
        return Array(symbols[startIndex...]) + Array(symbols[..<startIndex])
    }

    private var monthDays: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: visibleMonth),
              let firstWeekInterval = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start) else {
            return []
        }

        return (0..<42).compactMap {
            calendar.date(byAdding: .day, value: $0, to: firstWeekInterval.start)
        }
    }

    private func isSelected(_ day: Date) -> Bool {
        calendar.isDate(day, inSameDayAs: date)
    }

    private func isInVisibleMonth(_ day: Date) -> Bool {
        calendar.isDate(day, equalTo: visibleMonth, toGranularity: .month)
    }

    private func dayForeground(for day: Date) -> Color {
        if isSelected(day) {
            return .white
        }
        if !isInVisibleMonth(day) {
            return .secondary.opacity(0.45)
        }
        if calendar.isDateInToday(day) {
            return .accentColor
        }
        return .primary
    }

    private func dayBackground(for day: Date) -> Color {
        if isSelected(day) {
            return .accentColor
        }
        if calendar.isDateInToday(day) {
            return Color.accentColor.opacity(0.12)
        }
        return .clear
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = AppLocalization.locale
        formatter.setLocalizedDateFormatFromTemplate("yMMM")
        return formatter
    }()

    private static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = AppLocalization.locale
        formatter.setLocalizedDateFormatFromTemplate("yMMMdEEEE")
        return formatter
    }()
}

private struct CalendarComposerTimeButton: View {
    let title: String
    @Binding var date: Date
    let referenceDate: Date
    @State private var isShowingPicker = false
    @State private var customTimeText = ""
    @State private var customTimeError: String?

    private let columns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6)
    ]

    var body: some View {
        Button {
            isShowingPicker.toggle()
        } label: {
            CalendarComposerFieldChrome(
                title: title,
                value: displayValue,
                systemImage: "clock"
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isShowingPicker, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                customTimeField

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 6) {
                            ForEach(Self.timeSlots, id: \.minutes) { slot in
                                Button {
                                    date = date.settingTime(hour: slot.hour, minute: slot.minute)
                                    isShowingPicker = false
                                } label: {
                                    Text(slot.label)
                                        .font(.system(size: 12, weight: slot.isSameTime(as: date) ? .semibold : .regular))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                .fill(slot.isSameTime(as: date) ? Color.accentColor.opacity(0.18) : Color.clear)
                                        )
                                }
                                .buttonStyle(.plain)
                                .id(slot.minutes)
                            }
                        }
                        .padding(8)
                    }
                    .frame(width: 220, height: 230)
                    .onAppear {
                        proxy.scrollTo(nearestSlotMinutes, anchor: .center)
                    }
                }
            }
            .padding(10)
            .frame(width: 240)
        }
        .onChange(of: isShowingPicker) { _, isShowing in
            if isShowing {
                customTimeText = Self.timeFormatter.string(from: date)
                customTimeError = nil
            }
        }
        .accessibilityLabel(title)
        .accessibilityValue(displayValue)
    }

    private var customTimeField: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                TextField("HH:mm", text: $customTimeText)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        applyCustomTime()
                    }

                Button(L("OK")) {
                    applyCustomTime()
                }
                .keyboardShortcut(.defaultAction)
            }

            if let customTimeError {
                Text(customTimeError)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }
        }
    }

    private var displayValue: String {
        let timeText = Self.timeFormatter.string(from: date)
        guard !Calendar.autoupdatingCurrent.isDate(date, inSameDayAs: referenceDate) else {
            return timeText
        }

        return "\(Self.relativeDayFormatter.string(from: date)) \(timeText)"
    }

    private var nearestSlotMinutes: Int {
        let calendar = Calendar.autoupdatingCurrent
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return max(0, min(23 * 60 + 45, ((hour * 60 + minute + 7) / 15) * 15))
    }

    private func applyCustomTime() {
        guard let time = Self.parseTime(customTimeText) else {
            customTimeError = L("Use 24-hour time, for example 09:30.")
            return
        }

        date = date.settingTime(hour: time.hour, minute: time.minute)
        customTimeError = nil
        isShowingPicker = false
    }

    private static func parseTime(_ text: String) -> (hour: Int, minute: Int)? {
        let normalizedText = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "：", with: ":")

        let components: [String]
        if normalizedText.contains(":") {
            components = normalizedText.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        } else if normalizedText.count == 3 || normalizedText.count == 4 {
            let splitIndex = normalizedText.index(normalizedText.endIndex, offsetBy: -2)
            components = [
                String(normalizedText[..<splitIndex]),
                String(normalizedText[splitIndex...])
            ]
        } else {
            return nil
        }

        guard components.count == 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else {
            return nil
        }

        return (hour, minute)
    }

    private static let timeSlots: [CalendarComposerTimeSlot] = stride(from: 0, through: 23 * 60 + 45, by: 15).map {
        CalendarComposerTimeSlot(minutes: $0)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = AppLocalization.locale
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let relativeDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = AppLocalization.locale
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter
    }()
}

private struct CalendarComposerTimeSlot {
    let minutes: Int

    var hour: Int {
        minutes / 60
    }

    var minute: Int {
        minutes % 60
    }

    var label: String {
        String(format: "%02d:%02d", hour, minute)
    }

    func isSameTime(as date: Date, calendar: Calendar = .autoupdatingCurrent) -> Bool {
        calendar.component(.hour, from: date) == hour
            && calendar.component(.minute, from: date) == minute
    }
}

private struct CalendarComposerFieldChrome: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.84)
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor).opacity(0.65))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.18), lineWidth: 1)
        )
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        guard let monthInterval = dateInterval(of: .month, for: date) else {
            return startOfDay(for: date)
        }
        return monthInterval.start
    }
}

private extension Date {
    func settingDate(toMatch newDate: Date, calendar: Calendar = .autoupdatingCurrent) -> Date {
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: self)
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: newDate)
        return calendar.date(
            from: DateComponents(
                calendar: calendar,
                year: dateComponents.year,
                month: dateComponents.month,
                day: dateComponents.day,
                hour: timeComponents.hour,
                minute: timeComponents.minute,
                second: timeComponents.second
            )
        ) ?? self
    }

    func settingTime(hour: Int, minute: Int, calendar: Calendar = .autoupdatingCurrent) -> Date {
        calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: self
        ) ?? self
    }
}
