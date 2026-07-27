# Pomodoro Popover Statistics Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 在菜单栏日历面板的番茄时钟左侧增加可发现的统计入口，让用户不离开当前上下文即可查看今日成果与近 7 日节奏。

**Architecture:** 复用现有 `PomodoroStatsStore` 作为唯一数据源，经 `StatusBarController` 和 `PopoverController` 注入独立统计窗口。`PomodoroStatisticsWindowController` 复用天气详情窗口的 AppKit 浮层与定位模式，`PomodoroStripView` 只提供入口，不新增追踪字段或第二套持久化。

**Tech Stack:** Swift 6、SwiftUI、Combine、XCTest、macOS AppKit 菜单栏弹层。

---

## 产品与体验决策

- 核心场景：用户在准备开始、暂停间隙或结束一轮后，快速确认“今天完成多少、投入多久、最近是否稳定”。
- 入口：将左侧阶段图标变成按钮，并加轻量展开指示；保留番茄/火焰/叶子语义，不抢夺主操作按钮注意力。
- 信息优先级：第一层展示今日完成数、今日专注分钟；第二层用 7 根短柱展示近 7 日节奏，并给出 7 日完成率。
- 展开方式：打开独立 `NSPanel`，默认定位在日历弹层左侧；下拉面板自身尺寸与内容完全不变。
- 空状态：所有数值显示为 0，柱图保留轨道，让用户理解这里会随使用积累，而不是显示空白页面。
- 视觉：沿用当前圆角、语义色与系统字体；数字使用等宽字形；统计区使用弱分隔面，不叠加厚重卡片。
- 可访问性：入口具有按钮语义、展开状态、提示和稳定标识；图表对 VoiceOver 提供摘要，不逐柱制造噪音。

### Task 1: 打通统计数据注入

**Files:**
- Modify: `CalendarPro/App/StatusBarController.swift`
- Modify: `CalendarPro/App/PopoverController.swift`
- Modify: `CalendarPro/App/AppDelegate.swift`
- Modify: `CalendarPro/Views/RootPopoverView.swift`
- Modify: `CalendarPro/Views/Popover/CalendarPopoverView.swift`

**Steps:**
1. 给 `PopoverController` 增加 `PomodoroStatsStore` 依赖并保存。
2. 从正式应用与 UI 测试入口传入同一统计存储。
3. 将存储传到 `CalendarPopoverView`，确保数据发布后界面自动更新。
4. 构建工程，确认所有初始化点完整。

### Task 2: 实现独立统计窗口

**Files:**
- Create: `CalendarPro/App/PomodoroStatisticsWindowController.swift`
- Create: `CalendarPro/Views/Popover/PomodoroStatisticsWindowView.swift`
- Modify: `CalendarPro/Views/Popover/PomodoroStripView.swift`

**Steps:**
1. 将左侧阶段徽章改为无边框按钮，增加展开指示和辅助功能属性。
2. 新增独立无标题栏浮动窗口，展示今日双指标、7 日柱图和完成率摘要。
3. 复用详情窗口定位算法，优先显示在下拉面板左侧，屏幕空间不足时自动调整。
4. 为入口和统计区增加 UI 测试标识。

### Task 3: 测试与验证

**Files:**
- Test: `CalendarProTests/Pomodoro/PomodoroStatsStoreTests.swift`

**Steps:**
1. 增加近 7 日统计摘要测试，锁定弹层依赖的完成数、分钟和完成率。
2. 运行 Pomodoro 单元测试。
3. 运行 macOS 工程构建。
4. 手动检查亮/暗色、空数据、计时中、暂停和休息阶段的展开布局。
