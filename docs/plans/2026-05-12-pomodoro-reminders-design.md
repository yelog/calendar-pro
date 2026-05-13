# Pomodoro Reminders Design

## Problem
The current Pomodoro timer silently advances when a focus or break phase ends. That keeps CalendarPro calm, but users can miss the transition when they are not watching the menu bar or popover. A missed transition weakens the core Pomodoro loop: stop focusing, rest, and return deliberately.

## Goals
- Make phase endings noticeable even when the popover is closed.
- Preserve CalendarPro's lightweight menu bar character.
- Avoid forced interruptions such as auto-opening windows or repeated alarms.
- Let users turn notification and sound reminders off independently.
- Keep manual skip/end actions quiet; only natural completions should alert.

## Recommended Behavior
Pomodoro remains disabled by default. When the user enables it, phase-end reminders are enabled by default:

- System notification: enabled.
- Sound: enabled.
- Reminder scope: both focus completion and break completion.
- No automatic popover opening.
- No repeating alarm.

Focus completion sends a notification that tells the user to rest. Long-break notifications mention the longer rest. Break completion sends a notification that invites the user back to focus. Both events play one short, gentle system sound when sound reminders are enabled.

If notification permission is denied or not available, the timer still plays the sound when enabled. The settings UI should show the notification permission state and provide a way to request permission.

## Architecture
Add reminder preferences to `PomodoroPreferences` so they persist with the existing Pomodoro settings. Add a small `PomodoroReminderService` that owns notification authorization, notification delivery, and sound playback. Inject the service into `PomodoroTimerController`; the controller triggers it only on natural phase transitions.

The service should be protocol-backed for tests. Production uses `UNUserNotificationCenter` and `NSSound`. Tests use a spy to assert reminder events without requiring macOS notification authorization.

## Testing
- Defaults keep Pomodoro disabled but enable notification and sound reminder preferences.
- SettingsStore persists notification and sound preferences.
- Natural focus completion triggers a focus-completed reminder.
- Natural break completion triggers a break-completed reminder.
- Manual skip does not trigger a reminder.
- Manual end does not trigger a reminder.
