# Popover Header Balance Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 调整月历弹层头部和底部按钮布局，让年月标题严格居中，并把 `今日` 导航移动到日历顶部附近。

**Architecture:** 在 `MonthHeaderView` 内把头部改为左右控制组加中央标题的分层布局，左右分别承载 `上月 + 休假` 与 `今日 + 下月`。`CalendarPopoverView` 同步移除底部的 `今日` 按钮，保留设置和退出操作。

**Tech Stack:** Swift 6, SwiftUI, XCTest

---

### Task 1: 调整头部控制组顺序与布局方式

**Files:**
- Modify: `CalendarPro/Views/Popover/MonthHeaderView.swift`

**Step 1: 改造头部结构**

- 用 `ZStack` 包住头部。
- 底层 `HStack` 放左右控制组。
- 上层保留年份与月份按钮作为独立居中层。

**Step 2: 左右两侧重新分配按钮**

- 左侧改为上月按钮 + `休假` 胶囊按钮。
- 右侧改为 `今日` 胶囊按钮 + 下月按钮。
- 给 `今日` 复用与 `休假` 一致的胶囊按钮样式。

**Step 3: 保留现有交互能力**

- `休假` 继续复用现有启用态、禁用态与 help 文案。
- `今日` 继续调用现有回到今天动作。
- 上下月按钮的 accessibility identifier 不变。

### Task 2: 更新头部接口与底部导航

**Files:**
- Modify: `CalendarPro/Views/Popover/CalendarPopoverView.swift`

**Step 1: 扩展头部接口**

- 给 `MonthHeaderView` 增加 `onResetToToday` 输入。
- 在 `CalendarPopoverView` 中把现有 `onResetToToday` 继续透传到头部。

**Step 2: 移除底部 Today**

- 删除底部中间的 `今日` 按钮与相关 `Spacer`。
- 保留设置与退出的视觉平衡。
- 保留原有设置和退出快捷键。

### Task 3: 验证

**Files:**
- Verify only

**Step 1: 构建校验**

Run: `xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'`

Expected: BUILD SUCCEEDED

**Step 2: 手动验证**

- 顶部从左到右为 上月、`休假`、标题、`今日`、下月。
- 标题视觉居中。
- `今日` 能回到当天。
- 底部只剩设置和退出。
