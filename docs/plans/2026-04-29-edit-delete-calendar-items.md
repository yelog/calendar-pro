# Calendar Item Edit And Delete Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add editing and deletion for calendar events and reminders from the existing detail windows.

**Architecture:** Reuse `CalendarItemComposerView` for both creation and editing by introducing a composer mode and initial values. Keep EventKit mutations inside `EventService`, and let `RootPopoverView` own refresh/selection cleanup after save or delete.

**Tech Stack:** Swift 6, SwiftUI, AppKit `NSPanel`, EventKit, XCTest.

---

### Task 1: EventKit Mutation API

**Files:**
- Modify: `CalendarPro/Features/Events/EventService.swift`
- Test: `CalendarProTests/Events/EventServiceTests.swift`

**Steps:**
1. Add update request builders from existing `EKEvent` and `EKReminder`.
2. Add `updateEvent(_:with:)`, `updateReminder(_:with:)`, `deleteEvent(_:)`, and `deleteReminder(_:)`.
3. Keep calendar validation consistent with existing create behavior.
4. Add tests for default edit requests preserving existing title, calendar, date/time, all-day, due time, and notes.

### Task 2: Reusable Composer Modes

**Files:**
- Modify: `CalendarPro/Views/Popover/CalendarItemComposerView.swift`
- Modify: `CalendarPro/App/EventDetailWindowController.swift`

**Steps:**
1. Introduce `CalendarItemComposerMode` with `.create` and `.edit`.
2. Initialize form state from mode-specific event/reminder requests.
3. Hide item type switching while editing.
4. Change header and save button copy for edit mode.
5. Add controller method `showEditor(...)` that uses the same key-window behavior as composer.

### Task 3: Detail Window Actions

**Files:**
- Modify: `CalendarPro/Views/Popover/EventDetailWindowView.swift`
- Modify: `CalendarPro/Views/Popover/ReminderDetailWindowView.swift`
- Modify: `CalendarPro/App/EventDetailWindowController.swift`

**Steps:**
1. Add Edit and Delete actions to both detail footers.
2. Use compact icon+text buttons: edit, delete, open in Calendar/Reminders.
3. Confirm destructive deletion with `confirmationDialog`.
4. Disable edit/delete for read-only calendars.

### Task 4: Root Wiring

**Files:**
- Modify: `CalendarPro/Views/RootPopoverView.swift`
- Modify: `CalendarPro/App/PopoverController.swift`
- Modify: `CalendarPro/App/AppDelegate.swift`
- Test: `CalendarProTests/CalendarProTests.swift`

**Steps:**
1. Extend detail presentation callbacks to include edit and delete closures.
2. Edit opens the reusable editor with writable calendars/lists.
3. Delete removes the item, refreshes selected date items, clears selection, and closes the detail window.
4. Update popover behavior tests for editor panels using the existing transient suspension pattern.

### Task 5: Verification

**Commands:**
- `xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'`
- `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -derivedDataPath /tmp/CalendarProDerivedData-edit-delete -only-testing:CalendarProTests/EventServiceTests -only-testing:CalendarProTests/PopoverControllerTests`

**Manual checks:**
- Open an event detail, edit title/time/notes, save, and verify the list refreshes.
- Open a reminder detail, edit title/due time/notes/list, save, and verify the list refreshes.
- Delete an event/reminder and verify the detail panel closes and the item disappears.
