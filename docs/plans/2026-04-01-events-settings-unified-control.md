# Events Settings Unified Control Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 重构“日程”设置页为“一个总开关 + 两个数据源子开关”，并让面板加载逻辑与新的设置层级保持一致。

**Architecture:** 保持 `SettingsStore -> MenuBarPreferences -> RootPopoverView/EventService` 的现有数据流，只新增一个 `showCalendarEvents` 子开关字段，并把 `showEvents` 明确为整个日程模块总开关。设置页 `EventsSettingsView` 改成单区块分层布局，面板加载逻辑按总开关与子开关分别决定是否加载日历和提醒事项。

**Tech Stack:** SwiftUI, EventKit, Foundation Codable, XCTest, xcodebuild

---

### Task 1: 为新增日历子开关建立可迁移的偏好模型

**Files:**
- Modify: `CalendarPro/Settings/MenuBarPreferences.swift`
- Modify: `CalendarPro/Settings/SettingsStore.swift`
- Test: `CalendarProTests/Settings/MenuBarPreferencesTests.swift`
- Test: `CalendarProTests/Settings/SettingsStoreTests.swift`

**Step 1: Write the failing test**

在 `CalendarProTests/Settings/MenuBarPreferencesTests.swift` 添加断言，覆盖：
- `MenuBarPreferences.default.showCalendarEvents == true`
- 旧版不含 `showCalendarEvents` 的 JSON 仍可成功解码
- 旧版 JSON 解码后，`showCalendarEvents` 默认回落到 `showEvents`

在 `CalendarProTests/Settings/SettingsStoreTests.swift` 添加断言，覆盖：
- `setShowCalendarEvents(false)` 只关闭日历子开关，不改写 `showEvents`
- 关闭再开启 `showEvents` 后，`showCalendarEvents` 与来源列表仍保留原值

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/MenuBarPreferencesTests -only-testing:CalendarProTests/SettingsStoreTests`
Expected: FAIL，提示缺少 `showCalendarEvents` 字段、迁移逻辑或 store setter。

**Step 3: Write minimal implementation**

在 `MenuBarPreferences.swift`：

```swift
var showCalendarEvents: Bool

private enum CodingKeys: String, CodingKey {
    case tokens, separator, showLunarInMenuBar, activeRegionIDs, enabledHolidayIDs, weekStart
    case showEvents, showCalendarEvents, enabledCalendarIDs, showReminders, enabledReminderCalendarIDs
}

init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    showEvents = try container.decode(Bool.self, forKey: .showEvents)
    showCalendarEvents = try container.decodeIfPresent(Bool.self, forKey: .showCalendarEvents) ?? showEvents
    ...
}
```

在 `SettingsStore.swift` 增加：

```swift
func setShowCalendarEvents(_ enabled: Bool) {
    var prefs = menuBarPreferences
    prefs.showCalendarEvents = enabled
    menuBarPreferences = prefs
    persistMenuBarPreferences()
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/MenuBarPreferencesTests -only-testing:CalendarProTests/SettingsStoreTests`
Expected: PASS

**Step 5: Commit**

```bash
git add CalendarPro/Settings/MenuBarPreferences.swift CalendarPro/Settings/SettingsStore.swift CalendarProTests/Settings/MenuBarPreferencesTests.swift CalendarProTests/Settings/SettingsStoreTests.swift
git commit -m "feat(settings): add calendar source toggle state"
```

### Task 2: 重构设置页为单区块分层布局

**Files:**
- Modify: `CalendarPro/Views/Settings/EventsSettingsView.swift`
- Modify: `CalendarPro/Views/Settings/GeneralSettingsView.swift`

**Step 1: Write the failing test**

补充或新增针对文案计算的断言，覆盖：
- 总开关关闭时摘要为 `日程已关闭`
- 两个子开关都关闭时摘要为 `未启用任何日程来源`
- 其他组合返回 `日历开 / 提醒关` 这类层级化摘要

如果当前没有视图测试，先把摘要逻辑提取为可单测的私有辅助函数或计算属性，再为其建立测试入口。

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/SettingsStoreTests -only-testing:CalendarProTests/MenuBarPreferencesTests`
Expected: FAIL，摘要文案或新状态组合未覆盖。

**Step 3: Write minimal implementation**

在 `EventsSettingsView.swift`：
- 删除两个并列 `GroupBox`
- 改为一个 `GroupBox("日程")`
- 顶部放置 `Toggle("在面板中显示日程", isOn: showEventsBinding)`
- 在总开关开启后展示两个子 section：

```swift
Toggle("包含日历日程", isOn: showCalendarEventsBinding)
if store.menuBarPreferences.showCalendarEvents {
    calendarSourcesList
}

Toggle("包含提醒事项", isOn: showRemindersBinding)
if store.menuBarPreferences.showReminders {
    reminderSourcesList
}
```

在 `GeneralSettingsView.swift` 把摘要逻辑改成：

```swift
if !prefs.showEvents { return "日程已关闭" }
if !prefs.showCalendarEvents && !prefs.showReminders { return "未启用任何日程来源" }
return "\(calendarText) / \(reminderText)"
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/SettingsStoreTests -only-testing:CalendarProTests/MenuBarPreferencesTests`
Expected: PASS

**Step 5: Commit**

```bash
git add CalendarPro/Views/Settings/EventsSettingsView.swift CalendarPro/Views/Settings/GeneralSettingsView.swift CalendarProTests/Settings/MenuBarPreferencesTests.swift CalendarProTests/Settings/SettingsStoreTests.swift
git commit -m "refactor(settings): unify events source controls"
```

### Task 3: 让面板加载逻辑遵循总开关与子开关

**Files:**
- Modify: `CalendarPro/Features/Events/EventService.swift`
- Modify: `CalendarPro/Views/RootPopoverView.swift`
- Modify: `CalendarPro/Views/Popover/CalendarPopoverView.swift`
- Modify: `CalendarPro/Views/Popover/EventListView.swift`
- Test: `CalendarProTests/Settings/SettingsStoreTests.swift`

**Step 1: Write the failing test**

为新的加载分支补充断言，至少覆盖：
- `showEvents == false` 时清空列表
- `showEvents == true && showCalendarEvents == false && showReminders == false` 时显示“未启用任何日程来源”
- 仅开启提醒事项时，面板摘要不再落入“当天无日程”

如果缺少直接视图测试，先把面板摘要文案提取到可测试函数，并为函数写断言。

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/MenuBarPreferencesTests -only-testing:CalendarProTests/SettingsStoreTests`
Expected: FAIL，加载逻辑或文案分支仍基于旧模型。

**Step 3: Write minimal implementation**

在 `EventService.swift` 把接口扩展为：

```swift
func fetchCalendarItems(
    for date: Date,
    enabledCalendarIDs: [String],
    enabledReminderCalendarIDs: [String],
    showCalendarEvents: Bool,
    showReminders: Bool
) async -> [CalendarItem]
```

并在内部按子开关分别追加数据。  
在 `RootPopoverView.swift`：
- 监听 `showCalendarEvents` 变化
- 调用 `fetchCalendarItems(... showCalendarEvents: ..., showReminders: ...)`
- 仅当总开关 `showEvents` 为 `false` 时直接清空

在 `CalendarPopoverView.swift` 或 `EventListView.swift` 引入空状态文案：

```swift
if showEventsEnabled && !showCalendarEvents && !showReminders {
    return "未启用任何日程来源"
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/MenuBarPreferencesTests -only-testing:CalendarProTests/SettingsStoreTests -only-testing:CalendarProTests/CalendarItemTests`
Expected: PASS

**Step 5: Commit**

```bash
git add CalendarPro/Features/Events/EventService.swift CalendarPro/Views/RootPopoverView.swift CalendarPro/Views/Popover/CalendarPopoverView.swift CalendarPro/Views/Popover/EventListView.swift CalendarProTests/Settings/MenuBarPreferencesTests.swift CalendarProTests/Settings/SettingsStoreTests.swift CalendarProTests/Events/CalendarItemTests.swift
git commit -m "feat(popover): respect unified events source toggles"
```

### Task 4: 完整验证并收尾

**Files:**
- Modify: `docs/plans/2026-04-01-events-settings-unified-control-design.md`
- Modify: `docs/plans/2026-04-01-events-settings-unified-control.md`

**Step 1: Run targeted tests**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/MenuBarPreferencesTests -only-testing:CalendarProTests/SettingsStoreTests -only-testing:CalendarProTests/CalendarItemTests`
Expected: PASS

**Step 2: Run build verification**

Run: `xcodebuild -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED

**Step 3: Manual verification checklist**

检查：
- 设置页只剩一个“日程”主区块
- 关闭“在面板中显示日程”后，重新打开时子开关与来源选择仍保留
- 只勾选“包含提醒事项”时，面板能显示提醒事项且摘要正确
- 两个子开关都关闭时，面板显示“未启用任何日程来源”
- 权限未授权时，权限提示仍在对应子区块内显示

**Step 4: Commit**

```bash
git add CalendarPro/Settings/MenuBarPreferences.swift CalendarPro/Settings/SettingsStore.swift CalendarPro/Views/Settings/EventsSettingsView.swift CalendarPro/Views/Settings/GeneralSettingsView.swift CalendarPro/Views/RootPopoverView.swift CalendarPro/Views/Popover/CalendarPopoverView.swift CalendarPro/Views/Popover/EventListView.swift CalendarPro/Features/Events/EventService.swift CalendarProTests/Settings/MenuBarPreferencesTests.swift CalendarProTests/Settings/SettingsStoreTests.swift CalendarProTests/Events/CalendarItemTests.swift docs/plans/2026-04-01-events-settings-unified-control-design.md docs/plans/2026-04-01-events-settings-unified-control.md
git commit -m "feat(settings): unify events visibility controls"
```
