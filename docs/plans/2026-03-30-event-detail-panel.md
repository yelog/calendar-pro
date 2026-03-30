# 日程详情仿下拉悬浮窗 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 在菜单栏下拉中点击某条日历日程时，弹出一个视觉上与下拉菜单一致的轻量独立详情浮层，保持当前 Popover 单栏布局不变，并避免长内容把窗口撑成大窗体。

**Architecture:** 保留当前独立 `NSPanel` 路线，但引入固定宽度和有上限的尺寸策略，把详情浮层的外观从“标准窗口”收敛成“仿下拉呼出的悬浮卡片”。`EventDetailWindowController` 负责统一面板大小与定位，`EventDetailWindowView` 负责固定头部和滚动正文布局，必要时提取共享视觉 token 供 `CalendarPopoverView` 与详情浮层共用。

**Tech Stack:** SwiftUI, AppKit, EventKit, Combine, XCTest

---

### Task 1: 固化浮层尺寸策略，禁止详情窗继续无限放大

**Files:**
- Create: `CalendarPro/App/EventDetailWindowSizing.swift`
- Create: `CalendarProTests/App/EventDetailWindowSizingTests.swift`
- Modify: `CalendarPro/App/EventDetailWindowController.swift`
- Modify: `CalendarPro.xcodeproj/project.pbxproj`

**Step 1: 写失败测试**

```swift
func testUsesFixedPopoverWidth() {
    let size = EventDetailWindowSizing.panelSize(for: CGSize(width: 780, height: 300))

    XCTAssertEqual(size.width, 340)
}

func testClampsHeightIntoFloatingWindowRange() {
    let small = EventDetailWindowSizing.panelSize(for: CGSize(width: 240, height: 120))
    let large = EventDetailWindowSizing.panelSize(for: CGSize(width: 240, height: 1200))

    XCTAssertEqual(small.height, 280)
    XCTAssertEqual(large.height, 440)
}

func testPrefersIdealHeightForShortContent() {
    let size = EventDetailWindowSizing.panelSize(for: CGSize(width: 240, height: 260))

    XCTAssertEqual(size.height, 360)
}
```

**Step 2: 运行测试确认失败**

Run: `ruby tools/generate_xcodeproj.rb`

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/EventDetailWindowSizingTests`

Expected: FAIL，提示 `EventDetailWindowSizing` 类型不存在。

**Step 3: 写最小实现**

```swift
enum EventDetailWindowSizing {
    static let width: CGFloat = 340
    static let minHeight: CGFloat = 280
    static let idealHeight: CGFloat = 360
    static let maxHeight: CGFloat = 440

    static func panelSize(for fittingSize: CGSize) -> CGSize {
        let preferredHeight = max(fittingSize.height, idealHeight)
        return CGSize(
            width: width,
            height: min(max(preferredHeight, minHeight), maxHeight)
        )
    }
}
```

同时在 `EventDetailWindowController` 中把面板尺寸改为：

```swift
let panelSize = NSSize(EventDetailWindowSizing.panelSize(for: fittingSize))
```

不要再沿用基于 `fittingSize.width` 的动态放大策略。

**Step 4: 运行测试确认通过**

Run: `ruby tools/generate_xcodeproj.rb`

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/EventDetailWindowSizingTests`

Expected: PASS

**Step 5: Commit**

```bash
git add CalendarPro/App/EventDetailWindowSizing.swift CalendarPro/App/EventDetailWindowController.swift CalendarProTests/App/EventDetailWindowSizingTests.swift CalendarPro.xcodeproj/project.pbxproj
git commit -m "feat(app): clamp event detail floating window size"
```

### Task 2: 把详情窗从标准窗口收敛成轻量悬浮浮层

**Files:**
- Modify: `CalendarPro/App/EventDetailWindowController.swift`
- Modify: `CalendarPro/App/EventDetailWindowLayout.swift`
- Modify: `CalendarProTests/App/EventDetailWindowLayoutTests.swift`
- Modify: `CalendarProTests/CalendarProTests.swift`

**Step 1: 扩充定位测试**

补一条测试，确保详情浮层靠近 Popover 一侧而不是贴边展开：

```swift
func testKeepsConfiguredGapFromAnchorWhenPlacedOnLeftSide() {
    let anchor = CGRect(x: 900, y: 500, width: 340, height: 400)
    let visible = CGRect(x: 0, y: 0, width: 1440, height: 900)

    let frame = EventDetailWindowLayout.defaultFrame(
        panelSize: CGSize(width: 340, height: 360),
        anchorFrame: anchor,
        visibleFrame: visible,
        spacing: 8
    )

    XCTAssertEqual(anchor.minX - frame.maxX, 8, accuracy: 0.5)
}
```

**Step 2: 运行测试确认失败**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/EventDetailWindowLayoutTests`

Expected: 若定位或间距策略未按设计实现，则断言失败。

**Step 3: 写最小实现**

- 把 `NSPanel` 的样式从强标题栏窗口收敛到轻量浮层：

```swift
let panel = NSPanel(
    contentRect: NSRect(x: 0, y: 0, width: 340, height: 360),
    styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
    backing: .buffered,
    defer: false
)
panel.isOpaque = false
panel.backgroundColor = .clear
panel.hasShadow = true
panel.isFloatingPanel = true
panel.hidesOnDeactivate = false
panel.level = .floating
```

- 继续保留：
  - 左侧优先
  - 右侧回退
  - `8-10pt` 间距
  - Y 轴夹取

- 不恢复系统标题栏按钮，仅使用内容内关闭按钮。

**Step 4: 运行测试确认通过并完成编译检查**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/EventDetailWindowLayoutTests`

Expected: PASS

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/PopoverControllerTests`

Expected: PASS，确认面板 presenter 链路未破坏。

**Step 5: Commit**

```bash
git add CalendarPro/App/EventDetailWindowController.swift CalendarPro/App/EventDetailWindowLayout.swift CalendarProTests/App/EventDetailWindowLayoutTests.swift CalendarProTests/CalendarProTests.swift
git commit -m "refactor(app): restyle event detail panel as floating popover"
```

### Task 3: 统一详情浮层与下拉菜单的视觉 token

**Files:**
- Create: `CalendarPro/Views/Popover/PopoverSurfaceMetrics.swift`
- Modify: `CalendarPro/Views/Popover/CalendarPopoverView.swift`
- Modify: `CalendarPro/Views/Popover/EventDetailWindowView.swift`
- Modify: `CalendarPro.xcodeproj/project.pbxproj`

**Step 1: 写最小共享 token**

创建共享常量，避免详情浮层和下拉菜单未来再分叉：

```swift
enum PopoverSurfaceMetrics {
    static let width: CGFloat = 340
    static let outerPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 10
    static let cornerRadius: CGFloat = 16
}
```

**Step 2: 应用到当前下拉菜单**

把：

```swift
.frame(width: CalendarPopoverLayout.mainPanelWidth)
```

改成：

```swift
.frame(width: PopoverSurfaceMetrics.width)
```

**Step 3: 应用到详情浮层**

在 `EventDetailWindowView` 中统一：

- 外层圆角
- 内边距
- section 间距
- 背景渐变语气
- 标题和元信息字号

同时把当前偏重的标题层级收敛为：

```swift
.font(.system(size: 16, weight: .semibold, design: .rounded))
```

避免再次出现“详情页像独立文档”的头部视觉。

**Step 4: 重新生成工程并完成编译检查**

Run: `ruby tools/generate_xcodeproj.rb`

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/PopoverControllerTests`

Expected: PASS

**Step 5: Commit**

```bash
git add CalendarPro/Views/Popover/PopoverSurfaceMetrics.swift CalendarPro/Views/Popover/CalendarPopoverView.swift CalendarPro/Views/Popover/EventDetailWindowView.swift CalendarPro.xcodeproj/project.pbxproj
git commit -m "refactor(ui): share popover surface metrics across detail panel"
```

### Task 4: 把长内容限制到滚动正文，不再撑大整个窗口

**Files:**
- Modify: `CalendarPro/Views/Popover/EventDetailWindowView.swift`
- Modify: `CalendarPro/App/EventDetailWindowController.swift`

**Step 1: 重构详情视图层次**

将当前全部内容平铺的 `VStack` 改成“固定头部 + 滚动正文”：

```swift
VStack(spacing: 12) {
    header
    summaryCard
    ScrollView {
        detailBody
    }
}
```

**Step 2: 限制长文本行为**

- 链接默认 `lineLimit(2)`
- 备注允许多行，但只能在正文滚动区扩展
- 若没有附加信息，空状态仍保留在正文区域

**Step 3: 把视图测量约束到固定宽度**

在 `EventDetailWindowView` 最外层显式设置：

```swift
.frame(width: PopoverSurfaceMetrics.width)
```

避免 `fittingSize` 再被宽向内容推大。

**Step 4: 回归测试**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/PopoverControllerTests`

Expected: PASS

手动验证：
- 打开一条带长 Teams 邀请的日程
- 确认宽度不变
- 确认正文可滚动而不是窗口继续增高

**Step 5: Commit**

```bash
git add CalendarPro/Views/Popover/EventDetailWindowView.swift CalendarPro/App/EventDetailWindowController.swift
git commit -m "refactor(ui): make event detail body scroll inside floating panel"
```

### Task 5: 做功能回归并记录 UI test 限制

**Files:**
- Modify: `docs/plans/2026-03-30-event-detail-panel.md`

**Step 1: 运行单元回归**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/PopoverControllerTests`

Expected: PASS

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/EventDetailWindowLayoutTests`

Expected: PASS

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/EventDetailWindowSizingTests`

Expected: PASS

**Step 2: 运行全量测试**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'`

Expected: 单元测试通过；若 `CalendarProUITests-Runner` 仍出现启动前被系统 kill，则记录为已知环境问题，不作为本次样式调整的阻断条件。

**Step 3: 完成手动验收**

手动检查以下项目：

- 详情浮层宽度与下拉菜单一致
- 长备注只滚动正文，不再把窗口整体拉大
- 点击不同事件为同一浮层更新内容
- 同一事件再次点击会关闭浮层
- 关闭 Popover 时详情浮层同步关闭

**Step 4: 更新计划尾注**

在计划文件末尾追加一段实施备注，说明：

- UI test runner 当前存在环境级 bootstrap 问题
- 本次验收以单元测试 + 手动 UI 校验为主

**Step 5: Commit**

```bash
git add docs/plans/2026-03-30-event-detail-panel.md
git commit -m "docs: note validation strategy for event detail floating panel"
```
