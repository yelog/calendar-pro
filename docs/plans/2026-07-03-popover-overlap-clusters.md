# Popover Overlap Clusters Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 在下拉日程时间线中把完全重叠、部分重叠和多个连通重叠日程表达为明确的重叠簇，避免用户误读为普通先后列表。

**Architecture:** 保持 `RootPopoverView -> CalendarPopoverView -> EventListView` 数据流不变，在 `EventTimelineSnapshot` 内把 timed items 从“同开始时间分组”升级为“连通时间区间分组”。`EventListView` 为重叠簇计算并排 lane、簇内时间比例和当前时间位置，再渲染局部时间网格；普通非重叠组继续沿用现有纵向卡片列表。

**Tech Stack:** Swift 6, SwiftUI, EventKit, XCTest, xcodebuild

---

### Task 1: 用测试定义重叠簇语义

**Files:**
- Modify: `CalendarProTests/Events/CalendarItemTests.swift`
- Modify: `CalendarPro/Views/Popover/EventListView.swift`

**Step 1: Write the failing tests**

在 `CalendarItemTests` 的 timeline 区域增加测试，覆盖：
- 完全重叠事件生成一个重叠簇，摘要为 `.identical`
- 部分重叠事件生成一个重叠簇，整体区间覆盖最早开始到最晚结束
- 链式多事件重叠生成一个连通簇，并计算 `maximumConcurrentItemCount`
- 非重叠事件仍生成独立普通组

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarItemTests`

Expected: FAIL，提示缺少重叠摘要字段或现有分组数量不符合新期望。

### Task 2: 实现重叠簇数据模型

**Files:**
- Modify: `CalendarPro/Views/Popover/EventListView.swift`
- Test: `CalendarProTests/Events/CalendarItemTests.swift`

**Step 1: Write minimal implementation**

在 `EventListView.swift` 中新增轻量模型：
- `EventTimelineOverlapKind`
- `EventTimelineOverlapSummary`
- `EventTimelineLaneItem`
- `EventTimelineItemSpan`

调整 `EventTimelineGroup`：
- 增加 `endMinutes`
- 增加 `overlapSummary`
- 增加 `laneItems` 与 `laneCount`
- 让 `displayTime` 对重叠簇显示整体区间，普通组保持开始时间
- `id` 使用区间和 item identifiers 生成，避免多个组同开始时间冲突

分组算法：
- 先把 timed item 转成 span
- 按开始时间、结束时间排序
- 用 sweep/merge 思路把所有连通重叠 span 合成一组
- 对簇内项目做贪心 lane 分配，计算每个项目在簇内的 `startRatio` / `endRatio`
- 当前时间落在重叠簇时使用 `.withinGroup(progress:)`，不再绑定单张卡片
- 同开始时间项目仍归入同组
- 只有重叠或同开始时间多项目时才生成 overlap summary

**Step 2: Run test to verify it passes**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarItemTests`

Expected: PASS。

### Task 3: 渲染重叠簇并排泳道

**Files:**
- Modify: `CalendarPro/Views/Popover/EventListView.swift`

**Step 1: Add UI**

在 `timedGroupView` 内容列中：
- 当 `overlapSummary != nil` 时，直接渲染局部时间网格，不显示额外统计提示
- 左侧关键时间刻度表达整体区间，右侧按 lane 并排显示紧凑日程卡片
- 每张卡片按真实开始/结束时间在簇内纵向定位，时间交集通过重叠高度直接呈现
- 当前时间落在簇内时，红线横穿整个网格，并在每张进行中的卡片内部显示对应进度线和已过区域
- 3 条以上 lane 使用横向滚动，保持每条 lane 的最小可读宽度

**Step 2: Keep existing interactions**

保留每个日程/提醒的点击行为、当前时间 marker、选中态和非重叠组原有卡片交互。

### Task 4: 设计记录

**Files:**
- Modify: `docs/plans/2026-04-01-popover-event-timeline-design.md`
- Modify: `docs/plans/2026-07-03-popover-overlap-clusters.md`

**Step 1: Update design record**

补充当前 timeline 设计文档中的“重叠日程”规则，说明完全重叠、部分重叠和多个重叠的表达方式。

### Task 5: 验证

**Files:**
- Verify changed files only

**Step 1: Run focused tests**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarItemTests`

**Step 2: Run build**

Run: `xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'`

**Step 3: Manual QA checklist**

- 两个完全同时间会议显示为一个同时间簇
- 两个部分重叠会议在同一重叠簇中并排显示，纵向位置反映真实开始/结束时间
- 三个以上链式重叠会议通过 lane 数量和卡片位置表达并发关系，不显示额外统计提示
- 当前时间红线横穿重叠簇，并切过每个进行中日程的正确进度点
- 普通不重叠会议仍是原有时间线卡片
- 点击会议/提醒仍打开原详情
