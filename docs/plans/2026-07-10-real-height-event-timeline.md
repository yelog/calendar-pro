# Real-Height Event Timeline Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the compact event stack with a scrollable 24-hour timeline whose event edges, idle gaps, overlap lanes, and current-time marker all use one minute-based coordinate system.

**Architecture:** Keep the existing `RootPopoverView → CalendarPopoverView → EventListView` data flow, but make `EventTimelineSnapshot` selected-date-aware and expose clipped minute spans for a unified day canvas. Render timed items in one absolute-positioned SwiftUI grid at `1pt/minute`; retain compact auxiliary sections for all-day and untimed items, and reuse the existing event/reminder actions.

**Tech Stack:** Swift 6, SwiftUI, EventKit, XCTest, xcodebuild

---

### Task 1: Define selected-day timeline geometry with tests

**Files:**
- Modify: `CalendarPro/Views/Popover/EventListView.swift`
- Test: `CalendarProTests/Events/CalendarItemTests.swift`

**Step 1: Write the failing tests**

Add tests for a public-to-tests layout helper that assert:

```swift
XCTAssertEqual(layout.startMinutes, 9 * 60)
XCTAssertEqual(layout.endMinutes, 10 * 60)
XCTAssertEqual(layout.durationMinutes, 60)
XCTAssertEqual(layout.yPosition(pointsPerMinute: 1), 540)
XCTAssertEqual(layout.height(pointsPerMinute: 1), 60)
```

Also cover:

- a 90-minute idle gap remains 90 minutes in the shared coordinate system;
- an event starting before the selected day clips to minute `0`;
- an event ending after the selected day clips to minute `1440`;
- a timed reminder is modeled as a point item at its due minute;
- adjacent events share no overlap lane;
- connected overlaps receive stable lane indices.

**Step 2: Run tests to verify they fail**

Run:

```bash
xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarItemTests
```

Expected: FAIL because the selected-day layout model and geometry helpers do not exist.

**Step 3: Implement the minimal layout model**

In `EventListView.swift`:

- introduce a timed layout item containing `item`, `startMinutes`, `endMinutes`, `laneIndex`, `laneCount`, and point/duration semantics;
- derive spans using selected-day start and next-day boundary, not hour components alone;
- clip events to the selected day;
- group connected overlaps and assign lanes with the existing greedy algorithm;
- keep reminders as point items without invented duration;
- expose minute-to-point helpers used by both tests and rendering.

**Step 4: Run focused tests**

Run the same `xcodebuild test` command.

Expected: PASS.

**Step 5: Commit**

```bash
git add CalendarPro/Views/Popover/EventListView.swift CalendarProTests/Events/CalendarItemTests.swift
git commit -m "refactor(popover): model a continuous day timeline"
```

### Task 2: Render the shared 24-hour canvas

**Files:**
- Modify: `CalendarPro/Views/Popover/EventListView.swift`
- Modify: `CalendarPro/Views/Popover/CalendarPopoverView.swift`

**Step 1: Replace group-stack rendering**

Render one `1440pt` timeline canvas using `1pt/minute`:

- hourly labels and major rules;
- half-hour minor rules;
- timed cards positioned by clipped `startMinutes` and `endMinutes`;
- overlap lanes sized from the group lane count;
- horizontal scrolling only when lane minimum width cannot fit.

Do not apply a visual minimum height to duration events.

**Step 2: Add height-aware event content**

Unify normal and overlap timed cards into a compact day-card view:

- full content at `≥44pt`;
- time and title at `24–43pt`;
- title/color-only rendering below `24pt`;
- point reminders use a compact clickable marker anchored to the exact due minute;
- help text and accessibility labels retain the full time/title information.

**Step 3: Keep auxiliary sections usable**

Move all-day and untimed items before the timed canvas so they do not sit below a `1440pt` scroll journey. Preserve event selection, reminder completion, and reminder detail actions.

**Step 4: Preserve the 200pt popover viewport**

Keep `CalendarPopoverView` at the existing event-region maximum height. The full day lives inside the existing scroll surface and must not enlarge the popover.

**Step 5: Build**

Run:

```bash
xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'
```

Expected: `BUILD SUCCEEDED`.

**Step 6: Commit**

```bash
git add CalendarPro/Views/Popover/EventListView.swift CalendarPro/Views/Popover/CalendarPopoverView.swift
git commit -m "feat(popover): render events on a real-height timeline"
```

### Task 3: Add current-time progress and stable auto-positioning

**Files:**
- Modify: `CalendarPro/Views/Popover/EventListView.swift`
- Test: `CalendarProTests/Events/CalendarItemTests.swift`

**Step 1: Write failing marker tests**

Cover:

- `10:54` maps to minute `654` and to 90% of a `10:00–11:00` event;
- non-today selections expose no current-time marker;
- today initially targets the current-minute anchor;
- non-today initially targets 30 minutes before the first timed item, clamped to the day;
- a minute refresh updates geometry without changing the initial scroll trigger identity.

**Step 2: Run tests to verify they fail**

Run the focused `CalendarItemTests` command.

Expected: FAIL until the day-level marker/anchor helpers exist.

**Step 3: Implement marker and scroll anchors**

- draw the current-time chip, dot, and line at `currentMinutes * pointsPerMinute`;
- clip an elapsed tint inside every ongoing duration card up to that same Y coordinate;
- add invisible scroll anchors for current time and item starts;
- scroll today near current time and other dates near the first timed item;
- trigger automatic scrolling only on appear, selected-date changes, and item-identity changes.

**Step 4: Run tests and build**

```bash
xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarItemTests
xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'
```

Expected: tests PASS and `BUILD SUCCEEDED`.

**Step 5: Commit**

```bash
git add CalendarPro/Views/Popover/EventListView.swift CalendarProTests/Events/CalendarItemTests.swift
git commit -m "feat(popover): track current time on the day timeline"
```

### Task 4: Regression verification and documentation sync

**Files:**
- Modify: `docs/plans/2026-04-01-popover-event-timeline-design.md`
- Verify: `docs/plans/2026-07-10-real-height-event-timeline-design.md`
- Verify: `docs/plans/2026-07-10-real-height-event-timeline.md`

**Step 1: Update the superseded design assumption**

In the original timeline design, record that the 2026-07-10 design supersedes the compact-list/non-scheduler constraint while retaining all-day, untimed-reminder, click-action, and EventKit data-flow rules.

**Step 2: Run focused tests**

```bash
xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarItemTests -only-testing:CalendarProTests/CalendarPopoverViewModelTests
```

Expected: PASS.

**Step 3: Run the full test suite**

```bash
xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'
```

Expected: PASS.

**Step 4: Run a clean build verification**

```bash
xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'
```

Expected: `BUILD SUCCEEDED`.

**Step 5: Manual QA checklist**

- A one-hour event is visually twice a 30-minute event.
- A 90-minute free interval occupies 90pt.
- A current-time line at 90% of an event is immediately legible.
- Overlap lanes preserve exact top and bottom edges.
- Cross-midnight events clip at the selected-day edge.
- Timed reminders align to their exact due-minute node.
- All-day and untimed items remain reachable above the time canvas.
- Event and reminder detail actions still work.
- Scrolling remains smooth in the `200pt` event viewport.

**Step 6: Commit**

```bash
git add docs/plans/2026-04-01-popover-event-timeline-design.md docs/plans/2026-07-10-real-height-event-timeline-design.md docs/plans/2026-07-10-real-height-event-timeline.md
git commit -m "docs(popover): document continuous day timeline delivery"
```
