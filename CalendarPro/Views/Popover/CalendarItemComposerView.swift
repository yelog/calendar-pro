import SwiftUI
import EventKit

private enum ComposerMeasuredRegion: Hashable {
    case header
    case content
    case footer
}

private struct ComposerRegionHeightsPreferenceKey: PreferenceKey {
    static var defaultValue: [ComposerMeasuredRegion: CGFloat] { [:] }

    static func reduce(value: inout [ComposerMeasuredRegion: CGFloat], nextValue: () -> [ComposerMeasuredRegion: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

enum CalendarItemComposerMode {
    case create(
        kind: CalendarItemCreationKind,
        selectedDate: Date,
        initialTimeRange: CalendarItemCreationTimeRange?
    )
    case editEvent(EKEvent)
    case editReminder(EKReminder)
}

struct CalendarItemComposerView: View {
    let mode: CalendarItemComposerMode
    let eventCalendars: [EKCalendar]
    let reminderCalendars: [EKCalendar]
    let onSaveEvent: (CalendarEventCreationRequest) throws -> Void
    let onSaveReminder: (ReminderCreationRequest) throws -> Void
    let onClose: () -> Void
    let maximumHeight: CGFloat
    let onPreferredHeightChange: ((CGFloat) -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedKind: CalendarItemCreationKind
    @State private var title: String = ""
    @State private var selectedEventCalendarIdentifier: String
    @State private var selectedReminderCalendarIdentifier: String
    @State private var schedule: CalendarEventScheduleDraft
    @State private var dueDate: Date
    @State private var reminderIncludesTime: Bool = true
    @State private var notes: String = ""
    @State private var validationMessage: String?
    @State private var isSaving = false
    @State private var regionHeights: [ComposerMeasuredRegion: CGFloat] = [:]
    @State private var formatters: ScheduleFormatters
    @FocusState private var focusedField: FocusedField?

    private let editingCalendar: Calendar
    private var isAllDay: Bool { schedule.isAllDay }

    private struct ScheduleFormatters {
        let locale: Locale
        let calendar: Calendar
        let date: DateFormatter
        let time: DateFormatter

        init(calendar: Calendar) {
            let locale = AppLocalization.locale
            self.locale = locale
            self.calendar = calendar

            let date = DateFormatter()
            date.locale = locale
            date.calendar = calendar
            date.timeZone = calendar.timeZone
            date.setLocalizedDateFormatFromTemplate("yMMMdEEE")
            self.date = date

            let time = DateFormatter()
            time.locale = locale
            time.calendar = calendar
            time.timeZone = calendar.timeZone
            time.dateFormat = "HH:mm"
            self.time = time
        }
    }

    private enum FocusedField: Hashable {
        case title
        case allDay
        case startDate
        case startTime
        case endDate
        case endTime
        case calendar
        case notes
        case actions
    }

    init(
        mode: CalendarItemComposerMode,
        eventCalendars: [EKCalendar],
        reminderCalendars: [EKCalendar],
        maximumHeight: CGFloat = 700,
        onPreferredHeightChange: ((CGFloat) -> Void)? = nil,
        onSaveEvent: @escaping (CalendarEventCreationRequest) throws -> Void,
        onSaveReminder: @escaping (ReminderCreationRequest) throws -> Void,
        onClose: @escaping () -> Void
    ) {
        self.mode = mode
        self.eventCalendars = eventCalendars
        self.reminderCalendars = reminderCalendars
        self.maximumHeight = maximumHeight
        self.onPreferredHeightChange = onPreferredHeightChange
        self.onSaveEvent = onSaveEvent
        self.onSaveReminder = onSaveReminder
        self.onClose = onClose

        var editingCalendar = Calendar.current
        editingCalendar.timeZone = TimeZone.current
        self.editingCalendar = editingCalendar
        _formatters = State(initialValue: ScheduleFormatters(calendar: editingCalendar))

        let initialValues = Self.initialValues(
            for: mode,
            eventCalendars: eventCalendars,
            reminderCalendars: reminderCalendars,
            calendar: editingCalendar
        )
        _selectedKind = State(initialValue: initialValues.kind)
        _title = State(initialValue: initialValues.title)
        _selectedEventCalendarIdentifier = State(initialValue: initialValues.eventCalendarIdentifier)
        _selectedReminderCalendarIdentifier = State(initialValue: initialValues.reminderCalendarIdentifier)
        _schedule = State(initialValue: CalendarEventScheduleDraft(
            startDate: initialValues.startDate,
            endDate: initialValues.endDate,
            isAllDay: initialValues.isAllDay,
            calendar: editingCalendar
        ))
        _dueDate = State(initialValue: initialValues.dueDate)
        _reminderIncludesTime = State(initialValue: initialValues.reminderIncludesTime)
        _notes = State(initialValue: initialValues.notes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PopoverSurfaceMetrics.sectionSpacing) {
            header
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(key: ComposerRegionHeightsPreferenceKey.self, value: [.header: proxy.size.height])
                    }
                }
            ScrollView(.vertical) {
                content
                    .padding(.vertical, 1)
                    .fixedSize(horizontal: false, vertical: true)
                    .background {
                        GeometryReader { proxy in
                            Color.clear.preference(key: ComposerRegionHeightsPreferenceKey.self, value: [.content: proxy.size.height])
                        }
                    }
            }
            .scrollIndicators(.automatic)
            .frame(height: min(regionHeights[.content] ?? maximumScrollHeight, maximumScrollHeight))
            footer
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(key: ComposerRegionHeightsPreferenceKey.self, value: [.footer: proxy.size.height])
                    }
                }
        }
        .padding(PopoverSurfaceMetrics.outerPadding)
        .frame(width: PopoverSurfaceMetrics.width, alignment: .topLeading)
        .background(surfaceBackground)
        .onPreferenceChange(ComposerRegionHeightsPreferenceKey.self, perform: updateMeasuredRegions)
        .onAppear {
            DispatchQueue.main.async {
                focusedField = .title
            }
        }
        .onChange(of: selectedKind) { _, _ in
            validationMessage = nil
        }
        .onChange(of: title) { _, _ in validationMessage = nil }
        .onChange(of: selectedCalendarIdentifier) { _, _ in validationMessage = nil }
        .onChange(of: schedule) { _, _ in validationMessage = nil }
        .onChange(of: AppLocalization.locale.identifier) { _, _ in
            formatters = ScheduleFormatters(calendar: editingCalendar)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(headerTitle)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                Text(formattedScheduleSummary)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("calendar-item-composer-schedule-summary")
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
                .frame(minHeight: 68, maxHeight: 112)
                .focused($focusedField, equals: .notes)
                .accessibilityIdentifier("calendar-item-composer-notes-field")
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
                    .accessibilityIdentifier("calendar-item-composer-validation-error")
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
            .focused($focusedField, equals: .calendar)
        }
    }

    private var eventScheduleFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(L("All Day"), isOn: Binding(
                get: { schedule.isAllDay },
                set: { setAllDay($0) }
            ))
                .font(.system(size: 12))
                .accessibilityIdentifier("calendar-item-composer-all-day-toggle")
                .focused($focusedField, equals: .allDay)

            HStack(spacing: 8) {
                CalendarComposerDateButton(
                    title: L("Start Date"),
                    date: schedule.startDate,
                    calendar: editingCalendar,
                    onSelectDate: setStartDay
                )
                .focused($focusedField, equals: .startDate)

                if !isAllDay {
                    CalendarComposerTimeButton(
                        title: L("Start Time"),
                        date: schedule.startDate,
                        calendar: editingCalendar,
                        onSelectTime: setStartTime
                    )
                    .frame(width: 112)
                    .focused($focusedField, equals: .startTime)
                } else {
                    Color.clear
                        .frame(width: 112, height: 1)
                        .accessibilityHidden(true)
                }
            }

            HStack(spacing: 8) {
                CalendarComposerDateButton(
                    title: L("End Date"),
                    date: schedule.isAllDay ? (schedule.displayedEndDate ?? schedule.endDate) : schedule.endDate,
                    calendar: editingCalendar,
                    onSelectDate: setEndDay
                )
                .focused($focusedField, equals: .endDate)

                if !isAllDay {
                    CalendarComposerTimeButton(
                        title: L("End Time"),
                        date: schedule.endDate,
                        calendar: editingCalendar,
                        onSelectTime: setEndTime
                    )
                    .frame(width: 112)
                    .focused($focusedField, equals: .endTime)
                } else {
                    Color.clear
                        .frame(width: 112, height: 1)
                        .accessibilityHidden(true)
                }
            }

            if let inputError = schedule.inputError {
                scheduleErrorLabel(inputError.localizedDescription)
            } else if let scheduleError = schedule.validationError {
                scheduleErrorLabel(scheduleError.localizedDescription)
            }
        }
    }

    private func scheduleErrorLabel(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.system(size: 11))
            .foregroundStyle(.red)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("calendar-item-composer-schedule-error")
            .accessibilityValue(message)
    }

    private func allDayRangeSummary(for dayCount: Int) -> String {
        dayCount == 1 ? L("1 day inclusive") : LF("%d days inclusive", dayCount)
    }

    private var reminderFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            calendarPicker(
                title: L("List"),
                calendars: reminderCalendars,
                selection: $selectedReminderCalendarIdentifier
            )
            .focused($focusedField, equals: .calendar)

            CalendarComposerDateButton(
                title: L("Date"),
                date: $dueDate,
                calendar: editingCalendar
            )

            Toggle(L("Include Time"), isOn: $reminderIncludesTime)
                .font(.system(size: 12))

            if reminderIncludesTime {
                CalendarComposerTimeButton(
                    title: L("Time"),
                    date: $dueDate,
                    calendar: editingCalendar
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
            .accessibilityIdentifier("calendar-item-composer-save-button")
            .disabled(!canSave)
            .focused($focusedField, equals: .actions)
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

    private var canSave: Bool {
        guard !isSaving,
              !selectedCalendarIdentifier.isEmpty,
              !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        guard selectedKind == .event else { return true }
        return schedule.validationError == nil && schedule.inputError == nil
    }

    private var formattedScheduleSummary: String {
        if selectedKind == .reminder {
            let dateText = formatters.date.string(from: dueDate)
            guard reminderIncludesTime else { return dateText }
            return "\(dateText) · \(formatters.time.string(from: dueDate))"
        }

        let visibleEndDate = isAllDay ? (schedule.displayedEndDate ?? schedule.endDate) : schedule.endDate
        let dateText: String
        if editingCalendar.isDate(schedule.startDate, inSameDayAs: visibleEndDate) {
            dateText = formatters.date.string(from: schedule.startDate)
        } else {
            dateText = "\(formatters.date.string(from: schedule.startDate)) – \(formatters.date.string(from: visibleEndDate))"
        }

        if isAllDay {
            let summary = schedule.coveredDayCount.map(allDayRangeSummary(for:))
            return [dateText, L("All Day"), summary].compactMap { $0 }.joined(separator: " · ")
        }

        let timeRange = "\(formatters.time.string(from: schedule.startDate))–\(formatters.time.string(from: schedule.endDate))"
        return "\(dateText) · \(timeRange)"
    }

    private func setStartDay(_ day: Date) throws {
        try applyScheduleChange { try $0.setStartDay(day) }
    }

    private func setEndDay(_ day: Date) throws {
        try applyScheduleChange { try $0.setEndDay(day) }
    }

    private func setStartTime(hour: Int, minute: Int) throws {
        try applyScheduleChange { try $0.setStartTime(hour: hour, minute: minute) }
    }

    private func setEndTime(hour: Int, minute: Int) throws {
        try applyScheduleChange { try $0.setEndTime(hour: hour, minute: minute) }
    }

    private func setAllDay(_ isAllDay: Bool) {
        try? applyScheduleChange { try $0.setAllDay(isAllDay) }
    }

    private func applyScheduleChange(_ update: (inout CalendarEventScheduleDraft) throws -> Void) throws {
        var updatedSchedule = schedule
        do {
            try update(&updatedSchedule)
            updatedSchedule.setInputError(nil)
            schedule = updatedSchedule
            validationMessage = nil
        } catch {
            setScheduleInputError(error)
            throw error
        }
    }

    private func setScheduleInputError(_ error: Error) {
        var updatedSchedule = schedule
        updatedSchedule.setInputError(error as? CalendarEventScheduleError ?? .unableToCalculateDates)
        schedule = updatedSchedule
    }

    struct InitialValues {
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

    static func initialValues(
        for mode: CalendarItemComposerMode,
        eventCalendars: [EKCalendar],
        reminderCalendars: [EKCalendar],
        calendar: Calendar = .autoupdatingCurrent,
        now: Date = Date()
    ) -> InitialValues {
        let eventCalendarID = eventCalendars.first?.calendarIdentifier ?? ""
        let reminderCalendarID = reminderCalendars.first?.calendarIdentifier ?? ""

        switch mode {
        case .create(let kind, let selectedDate, let initialTimeRange):
            let eventRequest = CalendarEventCreationRequest.makeDefault(
                selectedDate: selectedDate,
                calendarIdentifier: eventCalendarID,
                calendar: calendar,
                now: now
            )
            let reminderRequest = ReminderCreationRequest.makeDefault(
                selectedDate: selectedDate,
                calendarIdentifier: reminderCalendarID,
                calendar: calendar,
                now: now
            )

            return InitialValues(
                kind: kind,
                selectedDate: selectedDate,
                title: "",
                eventCalendarIdentifier: eventCalendarID,
                reminderCalendarIdentifier: reminderCalendarID,
                startDate: initialTimeRange?.startDate ?? eventRequest.startDate,
                endDate: initialTimeRange?.endDate ?? eventRequest.endDate,
                isAllDay: eventRequest.isAllDay,
                dueDate: initialTimeRange?.startDate ?? reminderRequest.dueDate,
                reminderIncludesTime: initialTimeRange != nil || reminderRequest.includesTime,
                notes: ""
            )
        case .editEvent(let event):
            let eventRequest = CalendarEventCreationRequest.makeEditing(event)
            let reminderRequest = ReminderCreationRequest.makeDefault(
                selectedDate: event.startDate,
                calendarIdentifier: reminderCalendarID,
                calendar: calendar,
                now: now
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
                calendarIdentifier: eventCalendarID,
                calendar: calendar,
                now: now
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

        if selectedKind == .event {
            guard schedule.inputError == nil else {
                validationMessage = schedule.inputError?.localizedDescription
                return
            }
            guard schedule.validationError == nil else {
                validationMessage = schedule.validationError?.localizedDescription
                return
            }
        }

        isSaving = true
        validationMessage = nil

        do {
            switch selectedKind {
            case .event:
                let request = try CalendarEventCreationRequest.make(
                    title: normalizedTitle,
                    calendarIdentifier: selectedEventCalendarIdentifier,
                    schedule: schedule,
                    notes: notes
                )
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

    private var maximumScrollHeight: CGFloat {
        guard maximumHeight.isFinite else { return .infinity }
        let headerHeight = regionHeights[.header] ?? 0
        let footerHeight = regionHeights[.footer] ?? 0
        let chromeHeight = headerHeight + footerHeight
            + PopoverSurfaceMetrics.outerPadding * 2
            + PopoverSurfaceMetrics.sectionSpacing * 2
        return max(0, maximumHeight - chromeHeight)
    }

    private func updateMeasuredRegions(_ measurements: [ComposerMeasuredRegion: CGFloat]) {
        var updatedHeights = regionHeights
        for (region, height) in measurements where height.isFinite && height > 0 {
            guard abs((updatedHeights[region] ?? 0) - height) > 1 else { continue }
            updatedHeights[region] = height
        }

        guard updatedHeights != regionHeights else { return }
        regionHeights = updatedHeights

        guard let headerHeight = updatedHeights[.header],
              let contentHeight = updatedHeights[.content],
              let footerHeight = updatedHeights[.footer] else {
            return
        }

        let naturalHeight = headerHeight + contentHeight + footerHeight
            + PopoverSurfaceMetrics.outerPadding * 2
            + PopoverSurfaceMetrics.sectionSpacing * 2
        onPreferredHeightChange?(ceil(naturalHeight))
    }
}

private struct CalendarComposerDateButton: View {
    private struct Formatters {
        let locale: Locale
        let calendar: Calendar
        let date: DateFormatter

        init(calendar: Calendar) {
            let locale = AppLocalization.locale
            self.locale = locale
            self.calendar = calendar

            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.setLocalizedDateFormatFromTemplate("yMdEEE")
            date = formatter
        }
    }

    let title: String
    @Binding var date: Date
    let calendar: Calendar
    let onSelectDay: ((Date) throws -> Void)?
    @State private var isShowingPicker = false
    @State private var selectionError: String?
    @State private var formatters: Formatters

    init(title: String, date: Binding<Date>, calendar: Calendar = .autoupdatingCurrent) {
        self.title = title
        _date = date
        self.calendar = calendar
        _formatters = State(initialValue: Formatters(calendar: calendar))
        onSelectDay = { day in
            date.wrappedValue = date.wrappedValue.settingDate(toMatch: day, calendar: calendar)
        }
    }

    init(
        title: String,
        date: Date,
        calendar: Calendar,
        onSelectDate: @escaping (Date) throws -> Void
    ) {
        self.title = title
        let binding = Binding<Date>(get: { date }, set: { _ in })
        _date = binding
        self.calendar = calendar
        _formatters = State(initialValue: Formatters(calendar: calendar))
        onSelectDay = { selectedDay in
            try onSelectDate(selectedDay)
        }
    }

    var body: some View {
        Button {
            isShowingPicker.toggle()
        } label: {
            CalendarComposerFieldChrome(
                title: title,
                value: formattedDate,
                systemImage: "calendar"
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isShowingPicker, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                CalendarComposerMonthPicker(
                    date: $date,
                    calendar: calendar,
                    onSelectDay: { applySelectedDay($0) }
                ) {
                    isShowingPicker = false
                }

                if let selectionError {
                    Text(selectionError)
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack {
                    Button(L("Today")) {
                        _ = applySelectedDay(Date())
                    }

                    Spacer(minLength: 0)
                }
            }
            .padding(12)
            .frame(width: 300)
            .onExitCommand { isShowingPicker = false }
        }
        .accessibilityLabel(title)
        .accessibilityValue(formattedDate)
        .accessibilityIdentifier(accessibilityIdentifier ?? "calendar-item-composer-reminder-date")
        .onChange(of: AppLocalization.locale.identifier) { _, _ in
            formatters = Formatters(calendar: calendar)
        }
        .onChange(of: calendar.timeZone.identifier) { _, _ in
            formatters = Formatters(calendar: calendar)
        }
    }

    private var accessibilityIdentifier: String? {
        switch title {
        case L("Start Date"): return "calendar-item-composer-start-date"
        case L("End Date"): return "calendar-item-composer-end-date"
        default: return nil
        }
    }

    private var formattedDate: String {
        formatters.date.string(from: date)
    }

    private func applySelectedDay(_ day: Date) -> Bool {
        do {
            if let onSelectDay {
                try onSelectDay(day)
            } else {
                date = date.settingDate(toMatch: day, calendar: calendar)
            }
            selectionError = nil
            isShowingPicker = false
            return true
        } catch {
            selectionError = error.localizedDescription
            return false
        }
    }

}

private struct CalendarComposerMonthPicker: View {
    private struct Formatters {
        let locale: Locale
        let calendar: Calendar
        let month: DateFormatter
        let day: DateFormatter

        init(calendar: Calendar) {
            let locale = AppLocalization.locale
            self.locale = locale
            self.calendar = calendar

            let monthFormatter = DateFormatter()
            monthFormatter.locale = locale
            monthFormatter.calendar = calendar
            monthFormatter.timeZone = calendar.timeZone
            monthFormatter.setLocalizedDateFormatFromTemplate("yMMM")
            month = monthFormatter

            let dayFormatter = DateFormatter()
            dayFormatter.locale = locale
            dayFormatter.calendar = calendar
            dayFormatter.timeZone = calendar.timeZone
            dayFormatter.setLocalizedDateFormatFromTemplate("yMMMdEEEE")
            day = dayFormatter
        }
    }

    @Binding var date: Date
    let calendar: Calendar
    let onSelectDay: (Date) -> Bool
    let onSelectDate: () -> Void
    @State private var visibleMonth: Date
    @State private var formatters: Formatters
    @State private var visibleWeekdaySymbols: [String]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    init(
        date: Binding<Date>,
        calendar: Calendar = .autoupdatingCurrent,
        onSelectDay: @escaping (Date) -> Bool = { _ in true },
        onSelectDate: @escaping () -> Void
    ) {
        _date = date
        self.calendar = calendar
        self.onSelectDay = onSelectDay
        self.onSelectDate = onSelectDate
        _visibleMonth = State(initialValue: calendar.startOfMonth(for: date.wrappedValue))
        _formatters = State(initialValue: Formatters(calendar: calendar))
        _visibleWeekdaySymbols = State(initialValue: Self.weekdaySymbols(for: calendar))
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Text(formattedVisibleMonth)
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
                        if onSelectDay(day) {
                            visibleMonth = calendar.startOfMonth(for: day)
                            onSelectDate()
                        }
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
                    .accessibilityLabel(formattedDay(day))
                }
            }
        }
        .frame(width: 276)
        .onChange(of: AppLocalization.locale.identifier) { _, _ in
            formatters = Formatters(calendar: calendar)
            visibleWeekdaySymbols = Self.weekdaySymbols(for: calendar)
        }
        .onChange(of: calendar.timeZone.identifier) { _, _ in
            formatters = Formatters(calendar: calendar)
            visibleWeekdaySymbols = Self.weekdaySymbols(for: calendar)
        }
    }

    private var weekdaySymbols: [String] {
        visibleWeekdaySymbols
    }

    private static func weekdaySymbols(for calendar: Calendar) -> [String] {
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

    private var formattedVisibleMonth: String {
        formatters.month.string(from: visibleMonth)
    }

    private func formattedDay(_ day: Date) -> String {
        formatters.day.string(from: day)
    }
}

private struct CalendarComposerTimeButton: View {
    private struct Formatter {
        let locale: Locale
        let calendar: Calendar
        let time: DateFormatter

        init(calendar: Calendar) {
            let locale = AppLocalization.locale
            self.locale = locale
            self.calendar = calendar

            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.dateFormat = "HH:mm"
            time = formatter
        }
    }

    let title: String
    @Binding var date: Date
    let calendar: Calendar
    let onSelectTime: ((Int, Int) throws -> Void)?
    @State private var isShowingPicker = false
    @State private var customTimeText = ""
    @State private var customTimeError: String?
    @State private var formatter: Formatter

    private let columns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6)
    ]

    init(
        title: String,
        date: Binding<Date>,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.title = title
        _date = date
        self.calendar = calendar
        _formatter = State(initialValue: Formatter(calendar: calendar))
        onSelectTime = nil
    }

    init(
        title: String,
        date: Date,
        calendar: Calendar,
        onSelectTime: @escaping (Int, Int) throws -> Void
    ) {
        self.title = title
        _date = .constant(date)
        self.calendar = calendar
        _formatter = State(initialValue: Formatter(calendar: calendar))
        self.onSelectTime = onSelectTime
    }

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
                                    applyTime(hour: slot.hour, minute: slot.minute)
                                } label: {
                                    Text(slot.label)
                                        .font(.system(size: 12, weight: slot.isSameTime(as: date, calendar: calendar) ? .semibold : .regular))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                .fill(slot.isSameTime(as: date, calendar: calendar) ? Color.accentColor.opacity(0.18) : Color.clear)
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
            .onExitCommand { isShowingPicker = false }
        }
        .onChange(of: isShowingPicker) { _, isShowing in
            if isShowing {
                customTimeText = displayValue
                customTimeError = nil
            }
        }
        .accessibilityLabel(title)
        .accessibilityValue(displayValue)
        .accessibilityIdentifier(accessibilityIdentifier ?? "calendar-item-composer-reminder-time")
        .onChange(of: AppLocalization.locale.identifier) { _, _ in
            formatter = Formatter(calendar: calendar)
        }
        .onChange(of: calendar.timeZone.identifier) { _, _ in
            formatter = Formatter(calendar: calendar)
        }
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
                    .submitScope()
                Button(L("OK")) {
                    applyCustomTime()
                }
                .keyboardShortcut(.defaultAction)
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
        formatter.time.string(from: date)
    }

    private var accessibilityIdentifier: String? {
        switch title {
        case L("Start Time"): return "calendar-item-composer-start-time"
        case L("End Time"): return "calendar-item-composer-end-time"
        default: return nil
        }
    }

    private var nearestSlotMinutes: Int {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return max(0, min(23 * 60 + 45, ((hour * 60 + minute + 7) / 15) * 15))
    }

    private func applyCustomTime() {
        guard let time = Self.parseTime(customTimeText) else {
            customTimeError = L("Use 24-hour time, for example 09:30.")
            return
        }

        applyTime(hour: time.hour, minute: time.minute)
    }

    private func applyTime(hour: Int, minute: Int) {
        do {
            if let onSelectTime {
                try onSelectTime(hour, minute)
            } else {
                date = date.settingTime(hour: hour, minute: minute, calendar: calendar)
            }
            customTimeError = nil
            isShowingPicker = false
        } catch {
            customTimeError = error.localizedDescription
        }
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
