# Detail Calendar Account Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Show the owning account/source under the calendar or list name in both event and reminder detail panels so same-named sources are distinguishable.

**Architecture:** Add a small presentation helper that normalizes the calendar title and optional source title, expose it through `EKCalendar`, then extend both event-detail and reminder-detail row views to render an optional secondary line. Keep the change scoped to existing detail rows so the rest of the popover layout stays stable.

**Tech Stack:** Swift, SwiftUI, EventKit, XCTest

---

### Task 1: Add calendar context presentation semantics

**Files:**
- Modify: `CalendarPro/Features/Events/CalendarItem.swift`
- Modify: `CalendarProTests/Events/CalendarItemTests.swift`

**Step 1: Write the failing test**

Add coverage for the display helper that decides whether the account/source line should be shown.

```swift
func testCalendarContextPresentation_keepsDistinctAccountTitle() {
    let presentation = CalendarContextPresentation(
        calendarTitle: "日历",
        sourceTitle: "yangyi13@lenovo.com"
    )

    XCTAssertEqual(presentation.calendarTitle, "日历")
    XCTAssertEqual(presentation.accountTitle, "yangyi13@lenovo.com")
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarItemTests`
Expected: FAIL because `CalendarContextPresentation` does not exist yet.

**Step 3: Write minimal implementation**

In `CalendarItem.swift`, introduce the presentation helper and its normalization rules.

```swift
struct CalendarContextPresentation: Equatable {
    let calendarTitle: String
    let accountTitle: String?

    init(calendarTitle: String, sourceTitle: String?) {
        let normalizedCalendarTitle = calendarTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedSourceTitle = sourceTitle?.trimmingCharacters(in: .whitespacesAndNewlines)

        self.calendarTitle = normalizedCalendarTitle

        if let normalizedSourceTitle,
           !normalizedSourceTitle.isEmpty,
           normalizedSourceTitle.localizedCaseInsensitiveCompare(normalizedCalendarTitle) != .orderedSame {
            self.accountTitle = normalizedSourceTitle
        } else {
            self.accountTitle = nil
        }
    }
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarItemTests`
Expected: PASS

**Step 5: Commit**

```bash
git add CalendarPro/Features/Events/CalendarItem.swift CalendarProTests/Events/CalendarItemTests.swift
git commit -m "feat(events): add calendar account presentation helper"
```

### Task 2: Render the account line in event and reminder detail

**Files:**
- Modify: `CalendarPro/Views/Popover/EventDetailWindowView.swift`
- Modify: `CalendarPro/Views/Popover/ReminderDetailWindowView.swift`

**Step 1: Wire the helper into the detail view**

Replace the single-line calendar/list rows with the shared presentation object.

```swift
private var calendarContextPresentation: CalendarContextPresentation {
    reminder.calendar.calendarContextPresentation
}
```

**Step 2: Extend the existing row view minimally**

Add an optional `secondaryValue` to `EventDetailRow` and `ReminderDetailRow` instead of creating new parallel row components.

```swift
private struct EventDetailRow: View {
    let icon: String
    let title: String
    let value: String
    var secondaryValue: String? = nil
}
```

Render the secondary line only when it exists, use smaller secondary styling, and middle-truncate long account strings.

**Step 3: Verify layout stays compact**

Check that the row still matches the existing card spacing, icon layout, and dark-surface style.

**Step 4: Build the app**

Run: `xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'`
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add CalendarPro/Views/Popover/EventDetailWindowView.swift CalendarPro/Views/Popover/ReminderDetailWindowView.swift CalendarPro/Features/Events/CalendarItem.swift
git commit -m "feat(details): show account under calendar and list names"
```

### Task 3: Final verification

**Files:**
- Review: `docs/plans/2026-04-16-event-detail-calendar-account-design.md`
- Review: `docs/plans/2026-04-16-event-detail-calendar-account.md`

**Step 1: Run the focused tests**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarItemTests`
Expected: PASS

**Step 2: Run the final build**

Run: `xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'`
Expected: BUILD SUCCEEDED

**Step 3: Manual verification**

Check these flows in the running app:

1. Two different accounts with the same calendar name now show different secondary account lines in event detail.
2. Two different accounts with the same list name now show different secondary account lines in reminder detail.
3. Rows with no account/source title still render as a single-line source card.
4. Duplicate source titles do not render a redundant second line.

**Step 4: Commit**

```bash
git add docs/plans/2026-04-16-event-detail-calendar-account-design.md docs/plans/2026-04-16-event-detail-calendar-account.md
git commit -m "docs(details): document calendar account display in detail views"
```
