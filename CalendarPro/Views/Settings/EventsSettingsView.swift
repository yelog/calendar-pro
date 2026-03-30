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
        GroupBox("日历日程") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("显示日程", isOn: showEventsBinding)
                    .toggleStyle(.checkbox)
                
                if !eventService.isAuthorized {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("需要日历访问权限")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        
                        Button("请求权限") {
                            Task {
                                await eventService.requestAccess()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                
                if eventService.isAuthorized && store.menuBarPreferences.showEvents {
                    Divider()
                    
                    Text("选择日历")
                        .font(.system(size: 12, weight: .medium))
                    
                    if eventService.calendars.isEmpty {
                        Text("暂无可用日历")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(calendarGroups, id: \.source?.title) { group in
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(group.source?.title ?? "未知")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(.secondary)
                                        
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
                        .frame(maxHeight: 200)
                    }
                }
                
                if eventService.remindersAuthorized {
                    Divider()
                    
                    Text("提醒事项")
                        .font(.system(size: 12, weight: .medium))
                    
                    Toggle("显示提醒事项", isOn: showRemindersBinding)
                        .toggleStyle(.checkbox)
                    
                    if store.menuBarPreferences.showReminders {
                        Text("选择提醒事项列表")
                            .font(.system(size: 12, weight: .medium))
                        
                        if eventService.reminderCalendars.isEmpty {
                            Text("暂无可用提醒事项列表")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        } else {
                            ScrollView {
                                VStack(spacing: 8) {
                                    ForEach(eventService.reminderCalendars, id: \.calendarIdentifier) { calendar in
                                        HStack {
                                            Circle()
                                                .fill(Color(nsColor: calendar.color))
                                                .frame(width: 12, height: 12)
                                            
                                            Text(calendar.title)
                                                .font(.system(size: 12))
                                            
                                            Spacer()
                                            
                                            Toggle("", isOn: reminderCalendarEnabledBinding(for: calendar.calendarIdentifier))
                                                .toggleStyle(.checkbox)
                                        }
                                    }
                                }
                            }
                            .frame(maxHeight: 200)
                        }
                    }
                }
            }
        }
    }
    
    private var showEventsBinding: Binding<Bool> {
        Binding(
            get: { store.menuBarPreferences.showEvents },
            set: { store.setShowEvents($0) }
        )
    }
    
    private func calendarEnabledBinding(for calendarID: String) -> Binding<Bool> {
        Binding(
            get: {
                let enabledIDs = store.menuBarPreferences.enabledCalendarIDs
                return enabledIDs.isEmpty || enabledIDs.contains(calendarID)
            },
            set: { store.setCalendarEnabled($0, calendarID: calendarID) }
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
            set: { store.setReminderCalendarEnabled($0, calendarID: calendarID) }
        )
    }
}