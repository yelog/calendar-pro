# Event Card Metadata Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为弹层日程卡片补充会议与重复提醒的语义 metadata，替换掉当前右上角无意义的左箭头。

**Architecture:** 在 `CalendarItem` 和 EventKit 扩展层补充会议链接、参会人数、提醒重复周期的共享语义；`EventCardView` 在右上角渲染紧凑 metadata；`ReminderDetailWindowView` 复用相同的重复周期 helper，避免卡片与详情逻辑分叉。

**Tech Stack:** Swift, SwiftUI, EventKit, XCTest

---

### Task 1: 提取共享 metadata 语义

**Files:**
- Modify: `CalendarPro/Features/Events/CalendarItem.swift`
- Modify: `CalendarProTests/Events/CalendarItemTests.swift`

**Step 1: Write the failing test**

在 `CalendarItemTests.swift` 中增加断言，覆盖：
- Teams 事件可暴露会议链接语义
- 重复提醒可生成紧凑周期文案
- 提醒详情可复用详细周期文案 helper

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarItemTests`
Expected: FAIL，提示缺少 metadata / recurrence helper

**Step 3: Write minimal implementation**

在 `CalendarItem.swift` 中新增：
- 会议链接只读派生属性
- 会议人数只读派生属性
- 提醒重复周期 helper，支持 `compact` / `detailed`

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarItemTests`
Expected: PASS

**Step 5: Commit**

```bash
git add CalendarPro/Features/Events/CalendarItem.swift CalendarProTests/Events/CalendarItemTests.swift
git commit -m "feat(events): expose event card metadata semantics"
```

### Task 2: 重构卡片右上角 metadata 区域

**Files:**
- Modify: `CalendarPro/Views/Popover/EventCardView.swift`

**Step 1: Replace disclosure arrow**

移除 `chevron.left`，改为条件化的 `metadataView`。

**Step 2: Render meeting metadata**

对会议事件渲染：
- Teams 品牌化图标
- 非 Teams 的通用会议图标 fallback
- `person.2` + 人数

**Step 3: Render repeating reminder metadata**

对重复提醒渲染：
- `repeat` 图标
- 紧凑周期文案

**Step 4: Verify card layout stability**

确认 metadata 不会破坏：
- 时间文本
- 标题两行截断
- 已完成 / 已取消样式

**Step 5: Commit**

```bash
git add CalendarPro/Views/Popover/EventCardView.swift CalendarPro/Features/Events/CalendarItem.swift
git commit -m "feat(popover): show semantic metadata in event cards"
```

### Task 3: 统一提醒详情的重复周期文案来源

**Files:**
- Modify: `CalendarPro/Views/Popover/ReminderDetailWindowView.swift`

**Step 1: Switch detail view to shared helper**

让提醒详情窗口改用共享 recurrence helper，保持与卡片逻辑一致，但保留 detailed 模式。

**Step 2: Run targeted tests**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarItemTests -only-testing:CalendarProTests/MeetingLinkDetectorTests`
Expected: PASS

**Step 3: Run build verification**

Run: `xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add CalendarPro/Views/Popover/EventCardView.swift CalendarPro/Views/Popover/ReminderDetailWindowView.swift CalendarPro/Features/Events/CalendarItem.swift CalendarProTests/Events/CalendarItemTests.swift docs/plans/2026-04-11-event-card-metadata-design.md docs/plans/2026-04-11-event-card-metadata.md
git commit -m "feat(events): replace disclosure with semantic card metadata"
```
