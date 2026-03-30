# 日程详情独立窗口 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 在菜单栏下拉中点击某条日历日程时，弹出一个独立的 macOS 详情窗口展示该日程内容，同时保持当前 Popover 布局不变。

**Architecture:** 保持 `NSPopover` 的单栏布局不变，把详情内容从 `CalendarPopoverView` 抽离成独立 SwiftUI 视图，并由 `PopoverController` 持有一个可复用的 `NSPanel` 协调器。`RootPopoverView` 继续管理日期和选中态，但只通过闭包向 AppKit 层发送“打开/关闭详情窗口”的意图；详情窗口关闭时再通过回调清理 SwiftUI 侧的选中状态，确保高亮和窗口生命周期一致。

**Tech Stack:** SwiftUI, AppKit, EventKit, Combine, XCTest

---

### Task 1: 稳定日程选择状态和点击语义

**Files:**
- Modify: `CalendarPro/Views/Popover/CalendarPopoverViewModel.swift`
- Modify: `CalendarProTests/Popover/CalendarPopoverViewModelTests.swift`
- Modify: `CalendarPro/Views/RootPopoverView.swift`

**Step 1: 写失败测试**

```swift
func testToggleEventSelectionSelectsIdentifier() {
    let viewModel = CalendarPopoverViewModel()

    let shouldPresent = viewModel.toggleEventSelection(identifier: "event-1")

    XCTAssertTrue(shouldPresent)
    XCTAssertEqual(viewModel.selectedEventIdentifier, "event-1")
}

func testToggleEventSelectionClearsIdentifierWhenTappingSameEvent() {
    let viewModel = CalendarPopoverViewModel()
    _ = viewModel.toggleEventSelection(identifier: "event-1")

    let shouldPresent = viewModel.toggleEventSelection(identifier: "event-1")

    XCTAssertFalse(shouldPresent)
    XCTAssertNil(viewModel.selectedEventIdentifier)
}
```

**Step 2: 运行测试确认失败**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarPopoverViewModelTests`

Expected: FAIL，提示 `toggleEventSelection(identifier:)` 不存在。

**Step 3: 写最小实现**

```swift
func toggleEventSelection(identifier: String) -> Bool {
    if selectedEventIdentifier == identifier {
        selectedEventIdentifier = nil
        return false
    }

    selectedEventIdentifier = identifier
    return true
}
```

同时修改 `RootPopoverView`，把当前点击逻辑统一走 `toggleEventSelection(identifier:)`，为后续窗口展示返回一个明确的“打开 / 关闭”结果。

**Step 4: 运行测试确认通过**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarPopoverViewModelTests`

Expected: PASS

**Step 5: Commit**

```bash
git add CalendarPro/Views/Popover/CalendarPopoverViewModel.swift CalendarPro/Views/RootPopoverView.swift CalendarProTests/Popover/CalendarPopoverViewModelTests.swift
git commit -m "refactor(popover): stabilize event selection state"
```

### Task 2: 让列表只对日历事件开放详情交互

**Files:**
- Modify: `CalendarPro/Views/Popover/CalendarPopoverView.swift`
- Modify: `CalendarPro/Views/Popover/EventListView.swift`
- Modify: `CalendarPro/Views/Popover/EventCardView.swift`
- Modify: `CalendarPro/Views/RootPopoverView.swift`

**Step 1: 写失败测试**

在 `CalendarProTests/Popover/CalendarPopoverViewModelTests.swift` 追加一个约束测试，确保切换日期时一定会清空当前选中事件，避免列表高亮和外部窗口脱节：

```swift
func testSelectDateClearsSelectedEventBeforeReload() {
    let viewModel = CalendarPopoverViewModel()
    _ = viewModel.toggleEventSelection(identifier: "event-1")

    viewModel.selectDate(makeDate(year: 2026, month: 3, day: 30))

    XCTAssertNil(viewModel.selectedEventIdentifier)
}
```

**Step 2: 运行测试确认失败**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarPopoverViewModelTests`

Expected: 若 Task 1 尚未让 `selectDate(_:)` 与新切换逻辑保持一致，这里会失败。

**Step 3: 写最小实现**

- 给 `EventListView` 增加：

```swift
let selectedEventIdentifier: String?
let onSelectEvent: (EKEvent) -> Void
```

- 在 `ForEach(items)` 内只对 `.event(let event)` 包装点击行为：

```swift
switch item {
case .event(let event):
    Button {
        onSelectEvent(event)
    } label: {
        EventCardView(
            item: item,
            isSelected: selectedEventIdentifier == event.selectionIdentifier,
            showsDisclosure: true
        )
    }
    .buttonStyle(.plain)
case .reminder:
    EventCardView(item: item, isSelected: false, showsDisclosure: false)
}
```

- 修改 `CalendarPopoverView` 透传 `selectedEventIdentifier` 和 `onSelectEvent`
- 删除 `CalendarPopoverView` 内与内嵌详情面板相关的宽度扩展和双栏布局，保持 Popover 单栏固定宽度

**Step 4: 运行测试确认通过并完成编译检查**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarPopoverViewModelTests`

Expected: PASS

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/PopoverControllerTests`

Expected: PASS，至少确认改动未破坏主壳编译。

**Step 5: Commit**

```bash
git add CalendarPro/Views/Popover/CalendarPopoverView.swift CalendarPro/Views/Popover/EventListView.swift CalendarPro/Views/Popover/EventCardView.swift CalendarPro/Views/RootPopoverView.swift CalendarProTests/Popover/CalendarPopoverViewModelTests.swift
git commit -m "feat(popover): wire event row selection for external detail window"
```

### Task 3: 实现独立窗口的定位算法

**Files:**
- Create: `CalendarPro/App/EventDetailWindowLayout.swift`
- Create: `CalendarProTests/App/EventDetailWindowLayoutTests.swift`
- Regenerate: `CalendarPro.xcodeproj/project.pbxproj` via `ruby tools/generate_xcodeproj.rb`

**Step 1: 写失败测试**

```swift
func testPrefersLeftSideWhenThereIsEnoughRoom() {
    let anchor = CGRect(x: 900, y: 500, width: 340, height: 400)
    let visibleFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)

    let frame = EventDetailWindowLayout.defaultFrame(
        panelSize: CGSize(width: 320, height: 360),
        anchorFrame: anchor,
        visibleFrame: visibleFrame
    )

    XCTAssertLessThan(frame.maxX, anchor.minX)
}

func testFallsBackToRightSideWhenLeftSideIsTooTight() {
    let anchor = CGRect(x: 20, y: 500, width: 340, height: 400)
    let visibleFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)

    let frame = EventDetailWindowLayout.defaultFrame(
        panelSize: CGSize(width: 320, height: 360),
        anchorFrame: anchor,
        visibleFrame: visibleFrame
    )

    XCTAssertGreaterThanOrEqual(frame.minX, anchor.maxX)
}
```

**Step 2: 运行测试确认失败**

Run: `ruby tools/generate_xcodeproj.rb`

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/EventDetailWindowLayoutTests`

Expected: FAIL，提示 `EventDetailWindowLayout` 类型不存在。

**Step 3: 写最小实现**

```swift
enum EventDetailWindowLayout {
    static func defaultFrame(
        panelSize: CGSize,
        anchorFrame: CGRect,
        visibleFrame: CGRect,
        spacing: CGFloat = 10
    ) -> CGRect {
        let leftOriginX = anchorFrame.minX - spacing - panelSize.width
        let rightOriginX = anchorFrame.maxX + spacing
        let originX = leftOriginX >= visibleFrame.minX ? leftOriginX : rightOriginX
        let unclampedY = anchorFrame.maxY - panelSize.height
        let originY = min(
            max(unclampedY, visibleFrame.minY),
            visibleFrame.maxY - panelSize.height
        )

        return CGRect(origin: CGPoint(x: originX, y: originY), size: panelSize)
    }
}
```

再补一个测试覆盖 Y 轴夹取，避免窗口跑出屏幕。

**Step 4: 运行测试确认通过**

Run: `ruby tools/generate_xcodeproj.rb`

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/EventDetailWindowLayoutTests`

Expected: PASS

**Step 5: Commit**

```bash
git add CalendarPro/App/EventDetailWindowLayout.swift CalendarProTests/App/EventDetailWindowLayoutTests.swift CalendarPro.xcodeproj/project.pbxproj
git commit -m "feat(app): add event detail window layout calculator"
```

### Task 4: 提取可复用的详情内容视图并实现 `NSPanel`

**Files:**
- Create: `CalendarPro/Views/Popover/EventDetailWindowView.swift`
- Create: `CalendarPro/App/EventDetailWindowController.swift`
- Regenerate: `CalendarPro.xcodeproj/project.pbxproj` via `ruby tools/generate_xcodeproj.rb`

**Step 1: 写失败测试**

在 `CalendarProTests/CalendarProTests.swift` 增加 presenter 协议层测试，先约束控制器对“显示 / 关闭”的最小接口：

```swift
func testCloseEventDetailWindowIsSafeWhenNothingIsShown() {
    let presenter = FakeEventDetailWindowPresenter()
    let controller = makeController(
        name: #function,
        popover: FakePopover(),
        interactionMonitor: FakePopoverInteractionMonitor(),
        eventDetailPresenter: presenter
    )

    controller.closeEventDetailWindow()

    XCTAssertEqual(presenter.closeCallCount, 1)
}
```

**Step 2: 运行测试确认失败**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/PopoverControllerTests`

Expected: FAIL，提示 `eventDetailPresenter` 注入点或 `closeEventDetailWindow()` 不存在。

**Step 3: 写最小实现**

- 抽出当前详情面板内容到 `EventDetailWindowView`
- 新增协议：

```swift
@MainActor
protocol EventDetailWindowPresenting: AnyObject {
    func show(event: EKEvent, anchoredTo anchorWindow: NSWindow?, onClose: @escaping @MainActor () -> Void)
    func close()
}
```

- 在 `EventDetailWindowController` 中：
  - 复用一个 `NSPanel`
  - 用 `NSHostingController(rootView: EventDetailWindowView(...))` 承载内容
  - 通过 `EventDetailWindowLayout` 计算位置
  - 在系统关闭和内容视图关闭按钮中统一执行 `onClose`

**Step 4: 运行测试确认通过**

Run: `ruby tools/generate_xcodeproj.rb`

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/PopoverControllerTests`

Expected: PASS

**Step 5: Commit**

```bash
git add CalendarPro/Views/Popover/EventDetailWindowView.swift CalendarPro/App/EventDetailWindowController.swift CalendarProTests/CalendarProTests.swift CalendarPro.xcodeproj/project.pbxproj
git commit -m "feat(app): add reusable event detail panel window"
```

### Task 5: 把详情窗口接入 PopoverController 并做回归验证

**Files:**
- Modify: `CalendarPro/App/PopoverController.swift`
- Modify: `CalendarPro/Views/RootPopoverView.swift`
- Modify: `CalendarProTests/CalendarProTests.swift`

**Step 1: 写失败测试**

```swift
func testClosingPopoverAlsoClosesEventDetailWindow() {
    let popover = FakePopover()
    let interactionMonitor = FakePopoverInteractionMonitor()
    let presenter = FakeEventDetailWindowPresenter()
    let controller = makeController(
        name: #function,
        popover: popover,
        interactionMonitor: interactionMonitor,
        eventDetailPresenter: presenter
    )

    controller.toggle(relativeTo: NSButton())
    controller.closeEventDetailWindow()
    interactionMonitor.triggerInteraction()

    XCTAssertEqual(presenter.closeCallCount, 2)
}
```

**Step 2: 运行测试确认失败**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/PopoverControllerTests`

Expected: FAIL，说明 Popover 收口时还没有联动详情窗口。

**Step 3: 写最小实现**

- 在 `PopoverController` 注入并持有 `EventDetailWindowPresenting`
- 在构造 `RootPopoverView` 时传入：

```swift
onPresentEventDetailWindow: { [weak self] event, onClose in
    self?.showEventDetailWindow(for: event, onClose: onClose)
},
onDismissEventDetailWindow: { [weak self] in
    self?.closeEventDetailWindow()
}
```

- 在 `closePopover()`、`popoverDidClose(_:)` 中同步调用 `closeEventDetailWindow()`
- 在 `RootPopoverView` 中：
  - 选中新事件时请求打开详情窗口
  - 取消选中、切换日期、筛选失效、权限关闭时请求关闭详情窗口
  - `onAppear` 时清空旧选中态，避免 Popover 再次打开后残留高亮

**Step 4: 运行测试和手动验证**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/PopoverControllerTests`

Expected: PASS

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'`

Expected: 单元测试通过；若 UI 测试环境可用则一并通过。

手动验证：
- 点击日历事件，详情窗口出现在 Popover 左侧
- 点击另一条事件，窗口内容更新但 Popover 尺寸不变
- 点击提醒事项，没有详情窗口
- 切换日期或关闭 Popover，详情窗口收起

**Step 5: Commit**

```bash
git add CalendarPro/App/PopoverController.swift CalendarPro/Views/RootPopoverView.swift CalendarProTests/CalendarProTests.swift
git commit -m "feat(app): present event detail in standalone macos window"
```
