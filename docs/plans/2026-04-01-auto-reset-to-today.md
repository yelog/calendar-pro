# Auto Reset To Today Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Automatically reset calendar popover to today when reopened after 5+ minutes of being closed

**Architecture:** ViewModel tracks lastClosedTime, PopoverController sends close notification, RootPopoverView checks on appear

**Tech Stack:** SwiftUI, Combine, NotificationCenter, MVVM

---

## Task 1: Add Notification Name Extension

**Files:**
- Modify: `CalendarPro/App/PopoverController.swift:1-4`

**Step 1: Add notification name extension**

Add at the top of PopoverController.swift (after imports):

```swift
import AppKit
import EventKit
import SwiftUI

extension Notification.Name {
    static let PopoverDidCloseNotification = Notification.Name("PopoverDidCloseNotification")
}
```

**Step 2: Commit**

```bash
git add CalendarPro/App/PopoverController.swift
git commit -m "feat: add PopoverDidClose notification name"
```

---

## Task 2: Update CalendarPopoverViewModel

**Files:**
- Modify: `CalendarPro/Views/Popover/CalendarPopoverViewModel.swift:11-18`
- Test: `CalendarProTests/Popover/CalendarPopoverViewModelTests.swift`

**Step 1: Write failing tests**

Add tests to `CalendarProTests/Popover/CalendarPopoverViewModelTests.swift`:

```swift
import XCTest
@testable import CalendarPro

final class CalendarPopoverViewModelTests: XCTestCase {
    var viewModel: CalendarPopoverViewModel!
    
    override func setUp() {
        viewModel = CalendarPopoverViewModel()
    }
    
    func testPopoverDidCloseRecordsTime() {
        XCTAssertNil(viewModel.lastClosedTime)
        viewModel.popoverDidClose()
        XCTAssertNotNil(viewModel.lastClosedTime)
    }
    
    func testCheckAndResetDoesNothingWhenNotClosed() {
        viewModel.displayedMonth = Calendar.current.date(byAdding: .month, value: -2, to: .now) ?? .now
        viewModel.checkAndResetIfNeeded()
        XCTAssertNotNil(viewModel.displayedMonth)
        let nowMonth = Calendar.current.component(.month, from: Date())
        let displayedMonth = Calendar.current.component(.month, from: viewModel.displayedMonth)
        XCTAssertNotEqual(nowMonth, displayedMonth)
    }
    
    func testCheckAndResetDoesNothingWithin5Minutes() {
        viewModel.displayedMonth = Calendar.current.date(byAdding: .month, value: -2, to: .now) ?? .now
        viewModel.popoverDidClose()
        viewModel.lastClosedTime = Date().addingTimeInterval(-299)
        viewModel.checkAndResetIfNeeded()
        let nowMonth = Calendar.current.component(.month, from: Date())
        let displayedMonth = Calendar.current.component(.month, from: viewModel.displayedMonth)
        XCTAssertNotEqual(nowMonth, displayedMonth)
    }
    
    func testCheckAndResetAfter5Minutes() {
        viewModel.displayedMonth = Calendar.current.date(byAdding: .month, value: -2, to: .now) ?? .now
        viewModel.popoverDidClose()
        viewModel.lastClosedTime = Date().addingTimeInterval(-301)
        viewModel.checkAndResetIfNeeded()
        let nowMonth = Calendar.current.component(.month, from: Date())
        let displayedMonth = Calendar.current.component(.month, from: viewModel.displayedMonth)
        XCTAssertEqual(nowMonth, displayedMonth)
        XCTAssertNotNil(viewModel.selectedDate)
        XCTAssertTrue(Calendar.current.isDate(viewModel.selectedDate!, inSameDayAs: Date()))
        XCTAssertNil(viewModel.lastClosedTime)
    }
}
```

**Step 2: Run tests to verify failure**

```bash
xcodebuild test -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarPopoverViewModelTests
```

Expected: Tests fail with "Cannot find 'popoverDidClose' in scope" and "Cannot find 'lastClosedTime' in scope"

**Step 3: Add time tracking properties and methods**

Modify `CalendarPopoverViewModel.swift`:

Add property after `selectionMode`:
```swift
@Published private(set) var selectionMode: SelectionMode = .calendar
@Published private(set) var lastClosedTime: Date?
```

Add methods after `resetToToday()`:
```swift
func popoverDidClose() {
    lastClosedTime = Date()
}

func checkAndResetIfNeeded() {
    guard let closedTime = lastClosedTime else { return }
    let interval = Date().timeIntervalSince(closedTime)
    if interval > 300 {
        resetToToday()
        selectDate(Date())
        lastClosedTime = nil
    }
}
```

**Step 4: Run tests to verify they pass**

```bash
xcodebuild test -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarPopoverViewModelTests
```

Expected: All tests pass

**Step 5: Commit**

```bash
git add CalendarPro/Views/Popover/CalendarPopoverViewModel.swift CalendarProTests/Popover/CalendarPopoverViewModelTests.swift
git commit -m "feat: add lastClosedTime tracking and auto-reset logic to ViewModel"
```

---

## Task 3: Send Notification from PopoverController

**Files:**
- Modify: `CalendarPro/App/PopoverController.swift:178-180`

**Step 1: Update popoverDidClose to send notification**

Modify in `PopoverController.swift`:

```swift
func popoverDidClose(_ notification: Notification) {
    interactionMonitor.stop()
    NotificationCenter.default.post(name: .PopoverDidCloseNotification, object: nil)
}
```

**Step 2: Commit**

```bash
git add CalendarPro/App/PopoverController.swift
git commit -m "feat: send PopoverDidClose notification when popover closes"
```

---

## Task 4: Add Notification Listener in RootPopoverView

**Files:**
- Modify: `CalendarPro/Views/RootPopoverView.swift:73-112`

**Step 1: Add notification listener**

Add after the `onAppear` modifier in RootPopoverView:

```swift
.onAppear {
    viewModel.checkAndResetIfNeeded()
    eventService.checkAuthorizationStatus()
    refreshEventsForCurrentSelection(selectingTodayIfNeeded: true)
}
.onReceive(NotificationCenter.default.publisher(for: .PopoverDidCloseNotification)) { _ in
    viewModel.popoverDidClose()
}
.onChange(of: eventService.isAuthorized) { _, isAuthorized in
```

**Step 2: Verify the change**

Check that:
- `checkAndResetIfNeeded()` is called first in `onAppear`
- `popoverDidClose()` notification listener is added after `onAppear`

**Step 3: Commit**

```bash
git add CalendarPro/Views/RootPopoverView.swift
git commit -m "feat: add PopoverDidClose notification listener and check on appear"
```

---

## Task 5: Run Full Test Suite

**Step 1: Run all tests**

```bash
xcodebuild test -scheme CalendarPro -destination 'platform=macOS'
```

Expected: All tests pass

**Step 2: Build and verify**

```bash
xcodebuild build -scheme CalendarPro -destination 'platform=macOS'
```

Expected: Build succeeds with no errors

---

## Task 6: Manual Testing Checklist

**Manual verification steps:**

1. Run the app
2. Open popover, navigate to a different month (e.g., 2 months ago)
3. Close popover
4. Immediately reopen (< 5 minutes) → Should stay on the different month
5. Close popover, wait 5+ minutes
6. Reopen → Should automatically show today and select today's date
7. Verify today's date is selected and events are loaded

---

## Summary

**Implementation complete.** The popover will now automatically reset to today when reopened after 5+ minutes of being closed, making it easier for users to quickly access current events.

**Files modified:**
- `CalendarPro/App/PopoverController.swift`
- `CalendarPro/Views/Popover/CalendarPopoverViewModel.swift`
- `CalendarPro/Views/RootPopoverView.swift`
- `CalendarProTests/Popover/CalendarPopoverViewModelTests.swift` (new tests)

**Commits:**
1. Add notification name extension
2. Add ViewModel time tracking and reset logic
3. Send notification when popover closes
4. Add notification listener and check on appear