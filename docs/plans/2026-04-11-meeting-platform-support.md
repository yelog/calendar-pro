# Meeting Platform Support Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Upgrade CalendarPro from string-based meeting link detection to platform-driven support so China-market and international meeting tools can have reliable naming, icons, and join actions comparable to Teams where confidence is high.

**Architecture:** Introduce a typed `MeetingPlatform` model in the meeting detector layer and make both the event detail join button and event card metadata render from that shared platform metadata. Roll out first-class support in phases, starting with high-confidence platforms already detected in code, then expanding URL variants and lower-confidence platforms with explicit generic fallbacks.

**Tech Stack:** Swift, SwiftUI, EventKit, XCTest

---

### Task 1: Replace string-based meeting metadata with a typed platform model

**Files:**
- Modify: `CalendarPro/Features/Events/MeetingLinkDetector.swift`
- Test: `CalendarProTests/Events/MeetingLinkDetectorTests.swift`

**Step 1: Write the failing test**

Add assertions proving the detector returns a typed platform model rather than only a display string. Cover at least:
- Teams
- Tencent Meeting
- Feishu
- Zoom
- Google Meet
- Webex

Example direction:

```swift
func testDetectsTencentMeetingPlatform() {
    let link = MeetingLinkDetector.findInText("https://meeting.tencent.com/dm/abc123")
    XCTAssertEqual(link?.platform, .tencentMeeting)
    XCTAssertEqual(link?.platform.displayName, "Tencent Meeting")
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/MeetingLinkDetectorTests`
Expected: FAIL because `platform` is still a string and no typed model exists yet.

**Step 3: Write minimal implementation**

In `MeetingLinkDetector.swift`:
- Introduce `enum MeetingPlatform`
- Move platform metadata into the enum or a nested config type
- Update `MeetingLink` to store `platform: MeetingPlatform`

Example structure:

```swift
enum MeetingPlatform {
    case teams
    case tencentMeeting
    case feishu
    case zoom
    case googleMeet
    case webex

    var displayName: String { ... }
    var joinButtonTitle: String { ... }
    var sfSymbolName: String { ... }
}

struct MeetingLink {
    let url: URL
    let platform: MeetingPlatform
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/MeetingLinkDetectorTests`
Expected: PASS

**Step 5: Commit**

```bash
git add CalendarPro/Features/Events/MeetingLinkDetector.swift CalendarProTests/Events/MeetingLinkDetectorTests.swift
git commit -m "refactor(events): model meeting platforms explicitly"
```

### Task 2: Fix join-button titles and detail-view icons for first-class platforms

**Files:**
- Modify: `CalendarPro/Views/Popover/EventDetailWindowView.swift`
- Modify: `CalendarPro/Features/Events/MeetingLinkDetector.swift`
- Test: `CalendarProTests/Events/MeetingLinkDetectorTests.swift`

**Step 1: Write the failing test**

Add tests for platform-specific join button titles or title metadata so the UI no longer depends on `Join %@ Meeting` for every platform.

Example direction:

```swift
func testTencentMeetingJoinTitleIsNotDuplicated() {
    XCTAssertEqual(MeetingPlatform.tencentMeeting.joinButtonTitle, "Join Tencent Meeting")
}

func testGoogleMeetJoinTitleIsNatural() {
    XCTAssertEqual(MeetingPlatform.googleMeet.joinButtonTitle, "Join Google Meet")
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/MeetingLinkDetectorTests`
Expected: FAIL because the platform model does not yet expose explicit titles.

**Step 3: Write minimal implementation**

In `MeetingPlatform` add:
- `joinButtonTitle`
- `detailSymbolName` or equivalent metadata

Then in `EventDetailWindowView.swift` update `JoinMeetingButton` to render:

```swift
Image(systemName: meetingLink.platform.detailSymbolName)
Text(meetingLink.platform.joinButtonTitle)
```

Use explicit strings such as:
- `Join Microsoft Teams Meeting`
- `Join Tencent Meeting`
- `Join Feishu Meeting`
- `Join Zoom Meeting`
- `Join Google Meet`
- `Join Webex Meeting`

**Step 4: Run targeted tests**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/MeetingLinkDetectorTests`
Expected: PASS

**Step 5: Commit**

```bash
git add CalendarPro/Views/Popover/EventDetailWindowView.swift CalendarPro/Features/Events/MeetingLinkDetector.swift CalendarProTests/Events/MeetingLinkDetectorTests.swift
git commit -m "fix(events): use platform-specific meeting join titles"
```

### Task 3: Remove Teams-only rendering and make event-card branding platform-driven

**Files:**
- Modify: `CalendarPro/Views/Popover/EventCardView.swift`
- Modify: `CalendarPro/Features/Events/MeetingLinkDetector.swift`

**Step 1: Write the failing test**

Visual change only. No brittle snapshot test is required here; verify via code structure and build.

**Step 2: Write minimal implementation**

Move Teams-only card rendering behind the platform model and add a small brand-mark decision layer.

Example direction:

```swift
@ViewBuilder
private func meetingPlatformIcon(for link: MeetingLink) -> some View {
    switch link.platform {
    case .teams:
        TeamsBrandMark()
    case .tencentMeeting:
        TencentMeetingBrandMark()
    case .feishu:
        FeishuBrandMark()
    default:
        Image(systemName: link.platform.cardSymbolName)
    }
}
```

First-class brand marks in this phase:
- Teams
- Tencent Meeting
- Feishu
- Zoom
- Google Meet
- Webex

If a platform lacks a clean brand mark, use a stable fallback symbol without special-casing strings in the view.

**Step 3: Run build verification**

Run: `xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add CalendarPro/Views/Popover/EventCardView.swift CalendarPro/Features/Events/MeetingLinkDetector.swift
git commit -m "feat(popover): render meeting metadata by platform"
```

### Task 4: Expand high-confidence URL coverage for China-market and international platforms

**Files:**
- Modify: `CalendarPro/Features/Events/MeetingLinkDetector.swift`
- Test: `CalendarProTests/Events/MeetingLinkDetectorTests.swift`

**Step 1: Write the failing test**

Add failing cases for the URL variants that should be first-class in this rollout:
- `voovmeeting.com/...`
- `whereby.com/<room>`
- `meet.goto.com/<id>`
- `global.gotomeeting.com/join/<id>`
- extra Webex join shape such as `.../wbxmjs/joinservice/...`

Example direction:

```swift
func testDetectsVooVMeetingLink() {
    let link = MeetingLinkDetector.findInText("https://voovmeeting.com/dm/123456789")
    XCTAssertEqual(link?.platform, .voovMeeting)
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/MeetingLinkDetectorTests`
Expected: FAIL because these URL variants are not all covered yet.

**Step 3: Write minimal implementation**

Extend the platform metadata with additional patterns:
- `voovmeeting.com`
- `whereby.com`
- GoTo Meeting modern and legacy URLs
- extra Webex join-service path

Mark platform confidence explicitly where needed. If a platform is low-confidence, do not create a first-class branded case yet.

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/MeetingLinkDetectorTests`
Expected: PASS

**Step 5: Commit**

```bash
git add CalendarPro/Features/Events/MeetingLinkDetector.swift CalendarProTests/Events/MeetingLinkDetectorTests.swift
git commit -m "feat(events): expand meeting link coverage"
```

### Task 5: Define fallback behavior for low-confidence platforms

**Files:**
- Modify: `CalendarPro/Features/Events/MeetingLinkDetector.swift`
- Modify: `CalendarPro/Views/Popover/EventDetailWindowView.swift`
- Test: `CalendarProTests/Events/MeetingLinkDetectorTests.swift`

**Step 1: Add support-tier metadata**

In `MeetingPlatform`, define a tier such as:

```swift
enum MeetingSupportTier {
    case firstClass
    case genericFallback
}
```

**Step 2: Use fallback titles when confidence is low**

For low-confidence or generic cases, detail view should use something like:

```swift
Text(L("Open Meeting Link"))
```

instead of a branded title.

**Step 3: Run targeted tests**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/MeetingLinkDetectorTests`
Expected: PASS

**Step 4: Run build verification**

Run: `xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'`
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add CalendarPro/Features/Events/MeetingLinkDetector.swift CalendarPro/Views/Popover/EventDetailWindowView.swift CalendarProTests/Events/MeetingLinkDetectorTests.swift docs/plans/2026-04-11-meeting-platform-support-design.md docs/plans/2026-04-11-meeting-platform-support.md
git commit -m "feat(events): add phased meeting platform support"
```
