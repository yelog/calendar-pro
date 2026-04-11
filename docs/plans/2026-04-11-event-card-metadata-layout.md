# Event Card Metadata Layout Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 调整弹层日程卡片的排版结构，让时间与 metadata 同行，标题独立占满下一行宽度。

**Architecture:** 保持现有会议 / 提醒 metadata 语义来源不变，只重构 `EventCardView` 的内容层级。卡片主体改为纵向三行结构：首行承载时间与 metadata，第二行承载标题，第三行承载副标题，从而避免 metadata 压缩标题宽度。

**Tech Stack:** Swift, SwiftUI, EventKit, XCTest, @mobile-ios-design

---

### Task 1: 重构卡片首行与标题布局

**Files:**
- Modify: `CalendarPro/Views/Popover/EventCardView.swift`

**Step 1: Write the failing test**

本次以视觉布局修正为主，不新增难以稳定表达的视图测试；先通过实现和构建验证布局语义。

**Step 2: Write minimal implementation**

在 `EventCardView.swift` 中：
- 将卡片主内容改为 `VStack(alignment: .leading, spacing: 2)`
- 新增 `headerRow`：`timeRangeText + Spacer + metadata`
- 标题独立为第二行
- 副标题独立为第三行

**Step 3: Verify visual constraints in code**

确认：
- metadata 只出现在首行
- 标题继续 `lineLimit(2)`
- 没有 metadata 的卡片仍使用相同结构

**Step 4: Run build verification**

Run: `xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'`
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add CalendarPro/Views/Popover/EventCardView.swift
git commit -m "fix(popover): move event metadata into header row"
```

### Task 2: 验证 metadata 与既有语义未回退

**Files:**
- Modify: `CalendarProTests/Events/CalendarItemTests.swift`
- Modify: `CalendarProTests/Events/MeetingLinkDetectorTests.swift`

**Step 1: Re-run targeted tests**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarItemTests -only-testing:CalendarProTests/MeetingLinkDetectorTests`
Expected: TEST SUCCEEDED

**Step 2: Commit**

```bash
git add CalendarPro/Views/Popover/EventCardView.swift CalendarProTests/Events/CalendarItemTests.swift CalendarProTests/Events/MeetingLinkDetectorTests.swift docs/plans/2026-04-11-event-card-metadata-layout-design.md docs/plans/2026-04-11-event-card-metadata-layout.md
git commit -m "fix(popover): let titles span full width beneath metadata"
```
