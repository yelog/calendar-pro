# Popover Event Timeline Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为 Calendar Pro 的下拉日程区域增加紧凑型 timeline 和当前时间标记，让用户快速判断当前时间所在的日程位置，同时支持带时间的提醒事项进入时间线。

**Architecture:** 保持现有 `RootPopoverView -> CalendarPopoverView -> EventListView` 数据流不变，只在视图层为 `CalendarItem` 计算临时 timeline 分组和当前时间 marker。`EventCardView` 负责展示进行中、已过去和提醒事项差异化状态，`CalendarItem` 补充“是否有明确时间”的判断，避免无时分提醒被错误归入 `00:00`。

**Tech Stack:** SwiftUI, AppKit semantic colors, EventKit, XCTest

---

### Task 1: 为 timeline 提供可测试的数据判定逻辑

**Files:**
- Modify: `CalendarPro/Features/Events/CalendarItem.swift`
- Modify: `CalendarPro/Views/Popover/EventListView.swift`
- Test: `CalendarProTests/Events/CalendarItemTests.swift`

**Step 1: Write the failing test**

在 `CalendarProTests/Events/CalendarItemTests.swift` 添加断言，覆盖：
- 带时分提醒事项会被判定为“有明确时间”
- 只有日期的提醒事项不会被判定为“有明确时间”
- timeline 分组会把 timed / all-day / untimed 项目拆开
- 当前时间 marker 会优先落在进行中组，否则落在下一个未来组

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarItemTests`
Expected: FAIL，提示缺少新的 timeline 判定逻辑

**Step 3: Write minimal implementation**

在 `CalendarItem.swift` 增加提醒事项是否具备明确时分的能力；在 `EventListView.swift` 内部加入可测试的 timeline 分组模型和 marker 计算函数。

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarItemTests`
Expected: PASS

**Step 5: Commit**

```bash
git add CalendarPro/Features/Events/CalendarItem.swift CalendarPro/Views/Popover/EventListView.swift CalendarProTests/Events/CalendarItemTests.swift
git commit -m "test(popover): add timeline grouping coverage"
```

### Task 2: 重构 EventListView 为 timeline 布局

**Files:**
- Modify: `CalendarPro/Views/Popover/EventListView.swift`
- Modify: `CalendarPro/Views/Popover/CalendarPopoverView.swift`

**Step 1: Write the failing test**

补充 `CalendarItemTests.swift` 中与 timeline 结构相关的断言，覆盖：
- 同一时间组多项目共用一个时间节点
- today 视图会计算当前时间 marker
- 非 today 视图不会返回 marker

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarItemTests`
Expected: FAIL，结构计算与预期不符

**Step 3: Write minimal implementation**

在 `EventListView.swift`：
- 用 timeline 行替换现有简单卡片列表
- 保留 `ScrollViewReader`
- 为 timed groups 与 untimed groups 分别渲染
- 将当前时间 marker 作为视觉 row/overlay 插入

必要时在 `CalendarPopoverView.swift` 微调事件区摘要文案或边距，适配新的 timeline 信息密度。

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarItemTests`
Expected: PASS

**Step 5: Commit**

```bash
git add CalendarPro/Views/Popover/EventListView.swift CalendarPro/Views/Popover/CalendarPopoverView.swift CalendarProTests/Events/CalendarItemTests.swift
git commit -m "feat(popover): add compact event timeline layout"
```

### Task 3: 扩展卡片状态与当前时间刷新

**Files:**
- Modify: `CalendarPro/Views/Popover/EventCardView.swift`
- Modify: `CalendarPro/Views/Popover/EventListView.swift`
- Test: `CalendarProTests/Events/CalendarItemTests.swift`

**Step 1: Write the failing test**

新增对进行中 / 未来 / 已过去状态计算的断言，确保：
- 进行中事件会被识别
- 过去项目与未来项目状态不会混淆

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/Events/CalendarItemTests`
Expected: FAIL，状态函数尚未实现或结果错误

**Step 3: Write minimal implementation**

在 `EventCardView.swift` 增加状态参数和样式分支；在 `EventListView.swift` 增加分钟级 timer，仅用于刷新当前时间 marker 与进行中状态。

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/Events/CalendarItemTests`
Expected: PASS

**Step 5: Commit**

```bash
git add CalendarPro/Views/Popover/EventCardView.swift CalendarPro/Views/Popover/EventListView.swift CalendarProTests/Events/CalendarItemTests.swift
git commit -m "feat(popover): highlight active timeline items"
```

### Task 4: 构建与回归验证

**Files:**
- Modify: `docs/plans/2026-04-01-popover-event-timeline-design.md`
- Modify: `docs/plans/2026-04-01-popover-event-timeline.md`

**Step 1: Run targeted tests**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarItemTests -only-testing:CalendarProTests/CalendarPopoverViewModelTests`
Expected: PASS

**Step 2: Run build verification**

Run: `xcodebuild -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED

**Step 3: Manual verification checklist**

检查：
- 今天视图中能看到当前时间 marker
- 非今天视图中 marker 不显示
- 带时间提醒出现在 timeline，只有日期的提醒进入未指定时间分组
- 点击事件/提醒后详情交互正常

**Step 4: Commit**

```bash
git add CalendarPro/Views/Popover/EventListView.swift CalendarPro/Views/Popover/EventCardView.swift CalendarPro/Features/Events/CalendarItem.swift CalendarProTests/Events/CalendarItemTests.swift docs/plans/2026-04-01-popover-event-timeline-design.md docs/plans/2026-04-01-popover-event-timeline.md
git commit -m "feat(popover): add current-time event timeline"
```
