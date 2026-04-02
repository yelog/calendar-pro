# Popover Now Marker Position Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 重构下拉日程中的当前时间 marker，使时间标签、时间轴节点、卡片入口分属不同视觉轨道，消除遮挡并保留进行中进度语义。

**Architecture:** 保持现有 item 级 marker 数据模型不变，主要重构 `EventListView` 的行布局和 marker 绘制策略。时间文本、时间轴、卡片内容拆成三轨后，`withinItem` marker 使用统一 overlay 在对应轨道中分别绘制时间胶囊、红点、连接线和卡片左缘入口刻度；`beforeGroup` / `afterGroup` 复用同一套视觉语言。

**Tech Stack:** SwiftUI, EventKit, XCTest

---

### Task 1: 更新设计文档并冻结视觉规则

**Files:**
- Modify: `docs/plans/2026-04-02-popover-now-marker-position-design.md`
- Modify: `docs/plans/2026-04-02-popover-now-marker-position.md`

**Step 1: Write the design update**

明确：
- 三轨分层布局
- 当前时间胶囊与时间轴轨分离
- 卡片内不再使用穿越正文的长横线

**Step 2: Save the implementation plan**

确保计划里写清楚改动文件、布局重构点和验证命令。

**Step 3: Commit**

```bash
git add docs/plans/2026-04-02-popover-now-marker-position-design.md docs/plans/2026-04-02-popover-now-marker-position.md
git commit -m "docs(popover): redesign now marker visual lanes"
```

### Task 2: 重构时间线布局为三轨结构

**Files:**
- Modify: `CalendarPro/Views/Popover/EventListView.swift`

**Step 1: Write the failing test**

沿用现有 `CalendarItemTests` 作为行为保护，当前阶段不新增视觉测试，先确保 marker 业务语义不回退。

**Step 2: Run test to verify baseline**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarItemTests`
Expected: PASS

**Step 3: Write minimal implementation**

在 `EventListView.swift`：
- 拆分时间文本轨和时间轴轨
- 更新组行和独立 marker row 的布局
- 为 overlay 提供新的轨道坐标计算

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarItemTests`
Expected: PASS

**Step 5: Commit**

```bash
git add CalendarPro/Views/Popover/EventListView.swift
git commit -m "refactor(popover): split event timeline into visual lanes"
```

### Task 3: 重绘 within-item marker 的入口样式

**Files:**
- Modify: `CalendarPro/Views/Popover/EventListView.swift`
- Modify: `CalendarPro/Views/Popover/EventCardView.swift`

**Step 1: Write the failing test**

继续使用现有行为测试作为回归保护，确认 item 级 marker 和 progress 计算不受影响。

**Step 2: Run test to verify baseline**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarItemTests`
Expected: PASS

**Step 3: Write minimal implementation**

实现：
- 当前时间胶囊只占时间文本轨
- 当前时间红点只占时间轴轨
- 连接线只连接到卡片边缘
- 卡片左缘显示短入口刻度或高亮端点
- 如有必要，微调 `EventCardView` 的进行中装饰以避免和入口刻度冲突

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarItemTests`
Expected: PASS

**Step 5: Commit**

```bash
git add CalendarPro/Views/Popover/EventListView.swift CalendarPro/Views/Popover/EventCardView.swift
git commit -m "fix(popover): redesign now marker entry into active card"
```

### Task 4: 完整验证

**Files:**
- Modify: `CalendarPro/Views/Popover/EventListView.swift`
- Modify: `CalendarPro/Views/Popover/EventCardView.swift`
- Test: `CalendarProTests/Events/CalendarItemTests.swift`

**Step 1: Run targeted tests**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarItemTests`
Expected: PASS

**Step 2: Run build verification**

Run: `xcodebuild -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED

**Step 3: Manual verification checklist**

检查：
- 当前时间标签不遮挡分组节点
- 当前时间红点与事件起始节点可同时看见
- 当前时间连接线在卡片边缘形成明确入口，不再像被卡片截断
- 进行中卡片内的纵向落点仍然合理

**Step 4: Commit**

```bash
git add CalendarPro/Views/Popover/EventListView.swift CalendarPro/Views/Popover/EventCardView.swift CalendarProTests/Events/CalendarItemTests.swift
git commit -m "fix(popover): polish current time timeline layering"
```
