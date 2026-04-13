# Read-Only Invite Participation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Hide misleading personal participation status and response controls for read-only group-invite events while preserving attendee and meeting metadata.

**Architecture:** Add a shared `EKEvent` participation-presentation semantic that separates hidden, read-only, and editable invite states. Reuse that semantic in `EventCardView` and `EventDetailWindowView` so list badges, detail header badges, and response controls all follow the same Apple Calendar-aligned rule set.

**Tech Stack:** Swift, SwiftUI, EventKit, XCTest

---

### Task 1: Add shared participation presentation semantics

**Files:**
- Modify: `CalendarPro/Features/Events/CalendarItem.swift`
- Modify: `CalendarProTests/Events/CalendarItemTests.swift`

**Step 1: Write the failing test**

Add coverage for the new shared presentation model.

```swift
func testParticipationPresentation_returnsReadOnlyForReadOnlyGroupInvite() {
    let event = makeEvent(
        title: "群组会议",
        start: makeDate(year: 2026, month: 4, day: 13, hour: 13, minute: 30),
        end: makeDate(year: 2026, month: 4, day: 13, hour: 15, minute: 0)
    )
    event.setValue(true, forKey: "currentUserInvitedAttendee")
    event.setValue(EKParticipantStatus.accepted.rawValue, forKey: "participationStatus")
    event.setValue(false, forKey: "canBeRespondedTo")
    event.setValue(false, forKey: "allowsParticipationStatusModifications")

    XCTAssertEqual(event.currentUserParticipationPresentation, .readOnly)
    XCTAssertNil(event.currentUserParticipationChoice)
}

func testParticipationPresentation_returnsEditableWithoutChoiceForPendingInvite() {
    let event = makeEvent(
        title: "待回复会议",
        start: makeDate(year: 2026, month: 4, day: 13, hour: 16, minute: 0),
        end: makeDate(year: 2026, month: 4, day: 13, hour: 17, minute: 0)
    )
    event.setValue(true, forKey: "currentUserInvitedAttendee")
    event.setValue(true, forKey: "canBeRespondedTo")

    XCTAssertEqual(event.currentUserParticipationPresentation, .editable(currentChoice: nil))
}

func testParticipationPresentation_returnsHiddenForAttendeeListWithoutUserContext() {
    let event = makeEvent(
        title: "普通会议",
        start: makeDate(year: 2026, month: 4, day: 13, hour: 9, minute: 0),
        end: makeDate(year: 2026, month: 4, day: 13, hour: 10, minute: 0)
    )

    XCTAssertEqual(event.currentUserParticipationPresentation, .hidden)
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarItemTests`
Expected: FAIL because `EventParticipationPresentation` and `currentUserParticipationPresentation` do not exist yet.

**Step 3: Write minimal implementation**

In `CalendarItem.swift`, introduce a shared semantic model and tighten the existing heuristics.

```swift
enum EventParticipationPresentation: Equatable {
    case hidden
    case readOnly
    case editable(currentChoice: EventParticipationChoice?)
}

extension EKEvent {
    var currentUserParticipationPresentation: EventParticipationPresentation {
        guard !currentUserActsAsOrganizer else {
            return .hidden
        }

        let choice = resolvedCurrentUserParticipationChoice
        let canRespond = runtimeBoolValue(forKey: "allowsParticipationStatusModifications")
            || runtimeBoolValue(forKey: "canBeRespondedTo")

        if canRespond {
            return .editable(currentChoice: choice)
        }

        if hasReliableCurrentUserParticipationIdentity || choice != nil {
            return .readOnly
        }

        return .hidden
    }

    var currentUserParticipationChoice: EventParticipationChoice? {
        guard case .editable(let currentChoice) = currentUserParticipationPresentation else {
            return nil
        }
        return currentChoice
    }
}
```

Important implementation notes:

1. Remove the `attendees.isEmpty == false` fallback as a signal for current-user participation context.
2. Do not treat `responds(to: "setParticipationStatus:")` as proof that the event is editable.
3. Keep attendee lists intact; this task only changes current-user participation semantics.

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarItemTests`
Expected: PASS

**Step 5: Commit**

```bash
git add CalendarPro/Features/Events/CalendarItem.swift CalendarProTests/Events/CalendarItemTests.swift
git commit -m "fix(events): classify read-only invite participation"
```

### Task 2: Drive list and detail UI from the shared presentation state

**Files:**
- Modify: `CalendarPro/Views/Popover/EventCardView.swift`
- Modify: `CalendarPro/Views/Popover/EventDetailWindowView.swift`
- Modify: `CalendarPro/Resources/Localizable.xcstrings`

**Step 1: Add the smallest regression assertion needed for the view contract**

Extend `CalendarItemTests` so the UI contract is explicit: read-only invites expose `.readOnly` presentation but no list-visible choice.

```swift
func testCalendarItemCurrentUserParticipationChoice_hidesReadOnlyStatusFromList() {
    let event = makeEvent(
        title: "群组会议",
        start: makeDate(year: 2026, month: 4, day: 13, hour: 13, minute: 30),
        end: makeDate(year: 2026, month: 4, day: 13, hour: 15, minute: 0)
    )
    event.setValue(true, forKey: "currentUserInvitedAttendee")
    event.setValue(EKParticipantStatus.accepted.rawValue, forKey: "participationStatus")

    XCTAssertEqual(event.currentUserParticipationPresentation, .readOnly)
    XCTAssertNil(CalendarItem.event(event).currentUserParticipationChoice)
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarItemTests`
Expected: FAIL until the view-facing semantics are wired through `CalendarItem`.

**Step 3: Write minimal implementation**

Update both views to consume `currentUserParticipationPresentation` instead of inferring behavior from scattered booleans.

```swift
private var participationPresentation: EventParticipationPresentation {
    event.currentUserParticipationPresentation
}

private var detailHeaderChoice: EventParticipationChoice? {
    guard case .editable(let currentChoice) = participationPresentation else {
        return nil
    }
    return currentChoice
}

private var showsReadOnlyParticipationNotice: Bool {
    participationPresentation == .readOnly
}
```

Implementation details:

1. `EventCardView`
   - Continue reading `item.currentUserParticipationChoice` for the compact badge.
   - Because Task 1 now hides read-only choices from that helper, list cards automatically stop showing the `Accepted` icon for group-invite read-only events.

2. `EventDetailWindowView`
   - Show the header badge only when `currentUserParticipationPresentation` is `.editable(.some(choice))`.
   - Show response buttons only when the presentation is `.editable`.
   - Show a read-only notice row when the presentation is `.readOnly`.
   - Do not render a status-only read-only badge.

3. `Localizable.xcstrings`
   - Add `"This event is read-only"` with English and Simplified Chinese values.

**Step 4: Run focused verification**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarItemTests`
Expected: PASS

Run: `xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'`
Expected: BUILD SUCCEEDED

**Step 5: Manual verification**

Check these flows in the running app:

1. A read-only group invite shows meeting metadata and attendees, but no personal `Accepted` badge.
2. The same event detail shows `This event is read-only` instead of response buttons.
3. A normal editable invite still shows the current response and still allows `Accept / Maybe / Decline`.

**Step 6: Commit**

```bash
git add CalendarPro/Views/Popover/EventCardView.swift CalendarPro/Views/Popover/EventDetailWindowView.swift CalendarPro/Resources/Localizable.xcstrings CalendarProTests/Events/CalendarItemTests.swift
git commit -m "fix(events): hide response UI for read-only invites"
```

### Task 3: Final verification and documentation check

**Files:**
- Review: `docs/plans/2026-04-13-read-only-invite-participation-design.md`
- Review: `docs/plans/2026-04-13-read-only-invite-participation.md`

**Step 1: Run the final targeted verification**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarItemTests -only-testing:CalendarProTests/EventServiceTests`
Expected: PASS

**Step 2: Run the final build**

Run: `xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'`
Expected: BUILD SUCCEEDED

**Step 3: Review the finished behavior against the approved design**

Confirm all of the following:

1. Read-only group invites no longer display misleading personal response state.
2. Attendee information is still visible.
3. Editable invites keep the current interaction model.

**Step 4: Commit**

```bash
git add docs/plans/2026-04-13-read-only-invite-participation-design.md docs/plans/2026-04-13-read-only-invite-participation.md
git commit -m "docs(events): document read-only invite participation behavior"
```
