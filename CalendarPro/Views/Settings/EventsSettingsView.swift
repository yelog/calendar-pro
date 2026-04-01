import SwiftUI
import EventKit

struct EventsSettingsView: View {
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
                GroupBox("日程") {
                    VStack(alignment: .leading, spacing: 14) {
                        Toggle("在面板中显示日程", isOn: showEventsBinding)
                            .toggleStyle(.checkbox)

                        Text("关闭后不会显示日历日程和提醒事项，已选来源会被保留。")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if store.menuBarPreferences.showEvents {
                            Divider()

                            Text("数据来源")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)

                            calendarEventsSection

                            Divider()

                            remindersSection
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 24)
        }
    }

    private var showEventsBinding: Binding<Bool> {
        Binding(
            get: { store.menuBarPreferences.showEvents },
            set: { store.setShowEvents($0) }
        )
    }

    private var showCalendarEventsBinding: Binding<Bool> {
        Binding(
            get: { store.menuBarPreferences.showCalendarEvents },
            set: { store.setShowCalendarEvents($0) }
        )
    }

    private func calendarEnabledBinding(for calendarID: String) -> Binding<Bool> {
        Binding(
            get: {
                let enabledIDs = store.menuBarPreferences.enabledCalendarIDs
                return enabledIDs.isEmpty || enabledIDs.contains(calendarID)
            },
            set: {
                store.setCalendarEnabled(
                    $0,
                    calendarID: calendarID,
                    allCalendarIDs: eventService.calendars.map(\.calendarIdentifier)
                )
            }
        )
    }

    private var showRemindersBinding: Binding<Bool> {
        Binding(
            get: { store.menuBarPreferences.showReminders },
            set: { store.setShowReminders($0) }
        )
    }

    private func reminderCalendarEnabledBinding(for calendarID: String) -> Binding<Bool> {
        Binding(
            get: {
                let enabledIDs = store.menuBarPreferences.enabledReminderCalendarIDs
                return enabledIDs.isEmpty || enabledIDs.contains(calendarID)
            },
            set: {
                store.setReminderCalendarEnabled(
                    $0,
                    calendarID: calendarID,
                    allCalendarIDs: eventService.reminderCalendars.map(\.calendarIdentifier)
                )
            }
        )
    }

    private var calendarEventsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("包含日历日程", isOn: showCalendarEventsBinding)
                .toggleStyle(.checkbox)

            if !eventService.isAuthorized {
                permissionRow(
                    title: "需要日历访问权限",
                    buttonTitle: "请求权限"
                ) {
                    Task {
                        await eventService.requestAccess()
                    }
                }
            } else if store.menuBarPreferences.showCalendarEvents {
                Text("选择日历")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                if eventService.calendars.isEmpty {
                    Text("暂无可用日历")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 12) {
                        ForEach(calendarGroups, id: \.source?.title) { group in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(group.source?.title ?? "未知")
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
                                            Toggle("", isOn: calendarEnabledBinding(for: calendar.calendarIdentifier))
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
    }

    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("包含提醒事项", isOn: showRemindersBinding)
                .toggleStyle(.checkbox)

            if !eventService.remindersAuthorized {
                permissionRow(
                    title: "需要提醒事项访问权限",
                    buttonTitle: "请求权限"
                ) {
                    Task {
                        await eventService.requestReminderAccess()
                    }
                }
            } else if store.menuBarPreferences.showReminders {
                Text("选择提醒事项列表")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                if eventService.reminderCalendars.isEmpty {
                    Text("暂无可用提醒事项列表")
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
                                Toggle("", isOn: reminderCalendarEnabledBinding(for: calendar.calendarIdentifier))
                                    .toggleStyle(.checkbox)
                            }
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
