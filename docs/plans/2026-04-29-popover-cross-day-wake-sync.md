# Popover Cross-Day Wake Sync Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Ensure the calendar popover does not keep yesterday selected after the app wakes or is reopened across a day boundary.

**Architecture:** `TimeRefreshCoordinator` owns day-boundary detection and exposes a small revision counter. `CalendarPopoverViewModel` tracks whether the current selection is automatically following today, so cross-day refreshes can move old-today to new-today without overwriting user-selected historical dates. `PopoverController` and `RootPopoverView` both invoke the same view-model sync rule when showing or receiving a day-change signal.

**Tech Stack:** Swift 6, AppKit `NSPopover`, SwiftUI, Combine, XCTest

---

### Task 1: Add explicit day-change state

**Files:**
- Modify: `CalendarPro/Infrastructure/TimeRefreshCoordinator.swift`
- Test: `CalendarProTests/TimeRefreshCoordinatorTests.swift`

**Implementation:**
- Add `@Published private(set) var dayChangeRevision = 0`.
- Store `lastKnownStartOfDay` at initialization.
- In `refreshNow()`, compare `calendarProvider().startOfDay(for:)` with the last known day and increment `dayChangeRevision` when it changes.

**Tests:**
- Verify wake notifications still refresh `currentDate`.
- Verify wake across a day boundary increments `dayChangeRevision`.
- Verify same-day refresh does not increment `dayChangeRevision`.

### Task 2: Track auto-following today in the popover view model

**Files:**
- Modify: `CalendarPro/Views/Popover/CalendarPopoverViewModel.swift`
- Test: `CalendarProTests/Popover/CalendarPopoverViewModelTests.swift`

**Implementation:**
- Add an internal `followsCurrentDaySelection` flag.
- Extend `selectDate` with `followsCurrentDay: Bool = false`.
- Add `selectCurrentDate()`.
- Add `syncCurrentDaySelectionIfNeeded(calendar:)`.

**Rules:**
- Empty selection syncs to today.
- Auto-selected today moves to the new today after day change.
- User-selected historical or future dates remain unchanged.

### Task 3: Connect sync points

**Files:**
- Modify: `CalendarPro/App/PopoverController.swift`
- Modify: `CalendarPro/Views/RootPopoverView.swift`
- Test: `CalendarProTests/CalendarProTests.swift`

**Implementation:**
- Before showing the popover, call `timeRefreshCoordinator.refreshNow()`, `checkAndResetIfNeeded()`, then `syncCurrentDaySelectionIfNeeded(calendar:)`.
- In `RootPopoverView`, observe `timeRefreshCoordinator.dayChangeRevision` and sync selection, events, almanac, and weather.
- Mark automatic today selection from `refreshEventsForCurrentSelection(selectingTodayIfNeeded:)` and the reset-to-today action with `followsCurrentDay: true`.

**Tests:**
- Verify controller opening after a day change syncs an auto-following today selection.
- Keep the existing 30-second reopen behavior covered.

### Task 4: Verify

Run targeted tests:

```bash
xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/TimeRefreshCoordinatorTests -only-testing:CalendarProTests/CalendarPopoverViewModelTests -only-testing:CalendarProTests/PopoverControllerTests
```

Expected: all targeted tests pass.

Run the full suite:

```bash
xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'
```

Expected: no regressions outside the popover day-sync path.
