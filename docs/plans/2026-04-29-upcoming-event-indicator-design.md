# Upcoming Event Indicator Design

## Overview

当日程或提醒事项即将到来（默认15分钟内）或正在进行时，在菜单栏日期文字右侧显示一个6pt彩色圆点指示器。

## Visual Design

```
普通状态：    4/29 14:30 周三
有即将到来：  4/29 14:30 周三 ●     ← 6px 圆点，用事件日历的颜色
正在进行：    4/29 14:30 周三 ●     ← 同一个圆点，持续显示到事件结束
```

- 圆点大小：6pt 直径
- 位置：文字最右侧，间隔 6px
- 颜色：1个事项取该日历颜色；多个事项取系统 accentColor
- 不做动画，静态实心圆点
- tooltip 追加事项摘要

## Architecture

```
UpcomingEventMonitor (@MainActor, ObservableObject)
  ├─ 订阅 TimeRefreshCoordinator.$currentDate
  ├─ 每分钟查询 EventService 获取今日事件/提醒
  ├─ 过滤出 "即将到来" 或 "正在进行" 的事项
  └─ 发布 @Published var activeIndicator: MenuBarEventIndicator?

MenuBarTextImageRenderer.render()
  └─ 文字右侧绘制 6pt 彩色圆点

StatusBarController.bindViewModel()
  └─ 订阅 indicator 合并到渲染管线
```

## Settings

- `showUpcomingIndicator: Bool` (default: true)
- `upcomingReminderMinutes: Int` (default: 15, options: 5/10/15/30/60)
- 位于 Events 设置页

## Files

- New: `Features/MenuBar/UpcomingEventMonitor.swift`
- Modify: `Features/MenuBar/ClockRenderService.swift` (renderer)
- Modify: `App/StatusBarController.swift`
- Modify: `Settings/MenuBarPreferences.swift`
- Modify: `Settings/SettingsStore.swift`
- Modify: `Views/Settings/EventsSettingsView.swift`
