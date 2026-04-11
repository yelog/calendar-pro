# Event Participation Status Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add current-user participation status display to event cards and event details, and let users reply Accept / Maybe / Decline directly from the detail panel with recurrence scope selection.

**Architecture:** Extend the shared `EKEvent` / `CalendarItem` semantics layer with current-user participation helpers and a save path backed by EventKit runtime participation properties. Reuse that shared model in both `EventCardView` and `EventDetailWindowView`, then rely on the existing `EKEventStoreChanged` refresh path to propagate saved changes back into the popover list.

**Tech Stack:** Swift, SwiftUI, EventKit, XCTest

---

### Task 1: Add shared participation semantics for events

**Files:**
- Modify: `CalendarPro/Features/Events/CalendarItem.swift`
- Modify: `CalendarProTests/Events/CalendarItemTests.swift`

**Step 1: Write the failing test**

Add assertions covering:
- current-user accepted response maps to a shared choice model
- tentative maps to `Maybe`
- pending or unrelated events do not expose a list-visible response
- recurring-event detection works from recurrence metadata

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarItemTests`
Expected: FAIL because the participation helpers do not exist yet.

**Step 3: Write minimal implementation**

In `CalendarItem.swift`:
- introduce `EventParticipationChoice`
- add `EKEvent` helpers for reading current-user participation state
- add recurrence-scope detection
- add a save helper that writes runtime `participationStatus` and calls `saveEvent(_:span:)`
- treat pending invite events with attendee lists as valid response contexts even when the provider omits an explicit current-user attendee entry

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarItemTests`
Expected: PASS

### Task 2: Surface participation status in event cards

**Files:**
- Modify: `CalendarPro/Views/Popover/EventCardView.swift`

**Step 1: Refactor metadata priority**

Replace the single right-top metadata value with a metadata list so current-user participation status can render alongside meeting metadata instead of replacing it.

**Step 2: Render a compact participation badge**

Render compact badges for:
- Accepted
- Maybe
- Declined

For list cards, render them as icon-only tokens so the badge can coexist with Teams / participant-count metadata without crowding the first row.

Do not render anything for pending / unknown.

**Step 3: Verify layout stability**

Check that:
- participation status and Teams / participant count can appear together
- the combined metadata still shares the first line with time
- the title row is not compressed unexpectedly

### Task 3: Add direct response controls to the event detail panel

**Files:**
- Modify: `CalendarPro/Views/Popover/EventDetailWindowView.swift`
- Modify: `CalendarPro/Resources/Localizable.xcstrings`

**Step 1: Show current status in the detail header**

Add a status badge near the title / close affordance.

**Step 2: Add the response section**

Add a `Response` card that:
- highlights the current choice
- offers Accept / Maybe / Decline buttons when editable
- falls back to read-only display when only the current status is available

**Step 3: Handle recurring-event scope selection**

When the event is part of a recurring series, present:
- `Only This Event`
- `Entire Series`
- `Cancel`

**Step 4: Handle save failures**

Show a user-visible error state if the response cannot be updated.

### Task 4: Verify behavior

**Files:**
- Modify: `CalendarProTests/Events/CalendarItemTests.swift`

**Step 1: Run targeted tests**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarItemTests -only-testing:CalendarProTests/EventServiceTests`
Expected: PASS

**Step 2: Run build verification**

Run: `xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'`
Expected: BUILD SUCCEEDED
