# Detail Text Selection Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 让日程详情页和提醒事项详情页中的标题、摘要、参会人和链接等核心内容支持选中复制，同时保持现有按钮交互不受影响。

**Architecture:** 保持现有详情页结构不变，只新增一个轻量的“只读可选文本”复用组件，并定点替换当前仍使用普通 `Text` 的内容区域。链接行改成“可选中文本 + 独立打开动作”，避免 `Link` 抢占拖选手势。

**Tech Stack:** SwiftUI, AppKit bridging for existing text views, EventKit, xcodebuild

---

### Task 1: 抽取只读可选文本能力并接入头部摘要

**Files:**
- Modify: `CalendarPro/Views/Popover/EventDetailWindowView.swift`
- Modify: `CalendarPro/Views/Popover/ReminderDetailWindowView.swift`

**Step 1: Write the failing test**

这次以构建和手动验证为主。先记录手动验证点：
- 标题无法拖选复制
- 日期/时间摘要无法拖选复制

**Step 2: Run test to verify it fails**

Run: `xcodebuild -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED，但手动验证发现标题与摘要仍不可复制。

**Step 3: Write minimal implementation**

在两个详情页文件内增加一个私有复用视图，例如：

```swift
private struct SelectableDetailText: View {
    let content: String
    let font: Font
    let color: Color
    var lineLimit: Int? = nil

    var body: some View {
        Text(content)
            .font(font)
            .foregroundStyle(color)
            .lineLimit(lineLimit)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
    }
}
```

并替换：
- 事件标题
- 事件日期摘要
- 事件时间摘要
- 提醒标题
- 提醒截止日期/截止时间/完成时间

**Step 4: Run test to verify it passes**

Run: `xcodebuild -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add CalendarPro/Views/Popover/EventDetailWindowView.swift CalendarPro/Views/Popover/ReminderDetailWindowView.swift
git commit -m "feat(detail): enable text selection in detail headers"
```

### Task 2: 扩展到参会人和链接文本

**Files:**
- Modify: `CalendarPro/Views/Popover/EventDetailWindowView.swift`
- Modify: `CalendarPro/Views/Popover/ReminderDetailWindowView.swift`

**Step 1: Write the failing test**

记录手动验证点：
- 参会人姓名不可复制
- 链接文本难以拖选复制

**Step 2: Run test to verify it fails**

Run: `xcodebuild -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED，但手动验证仍无法稳定复制参会人和链接。

**Step 3: Write minimal implementation**

在 `EventDetailWindowView.swift`：
- 给参会人姓名改用可选文本
- 将 `LinkDetailRow` 从整段 `Link` 改为“可选中文本 + 打开按钮/图标按钮”

在 `ReminderDetailWindowView.swift`：
- 同步改造 `ReminderLinkDetailRow`

保留当前视觉风格：蓝色、下划线、辅助说明，但不要让整段文本承担点击动作。

**Step 4: Run test to verify it passes**

Run: `xcodebuild -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add CalendarPro/Views/Popover/EventDetailWindowView.swift CalendarPro/Views/Popover/ReminderDetailWindowView.swift
git commit -m "feat(detail): make links and attendees selectable"
```

### Task 3: 手动验证与收尾

**Files:**
- Modify: `docs/plans/2026-04-01-detail-text-selection-design.md`
- Modify: `docs/plans/2026-04-01-detail-text-selection.md`

**Step 1: Run build verification**

Run: `xcodebuild -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED

**Step 2: Manual verification checklist**

检查：
- 事件标题可选中复制
- 事件日期与时间摘要可选中复制
- 参会人姓名可选中复制
- 事件链接文本可选中复制，打开链接动作仍正常
- 提醒标题、截止日期、截止时间、完成时间可选中复制
- 提醒链接文本可选中复制，打开链接动作仍正常
- 关闭按钮、完成勾选、展开/收起、底部打开原应用按钮正常

**Step 3: Commit**

```bash
git add CalendarPro/Views/Popover/EventDetailWindowView.swift CalendarPro/Views/Popover/ReminderDetailWindowView.swift docs/plans/2026-04-01-detail-text-selection-design.md docs/plans/2026-04-01-detail-text-selection.md
git commit -m "feat(detail): support selecting detail text"
```
