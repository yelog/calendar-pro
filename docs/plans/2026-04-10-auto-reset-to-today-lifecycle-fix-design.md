# Calendar Popover 自动回今天生命周期修正设计

## 背景

`2026-04-01-auto-reset-to-today-design.md` 已引入“关闭一段时间后重新打开，自动回到今天”的能力，但实现依赖 `RootPopoverView.onAppear` 和关闭通知转发。实际运行中，popover 关闭后 SwiftUI 视图不一定还能稳定收到关闭事件，导致 `lastClosedTime` 可能没有被记录，重新打开时仍沿用上一次选中的日期。

本次修正同时收紧两个点：

- 自动回今天阈值从 5 分钟缩短为 30 秒
- 由 `PopoverController` 直接管理 popover 打开/关闭时的状态流转

## 目标

- 用户关闭 popover 30 秒内再次打开时，保留上次浏览上下文
- 用户关闭 popover 超过 30 秒再次打开时，自动切回今天所在月份并选中今天
- 避免依赖 SwiftUI 视图是否处于活跃订阅状态来记录关闭时间

## 方案

采用 **PopoverController 持有 CalendarPopoverViewModel** 的方式：

- `PopoverController` 作为 popover 真实生命周期拥有者，直接持有并复用同一个 `CalendarPopoverViewModel`
- 在 `showPopover` 前调用 `viewModel.checkAndResetIfNeeded()`，确保每次显示前先判断是否需要回到今天
- 在 `popoverDidClose` 中直接调用 `viewModel.popoverDidClose()` 记录关闭时间
- `RootPopoverView` 只消费外部注入的 `viewModel`，不再承担关闭通知桥接职责

## 状态流

```text
用户选择其他日期
→ viewModel.selectedDate 更新
→ 关闭 popover
→ PopoverController.popoverDidClose() 记录关闭时间
→ 30 秒后重新打开
→ PopoverController.showPopover() 先检查时间间隔
→ 超时则 resetToToday + selectDate(today)
→ RootPopoverView.onAppear 刷新当天信息和事件
```

## 影响范围

- `CalendarPro/App/PopoverController.swift`
- `CalendarPro/Views/RootPopoverView.swift`
- `CalendarPro/Views/Popover/CalendarPopoverViewModel.swift`
- `CalendarPro/App/AppDelegate.swift`
- `CalendarProTests/CalendarProTests.swift`
- `CalendarProTests/Popover/CalendarPopoverViewModelTests.swift`

## 测试点

1. 关闭后 30 秒内再次打开：不重置，保留原选择
2. 关闭后超过 30 秒再次打开：切回今天并选中今天
3. 控制器层 reopen 行为能够直接驱动重置，不再依赖通知转发
