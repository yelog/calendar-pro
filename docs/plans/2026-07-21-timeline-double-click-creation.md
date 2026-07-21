# Timeline Double-Click Creation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 让用户在下拉日程时间线空白区域双击时，以点击位置对应的半小时区间打开日程/提醒事项创建器。

**Architecture:** 在 `EventListView` 中用可测试的纯逻辑把手势纵坐标转换为半小时时间范围，再通过 `CalendarPopoverView` 和 `RootPopoverView` 的现有单向回调链传给详情窗口控制器。创建器的创建模式携带可选时间范围，时间线入口覆盖日程起止时间和提醒到期时间，顶部“+”入口继续使用原默认值。

**Tech Stack:** Swift 6、SwiftUI、AppKit、EventKit、XCTest、Xcode 16/macOS 14+

---

### Task 1: 建立半小时时间槽模型

**Files:**
- Modify: `CalendarPro/Features/Events/EventService.swift`
- Modify: `CalendarPro/Views/Popover/EventListView.swift`
- Test: `CalendarProTests/Events/CalendarItemTests.swift`

**Step 1: Write the failing tests**

在 `CalendarItemTests` 增加固定 UTC 日历用例，验证纵坐标 `620` 得到 `10:00–10:30`、`640` 得到 `10:30–11:00`、精确 `630` 进入后半区，并验证负坐标、全天高度以外坐标以及 `23:30–次日 00:00`。

**Step 2: Run tests to verify they fail**

Run:

```bash
xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarItemTests
```

Expected: FAIL，提示 `CalendarItemCreationTimeRange` 或 `EventTimelineCreationSlot` 不存在。

**Step 3: Implement the minimal model**

在 `EventService.swift` 增加领域值对象：

```swift
struct CalendarItemCreationTimeRange: Equatable {
    let startDate: Date
    let endDate: Date
}
```

在 `EventListView.swift` 增加内部计算器：

```swift
struct EventTimelineCreationSlot {
    static let durationMinutes = 30

    static func make(
        yPosition: CGFloat,
        selectedDate: Date,
        pointsPerMinute: CGFloat,
        calendar: Calendar
    ) -> CalendarItemCreationTimeRange? {
        guard pointsPerMinute > 0 else { return nil }
        let rawMinute = Int(floor(yPosition / pointsPerMinute))
        let minute = min(max(rawMinute, 0), EventDayTimelineLayout.minutesPerDay - 1)
        let slotStartMinute = (minute / durationMinutes) * durationMinutes
        let dayStart = calendar.startOfDay(for: selectedDate)
        guard let startDate = calendar.date(byAdding: .minute, value: slotStartMinute, to: dayStart),
              let endDate = calendar.date(byAdding: .minute, value: durationMinutes, to: startDate) else {
            return nil
        }
        return CalendarItemCreationTimeRange(startDate: startDate, endDate: endDate)
    }
}
```

**Step 4: Run tests to verify they pass**

重复 Task 1 Step 2 命令。Expected: PASS。

### Task 2: 让创建器接收精确初始时间

**Files:**
- Modify: `CalendarPro/Views/Popover/CalendarItemComposerView.swift`
- Test: `CalendarProTests/Events/EventServiceTests.swift`

**Step 1: Write the failing tests**

增加创建器初始值测试：给定 `10:30–11:00` 范围，日程开始/结束时间分别为 `10:30` 和 `11:00`，提醒事项时间为 `10:30` 且 `includesTime == true`；不传范围时仍使用现有默认请求。

**Step 2: Run tests to verify they fail**

Run:

```bash
xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/EventServiceTests
```

Expected: FAIL，创建模式不接受 `initialTimeRange`，且初始化逻辑不可验证。

**Step 3: Extend composer creation mode**

将创建模式扩展为：

```swift
case create(
    kind: CalendarItemCreationKind,
    selectedDate: Date,
    initialTimeRange: CalendarItemCreationTimeRange?
)
```

将 `InitialValues` 和 `initialValues(...)` 调整为模块内可测试但不公开到模块外。创建分支先生成现有默认请求，再按可选范围覆盖：

```swift
startDate: initialTimeRange?.startDate ?? eventRequest.startDate
endDate: initialTimeRange?.endDate ?? eventRequest.endDate
dueDate: initialTimeRange?.startDate ?? reminderRequest.dueDate
reminderIncludesTime: true
```

编辑模式保持不变。

**Step 4: Run tests to verify they pass**

重复 Task 2 Step 2 命令。Expected: PASS。

### Task 3: 贯通时间线创建回调

**Files:**
- Modify: `CalendarPro/Views/Popover/EventListView.swift`
- Modify: `CalendarPro/Views/Popover/CalendarPopoverView.swift`
- Modify: `CalendarPro/Views/RootPopoverView.swift`
- Modify: `CalendarPro/App/EventDetailWindowController.swift`
- Modify: `CalendarPro/App/PopoverController.swift`
- Modify: `CalendarPro/App/AppDelegate.swift`
- Modify: `CalendarProTests/CalendarProTests.swift`

**Step 1: Add callback and presenter assertions**

扩展测试替身以记录创建器收到的 `CalendarItemCreationTimeRange?`，验证普通“+”入口可传 `nil`，精确时间入口可保留范围，同时继续验证弹层临时行为恢复。

**Step 2: Run targeted tests to verify they fail**

Run:

```bash
xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/PopoverControllerTests
```

Expected: FAIL，presenter 和控制器签名尚未接受时间范围。

**Step 3: Thread the optional range through existing data flow**

为 `showComposer`、`showItemComposer` 和 `onPresentItemComposer` 增加 `initialTimeRange` 参数。`RootPopoverView` 将现有创建处理器改为接受可选范围：顶部“+”传 `nil`，时间线回调传精确范围。时间线入口仅在 `canCreateEvent` 为真时启用，并始终以 `.event` 作为默认类型。

**Step 4: Add the background-only double-click gesture**

在 `dayTimelineGrid` 的最底层增加透明、具备矩形命中形状的背景，并附加 `SpatialTapGesture(count: 2)`。从 `value.location.y` 生成槽位并触发回调；日程/提醒事项按钮保留在更高层，避免背景接收已有项目上的双击。

**Step 5: Run targeted tests**

重复 Task 3 Step 2 命令。Expected: PASS。

### Task 4: 空白日持续呈现可交互时间线

**Files:**
- Modify: `CalendarPro/Views/Popover/EventListView.swift`
- Test: `CalendarProTests/Events/CalendarItemTests.swift`

**Step 1: Write the failing layout test**

验证非今天且没有任何项目时，布局提供 `09:00` 初始滚动上下文；今天的空白日仍以当前时间为中心。

**Step 2: Run the test to verify it fails**

运行 Task 1 的定向测试命令。Expected: FAIL，空白非今天的 `initialScrollMinutes` 当前为 `nil`。

**Step 3: Render the grid independently of item count**

加载中继续显示进度；非加载状态始终显示滚动时间线。空项目时在时间线上方显示现有 `emptyStateText` 轻量提示。全天/无时间项目仍在辅助区展示，全天时间网格无论是否存在 timed item 都渲染。非今天空白日默认滚动到 09:00。

**Step 4: Run the layout tests**

重复 Task 1 的定向测试命令。Expected: PASS。

### Task 5: 完整回归与文档核对

**Files:**
- Verify: `docs/plans/2026-07-21-timeline-double-click-creation-design.md`
- Verify: `docs/plans/2026-07-21-timeline-double-click-creation.md`

**Step 1: Check formatting and compile**

Run:

```bash
git diff --check
xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'
```

Expected: 无格式错误，BUILD SUCCEEDED。

**Step 2: Run the complete test suite**

Run:

```bash
xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'
```

Expected: TEST SUCCEEDED。

**Step 3: Manual verification checklist**

- 空白日与有日程日期均显示时间网格。
- 双击 `10:00–10:29` 空白处预填 `10:00–10:30`。
- 双击 `10:30–10:59` 空白处预填 `10:30–11:00`。
- 切换到提醒事项后到期时间为槽位开始时间。
- 双击已有项目不会打开新的创建器。
- 单击、纵向滚动和横向滚动行为保持正常。

**Step 4: Commit implementation**

```bash
git add CalendarPro CalendarProTests docs/plans/2026-07-21-timeline-double-click-creation.md
git commit -m "feat(popover): create items from timeline double-click"
```
