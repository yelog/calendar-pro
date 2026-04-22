# 统一时间刷新需求分析

**日期：** 2026-04-21

## 目标

统一菜单栏时间、弹层当前时间线、今日高亮等“现在”语义的时间来源和刷新调度，减少分钟显示滞后、睡眠唤醒后不及时刷新、多个视图各自维护 timer 带来的漂移风险。

## 当前问题

1. 菜单栏分钟模式只在首次启动时对齐整分钟，随后使用固定 60 秒重复 timer。若主线程卡顿或睡眠唤醒导致某次触发延迟，后续刷新可能持续偏离整分钟边界。
2. 弹层日程时间线在视图出现时启动 60 秒 timer，没有对齐整分钟。若用户在 `10:20:45` 打开弹层，下一次刷新可能到 `10:21:45`，当前时间标记最坏会慢接近一分钟。
3. 菜单栏已经监听系统时钟、时区、跨天变化，但没有显式覆盖睡眠唤醒、桌面会话重新激活、应用重新激活场景。
4. 菜单栏、弹层、月历今日高亮分别从 `Date()` 或本地状态取时间，逻辑分散，后续修复容易遗漏。

## 设计

新增共享 `TimeRefreshCoordinator`，作为应用内“当前时间”协调器：

- 暴露 `currentDate`，供菜单栏、弹层和月历派生展示状态。
- 支持 `.minute` 与 `.second` 刷新粒度。菜单栏开启秒显示时提升到秒级，否则使用分钟级。
- 分钟级刷新不使用固定 60 秒重复 timer，而是每次触发后重新计算下一次整分钟边界。
- 监听系统时钟变化、时区变化、跨天、应用激活、睡眠唤醒、桌面会话激活，收到事件后立即刷新 `currentDate` 并重排下一次定时器。
- 保留依赖注入能力，测试可注入固定 `now`、独立 `NotificationCenter`。

## 数据流

```text
TimeRefreshCoordinator.currentDate
→ MenuBarViewModel 渲染菜单栏文本
→ RootPopoverView 计算今天、选中今天、月历网格高亮
→ EventListView 计算当前时间 marker 与事件状态
```

## 非目标

- 不引入网络校时，准确性仍以 macOS 系统时间为准。
- 不新增用户设置项。
- 不改变 EventKit 拉取策略；时间线刷新只刷新本地视觉状态。

## 验证

- 单测覆盖分钟边界 delay、系统时间通知刷新、唤醒通知刷新。
- 菜单栏现有刷新粒度与系统时钟变化测试继续通过。
- 弹层 ViewModel 与日程 item 相关测试继续通过。
- 运行跳过 UI 测试的全量单元测试：`xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -skip-testing:CalendarProUITests`。
