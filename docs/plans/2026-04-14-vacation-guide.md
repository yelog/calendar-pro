# Vacation Guide Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为中国大陆地区新增基于法定假日、周末和调休规则的年度休假建议功能。

**Architecture:** 在现有 holiday provider 与 resolver 基础上新增 `VacationPlanningService`，生成结构化的 `VacationOpportunity` 数据；UI 通过 popover 入口打开独立浮层窗口展示建议卡片，并支持跳回月历定位。功能仅对 `mainland-cn` 生效，依赖已启用的法定节假日数据。

**Tech Stack:** Swift 6, SwiftUI, AppKit `NSPanel`, XCTest

---

### Task 1: 定义休假规划领域模型

**Files:**
- Create: `CalendarPro/Features/VacationPlanning/VacationOpportunity.swift`
- Test: `CalendarProTests/VacationPlanning/VacationPlanningServiceTests.swift`

### Task 2: 实现休假建议算法

**Files:**
- Create: `CalendarPro/Features/VacationPlanning/VacationPlanningService.swift`
- Modify: `CalendarPro/Features/Holidays/HolidayResolver.swift`
- Test: `CalendarProTests/VacationPlanning/VacationPlanningServiceTests.swift`

### Task 3: 构建休假建议窗口与卡片

**Files:**
- Create: `CalendarPro/Views/Popover/VacationGuideWindowView.swift`
- Create: `CalendarPro/Views/Popover/VacationOpportunityCardView.swift`
- Create: `CalendarPro/App/VacationGuideWindowController.swift`

补充要求：
- 列表按节日时间顺序展示
- 窗口高度在可视区域内尽量向下撑满
- 与事件/提醒详情窗口互斥
- 窗口打开时自动滚动到 popover 当前月份对应的建议，没有则滚动到之后最近的一条

### Task 4: 接入 popover 入口与月历定位

**Files:**
- Modify: `CalendarPro/Views/Popover/MonthHeaderView.swift`
- Modify: `CalendarPro/Views/Popover/CalendarPopoverView.swift`
- Modify: `CalendarPro/Views/Popover/CalendarPopoverViewModel.swift`
- Modify: `CalendarPro/Views/RootPopoverView.swift`
- Modify: `CalendarPro/App/AppDelegate.swift`
- Test: `CalendarProTests/Popover/CalendarPopoverViewModelTests.swift`

### Task 5: 增加可用性判断与空状态

**Files:**
- Modify: `CalendarPro/Infrastructure/LocaleFeatureAvailability.swift`
- Modify: `CalendarPro/Settings/RegionSettingsViewModel.swift`
- Modify: `CalendarPro/Views/Popover/VacationGuideWindowView.swift`

### Task 6: 验证

**Files:**
- Verify only

Run:
- `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/VacationPlanningServiceTests -only-testing:CalendarProTests/Popover/CalendarPopoverViewModelTests`
- `xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'`
