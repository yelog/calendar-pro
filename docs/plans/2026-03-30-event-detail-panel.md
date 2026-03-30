# 日程详情侧边面板 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 在日历 Popover 中点击某条日程时，于左侧展开详情面板并展示该日程的详细信息。

**Architecture:** 保持现有 `NSPopover` 容器不变，在 SwiftUI 视图层实现一个按选中状态切换的双栏布局；由 `CalendarPopoverViewModel` 增加日程选择状态，`RootPopoverView` 负责在日期切换和事件刷新时同步清理失效选择。

**Tech Stack:** SwiftUI, AppKit, EventKit, XCTest

---

### Task 1: 扩展 Popover 状态模型

**Files:**

- Modify: `CalendarPro/Views/Popover/CalendarPopoverViewModel.swift`
- Test: `CalendarProTests/Popover/CalendarPopoverViewModelTests.swift`

**Step 1: 写失败测试**

- 为 view model 增加日程选择和清空测试
- 为切换日期时清理已选日程增加测试

**Step 2: 实现状态**

- 新增 `selectedEventIdentifier`
- 新增 `selectEvent(identifier:)`
- 新增 `clearSelectedEvent()`
- 在 `selectDate(_:)` 内清理当前日程选择

**Step 3: 运行测试**

- 运行 `CalendarPopoverViewModelTests`

### Task 2: 让根视图协调详情开关

**Files:**

- Modify: `CalendarPro/Views/RootPopoverView.swift`

**Step 1: 统一事件加载入口**

- 避免 `selectedDate` 改变时重复触发事件加载
- 让日期切换和“今日”操作都通过同一条状态链路刷新

**Step 2: 管理选中日程失效**

- 基于 `selectedEventIdentifier` 找到当前选中日程
- 当刷新后列表中不再包含该日程时，自动关闭详情面板
- 在关闭日程展示或无权限时清空详情状态

### Task 3: 实现左右双栏 UI

**Files:**

- Modify: `CalendarPro/Views/Popover/CalendarPopoverView.swift`

**Step 1: 改造布局**

- 用 `HStack` 承载左侧详情面板和右侧主内容
- 在有选中日程时扩大视图宽度

**Step 2: 实现详情面板**

- 展示标题、时间、日历、地点、备注
- 加入关闭按钮和空状态
- 保持视觉上与主面板有明确分层

**Step 3: 处理尺寸**

- 给主面板和详情面板固定宽度
- 让 HostingController 使用 SwiftUI 的首选内容尺寸

### Task 4: 让列表支持点击与高亮

**Files:**

- Modify: `CalendarPro/Views/Popover/EventListView.swift`
- Modify: `CalendarPro/Views/Popover/EventCardView.swift`

**Step 1: 增加点击能力**

- 给列表增加 `onSelectEvent`
- 为每条日程生成稳定的选择 ID

**Step 2: 增加选中样式**

- 当前选中卡片展示更强的背景和描边
- 增加轻量的“查看详情”视觉提示

### Task 5: 验证

**Files:**

- Modify: `CalendarPro/App/PopoverController.swift`
- Modify: `CalendarPro/App/AppDelegate.swift`

**Step 1: 接入自适应尺寸**

- 为 `NSHostingController` 开启 `preferredContentSize` 同步
- 保证真实 Popover 至少能响应宽度变化

**Step 2: 执行测试**

- 运行 `CalendarPopoverViewModelTests`
- 运行 `CalendarProTests`
- 如本地环境允许，再跑一次完整 macOS 测试目标
