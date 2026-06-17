# Pomodoro Menu Bar Settings Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Move Pomodoro menu bar presentation settings into `Settings > Menu Bar > Display Items` while keeping Pomodoro behavior settings in the Pomodoro page.

**Architecture:** Keep the existing `PomodoroPreferences` persistence and `StatusBarController` suffix rendering. Add a dedicated Pomodoro row to `MenuBarSettingsView` that controls `isEnabled` and `menuBarStyle`, and remove the duplicate menu bar style section from `PomodoroSettingsView`.

**Tech Stack:** Swift 6, SwiftUI, Combine, XCTest, macOS menu bar rendering.

---

### Task 1: Move Pomodoro Presentation Controls

**Files:**
- Modify: `CalendarPro/Views/Settings/MenuBarSettingsView.swift`
- Modify: `CalendarPro/Views/Settings/PomodoroSettingsView.swift`

**Steps:**
1. Add a Pomodoro row at the end of `MenuBarSettingsView` display items.
2. Bind the Pomodoro checkbox to `SettingsStore.setPomodoroEnabled(_:)`.
3. Bind the style picker to `SettingsStore.setPomodoroMenuBarStyle(_:)`.
4. Disable the style picker when Pomodoro is disabled.
5. Show a short hint that Pomodoro appears in the menu bar only while running.
6. Remove the old `Menu Bar Style` section and unused helpers from `PomodoroSettingsView`.

### Task 2: Keep Persistence And Rendering Unchanged

**Files:**
- Review: `CalendarPro/Settings/MenuBarPreferences.swift`
- Review: `CalendarPro/App/StatusBarController.swift`
- Review: `CalendarPro/Features/Pomodoro/PomodoroMenuBarFormatter.swift`

**Steps:**
1. Do not move `PomodoroPreferences.menuBarStyle` into `MenuBarPreferences`.
2. Do not add `DisplayTokenKind.pomodoro` in this iteration.
3. Keep menu bar suffix rendering in `StatusBarController.displayText`.

### Task 3: Update Localization And Tests

**Files:**
- Modify: `CalendarPro/Resources/Localizable.xcstrings`
- Modify: `CalendarProTests/Settings/MenuBarPreferencesTests.swift`

**Steps:**
1. Add a localized hint for the new Pomodoro row if no existing text fits.
2. Strengthen the Pomodoro preferences persistence test by setting enabled to true and style to pie before reload.
3. Keep existing formatter tests unchanged.

### Task 4: Verify

**Commands:**
- `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/MenuBarPreferencesTests -only-testing:CalendarProTests/PomodoroMenuBarFormatterTests`
- `xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'`

**Expected:**
- Targeted tests and build succeed.
