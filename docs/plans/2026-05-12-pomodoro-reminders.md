# Pomodoro Reminders Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add noticeable but configurable Pomodoro phase-end notifications and sounds.

**Architecture:** Persist reminder preferences inside `PomodoroPreferences`, add a protocol-backed reminder service, and trigger it from `PomodoroTimerController` only for natural phase completions. The settings view exposes separate notification and sound toggles plus permission status.

**Tech Stack:** Swift 6, SwiftUI, AppKit `NSSound`, UserNotifications `UNUserNotificationCenter`, XCTest.

---

### Task 1: Preferences

**Files:**
- Modify: `CalendarPro/Settings/MenuBarPreferences.swift`
- Modify: `CalendarPro/Settings/SettingsStore.swift`
- Test: `CalendarProTests/Settings/MenuBarPreferencesTests.swift`

Add `PomodoroReminderPreferences` with `notificationsEnabled` and `soundEnabled`, default both to true. Add it to `PomodoroPreferences`. Add setters in `SettingsStore`.

### Task 2: Reminder Service

**Files:**
- Create: `CalendarPro/Features/Pomodoro/PomodoroReminderService.swift`

Create a protocol for sending phase-end reminders and requesting notification permission. Production implementation should use `UNUserNotificationCenter` for notifications and `NSSound` for one-shot sound playback.

### Task 3: Timer Integration

**Files:**
- Modify: `CalendarPro/Features/Pomodoro/PomodoroTimerController.swift`
- Modify: `CalendarPro/App/StatusBarController.swift`
- Modify: `CalendarPro/App/AppDelegate.swift`
- Test: `CalendarProTests/Pomodoro/PomodoroTimerControllerTests.swift`

Inject the reminder service and a preferences provider into the timer. Trigger reminders after natural focus completion and natural break completion. Do not trigger reminders for skip or end.

### Task 4: Settings UI

**Files:**
- Modify: `CalendarPro/Views/Settings/PomodoroSettingsView.swift`
- Modify: `CalendarPro/Resources/Localizable.xcstrings`

Add a `Phase End Reminders` section with notification and sound toggles. Provide permission status text and a request-permission button when notifications are enabled.

### Task 5: Verify

Run focused tests:

```bash
xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/PomodoroTimerControllerTests -only-testing:CalendarProTests/MenuBarPreferencesTests
```

Run build:

```bash
xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'
```
