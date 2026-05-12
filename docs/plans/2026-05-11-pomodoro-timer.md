# Pomodoro Timer Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a classic pomodoro timer to the existing menu bar calendar without disrupting the calendar-first popover workflow.

**Architecture:** Add a long-lived `PomodoroTimerController` owned by `StatusBarController`, render a compact `PomodoroStripView` inside the existing calendar popover, and append a compact countdown suffix to the existing menu bar text while active. Use wall-clock `Date` calculations to avoid timer drift.

**Tech Stack:** Swift 6, SwiftUI, AppKit `NSStatusItem`, Combine, XCTest, existing CalendarPro localization helpers.

---

## Task 1: Core Pomodoro State Machine

**Files:**
- Create: `CalendarPro/Features/Pomodoro/PomodoroTimerController.swift`
- Test: `CalendarProTests/Pomodoro/PomodoroTimerControllerTests.swift`

**Step 1: Write failing tests**

Create tests for:

- Initial state is idle.
- `startFocus()` creates a 25-minute focus session.
- Completing focus rounds 1 to 3 enters a 5-minute short break.
- Completing the fourth focus enters a 15-minute long break.
- Completing a break starts the next focus.
- `pause()` and `resume()` preserve remaining seconds.
- `skip()` advances to the correct next stage.
- `end()` resets to idle.

Use an injected `now` closure backed by a mutable `Date`.

**Step 2: Run tests to verify failure**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/PomodoroTimerControllerTests`

Expected: FAIL because the type does not exist.

**Step 3: Implement minimal state machine**

Create `PomodoroTimerController` as `@MainActor final class PomodoroTimerController: ObservableObject`.

Include:

- `enum Phase { case idle, focus, shortBreak, longBreak }`
- `struct State: Equatable` with `phase`, `remainingSeconds`, `totalSeconds`, `completedFocusCount`, `isPaused`, and computed `progress`.
- Constants: `focusDuration = 25 * 60`, `shortBreakDuration = 5 * 60`, `longBreakDuration = 15 * 60`, `focusesBeforeLongBreak = 4`.
- Commands: `startFocus()`, `pause()`, `resume()`, `skip()`, `end()`, `refresh()`.
- Internal end date and paused remaining seconds.

Use `Timer.publish(every: 1, on: .main, in: .common).autoconnect()` or a Foundation `Timer` to call `refresh()` while active. Tests can call `refresh()` manually.

**Step 4: Run tests to verify pass**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/PomodoroTimerControllerTests`

Expected: PASS.

**Step 5: Regenerate project if needed**

Run: `ruby tools/generate_xcodeproj.rb`

Expected: project includes the new source and test files.

Do not commit unless the user explicitly requests it.

## Task 2: Menu Bar Formatting

**Files:**
- Create or extend: `CalendarPro/Features/Pomodoro/PomodoroMenuBarFormatter.swift`
- Modify: `CalendarPro/App/StatusBarController.swift`
- Test: `CalendarProTests/Pomodoro/PomodoroMenuBarFormatterTests.swift`

**Step 1: Write failing formatter tests**

Cover:

- Idle returns no suffix.
- Focus state returns a compact tomato countdown suffix.
- Break state returns a compact localized break countdown suffix.
- Tooltip includes phase and remaining time.

**Step 2: Run tests to verify failure**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/PomodoroMenuBarFormatterTests`

Expected: FAIL because formatter does not exist.

**Step 3: Implement formatter**

Add pure formatting helpers:

- `suffix(for state: PomodoroTimerController.State) -> String?`
- `tooltip(for state: PomodoroTimerController.State) -> String?`
- `timeText(seconds:) -> String`

Keep output short: focus `🍅18:42`; break Chinese `休04:31`, English `Br 04:31`.

**Step 4: Integrate status bar rendering**

In `StatusBarController`:

- Add a stored `PomodoroTimerController`.
- Pass it into `PopoverController`.
- Observe `pomodoroTimer.$state` together with existing menu bar publishers.
- Append formatter suffix to the existing display text before rendering.
- Append formatter tooltip to the existing tooltip when active.

**Step 5: Run tests**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/PomodoroMenuBarFormatterTests`

Expected: PASS.

## Task 3: Popover Integration

**Files:**
- Modify: `CalendarPro/App/PopoverController.swift`
- Modify: `CalendarPro/Views/RootPopoverView.swift`
- Modify: `CalendarPro/Views/Popover/CalendarPopoverView.swift`
- Create: `CalendarPro/Views/Popover/PomodoroStripView.swift`

**Step 1: Add controller plumbing**

Modify `PopoverController` to accept and store `PomodoroTimerController`.

Pass the controller to `RootPopoverView`.

Modify `RootPopoverView` to observe the controller and pass state plus command closures to `CalendarPopoverView`.

**Step 2: Add CalendarPopoverView API**

Add parameters:

- `pomodoroState: PomodoroTimerController.State`
- `onStartPomodoroFocus: () -> Void`
- `onPausePomodoro: () -> Void`
- `onResumePomodoro: () -> Void`
- `onSkipPomodoro: () -> Void`
- `onEndPomodoro: () -> Void`

Render `PomodoroStripView` between `infoStripsSection` and `eventsSection`.

**Step 3: Implement PomodoroStripView**

Use existing visual language:

- `RoundedRectangle(cornerRadius: PopoverSurfaceMetrics.cornerRadius, style: .continuous)`.
- `PopoverSurfaceMetrics.floatingPanelBaseFill` and border color.
- Focus accent: tomato/amber.
- Break accent: teal/green.
- Compact progress bar.
- Plain or bordered small action buttons consistent with existing SwiftUI controls.

**Step 4: Build**

Run: `xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'`

Expected: PASS.

## Task 4: Localization

**Files:**
- Modify: `CalendarPro/Resources/zh-Hans.lproj/Localizable.strings`
- Modify: `CalendarPro/Resources/en.lproj/Localizable.strings`

**Step 1: Locate existing localization files**

Use `glob` for `CalendarPro/Resources/**/*.strings` if paths differ.

**Step 2: Add strings**

Add keys for:

- `Pomodoro`
- `Start Focus`
- `Focusing`
- `Paused`
- `Short Break`
- `Long Break`
- `Pause`
- `Resume`
- `Skip`
- `End`
- `25 min focus · 5 min break`
- `Round %d of 4`
- `Short break next`
- `Long break next`
- `Focus starts next`

**Step 3: Build**

Run: `xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'`

Expected: PASS.

## Task 5: Final Verification

**Files:**
- Potentially modified: `CalendarPro.xcodeproj/project.pbxproj`

**Step 1: Regenerate project**

Run: `ruby tools/generate_xcodeproj.rb`

Expected: New files are included in the Xcode project.

**Step 2: Run focused tests**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/PomodoroTimerControllerTests -only-testing:CalendarProTests/PomodoroMenuBarFormatterTests`

Expected: PASS.

**Step 3: Run full build**

Run: `xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'`

Expected: PASS.

**Step 4: Manual verification checklist**

Verify:

- Idle popover shows the pomodoro card without crowding the month grid.
- Start focus updates card and menu bar suffix.
- Pause/resume works.
- Skip focus enters break.
- Skip break enters focus.
- End returns to idle and removes menu bar suffix.
- Closing and reopening the popover keeps active timer state.
- Calendar event list remains usable.
