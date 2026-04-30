# Calendar Event Color Implementation Plan

**Goal:** Make CalendarPro show Apple Calendar event colors more clearly in the popover event list.

**Architecture:** EventKit exposes the color through each item's backing `EKCalendar` (`event.calendar.color` / `reminder.calendar.color`). CalendarPro already normalizes this as `CalendarItem.color`, so the implementation stays in SwiftUI presentation code and does not add new permissions, settings, or persistence.

**Tech Stack:** Swift 6, SwiftUI, EventKit, XCTest.

---

## Requirement Analysis

Apple Calendar colors are calendar colors, not an independent per-event color field. An `EKEvent` belongs to an `EKCalendar`, and `EKCalendar.color`/`cgColor` can be read once the app has calendar access. CalendarPro already fetches this via EventKit and exposes it through `CalendarItem.color`.

Current CalendarPro usage is technically correct but visually weak: a small dot and a thin ongoing-state line can be missed in a dense event list. The UI should make calendar identity scannable without turning every card into a saturated color block.

## UI/UX Design

Use a restrained native macOS list treatment:

- Always show a 4 pt rounded left color rail for events and reminders.
- Tint the card background lightly with the calendar color, stronger for selected and ongoing items.
- Use the calendar color for selected/ongoing borders instead of only the app accent color.
- Keep canceled items red-toned, with the calendar color muted in the rail so cancellation remains the primary semantic state.
- Keep text colors semantic (`primary`, `secondary`) for accessibility and dark-mode contrast.

This gives the same recognition benefit as Apple Calendar's colored blocks while preserving CalendarPro's compact popover layout.

## Implementation Plan

### Task 1: Document design and feasibility

**Files:**
- Create: `docs/plans/2026-04-30-calendar-event-color-design.md`

**Steps:**
1. Record EventKit feasibility and visual design decisions.
2. Note that no model or permission changes are required.

### Task 2: Improve event card color treatment

**Files:**
- Modify: `CalendarPro/Views/Popover/EventCardView.swift`

**Steps:**
1. Add color-scheme awareness to the card.
2. Introduce a left calendar-color rail for every item.
3. Replace generic selected/ongoing accent tints with item calendar-color tints.
4. Keep canceled and completed states visually distinct.

### Task 3: Verify

**Commands:**
- `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarItemTests`
- `xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'`

**Manual QA:**
- Open the popover with events from multiple calendars.
- Confirm colors match Apple Calendar calendar colors.
- Confirm selected, ongoing, past, canceled, reminder, light mode, and dark mode states remain legible.
