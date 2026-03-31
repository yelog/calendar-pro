# External Calendar Change Sync Design

## Overview

监听系统日历/提醒事项的外部变更（如用户在 Apple Calendar 或 Reminders 中增删改事件），自动刷新 App 中显示的事件数据。

## Problem

当前 App 仅在以下时机获取事件数据：
- Popover 打开时 (`.onAppear`)
- 用户切换选中日期时
- 用户更改设置（显示开关、启用的日历）时

如果用户在 Apple Calendar/Reminders 中修改了事件，App 不会自动感知，必须重新打开 Popover 或重新选择日期才能看到变化。

## Solution

在 `EventService` 中监听 `EKEventStoreChanged` 通知，通过 `@Published` revision 计数器通知上层 View 刷新。

## Architecture

### Approach: EventService 内部监听 + Publisher 通知

选择此方案的理由：
1. `EventService` 已是 EventKit 的唯一网关，监听 EventKit 通知是自然的职责延伸
2. 改动最小（~20 行），完全复用现有的 `@ObservedObject` + `.onChange` 模式
3. 不引入新的单例、通信机制或依赖注入路径

### Data Flow

```
EKEventStoreChanged (系统通知)
  → EventService.handleStoreChanged()
    → 300ms debounce
      → fetchCalendars() + fetchReminderCalendars()
      → storeChangeRevision += 1
        → RootPopoverView .onChange(of: storeChangeRevision)
          → refreshEventsForCurrentSelection()
```

## Changes

### 1. EventService.swift

**新增属性：**
- `@Published private(set) var storeChangeRevision: Int = 0` — 外部变更计数器，每次递增触发 SwiftUI 响应
- `private var debounceTask: Task<Void, Never>?` — 防抖任务句柄

**新增 init：**
```swift
override init() {
    super.init()
    NotificationCenter.default.addObserver(
        self,
        selector: #selector(handleStoreChanged),
        name: .EKEventStoreChanged,
        object: eventStore
    )
}
```

**新增方法：**
```swift
@objc private func handleStoreChanged(_ notification: Notification) {
    debounceTask?.cancel()
    debounceTask = Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        fetchCalendars()
        fetchReminderCalendars()
        storeChangeRevision += 1
    }
}
```

**设计要点：**
- 300ms 防抖：`EKEventStoreChanged` 可能短时间内连续触发多次（批量操作），避免重复刷新
- `object: eventStore` 确保只监听本 App 关联的 store 变更
- 通知触发时同步刷新日历列表（日历可能被新增/删除）
- revision 递增后，SwiftUI 响应式机制自动通知所有观察者

### 2. RootPopoverView.swift

**新增 `.onChange` 修饰符：**
```swift
.onChange(of: eventService.storeChangeRevision) { _ in
    refreshEventsForCurrentSelection()
}
```

**设计要点：**
- 完全复用现有的 `refreshEventsForCurrentSelection()` 方法
- Popover 未打开时 `RootPopoverView` 不在视图树中，不会触发无意义刷新
- 下次打开 Popover 时 `.onAppear` 会自动拉取最新数据

## Edge Cases

1. **Popover 未打开时收到变更通知**：`storeChangeRevision` 在 `EventService` 中递增，但 `RootPopoverView` 不存在，`.onChange` 不触发。下次 `.onAppear` 时会全量刷新，数据仍然最新。
2. **短时间内多次变更**：300ms 防抖合并为一次刷新。
3. **selectedDate 为 nil**：`refreshEventsForCurrentSelection` 内部已有保护逻辑，不会发起无效请求。
4. **日历被删除**：`fetchCalendars()` / `fetchReminderCalendars()` 会刷新日历列表，已删除的日历不再返回，后续 `fetchCalendarItems` 自然过滤。

## Not In Scope

- 定时轮询机制（不需要，`EKEventStoreChanged` 已覆盖所有外部变更场景）
- 跨天自动刷新（`NSCalendarDayChanged` 相关，属于独立改进点）
- 事件数据持久缓存（当前按需获取模式已足够）
- 变更 diff 粒度（`EKEventStoreChanged` 不提供具体变更内容，全量刷新是唯一选择）
