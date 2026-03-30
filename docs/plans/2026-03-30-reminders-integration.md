# Reminders Integration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add reminders display support alongside calendar events, matching Apple Calendar behavior.

**Architecture:** Create unified `CalendarItem` enum to merge events and reminders. Extend `EventService` to fetch both types with proper permissions. Update UI components to handle the unified type with visual distinction for completed reminders.

**Tech Stack:** SwiftUI, EventKit, Combine

---

### Task 1: Create CalendarItem Enum

**Files:**
- Create: `CalendarPro/Features/Events/CalendarItem.swift`

**Step 1: Create CalendarItem enum**

```swift
import EventKit

enum CalendarItem: Identifiable {
    case event(EKEvent)
    case reminder(EKReminder)
    
    var id: String {
        switch self {
        case .event(let event):
            return "event-\(event.eventIdentifier)"
        case .reminder(let reminder):
            return "reminder-\(reminder.calendarItemIdentifier)"
        }
    }
    
    var title: String {
        switch self {
        case .event(let event):
            return event.title ?? "无标题"
        case .reminder(let reminder):
            return reminder.title ?? "无标题"
        }
    }
    
    var startDate: Date? {
        switch self {
        case .event(let event):
            return event.startDate
        case .reminder(let reminder):
            return reminder.dueDateComponents?.date
        }
    }
    
    var isCompleted: Bool {
        switch self {
        case .event:
            return false
        case .reminder(let reminder):
            return reminder.isCompleted
        }
    }
    
    var color: NSColor {
        switch self {
        case .event(let event):
            return event.calendar.color
        case .reminder(let reminder):
            return reminder.calendar.color
        }
    }
    
    var location: String? {
        switch self {
        case .event(let event):
            return event.location
        case .reminder:
            return nil
        }
    }
    
    var isAllDay: Bool {
        switch self {
        case .event(let event):
            return event.isAllDay
        case .reminder:
            return false
        }
    }
    
    var endDate: Date? {
        switch self {
        case .event(let event):
            return event.endDate
        case .reminder:
            return nil
        }
    }
}
```

**Step 2: Verify file compiles**

Run: `xcodebuild -scheme CalendarPro -configuration Debug build 2>&1 | grep -E "error:|warning:" | head -20`

**Step 3: Commit**

```bash
git add CalendarPro/Features/Events/CalendarItem.swift
git commit -m "feat: add CalendarItem enum to unify events and reminders"
```

---

### Task 2: Update MenuBarPreferences for Reminders Settings

**Files:**
- Modify: `CalendarPro/Settings/MenuBarPreferences.swift`

**Step 1: Add reminders properties**

Add after `enabledCalendarIDs`:
```swift
var showReminders: Bool
var enabledReminderCalendarIDs: [String]
```

**Step 2: Update default initializer**

Update `default` static property, add after `enabledCalendarIDs: []`:
```swift
showReminders: true,
enabledReminderCalendarIDs: []
```

**Step 3: Update preview initializer**

Update `previewShort` static property, add after `enabledCalendarIDs: []`:
```swift
showReminders: true,
enabledReminderCalendarIDs: []
```

**Step 4: Verify build**

Run: `xcodebuild -scheme CalendarPro -configuration Debug build 2>&1 | grep -E "error:|warning:" | head -20`

**Step 5: Commit**

```bash
git add CalendarPro/Settings/MenuBarPreferences.swift
git commit -m "feat: add reminders settings to MenuBarPreferences"
```

---

### Task 3: Update SettingsStore for Reminders

**Files:**
- Modify: `CalendarPro/Settings/SettingsStore.swift`

**Step 1: Add setShowReminders method**

Add after `setCalendarEnabled` method:
```swift
func setShowReminders(_ enabled: Bool) {
    menuBarPreferences.showReminders = enabled
    save()
}

func setReminderCalendarEnabled(_ enabled: Bool, calendarID: String) {
    if enabled {
        if !menuBarPreferences.enabledReminderCalendarIDs.contains(calendarID) {
            menuBarPreferences.enabledReminderCalendarIDs.append(calendarID)
        }
    } else {
        menuBarPreferences.enabledReminderCalendarIDs.removeAll { $0 == calendarID }
    }
    save()
}
```

**Step 2: Verify build**

Run: `xcodebuild -scheme CalendarPro -configuration Debug build 2>&1 | grep -E "error:|warning:" | head -20`

**Step 3: Commit**

```bash
git add CalendarPro/Settings/SettingsStore.swift
git commit -m "feat: add reminders settings methods to SettingsStore"
```

---

### Task 4: Update EventService for Reminders

**Files:**
- Modify: `CalendarPro/Features/Events/EventService.swift`

**Step 1: Add reminders properties**

Add after `isAuthorized` property:
```swift
@Published private(set) var remindersAuthorized: Bool = false
@Published private(set) var reminderCalendars: [EKCalendar] = []
```

**Step 2: Update checkAuthorizationStatus**

Replace the method with:
```swift
func checkAuthorizationStatus() {
    let eventStatus = EKEventStore.authorizationStatus(for: .event)
    let reminderStatus = EKEventStore.authorizationStatus(for: .reminder)
    
    isAuthorized = eventStatus == .fullAccess || eventStatus == .writeOnly
    remindersAuthorized = reminderStatus == .fullAccess || reminderStatus == .writeOnly
    authorizationStatus = eventStatus
}
```

**Step 3: Update requestAccess method**

Replace with:
```swift
func requestAccess() async -> Bool {
    do {
        let eventGranted = try await eventStore.requestFullAccessToEvents()
        isAuthorized = eventGranted
        authorizationStatus = eventGranted ? .fullAccess : .denied
        
        if eventGranted {
            fetchCalendars()
        }
        
        return eventGranted
    } catch {
        isAuthorized = false
        authorizationStatus = .denied
        return false
    }
}

func requestReminderAccess() async -> Bool {
    do {
        let granted = try await eventStore.requestFullAccessToReminders()
        remindersAuthorized = granted
        if granted {
            fetchReminderCalendars()
        }
        return granted
    } catch {
        remindersAuthorized = false
        return false
    }
}
```

**Step 4: Add fetchReminderCalendars method**

Add after `fetchCalendars`:
```swift
func fetchReminderCalendars() {
    guard remindersAuthorized else { return }
    reminderCalendars = eventStore.calendars(for: .reminder)
}
```

**Step 5: Add fetchReminders method**

Add after `fetchEvents`:
```swift
func fetchReminders(for date: Date, enabledCalendarIDs: [String]) -> [EKReminder] {
    guard remindersAuthorized else { return [] }
    
    let calendar = Calendar.current
    let startOfDay = calendar.startOfDay(for: date)
    let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
    
    let calendarsToFetch: [EKCalendar]
    if enabledCalendarIDs.isEmpty {
        calendarsToFetch = reminderCalendars
    } else {
        calendarsToFetch = reminderCalendars.filter { enabledCalendarIDs.contains($0.calendarIdentifier) }
    }
    
    guard !calendarsToFetch.isEmpty else { return [] }
    
    let predicate = eventStore.predicateForReminders(in: calendarsToFetch)
    let allReminders = eventStore.reminders(matching: predicate)
    
    return allReminders.filter { reminder in
        guard let dueDate = reminder.dueDateComponents?.date else { return false }
        return dueDate >= startOfDay && dueDate < endOfDay
    }
}
```

**Step 6: Add fetchCalendarItems method**

Add after `fetchReminders`:
```swift
func fetchCalendarItems(for date: Date, enabledCalendarIDs: [String], enabledReminderCalendarIDs: [String], showReminders: Bool) -> [CalendarItem] {
    var items: [CalendarItem] = []
    
    let events = fetchEvents(for: date)
    let filteredEvents = events.filter { event in
        enabledCalendarIDs.isEmpty || enabledCalendarIDs.contains(event.calendar.calendarIdentifier)
    }
    items.append(contentsOf: filteredEvents.map { .event($0) })
    
    if showReminders {
        let reminders = fetchReminders(for: date, enabledCalendarIDs: enabledReminderCalendarIDs)
        items.append(contentsOf: reminders.map { .reminder($0) })
    }
    
    return items.sorted { item1, item2 in
        let date1 = item1.startDate ?? Date.distantFuture
        let date2 = item2.startDate ?? Date.distantFuture
        return date1 < date2
    }
}
```

**Step 7: Add reminderCalendarWithIdentifier method**

Add after `calendar(withIdentifier:)`:
```swift
func reminderCalendar(withIdentifier identifier: String) -> EKCalendar? {
    return reminderCalendars.first { $0.calendarIdentifier == identifier }
}
```

**Step 8: Verify build**

Run: `xcodebuild -scheme CalendarPro -configuration Debug build 2>&1 | grep -E "error:|warning:" | head -20`

**Step 9: Commit**

```bash
git add CalendarPro/Features/Events/EventService.swift
git commit -m "feat: add reminders fetching support to EventService"
```

---

### Task 5: Update EventsSettingsView for Reminders

**Files:**
- Modify: `CalendarPro/Views/Settings/EventsSettingsView.swift`

**Step 1: Add reminders section**

Add after the calendar selection ScrollView (before closing VStack):
```swift
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
```

**Step 2: Add bindings**

Add after `calendarEnabledBinding` method:
```swift
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
```

**Step 3: Verify build**

Run: `xcodebuild -scheme CalendarPro -configuration Debug build 2>&1 | grep -E "error:|warning:" | head -20`

**Step 4: Commit**

```bash
git add CalendarPro/Views/Settings/EventsSettingsView.swift
git commit -m "feat: add reminders settings UI to EventsSettingsView"
```

---

### Task 6: Update EventCardView for CalendarItem

**Files:**
- Modify: `CalendarPro/Views/Popover/EventCardView.swift`

**Step 1: Change event property to item**

Replace `let event: EKEvent` with:
```swift
let item: CalendarItem
```

**Step 2: Update body**

Replace entire body with:
```swift
HStack(alignment: .top, spacing: 8) {
    Circle()
        .fill(Color(nsColor: item.color))
        .frame(width: 6, height: 6)
        .padding(.top, 4)
    
    VStack(alignment: .leading, spacing: 2) {
        Text(timeRangeText)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
        
        Text(item.title)
            .font(.system(size: 13, weight: .regular))
            .lineLimit(2)
            .strikethrough(item.isCompleted)
            .foregroundStyle(item.isCompleted ? .secondary : .primary)
        
        if let location = item.location, !location.isEmpty {
            Text(location)
                .font(.system(size: 10))
                .foregroundStyle(.secondary.opacity(0.8))
                .lineLimit(1)
        }
    }
    
    Spacer()
}
.padding(8)
.background(Color(nsColor: .controlBackgroundColor))
.clipShape(RoundedRectangle(cornerRadius: 8))
```

**Step 3: Update timeRangeText**

Replace with:
```swift
private var timeRangeText: String {
    if item.isAllDay {
        return "全天"
    }
    
    guard let startDate = item.startDate else {
        return ""
    }
    
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    
    let start = formatter.string(from: startDate)
    
    if let endDate = item.endDate {
        let end = formatter.string(from: endDate)
        return "\(start)-\(end)"
    }
    
    return start
}
```

**Step 4: Verify build**

Run: `xcodebuild -scheme CalendarPro -configuration Debug build 2>&1 | grep -E "error:|warning:" | head -20`

**Step 5: Commit**

```bash
git add CalendarPro/Views/Popover/EventCardView.swift
git commit -m "feat: update EventCardView to handle CalendarItem"
```

---

### Task 7: Update EventListView for CalendarItem

**Files:**
- Modify: `CalendarPro/Views/Popover/EventListView.swift`

**Step 1: Change events to items**

Replace `let events: [EKEvent]` with:
```swift
let items: [CalendarItem]
```

**Step 2: Update body**

Replace `events` with `items` and `event` with `item`:
```swift
var body: some View {
    if isLoading {
        HStack {
            Spacer()
            ProgressView()
                .scaleEffect(0.7)
            Spacer()
        }
        .frame(height: 60)
    } else if items.isEmpty {
        Text("当天无日程")
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
    } else {
        VStack(spacing: 6) {
            ForEach(items) { item in
                EventCardView(item: item)
            }
        }
    }
}
```

**Step 3: Verify build**

Run: `xcodebuild -scheme CalendarPro -configuration Debug build 2>&1 | grep -E "error:|warning:" | head -20`

**Step 4: Commit**

```bash
git add CalendarPro/Views/Popover/EventListView.swift
git commit -m "feat: update EventListView to use CalendarItem"
```

---

### Task 8: Update CalendarPopoverView

**Files:**
- Modify: `CalendarPro/Views/Popover/CalendarPopoverView.swift`

**Step 1: Change events to items**

Replace `let events: [EKEvent]` with:
```swift
let items: [CalendarItem]
```

**Step 2: Verify build**

Run: `xcodebuild -scheme CalendarPro -configuration Debug build 2>&1 | grep -E "error:|warning:" | head -20`

**Step 3: Commit**

```bash
git add CalendarPro/Views/Popover/CalendarPopoverView.swift
git commit -m "feat: update CalendarPopoverView to use CalendarItem"
```

---

### Task 9: Update RootPopoverView

**Files:**
- Modify: `CalendarPro/Views/RootPopoverView.swift`

**Step 1: Change events to items**

Replace `@State private var eventsForSelectedDate: [EKEvent] = []` with:
```swift
@State private var itemsForSelectedDate: [CalendarItem] = []
```

**Step 2: Update filterEventsByEnabledCalendars method**

Replace with:
```swift
private func filterItemsByEnabledCalendars(_ items: [CalendarItem]) -> [CalendarItem] {
    let enabledCalendarIDs = settingsStore.menuBarPreferences.enabledCalendarIDs
    let enabledReminderCalendarIDs = settingsStore.menuBarPreferences.enabledReminderCalendarIDs
    
    return items.filter { item in
        switch item {
        case .event(let event):
            return enabledCalendarIDs.isEmpty || enabledCalendarIDs.contains(event.calendar.calendarIdentifier)
        case .reminder(let reminder):
            return enabledReminderCalendarIDs.isEmpty || enabledReminderCalendarIDs.contains(reminder.calendar.calendarIdentifier)
        }
    }
}
```

**Step 3: Update loadEventsForSelectedDate**

Replace with:
```swift
private func loadItemsForSelectedDate() {
    guard settingsStore.menuBarPreferences.showEvents else {
        itemsForSelectedDate = []
        return
    }
    
    isLoadingEvents = true
    
    Task {
        let items = eventService.fetchCalendarItems(
            for: selectedDate,
            enabledCalendarIDs: settingsStore.menuBarPreferences.enabledCalendarIDs,
            enabledReminderCalendarIDs: settingsStore.menuBarPreferences.enabledReminderCalendarIDs,
            showReminders: settingsStore.menuBarPreferences.showReminders
        )
        
        await MainActor.run {
            itemsForSelectedDate = items
            isLoadingEvents = false
        }
    }
}
```

**Step 4: Update onChange handlers**

Find `.onChange(of: selectedDate)` and update to call `loadItemsForSelectedDate()` instead.

Find any `.onChange(of: settingsStore.menuBarPreferences.showEvents)` and add:
```swift
.onChange(of: settingsStore.menuBarPreferences.showReminders) { _, _ in
    loadItemsForSelectedDate()
}
.onChange(of: settingsStore.menuBarPreferences.enabledReminderCalendarIDs) { _, _ in
    loadItemsForSelectedDate()
}
```

**Step 5: Update EventListView call**

Replace `events: eventsForSelectedDate` with `items: itemsForSelectedDate`

**Step 6: Verify build**

Run: `xcodebuild -scheme CalendarPro -configuration Debug build 2>&1 | grep -E "error:|warning:" | head -20`

**Step 7: Commit**

```bash
git add CalendarPro/Views/RootPopoverView.swift
git commit -m "feat: integrate reminders display in RootPopoverView"
```

---

### Task 10: Initialize Reminders on App Launch

**Files:**
- Modify: `CalendarPro/App/StatusBarController.swift` or similar app initialization file

**Step 1: Add reminder initialization**

Find where `eventService.requestAccess()` is called and add reminder access request:
```swift
Task {
    await eventService.requestAccess()
    await eventService.requestReminderAccess()
}
```

**Step 2: Verify build**

Run: `xcodebuild -scheme CalendarPro -configuration Debug build 2>&1 | grep -E "error:|warning:" | head -20`

**Step 3: Commit**

```bash
git add .
git commit -m "feat: request reminders access on app launch"
```

---

### Task 11: Update Info.plist for Reminders Permission

**Files:**
- Modify: `CalendarPro/Info.plist` or project settings

**Step 1: Add reminders usage description**

Add `NSRemindersUsageDescription` key with value:
```
此应用需要访问提醒事项以显示您的待办事项
```

**Step 2: Verify build**

Run: `xcodebuild -scheme CalendarPro -configuration Debug build 2>&1 | grep -E "error:|warning:" | head -20`

**Step 3: Commit**

```bash
git add .
git commit -m "feat: add reminders permission description to Info.plist"
```

---

### Task 12: Final Build and Test

**Step 1: Full build**

Run: `xcodebuild -scheme CalendarPro -configuration Debug build`

**Step 2: Run tests**

Run: `xcodebuild test -scheme CalendarPro -destination 'platform=macOS'`

**Step 3: Manual testing checklist**

1. Launch app and verify both calendar and reminders permissions are requested
2. Check settings show reminders toggle and list selector
3. Create a reminder in Apple Reminders app with today's due date
4. Verify reminder appears in app's event list
5. Complete the reminder and verify strikethrough style
6. Test filtering by enabling/disabling specific reminder lists

**Step 4: Final commit if needed**

```bash
git add .
git commit -m "fix: any remaining issues from testing"
```