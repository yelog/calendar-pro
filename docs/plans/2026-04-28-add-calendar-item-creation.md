# Add Calendar Item Creation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add first-class creation of calendar events and reminders from the menu bar popover for the currently selected day.

**Architecture:** Extend the existing EventKit-backed `EventService` with small write models and save methods, then reuse the existing floating detail-panel infrastructure for a compact composer. The popover owns refresh/selection state; the composer only gathers input and returns a save request.

**Tech Stack:** Swift 6, SwiftUI, AppKit `NSPanel`, EventKit, XCTest, generated Xcode project.

---

## UI/UX Design

- Entry point: add a compact `plus` menu in the selected-date event header of `CalendarPopoverView`, next to the item count.
- Menu actions: `New Event` and `New Reminder`, shown only when that source type is enabled and has authorization; disabled states are handled by omitting unavailable actions.
- Composer: open a floating panel anchored like event/reminder details. The panel title changes by type and uses the selected date as the default.
- Event fields: title, calendar picker, all-day toggle, date, start time, end time, notes.
- Reminder fields: title, reminder-list picker, date, optional time toggle, time, notes.
- Save behavior: save to EventKit, close the composer, refresh the selected date list, and rely on the existing `EKEventStoreChanged` debounce as a secondary refresh path.
- Error behavior: keep the panel open and show a concise inline error if EventKit rejects the save or no writable source is available.

## Task 1: EventKit Write Models and Save Methods

**Files:**
- Modify: `CalendarPro/Features/Events/EventService.swift`
- Test: `CalendarProTests/Events/EventServiceTests.swift`

**Steps:**
1. Add `CalendarItemCreationKind`, `CalendarEventCreationRequest`, and `ReminderCreationRequest`.
2. Add helpers for writable event calendars and writable reminder lists.
3. Add `createEvent(_:)` and `createReminder(_:)` methods that save via `EKEventStore`.
4. Add unit tests for default request date/time calculation and writable source filtering where testable without system permissions.

## Task 2: Composer Panel

**Files:**
- Create: `CalendarPro/Views/Popover/CalendarItemComposerView.swift`
- Modify: `CalendarPro/App/EventDetailWindowController.swift`

**Steps:**
1. Build a compact SwiftUI form matching existing popover panel metrics.
2. Provide event/reminder-specific sections and validation.
3. Extend `EventDetailWindowPresenting` with a composer presentation method.
4. Reuse the existing `NSPanel` sizing/placement path.

## Task 3: Popover Entry and Refresh Wiring

**Files:**
- Modify: `CalendarPro/Views/Popover/CalendarPopoverView.swift`
- Modify: `CalendarPro/Views/RootPopoverView.swift`
- Modify: `CalendarPro/App/PopoverController.swift`
- Modify: `CalendarPro/App/AppDelegate.swift`

**Steps:**
1. Add `onCreateItem` callback through the popover view tree.
2. Add plus menu in the selected date event section.
3. In root view, present composer for the selected date and refresh after successful save.
4. Close conflicting floating panels before opening the composer.

## Task 4: Localization and Project Regeneration

**Files:**
- Modify: `CalendarPro/Resources/Localizable.xcstrings`
- Modify: `CalendarPro.xcodeproj/project.pbxproj`

**Steps:**
1. Add localized strings for composer labels, actions, validation, and errors.
2. Run `ruby tools/generate_xcodeproj.rb` after adding the new Swift file.

## Task 5: Verification

**Commands:**
- `xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'`
- Targeted tests if the build succeeds.

**Manual Checks:**
- Open popover, select a date, create an event, confirm it appears in the timeline.
- Create an all-day event and confirm it appears under all-day items.
- Create a reminder with and without due time, confirm timeline/no-time placement.
- Confirm disabled/unauthorized sources do not crash the composer.
