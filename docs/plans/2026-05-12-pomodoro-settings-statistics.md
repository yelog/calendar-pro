# Pomodoro Settings and Statistics Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a Pomodoro settings tab with enable switch, menu bar style selection, and local aggregate focus statistics.

**Architecture:** Store user-facing pomodoro preferences in `SettingsStore`, keep local daily aggregate statistics in a new `PomodoroStatsStore`, and inject both into the existing status bar, popover, and settings window flow. Extend the existing formatter and timer controller rather than adding a second menu bar item or new app mode.

**Tech Stack:** Swift 6, SwiftUI, AppKit `NSStatusItem`, Combine, UserDefaults JSON persistence, XCTest.

---

## Task 1: Pomodoro Preferences

**Files:**
- Modify: `CalendarPro/Settings/MenuBarPreferences.swift`
- Modify: `CalendarPro/Settings/SettingsStore.swift`
- Test: `CalendarProTests/Settings/MenuBarPreferencesTests.swift`

**Step 1: Add tests**

Add tests for default preferences and decode fallback:

- `PomodoroPreferences.default.isEnabled == false`
- `PomodoroPreferences.default.menuBarStyle == .countdown`
- `SettingsStore` loads default pomodoro preferences when no stored data exists.

**Step 2: Implement preferences**

Add:

- `enum PomodoroMenuBarStyle: String, Codable, CaseIterable, Identifiable`
- `struct PomodoroPreferences: Codable, Equatable`

Add `@Published var pomodoroPreferences` to `SettingsStore`, a separate `pomodoroPreferencesKey`, and setters:

- `setPomodoroEnabled(_:)`
- `setPomodoroMenuBarStyle(_:)`

**Step 3: Run tests**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/MenuBarPreferencesTests`

Expected: PASS.

## Task 2: Pomodoro Stats Store

**Files:**
- Create: `CalendarPro/Features/Pomodoro/PomodoroStatsStore.swift`
- Test: `CalendarProTests/Pomodoro/PomodoroStatsStoreTests.swift`

**Step 1: Add tests**

Cover:

- Records focus start.
- Records natural focus completion and adds 25 minutes.
- Records skipped focus.
- Records interrupted focus.
- Prunes data older than 180 days.
- 7-day summary returns zero-value days for missing records.
- 30-day summary returns total minutes, average per day, and best day.

**Step 2: Implement stats store**

Create:

- `PomodoroDailyStats`
- `PomodoroStatsSummary`
- `PomodoroStatsStore: ObservableObject`

Use `UserDefaults` JSON persistence and calendar-based `yyyy-MM-dd` day keys.

**Step 3: Run tests**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/PomodoroStatsStoreTests`

Expected: PASS.

## Task 3: Timer Statistics Events

**Files:**
- Modify: `CalendarPro/Features/Pomodoro/PomodoroTimerController.swift`
- Modify: `CalendarProTests/Pomodoro/PomodoroTimerControllerTests.swift`

**Step 1: Add tests**

Add tests that inject a `PomodoroStatsStore` and verify:

- `startFocus()` records started.
- Natural completion records completed.
- `skip()` during focus records skipped.
- `end()` during focus records interrupted.
- `skip()` and `end()` during break do not increment negative focus counters.

**Step 2: Implement stats hooks**

Add optional `statsStore` dependency to `PomodoroTimerController`.

Differentiate natural completion from manual skip by passing a transition reason to `advanceFromCurrentPhase`.

**Step 3: Run tests**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/PomodoroTimerControllerTests -only-testing:CalendarProTests/PomodoroStatsStoreTests`

Expected: PASS.

## Task 4: Menu Bar Styles

**Files:**
- Modify: `CalendarPro/Features/Pomodoro/PomodoroMenuBarFormatter.swift`
- Modify: `CalendarPro/App/StatusBarController.swift`
- Modify: `CalendarProTests/Pomodoro/PomodoroMenuBarFormatterTests.swift`

**Step 1: Add tests**

Cover formatter output for:

- Countdown focus and break.
- Progress focus and break.
- Pie focus and break.
- Disabled preferences returning nil.

**Step 2: Implement formatter styles**

Change `suffix` to accept `PomodoroPreferences`.

Implement examples:

- Countdown: `🍅18:42`
- Progress: `🍅▰▰▱▱ 18m`
- Pie: `◔ 18m`

**Step 3: Integrate status bar**

In `StatusBarController`, observe `settingsStore.$pomodoroPreferences` in the menu bar rendering pipeline.

End active timer when disabled.

**Step 4: Run tests**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/PomodoroMenuBarFormatterTests`

Expected: PASS.

## Task 5: Popover Enable Switch Integration

**Files:**
- Modify: `CalendarPro/Views/RootPopoverView.swift`
- Modify: `CalendarPro/Views/Popover/CalendarPopoverView.swift`

**Step 1: Hide card when disabled**

Pass `pomodoroPreferences` into `CalendarPopoverView`.

Render `PomodoroStripView` only when enabled.

**Step 2: Build**

Run: `xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'`

Expected: PASS.

## Task 6: Settings UI

**Files:**
- Modify: `CalendarPro/Views/Settings/SettingsRootView.swift`
- Create: `CalendarPro/Views/Settings/PomodoroSettingsView.swift`
- Modify: `CalendarPro/App/AppDelegate.swift`
- Modify: `CalendarPro/App/StatusBarController.swift`

**Step 1: Add sidebar tab**

Add `.pomodoro` to `SettingsSidebarItem` with icon `timer`.

**Step 2: Inject stats store into settings**

Create one `PomodoroStatsStore` in `AppDelegate` and pass it to both `StatusBarController` and `SettingsRootView`.

Update UI-test window path similarly.

**Step 3: Create PomodoroSettingsView**

Sections:

- Feature toggle.
- Menu bar style segmented picker with preview.
- Today cards.
- 7-day bar chart.
- 30-day summary.
- Completion quality.
- Legend.

Draw charts with SwiftUI rectangles and simple labels.

**Step 4: Build**

Run: `xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'`

Expected: PASS.

## Task 7: Localization and Project Regeneration

**Files:**
- Modify: `CalendarPro/Resources/Localizable.xcstrings`
- Modify: `CalendarPro.xcodeproj/project.pbxproj`

**Step 1: Add strings**

Add English and Simplified Chinese strings for all new labels and descriptions.

**Step 2: Regenerate project**

Run: `ruby tools/generate_xcodeproj.rb`

Expected: new files included.

## Task 8: Final Verification

**Step 1: Run focused tests**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/PomodoroTimerControllerTests -only-testing:CalendarProTests/PomodoroMenuBarFormatterTests -only-testing:CalendarProTests/PomodoroStatsStoreTests -only-testing:CalendarProTests/MenuBarPreferencesTests`

Expected: PASS.

**Step 2: Run build**

Run: `xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'`

Expected: PASS.

**Step 3: Manual verification**

Verify settings tab, toggle behavior, style previews, menu bar suffix changes, chart readability, and stats updates.
