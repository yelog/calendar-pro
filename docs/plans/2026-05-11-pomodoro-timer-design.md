# Pomodoro Timer Design

## Context

CalendarPro is a macOS menu bar calendar. Its primary workflow is opening a compact popover from a single menu bar item to check dates, events, reminders, almanac, and weather. The pomodoro timer should improve focus behavior without replacing the calendar as the main product surface.

The current architecture has a long-lived `StatusBarController`, a `PopoverController` that hosts `RootPopoverView`, and `CalendarPopoverView` as the compact SwiftUI surface. Menu bar text is rendered through `MenuBarViewModel`, `ClockRenderService`, and `MenuBarTextImageRenderer`.

## Goals

- Add a scientifically familiar classic pomodoro loop: 25 minutes focus, 5 minutes short break, and 15 minutes long break after every 4 completed focus sessions.
- Keep the feature visually integrated with the existing calendar popover.
- Keep the native calendar workflow dominant and uninterrupted.
- Make active focus state visible from the menu bar without adding a second status item.
- Avoid notification permission requests in the first version.

## Non-Goals

- No custom duration settings in the first version.
- No system notifications, sounds, or alert windows.
- No task list, analytics, streaks, or productivity scoring.
- No persistence of an active timer across app relaunch in the first version.

## Recommended Approach

Use a lightweight pomodoro card inside the existing calendar popover and append compact countdown text to the current menu bar text while a session is active.

This approach keeps the feature discoverable and useful without creating a separate app mode. It avoids a second menu bar icon and avoids turning the popover header into a timer-first surface.

Rejected alternatives:

- A footer-only button keeps the calendar layout nearly unchanged but hides the feature too deeply.
- A large hero timer has stronger visual impact but competes with the calendar and event list.
- A second menu bar item improves visibility but consumes more menu bar space and weakens the single-entry product model.

## UX Design

The pomodoro card appears between the calendar grid/info strips area and the events section. It should be compact enough to preserve the calendar-first layout.

Default state:

- Title: `Pomodoro`
- Supporting copy: `25 min focus · 5 min break`
- Primary action: `Start Focus`

Focus state:

- Title: `Focusing`
- Large countdown, for example `18:42`
- Metadata: `Round 2 of 4 · Short break next`
- Actions: `Pause`, `Skip`, `End`

Paused state:

- Title: `Paused`
- Countdown remains visible.
- Actions: `Resume`, `End`

Break state:

- Title: `Short Break` or `Long Break`
- Countdown remains visible.
- Metadata: `Focus starts next`
- Actions: `Skip`, `End`

Visual style:

- Use a low-saturation tomato or amber accent for focus.
- Use green or teal accent for breaks.
- Use existing `PopoverSurfaceMetrics` floating panel colors and border treatment.
- Use rounded system typography consistent with the existing month header and event count text.
- Prefer a small progress bar or ring. A progress bar is simpler and less visually dominant.

Menu bar behavior:

- When idle, menu bar text remains unchanged.
- During focus, append compact countdown text, for example `🍅18:42`.
- During break, append compact break text, for example `休04:31` in Chinese or `Br 04:31` in English.
- The tooltip should include the current phase and remaining time.

Stage transition behavior:

- Stage changes are silent.
- At the end of focus, automatically enter short break unless the completed focus is the fourth round, in which case enter long break.
- At the end of a break, automatically enter the next focus round.
- Closing the popover does not stop the timer.
- Quitting/relaunching resets the timer to idle in the first version.

## Architecture

Add a long-lived pomodoro state object owned by `StatusBarController`, similar to the existing time refresh coordinator lifetime.

Proposed production types:

- `PomodoroTimerState`: value type describing phase, remaining seconds, total seconds, completed focus count, and whether the timer is paused.
- `PomodoroTimerController`: `ObservableObject` and `@MainActor` owner of timer transitions and commands.
- `PomodoroStripView`: compact SwiftUI card rendered inside `CalendarPopoverView`.
- `PomodoroMenuBarFormatter`: helper for compact menu bar suffix and tooltip text.

Data flow:

- `StatusBarController` creates one `PomodoroTimerController`.
- `PopoverController` receives the controller and passes it into `RootPopoverView`.
- `RootPopoverView` passes state and actions to `CalendarPopoverView`.
- `CalendarPopoverView` renders `PomodoroStripView` in the calendar mode.
- `StatusBarController` observes pomodoro state and combines it with the existing menu bar display text before rendering the status item image.

The timer should use wall-clock dates rather than decrement-only counters. Store a stage `endDate` and calculate remaining time from `Date()` on refresh. This prevents drift during sleep or main-thread delays.

## Settings

The pomodoro card can be controlled by a settings checkbox. The final default is disabled so CalendarPro remains calendar-first until the user explicitly opts in:

- `Show Pomodoro Timer`

No duration customization should be added in this version.

## Localization

Add Simplified Chinese and English strings for card labels, phase names, action labels, metadata, and menu bar suffixes.

Chinese copy should be concise and calm, for example:

- `番茄时钟`
- `开始专注`
- `专注中`
- `短休息`
- `长休息`
- `第 %d / 4 轮`

## Testing

Unit tests should cover:

- Initial idle state.
- Starting focus creates a 25-minute focus session.
- Completing focus 1 to 3 enters a 5-minute short break.
- Completing focus 4 enters a 15-minute long break and resets the round cycle.
- Pause/resume preserves remaining time.
- Skip advances to the correct next stage.
- End resets to idle.
- Menu bar formatter returns no suffix when idle and compact suffixes while active.

Manual verification should cover:

- Popover open/close while timer runs.
- Deep and light appearance.
- Calendar events still fit and scroll normally.
- Menu bar width remains acceptable with the suffix.
