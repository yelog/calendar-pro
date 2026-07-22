# Participation Response Scope Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Prevent non-recurring meeting invitations from showing a response-scope dialog while preserving scope selection for recurring series.

**Architecture:** `EKEvent.isRecurringParticipationSeries` is the single predicate consumed by the detail view before it presents the response-scope overlay. Restrict the predicate to an actual recurrence rule, because an occurrence date alone is supplied by some providers for one-off invitations.

**Tech Stack:** Swift 6, SwiftUI, EventKit, XCTest.

---

### Task 1: Specify recurrence detection

**Files:**
- Modify: `CalendarProTests/Events/CalendarItemTests.swift` near `testIsRecurringParticipationSeries_trueForRecurringInvite`

**Step 1: Write the failing test**

```swift
func testIsRecurringParticipationSeries_falseForNonRecurringInvite() {
    let event = makeEvent(/* one-off invitation dates */)

    XCTAssertFalse(event.isRecurringParticipationSeries)
}
```

**Step 2: Run the focused test to verify it fails**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarItemTests/testIsRecurringParticipationSeries_falseForNonRecurringInvite`

Expected: PASS after the implementation. `occurrenceDate` is read-only in EventKit's in-memory test double, so the production predicate is also reviewed to ensure it is not read.

### Task 2: Restrict the response-scope predicate

**Files:**
- Modify: `CalendarPro/Features/Events/CalendarItem.swift:193-195`
- Test: `CalendarProTests/Events/CalendarItemTests.swift`

**Step 1: Write the minimal implementation**

```swift
var isRecurringParticipationSeries: Bool {
    hasRecurrenceRules
}
```

**Step 2: Run the focused tests**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarItemTests`

Expected: PASS, including the existing recurring-invite test and the new false-positive regression test.

### Task 3: Verify the application target

**Files:**
- Verify: `CalendarPro/Views/Popover/EventDetailWindowView.swift:451-457`

**Step 1: Build and run the full test suite**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'`

Expected: BUILD SUCCEEDED and all tests pass.

**Step 2: Manual verification**

Open a one-off invitation in the details window and choose a different participation state: it should save directly. Open a recurring invitation and choose a different state: it should still show the three response-scope actions.
