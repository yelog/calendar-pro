import SwiftUI
import EventKit

struct ReminderDetailWindowView: View {
    let reminder: EKReminder
    let onToggle: (EKReminder) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PopoverSurfaceMetrics.sectionSpacing) {
            header
            summaryCard
            detailScrollView
            FooterActions(reminder: reminder)
        }
        .padding(PopoverSurfaceMetrics.outerPadding)
        .frame(width: PopoverSurfaceMetrics.width, alignment: .topLeading)
        .background(surfaceBackground)
    }

    private var calendarColor: Color {
        Color(nsColor: reminder.calendar.color)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "Reminder Details"))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)

                HStack(alignment: .top, spacing: 8) {
                    Button {
                        onToggle(reminder)
                    } label: {
                        Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 16))
                            .foregroundStyle(reminder.isCompleted ? calendarColor : .secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)

                    SelectableDetailText(
                        text: reminder.title ?? String(localized: "Untitled"),
                        font: .system(size: 16, weight: .semibold, design: .rounded),
                        lineLimit: 2,
                        strikethrough: reminder.isCompleted
                    )
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
            .accessibilityIdentifier("reminder-detail-close-button")
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let dueDateText {
                SelectableDetailText(
                    text: dueDateText,
                    font: .system(size: 14, weight: .semibold, design: .rounded)
                )
            } else {
                Text(String(localized: "No Due Date"))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            if let dueTimeText {
                SelectableDetailText(
                    text: dueTimeText,
                    font: .system(size: 12),
                    foregroundColor: .secondary
                )
            }

            if reminder.isCompleted, let completionDate = reminder.completionDate {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.green)
                    SelectableDetailText(
                        text: String(format: String(localized: "Completed on %@"), formattedDate(completionDate)),
                        font: .system(size: 11),
                        foregroundColor: .secondary
                    )
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(sectionBackground(tint: calendarColor.opacity(0.12)))
    }

    // MARK: - Detail Scroll View

    private var detailScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PopoverSurfaceMetrics.sectionSpacing) {
                ReminderDetailRow(icon: "list.bullet", title: String(localized: "List"), value: reminder.calendar.title)

                if let recurrenceText {
                    ReminderDetailRow(icon: "repeat", title: String(localized: "Repeat"), value: recurrenceText)
                }

                if priorityText != nil {
                    ReminderDetailRow(icon: "flag.fill", title: String(localized: "Priority"), value: priorityText!)
                }

                if let alarmText {
                    ReminderDetailRow(icon: "bell.fill", title: String(localized: "Alert"), value: alarmText)
                }

                if let url = reminder.url {
                    ReminderLinkDetailRow(url: url)
                }

                if let notesText {
                    ReminderNotesDetailRow(notes: notesText)
                }

                if !hasAnyDetail {
                    ReminderEmptyDetailState()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 1)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    // MARK: - Computed Properties

    private var dueDateText: String? {
        guard let components = reminder.dueDateComponents,
              let date = Calendar.current.date(from: components) else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("MMMdEEEE")
        return formatter.string(from: date)
    }

    private var dueTimeText: String? {
        guard let components = reminder.dueDateComponents,
              components.hour != nil else {
            return nil
        }
        guard let date = Calendar.current.date(from: components) else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private var recurrenceText: String? {
        guard let rules = reminder.recurrenceRules, !rules.isEmpty,
              let rule = rules.first else {
            return nil
        }
        return describeRecurrenceRule(rule)
    }

    private var priorityText: String? {
        switch reminder.priority {
        case 0: return nil
        case 1...4: return String(localized: "High")
        case 5: return String(localized: "Medium")
        case 6...9: return String(localized: "Low")
        default: return nil
        }
    }

    private var alarmText: String? {
        guard let alarms = reminder.alarms, !alarms.isEmpty else {
            return nil
        }
        let descriptions = alarms.compactMap { alarm -> String? in
            if let absoluteDate = alarm.absoluteDate {
                let formatter = DateFormatter()
                formatter.locale = .autoupdatingCurrent
                formatter.dateStyle = .short
                formatter.timeStyle = .short
                return formatter.string(from: absoluteDate)
            }
            let offset = alarm.relativeOffset
            if offset == 0 {
                return String(localized: "At Due Time")
            }
            let minutes = Int(abs(offset) / 60)
            if minutes < 60 {
                return String(format: String(localized: "%d minutes before"), minutes)
            }
            let hours = minutes / 60
            if hours < 24 {
                return String(format: String(localized: "%d hours before"), hours)
            }
            let days = hours / 24
            return String(format: String(localized: "%d days before"), days)
        }
        return descriptions.joined(separator: ", ")
    }

    private var notesText: String? {
        reminder.notes?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }

    private var hasAnyDetail: Bool {
        recurrenceText != nil
            || priorityText != nil
            || alarmText != nil
            || reminder.url != nil
            || notesText != nil
    }

    // MARK: - Helpers

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func describeRecurrenceRule(_ rule: EKRecurrenceRule) -> String {
        let interval = rule.interval
        switch rule.frequency {
        case .daily:
            return interval == 1 ? String(localized: "Daily") : String(format: String(localized: "Every %d Days"), interval)
        case .weekly:
            if interval == 1 {
                if let days = rule.daysOfTheWeek, !days.isEmpty {
                    let dayNames = days.map { weekdayName($0.dayOfTheWeek) }
                    return String(format: String(localized: "Weekly %@"), dayNames.joined(separator: ", "))
                }
                return String(localized: "Weekly")
            }
            return String(format: String(localized: "Every %d Weeks"), interval)
        case .monthly:
            return interval == 1 ? String(localized: "Monthly") : String(format: String(localized: "Every %d Months"), interval)
        case .yearly:
            return interval == 1 ? String(localized: "Yearly") : String(format: String(localized: "Every %d Years"), interval)
        @unknown default:
            return String(localized: "Custom Repeat")
        }
    }

    private func weekdayName(_ weekday: EKWeekday) -> String {
        let calendar = Calendar.autoupdatingCurrent
        let symbols = DateFormatter().shortStandaloneWeekdaySymbols ?? calendar.shortWeekdaySymbols
        switch weekday {
        case .sunday: return symbols[0]
        case .monday: return symbols[1]
        case .tuesday: return symbols[2]
        case .wednesday: return symbols[3]
        case .thursday: return symbols[4]
        case .friday: return symbols[5]
        case .saturday: return symbols[6]
        @unknown default: return ""
        }
    }

    // MARK: - Background

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
}

// MARK: - Detail Row

private struct ReminderDetailRow: View {
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

                SelectableDetailText(
                    text: value,
                    font: .system(size: 12),
                    lineLimit: lineLimit
                )
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

// MARK: - Link Row

private struct ReminderLinkDetailRow: View {
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
                Text(String(localized: "Link"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                SelectableDetailText(
                    text: url.absoluteString,
                    font: .system(size: 12),
                    foregroundColor: .accentColor,
                    lineLimit: 2,
                    underline: true
                )

                OpenURLActionButton(title: String(localized: "Open Link"), url: url)
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

// MARK: - Notes Row

private struct ReminderNotesDetailRow: View {
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
                Text(String(localized: "Notes"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                if isExpanded {
                    Text(notes)
                        .font(.system(size: 12))
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                } else {
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

                if needsCollapse {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Text(isExpanded ? String(localized: "Collapse") : String(localized: "Expand"))
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
        .onAppear {
            needsCollapse = notes.components(separatedBy: .newlines).count > collapsedLineLimit
                || notes.count > 200
        }
    }
}

// MARK: - Empty State

private struct ReminderEmptyDetailState: View {
    var body: some View {
        Text(String(localized: "No More Details"))
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

// MARK: - Footer Actions

private struct FooterActions: View {
    let reminder: EKReminder

    var body: some View {
        Button {
            let item = CalendarItem.reminder(reminder)
            guard let url = item.remindersAppURL else {
                if let fallback = URL(string: "x-apple-reminderkit://") {
                    NSWorkspace.shared.open(fallback)
                }
                return
            }
            NSWorkspace.shared.open(url)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "list.bullet.rectangle.portrait")
                    .font(.system(size: 11, weight: .semibold))
                Text(String(localized: "Open in Reminders"))
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

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
