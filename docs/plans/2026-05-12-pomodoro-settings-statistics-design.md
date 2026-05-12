# Pomodoro Settings and Statistics Design

## Context

CalendarPro now includes a lightweight classic pomodoro timer in the calendar popover and menu bar. The next step is to make the feature configurable and useful over time without turning the app into a productivity tracker.

The settings window already uses a left sidebar with independent detail pages. Persistent app preferences currently live in `SettingsStore` and `MenuBarPreferences`, while the pomodoro timer state is owned by `StatusBarController` and passed into the popover.

## Goals

- Add an independent Pomodoro settings tab.
- Allow users to enable or disable the pomodoro feature.
- Offer menu bar display styles: countdown, progress bar, and pie indicator.
- Persist local aggregate pomodoro statistics across app restarts.
- Present statistics that help users self-regulate: today, 7-day rhythm, 30-day trend, and completion quality.
- Avoid storing task names, app activity, calendar event content, or exact focus timestamps.

## Non-Goals

- No custom pomodoro durations in this version.
- No cloud sync.
- No notification settings.
- No gamified badges, leaderboards, streak pressure, or detailed activity tracking.
- No per-task or per-project reporting.

## UX Design

Add a new sidebar item:

- Title: `Pomodoro`
- Icon: `timer`
- Sidebar description: `Focus rhythm and statistics`
- Detail description: `Tune focus visibility and review local focus trends.`

The page has three sections.

### 1. Feature

The first section contains the master toggle:

- `Enable Pomodoro Timer`
- Description: `Show the pomodoro card in the calendar panel and menu bar while active.`

When disabled:

- The popover pomodoro card is hidden.
- The menu bar pomodoro suffix is hidden.
- Any active timer is ended.
- Existing statistics are preserved.

### 2. Menu Bar Style

Use a segmented picker with three options:

- `Countdown`: most precise and the default. Example: `🍅18:42`.
- `Progress`: compact progress plus rounded minutes. Example: `🍅▰▰▱▱ 18m`.
- `Pie`: most visually quiet. Example: `◔ 18m`.

Show a preview row under the picker. The preview should use the same formatting code as the real menu bar suffix.

### 3. Statistics

Statistics should feel calm and explanatory. The page should avoid competitive language.

Cards:

- `Today`: completed pomodoros and focus minutes.
- `7-Day Rhythm`: compact bar chart of completed pomodoros per day.
- `30-Day Trend`: total focus minutes, daily average, and best day.
- `Completion Quality`: completion rate and interruption rate.

Legend:

- Tomato/red: completed focus sessions.
- Green/teal: break phase.
- Gray: no record.
- Light red: skipped or interrupted focus sessions.

## Data Model

Add `PomodoroPreferences`:

- `isEnabled: Bool = false`
- `menuBarStyle: PomodoroMenuBarStyle = .countdown`

Add `PomodoroDailyStats`:

- `dayKey: String`
- `focusStartedCount: Int`
- `focusCompletedCount: Int`
- `focusSkippedCount: Int`
- `focusInterruptedCount: Int`
- `completedFocusMinutes: Int`

Add `PomodoroStatsStore`:

- Persist `[PomodoroDailyStats]` to `UserDefaults` as JSON.
- Keep only the most recent 180 days.
- Provide recent day arrays and summaries for 7-day and 30-day views.

Counting rules:

- Starting a focus phase records `focusStartedCount += 1`.
- Natural focus completion records `focusCompletedCount += 1` and `completedFocusMinutes += 25`.
- Skipping a focus phase records `focusSkippedCount += 1` and does not count as completion.
- Ending during a focus phase records `focusInterruptedCount += 1` and does not count as completion.
- Skipping or ending during a break does not count as a negative focus event.

## Architecture

- `SettingsStore` owns `pomodoroPreferences` and persists them separately from `MenuBarPreferences`.
- `StatusBarController` owns `PomodoroStatsStore` and injects it into `PomodoroTimerController`.
- `StatusBarController` observes `SettingsStore.$pomodoroPreferences` and hides/ends the timer when disabled.
- `PomodoroMenuBarFormatter` formats all three menu bar styles.
- `RootPopoverView` receives `pomodoroPreferences` and only shows `PomodoroStripView` when enabled.
- `SettingsRootView` adds `.pomodoro` and renders `PomodoroSettingsView` with `SettingsStore` and `PomodoroStatsStore`.

The settings view should use native SwiftUI controls and the current settings visual language. Charts should be drawn with simple SwiftUI rectangles instead of adding a charting dependency.

## Testing

Unit tests should cover:

- `PomodoroPreferences` defaults and decode fallback.
- `PomodoroMenuBarFormatter` output for countdown, progress, and pie styles.
- `PomodoroStatsStore` records started, completed, skipped, and interrupted focus sessions.
- Statistics pruning keeps only recent 180 days.
- 7-day and 30-day summaries include zero-record days.
- `PomodoroTimerController` records natural completion, skip, and interruption correctly.

Manual verification should cover:

- Settings sidebar shows the new Pomodoro tab.
- Toggle hides and shows popover card and menu bar suffix.
- Style picker changes menu bar suffix while a session is active.
- Statistics update after a completed, skipped, and interrupted focus.
- Dark and light mode readability.
