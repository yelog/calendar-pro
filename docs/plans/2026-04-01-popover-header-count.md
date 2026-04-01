# Popover Header Count Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 精简下拉日程头部，只保留“左侧日期标题 + 右侧总数”，移除“点击查看详情”类说明文案。

**Architecture:** 保持 `RootPopoverView -> CalendarPopoverView -> EventListView` 现有数据流不变，只在 `CalendarPopoverView` 内抽离一个纯文本总数格式化器，并把头部布局从双行改为单行。列表内容、空状态和点击交互均保持原样。

**Tech Stack:** SwiftUI, EventKit, XCTest

---

### Task 1: 抽离可测试的头部总数字符串逻辑

**Files:**
- Modify: `CalendarPro/Views/Popover/CalendarPopoverView.swift`
- Test: `CalendarProTests/Popover/CalendarPopoverViewModelTests.swift`

**Step 1: Write the failing test**

在 `CalendarPopoverViewModelTests.swift` 添加断言，覆盖：
- 加载态返回 `加载中`
- 空列表返回 `0 项`
- 非空列表返回总条数文本

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarPopoverViewModelTests`
Expected: FAIL，提示缺少总数字符串格式化逻辑

**Step 3: Write minimal implementation**

在 `CalendarPopoverView.swift` 增加一个纯文本格式化器，输入 `isLoadingEvents` 和 `itemCount`，输出头部右侧所需文案。

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarPopoverViewModelTests`
Expected: PASS

**Step 5: Commit**

```bash
git add CalendarPro/Views/Popover/CalendarPopoverView.swift CalendarProTests/Popover/CalendarPopoverViewModelTests.swift
git commit -m "test(popover): cover header count formatting"
```

### Task 2: 把日程头部改成单行布局

**Files:**
- Modify: `CalendarPro/Views/Popover/CalendarPopoverView.swift`

**Step 1: Update the header layout**

在 `eventsSection` 中移除原副标题 `Text`，改为：
- 左侧日期标题
- 右侧总数文本

总数文本使用次级样式并靠右对齐。

**Step 2: Run targeted tests**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarPopoverViewModelTests`
Expected: PASS

**Step 3: Run build verification**

Run: `xcodebuild -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED

**Step 4: Manual verification checklist**

检查：
- 标题左侧仍显示日期
- 右侧显示 `N 项` 或 `加载中`
- 原“点击查看详情”文案已消失
- 列表内容和点击交互保持不变

**Step 5: Commit**

```bash
git add CalendarPro/Views/Popover/CalendarPopoverView.swift docs/plans/2026-04-01-popover-header-count-design.md docs/plans/2026-04-01-popover-header-count.md
git commit -m "fix(popover): simplify selected-day header summary"
```
