# Cancelled Event Style Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为弹层日程列表和详情窗口中的已取消事件增加统一、清晰的取消态视觉语义。

**Architecture:** 通过 `CalendarItem` 暴露 `EKEvent` 的取消态语义，让列表卡片和详情窗口共享同一判断来源。`EventCardView` 负责时间轴卡片的弱化样式，`EventDetailWindowView` 负责标题删除线和状态胶囊，保持布局与数据流不变。

**Tech Stack:** Swift, SwiftUI, EventKit, XCTest

---

### Task 1: 为取消态语义补测试

**Files:**
- Modify: `CalendarProTests/Events/CalendarItemTests.swift`
- Modify: `CalendarPro/Features/Events/CalendarItem.swift`

**Step 1: Write the failing test**

在 `CalendarItemTests.swift` 中增加断言，覆盖：
- 普通 `EKEvent` 不会被识别为已取消
- `status == .canceled` 的 `EKEvent` 会被识别为已取消
- `EKReminder` 始终不是取消态

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarItemTests`
Expected: FAIL，提示缺少取消态语义

**Step 3: Write minimal implementation**

给 `CalendarItem` 增加一个只读取消态语义属性，内部仅对 `EKEvent` 读取 EventKit 原生状态。

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarItemTests`
Expected: PASS

**Step 5: Commit**

```bash
git add CalendarPro/Features/Events/CalendarItem.swift CalendarProTests/Events/CalendarItemTests.swift
git commit -m "test(events): cover cancelled event semantics"
```

### Task 2: 应用时间轴卡片取消态样式

**Files:**
- Modify: `CalendarPro/Views/Popover/EventCardView.swift`

**Step 1: Update card content styling**

在 `EventCardView.swift` 中按取消态调整：
- 标题删除线
- 时间与副标题降级为次级语义
- 左侧颜色点弱化

**Step 2: Update card container styling**

调整背景、边框和透明度规则：
- 取消态优先于 `ongoing`、`past`、`isSelected`
- 取消事件不再使用进行中高亮底色
- 选中时只保留较轻边框提示

**Step 3: Run targeted tests**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarItemTests`
Expected: PASS

**Step 4: Run build verification**

Run: `xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'`
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add CalendarPro/Views/Popover/EventCardView.swift CalendarPro/Features/Events/CalendarItem.swift CalendarProTests/Events/CalendarItemTests.swift
git commit -m "fix(popover): style cancelled events in timeline"
```

### Task 3: 应用详情窗口取消态样式

**Files:**
- Modify: `CalendarPro/Views/Popover/EventDetailWindowView.swift`

**Step 1: Add cancelled status presentation**

在详情窗口标题区增加一个轻量 `已取消` 状态胶囊。

**Step 2: Update title styling**

让事件标题在取消态下使用删除线，同时保持原有两行截断和文字选择行为。

**Step 3: Verify detail layout remains stable**

确认取消态不会破坏顶部 header、摘要卡和滚动内容布局。

**Step 4: Run build and targeted tests**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarItemTests && xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'`
Expected: PASS and BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add CalendarPro/Views/Popover/EventDetailWindowView.swift CalendarPro/Views/Popover/EventCardView.swift CalendarPro/Features/Events/CalendarItem.swift CalendarProTests/Events/CalendarItemTests.swift docs/plans/2026-04-10-cancelled-event-style-design.md docs/plans/2026-04-10-cancelled-event-style.md
git commit -m "fix(events): add cancelled event styling"
```
