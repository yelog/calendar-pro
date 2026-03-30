# Reminders Integration Design

## Overview
Add support for displaying reminders (提醒事项) alongside calendar events, matching Apple Calendar's behavior.

## Requirements

1. **Display**: Show reminders mixed with events in a single list, sorted by time
2. **Toggle**: Separate switch to enable/disable reminders display
3. **Completed items**: Show completed reminders with strikethrough and gray style
4. **List selection**: Allow selecting specific reminder lists (like calendar selection)

## Architecture

### 1. Data Layer

**CalendarItem enum** - Unified type for events and reminders:
```swift
enum CalendarItem: Identifiable {
    case event(EKEvent)
    case reminder(EKReminder)
    
    var id: String { ... }
    var title: String { ... }
    var startDate: Date { ... }  // reminder uses dueDate
    var isCompleted: Bool { ... }
    var color: NSColor { ... }
}
```

**EventService changes:**
- Add `remindersAuthorized: Bool` property
- Add `reminderCalendars: [EKCalendar]` property
- Modify `requestAccess()` to request both event and reminder permissions
- Add `fetchReminders(for:) -> [EKReminder]` method
- Add `fetchCalendarItems(for:) -> [CalendarItem]` method (merges events + reminders)

### 2. Settings Layer

**MenuBarPreferences changes:**
```swift
var showReminders: Bool
var enabledReminderCalendarIDs: [String]
```

**SettingsStore changes:**
- Add `setShowReminders(_:)` method
- Add `setReminderCalendarEnabled(_:calendarID:)` method

### 3. UI Layer

**EventsSettingsView changes:**
- Add "显示提醒事项" toggle
- Add reminder lists selector (similar to calendar selector)
- Request reminder permission when toggle enabled

**EventListView changes:**
- Accept `[CalendarItem]` instead of `[EKEvent]`

**EventCardView changes:**
- Accept `CalendarItem` instead of `EKEvent`
- Show strikethrough + gray text for completed reminders
- Show "已完成" badge or icon for completed reminders

## Data Flow

```
EventService
    ├── fetchEvents(for: date) -> [EKEvent]
    ├── fetchReminders(for: date) -> [EKReminder]
    └── fetchCalendarItems(for: date) -> [CalendarItem]
            └── merges and sorts by time

SettingsStore
    ├── showReminders: Bool
    ├── enabledReminderCalendarIDs: [String]
    └── filters calendars before fetch

EventListView
    └── displays [CalendarItem] sorted by time
```

## Error Handling

- If reminder permission denied: show warning in settings, continue with events only
- If no reminder lists available: show "暂无可用提醒事项列表"
- If reminder has no due date: sort to end of list

## Testing

- Unit tests for `CalendarItem` sorting logic
- Unit tests for merging events and reminders
- Test permission flow for both event and reminder access