# 日程列表功能设计

## 目标

在日历 Popover 中显示 Apple Calendar 日程，支持：

- 点击日期显示当天日程列表
- 所有已配置日历（iCloud、Google、Exchange 等）
- 设置中可关闭日程显示
- 各日历单独开关控制

---

## UI 结构

### CalendarPopoverView 调整

```
├── MonthHeaderView（月份导航）
├── CalendarGridView（日历网格） ← 点击日期触发选中
├── EventListView（日程列表） ← 新增，条件显示
├── regionSummary
├── Divider
└── 底部按钮栏（设置、今日、退出）
```

**Popover 高度动态调整**：

- 无日程/关闭时：400px（保持现状）
- 有日程时：520-580px（自动扩展）

---

### 日程卡片样式

简洁卡片式设计：

```
┌─────────────────────────────────────┐
│ ● 09:00-10:30                       │
│   产品评审会议                        │
│   📂 工作                            │
└─────────────────────────────────────┘
```

- 圆角卡片：背景色 `Color(nsColor: .controlBackgroundColor)`
- 颜色标识：圆点使用日历原色 (EKCalendar.color)
- 时间显示：全天事件显示"全天"
- 日历名称：灰色小字，可选显示

---

## 设置项

在 `MenuBarSettingsView` 新增 "日历日程" GroupBox：

| 设置项   | 类型     | 说明                          |
| -------- | -------- | ----------------------------- |
| 显示日程 | Toggle   | 总开关，关闭后不请求 EventKit |
| 日历选择 | 多选列表 | 各日历单独开关                |

---

## 数据模型

### MenuBarPreferences 新增字段

```swift
struct MenuBarPreferences: Codable, Equatable {
    // 现有字段...

    // 新增
    var showEvents: Bool  // 日程总开关
    var enabledCalendarIDs: [String]  // 启用的日历 ID 列表
}
```

### EventService

封装 EventKit 访问：

```swift
final class EventService: ObservableObject {
    @Published var authorizationStatus: EKAuthorizationStatus
    @Published var calendars: [EKCalendar]

    func requestAccess() async -> Bool
    func fetchEvents(for date: Date) -> [EKEvent]
    func refreshCalendars()
}
```

---

## 权限处理

- Info.plist 添加 `NSCalendarsUsageDescription` = "用于显示您的日历日程"
- 首次打开日程功能时弹出系统权限对话框
- 拒绝权限时显示提示："请在系统设置中允许访问日历"

---

## 文件新增/修改

| 文件                             | 操作 | 说明                   |
| -------------------------------- | ---- | ---------------------- |
| `Info.plist`                     | 修改 | 添加权限描述           |
| `MenuBarPreferences.swift`       | 修改 | 添加日程配置字段       |
| `SettingsStore.swift`            | 修改 | 添加日程配置方法       |
| `EventService.swift`             | 新增 | EventKit 封装          |
| `EventListView.swift`            | 新增 | 日程列表 UI            |
| `EventCardView.swift`            | 新增 | 单个日程卡片           |
| `CalendarPopoverViewModel.swift` | 修改 | 添加 selectedDate 状态 |
| `CalendarPopoverView.swift`      | 修改 | 集成日程列表           |
| `CalendarGridView.swift`         | 修改 | 点击日期交互           |
| `MenuBarSettingsView.swift`      | 修改 | 日程设置 UI            |
| `RootPopoverView.swift`          | 修改 | 集成 EventService      |
