# Calendar Popover 自动回到今天功能设计

## 需求概述

当 calendar 下拉窗口关闭超过 5 分钟后，用户再次打开时，将自动回到今天的日期视图，并选中今天的日期。

## 核心流程

```
Popover 关闭 → 记录关闭时间 → Popover 打开 → 检查时间间隔 → 超过5分钟 → 重置到今天
```

## 架构设计

### 方案选择

采用 **ViewModel 管理时间状态** 的方案：

- CalendarPopoverViewModel 记录和管理关闭时间
- PopoverController 发送关闭通知
- RootPopoverView 监听通知并在 onAppear 检查
- 逻辑集中在 ViewModel，符合 MVVM 模式

### 模块职责

#### PopoverController
- 在 `popoverDidClose` 时发送通知 `PopoverDidCloseNotification`

#### RootPopoverView
- 监听 `PopoverDidCloseNotification`
- 将关闭事件传递给 ViewModel
- 在 `onAppear` 时调用 ViewModel 的检查方法

#### CalendarPopoverViewModel
- 维护 `lastClosedTime: Date?` 状态
- 提供 `popoverDidClose()` 方法记录关闭时间
- 提供 `checkAndResetIfNeeded()` 方法检查时间间隔并重置

## 实现细节

### 1. CalendarPopoverViewModel 新增

```swift
@Published private(set) var lastClosedTime: Date?

func popoverDidClose() {
    lastClosedTime = Date()
}

func checkAndResetIfNeeded() {
    guard let closedTime = lastClosedTime else { return }
    let interval = Date().timeIntervalSince(closedTime)
    if interval > 300 { // 5分钟 = 300秒
        resetToToday()
        selectDate(Date())
        lastClosedTime = nil
    }
}
```

### 2. PopoverController 新增

```swift
extension Notification.Name {
    static let PopoverDidCloseNotification = Notification.Name("PopoverDidCloseNotification")
}

func popoverDidClose(_ notification: Notification) {
    interactionMonitor.stop()
    NotificationCenter.default.post(name: .PopoverDidCloseNotification, object: nil)
}
```

### 3. RootPopoverView 新增监听

```swift
.onReceive(NotificationCenter.default.publisher(for: .PopoverDidCloseNotification)) { _ in
    viewModel.popoverDidClose()
}
```

在 `onAppear` 中调用：
```swift
.onAppear {
    viewModel.checkAndResetIfNeeded()
    // ... 现有逻辑
}
```

## 边界情况

1. **首次打开**：`lastClosedTime` 为 nil，不会重置
2. **5分钟内打开**：不重置，保留上次位置
3. **超过5分钟打开**：重置到今天并选中
4. **跨天场景**：超过5分钟必然包含跨天，重置逻辑自然生效

## 测试要点

1. 关闭后立即打开（<5分钟）：不重置
2. 关闭后等待超过5分钟再打开：重置到今天
3. 首次启动：不触发重置
4. 重置后选中今天的日期并加载日程