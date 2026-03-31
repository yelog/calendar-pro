# External Calendar Change Sync Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 监听系统日历/提醒事项的外部变更，自动刷新 App 中的事件数据。

**Architecture:** 在 `EventService` 中注册 `EKEventStoreChanged` 通知监听，收到通知后经 300ms 防抖，刷新日历列表并递增 `@Published storeChangeRevision` 计数器。`RootPopoverView` 通过 `.onChange(of: storeChangeRevision)` 触发已有的 `refreshEventsForCurrentSelection()` 完成刷新。

**Tech Stack:** Swift, EventKit, SwiftUI, Combine, XCTest

---

### Task 1: EventService 添加变更监听

**Files:**
- Modify: `CalendarPro/Features/Events/EventService.swift:7-14`

**Step 1: 添加新属性**

在 `EventService` 类中，`reminderCalendars` 属性之后、`eventStore` 属性之前，添加变更计数器：

```swift
@Published private(set) var storeChangeRevision: Int = 0
```

在 `eventStore` 属性之后，添加防抖任务句柄：

```swift
private var debounceTask: Task<Void, Never>?
```

**Step 2: 添加 init 方法注册通知**

在属性声明之后、`checkAuthorizationStatus()` 方法之前，添加：

```swift
init() {
    NotificationCenter.default.addObserver(
        self,
        selector: #selector(handleStoreChanged),
        name: .EKEventStoreChanged,
        object: eventStore
    )
}
```

**Step 3: 添加通知处理方法**

在 `reminderCalendar(withIdentifier:)` 方法之后（文件末尾 `}` 之前），添加：

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

**Step 4: 编译验证**

Run: `xcodebuild build -scheme CalendarPro -destination 'platform=macOS' -quiet`
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add CalendarPro/Features/Events/EventService.swift
git commit -m "feat(events): listen to EKEventStoreChanged for external calendar changes"
```

---

### Task 2: RootPopoverView 响应变更信号

**Files:**
- Modify: `CalendarPro/Views/RootPopoverView.swift:92-97`

**Step 1: 添加 `.onChange` 修饰符**

在 `RootPopoverView.swift` 中，`.onChange(of: settingsStore.menuBarPreferences.enabledReminderCalendarIDs)` 代码块之后、`.onChange(of: viewModel.selectedDate)` 代码块之前，添加：

```swift
.onChange(of: eventService.storeChangeRevision) { _, _ in
    refreshEventsForCurrentSelection()
}
```

**Step 2: 编译验证**

Run: `xcodebuild build -scheme CalendarPro -destination 'platform=macOS' -quiet`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add CalendarPro/Views/RootPopoverView.swift
git commit -m "feat(events): refresh event list on external calendar store changes"
```

---

### Task 3: 添加单元测试

**Files:**
- Modify: `CalendarProTests/Events/EventServiceTests.swift`

**Step 1: 添加初始值测试**

在 `EventServiceTests` 类中，`testIsAuthorizedInitiallyFalse()` 方法之后，添加：

```swift
func testStoreChangeRevisionInitiallyZero() {
    let service = EventService()
    XCTAssertEqual(service.storeChangeRevision, 0)
}
```

**Step 2: 添加通知响应测试**

在上述方法之后，添加：

```swift
func testStoreChangeRevisionIncrementsOnNotification() async {
    let service = EventService()
    
    NotificationCenter.default.post(
        name: .EKEventStoreChanged,
        object: nil
    )
    
    // Wait for debounce (300ms) + margin
    try? await Task.sleep(for: .milliseconds(500))
    
    XCTAssertEqual(service.storeChangeRevision, 1)
}
```

**Step 3: 运行测试**

Run: `xcodebuild test -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/EventServiceTests -quiet`
Expected: All tests passed

**Step 4: Commit**

```bash
git add CalendarProTests/Events/EventServiceTests.swift
git commit -m "test(events): add tests for EKEventStoreChanged notification handling"
```

---

### Task 4: 手动验证

**验证步骤：**

1. 运行 App，打开 Popover，确认当天事件列表显示正常
2. 打开 macOS 系统日历 App，在当天新增一个事件
3. 观察 Popover 中的事件列表是否在约 0.5 秒内自动更新显示新事件
4. 在系统日历 App 中删除该事件，确认 Popover 自动移除
5. 打开系统提醒事项 App，新增一个今天截止的提醒，确认 Popover 自动显示
6. 关闭 Popover，在系统日历中修改事件，重新打开 Popover，确认显示最新数据
