# Popover Now Marker Through Card Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 让当前时间红线在进行中日程场景下横穿整张卡片并浮在内容上层。

**Architecture:** 保持现有 `EventTimelineSnapshot` 和 marker 语义不变，只调整 `EventListView` 中 `withinItemMarkerOverlay` 的终点坐标和绘制元素。当前时间胶囊、红点和横线继续使用同一套 overlay 坐标，非进行中场景的 marker row 不受影响。

**Tech Stack:** SwiftUI, EventKit, XCTest, xcodebuild

---

### Task 1: 记录新的 marker 视觉规则

**Files:**
- Create: `docs/plans/2026-04-09-popover-now-marker-through-card-design.md`
- Create: `docs/plans/2026-04-09-popover-now-marker-through-card.md`

**Step 1: Write the design update**

明确：
- `withinItem` 场景下红线横穿卡片
- 红线绘制在卡片内容上层
- 左缘短入口刻度删除

**Step 2: Save the implementation plan**

把文件路径、验证命令和最小代码范围写清楚。

### Task 2: 重绘进行中日程的横向红线

**Files:**
- Modify: `CalendarPro/Views/Popover/EventListView.swift`
- Test: `CalendarProTests/Events/CalendarItemTests.swift`

**Step 1: Run regression baseline**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarItemTests`
Expected: PASS

**Step 2: Write minimal implementation**

在 `withinItemMarkerOverlay` 中：
- 将红线终点从卡片左缘改为卡片右侧内边距
- 删除左缘短刻度绘制
- 保留时间胶囊、红点和同轴横线

**Step 3: Run targeted tests**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarItemTests`
Expected: PASS

### Task 3: 做编译和视觉回归验证

**Files:**
- Modify: `CalendarPro/Views/Popover/EventListView.swift`

**Step 1: Run build verification**

Run: `xcodebuild -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED

**Step 2: Manual verification checklist**

检查：
- 进行中日程的红线横穿卡片
- 红线位于卡片内容上层
- 红点、时间胶囊和红线共线
- `beforeGroup` / `afterGroup` 视觉不回退
