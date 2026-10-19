import SwiftUI
import EventKit

struct UpcomingEventsSettingsView: View {
    @ObservedObject var store: SettingsStore
    @ObservedObject var eventService: EventService

    struct CalendarGroup {
        let source: EKSource?
        let calendars: [EKCalendar]
    }

    private var calendarGroups: [CalendarGroup] {
        let calendars = eventService.calendars
        let grouped = Dictionary(grouping: calendars, by: { $0.source })
        let groups = grouped.map { CalendarGroup(source: $0.key, calendars: $0.value) }
        return groups.sorted { lhs, rhs in
            let lhsTitle = lhs.source?.title ?? ""
            let rhsTitle = rhs.source?.title ?? ""
            return lhsTitle < rhsTitle
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox(L("Event Overview")) {
                    recentEventsSection
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 24)
        }
    }

    private var showUpcomingSectionBinding: Binding<Bool> {
        Binding(
            get: { store.menuBarPreferences.showUpcomingSection },
            set: { store.setShowUpcomingSection($0) }
        )
    }

    private var upcomingDayLimitBinding: Binding<Int> {
        Binding(
            get: { store.menuBarPreferences.upcomingDayLimit },
            set: { store.setUpcomingDayLimit($0) }
        )
    }

    private var upcomingIncludeRemindersBinding: Binding<Bool> {
        Binding(
            get: { store.menuBarPreferences.upcomingIncludeReminders },
            set: { store.setUpcomingIncludeReminders($0) }
        )
    }

    private func upcomingCalendarEnabledBinding(for calendarID: String) -> Binding<Bool> {
        Binding(
            get: {
                let enabledIDs = store.menuBarPreferences.upcomingEnabledCalendarIDs
                return enabledIDs.isEmpty || enabledIDs.contains(calendarID)
            },
            set: {
                store.setUpcomingCalendarEnabled(
                    $0,
                    calendarID: calendarID,
                    allCalendarIDs: eventService.calendars.map(\.calendarIdentifier)
                )
            }
        )
    }

    private func upcomingReminderCalendarEnabledBinding(for calendarID: String) -> Binding<Bool> {
        Binding(
            get: {
                let enabledIDs = store.menuBarPreferences.upcomingEnabledReminderCalendarIDs
                return enabledIDs.isEmpty || enabledIDs.contains(calendarID)
            },
            set: {
                store.setUpcomingReminderCalendarEnabled(
                    $0,
                    calendarID: calendarID,
                    allCalendarIDs: eventService.reminderCalendars.map(\.calendarIdentifier)
                )
            }
        )
    }

    private var recentEventsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(L("Show Overview View"), isOn: showUpcomingSectionBinding)
                .toggleStyle(.checkbox)

            Text(L("Overview View Description"))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if store.menuBarPreferences.showUpcomingSection {
                HStack {
                    Text(L("Overview Future Range"))
                    Spacer()
                    Picker(L("Overview Future Range"), selection: upcomingDayLimitBinding) {
                        Text(LF("%d days", 30)).tag(30)
                        Text(LF("%d days", 90)).tag(90)
                        Text(LF("%d days", 180)).tag(180)
                        Text(L("No Limit")).tag(0)
                    }
                    .frame(width: 120)
                    .labelsHidden()
                }

                Toggle(L("Include Reminders in Overview"), isOn: upcomingIncludeRemindersBinding)
                    .toggleStyle(.checkbox)

                upcomingCalendarSourcesSection

                if store.menuBarPreferences.upcomingIncludeReminders {
                    upcomingReminderSourcesSection
                }
            }
        }
    }

    @ViewBuilder
    private var upcomingCalendarSourcesSection: some View {
        if !eventService.isAuthorized {
            permissionRow(
                title: L("Calendar Access Required"),
                buttonTitle: L("Request Access")
            ) {
                Task {
                    await eventService.requestAccess()
                }
            }
        } else {
            Text(L("Choose Calendars for Overview"))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            if eventService.calendars.isEmpty {
                Text(L("No Calendars Available"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 12) {
                    ForEach(calendarGroups, id: \.source?.title) { group in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(group.source?.title ?? L("Unknown"))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.tertiary)

                            VStack(spacing: 4) {
                                ForEach(group.calendars, id: \.calendarIdentifier) { calendar in
                                    HStack {
                                        Circle()
                                            .fill(Color(nsColor: calendar.color))
                                            .frame(width: 10, height: 10)
                                        Text(calendar.title)
                                            .font(.system(size: 12))
                                        Spacer()
                                        Toggle("", isOn: upcomingCalendarEnabledBinding(for: calendar.calendarIdentifier))
                                            .toggleStyle(.checkbox)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var upcomingReminderSourcesSection: some View {
        if !eventService.remindersAuthorized {
            permissionRow(
                title: L("Reminders Access Required"),
                buttonTitle: L("Request Access")
            ) {
                Task {
                    await eventService.requestReminderAccess()
                }
            }
        } else {
            Text(L("Choose Reminder Lists for Overview"))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            if eventService.reminderCalendars.isEmpty {
                Text(L("No Reminder Lists Available"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 4) {
                    ForEach(eventService.reminderCalendars, id: \.calendarIdentifier) { calendar in
                        HStack {
                            Circle()
                                .fill(Color(nsColor: calendar.color))
                                .frame(width: 10, height: 10)
                            Text(calendar.title)
                                .font(.system(size: 12))
                            Spacer()
                            Toggle("", isOn: upcomingReminderCalendarEnabledBinding(for: calendar.calendarIdentifier))
                                .toggleStyle(.checkbox)
                        }
                    }
                }
            }
        }
    }

    private func permissionRow(title: String, buttonTitle: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Button(buttonTitle, action: action)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
    }
}
