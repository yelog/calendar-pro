# Menu Bar Event Indicator Two-Row Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Render multiple menu bar event indicator dots in two rows so active events use less horizontal status bar space.

**Architecture:** Keep the event source and status item plumbing unchanged. Update `MenuBarTextImageRenderer` to calculate indicator width by columns and draw multi-dot indicators in a two-row, column-major layout.

**Tech Stack:** Swift 6, AppKit `NSImage` drawing, XCTest, Xcode command-line tests.

---

### Task 1: Add Renderer Coverage

**Files:**
- Modify: `CalendarProTests/MenuBar/ClockRenderServiceTests.swift`

**Step 1: Add a test for compact multi-dot width**

Add a test that renders text with one, two, and three dots. Assert that:

- indicator images are non-template;
- two-dot width equals one-dot width because both use one indicator column;
- three-dot width is narrower than the old horizontal layout would have been.

**Step 2: Run the focused test**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/ClockRenderServiceTests`

Expected: the new compact-width assertion fails before implementation.

### Task 2: Implement Two-Row Dot Layout

**Files:**
- Modify: `CalendarPro/Features/MenuBar/ClockRenderService.swift:195-254`

**Step 1: Replace horizontal width calculation**

Calculate indicator columns as:

```swift
let dotColumnCount = dots.count > 1 ? Int(ceil(Double(dots.count) / 2.0)) : dots.count
```

Use `dotColumnCount` to compute indicator width instead of `dots.count`.

**Step 2: Draw column-major positions**

For each dot index:

```swift
let column = index / 2
let row = index % 2
```

Use one row for a single dot and two rows for multiple dots. Draw row `0` above row `1`.

**Step 3: Keep existing dot appearance**

Do not change color parsing, fallback color, `.ongoing` fill, `.upcoming` stroke, or stroke width.

### Task 3: Verify

**Files:**
- Test: `CalendarProTests/MenuBar/ClockRenderServiceTests.swift`

**Step 1: Run focused menu bar tests**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/ClockRenderServiceTests`

Expected: PASS.

**Step 2: Run full test suite when feasible**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'`

Expected: PASS.
