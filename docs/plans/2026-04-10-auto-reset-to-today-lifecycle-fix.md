# Auto Reset To Today Lifecycle Fix Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the calendar popover reset back to today after 30 seconds of being closed, with the popover controller driving the lifecycle directly.

**Architecture:** `PopoverController` owns a shared `CalendarPopoverViewModel`, records close time in the popover delegate callback, and checks reset conditions immediately before showing the popover. `RootPopoverView` becomes a consumer of the injected view model instead of bridging close notifications.

**Tech Stack:** SwiftUI, AppKit `NSPopover`, XCTest, MVVM

---

### Task 1: Move popover lifecycle ownership into the controller

**Files:**
- Modify: `CalendarPro/App/PopoverController.swift`
- Modify: `CalendarPro/Views/RootPopoverView.swift`
- Modify: `CalendarPro/App/AppDelegate.swift`

**Step 1: Inject a shared `CalendarPopoverViewModel` into `PopoverController`**

Add a stored `viewModel` property and initializer parameter so the controller can reuse one state object across close/open cycles.

**Step 2: Pass the injected view model into `RootPopoverView`**

Update `updateContentView()` to create `RootPopoverView(settingsStore:eventService:viewModel:...)`.

**Step 3: Drive reset logic in the popover controller**

Call `viewModel.checkAndResetIfNeeded()` before `popover.show(...)`, and call `viewModel.popoverDidClose()` from `popoverDidClose(_:)`.

**Step 4: Remove SwiftUI-side close notification bridging**

Delete the `NotificationCenter` bridge and the `RootPopoverView.onReceive(...)` close listener.

### Task 2: Reduce the timeout to 30 seconds

**Files:**
- Modify: `CalendarPro/Views/Popover/CalendarPopoverViewModel.swift`
- Test: `CalendarProTests/Popover/CalendarPopoverViewModelTests.swift`

**Step 1: Replace the hard-coded 300-second threshold**

Introduce a small `autoResetInterval` property with a default value of `30` seconds.

**Step 2: Keep the reset behavior unchanged apart from the threshold**

When the interval is exceeded, continue to call `resetToToday()`, `selectDate(Date())`, and clear `lastClosedTime`.

**Step 3: Update unit tests to use 29s / 31s boundaries**

Rename the tests to reflect the new 30-second threshold and update the injected timestamps.

### Task 3: Cover controller-driven reopen behavior

**Files:**
- Test: `CalendarProTests/CalendarProTests.swift`

**Step 1: Inject a test view model into `PopoverControllerTests`**

Update the controller factory helper to accept an optional `CalendarPopoverViewModel`.

**Step 2: Add a reopen test**

Open the popover, close it, backdate `lastClosedTime` by 31 seconds, reopen it, and assert that the displayed month and selected date both point to today.

### Task 4: Verify the targeted test suite

**Step 1: Run popover-focused tests**

Run:

```bash
xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/Popover/CalendarPopoverViewModelTests -only-testing:CalendarProTests/PopoverControllerTests
```

Expected: Both the view model threshold tests and the controller reopen test pass.

**Step 2: Run the full test suite if the targeted tests are clean**

Run:

```bash
xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'
```

Expected: No regressions in popover, event detail, or settings behavior.
