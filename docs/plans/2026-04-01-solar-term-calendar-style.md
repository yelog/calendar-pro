# Solar Term Calendar Style Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 在下拉月历中把节气副标题显示为红字，同时保留法定假日/公众假期红底和调休日蓝底的现有视觉语义。

**Architecture:** 在农历描述与 `CalendarDay` 之间增加一个轻量节气语义位，由 `CalendarDayFactory` 统一传递给月历格子。`CalendarGridView` 继续优先使用假日语义卡片，仅在没有假日背景语义时，对节气文本应用红色副标题样式。

**Tech Stack:** Swift, SwiftUI, XCTest

---

### Task 1: 为节气样式语义补测试

**Files:**
- Modify: `CalendarProTests/Calendar/CalendarDayFactoryTests.swift`
- Modify: `CalendarPro/Features/Lunar/LunarDateDescriptor.swift`

**Step 1: Write the failing test**

在 `CalendarDayFactoryTests.swift` 增加断言，覆盖：
- 节气日会带上节气语义位
- 非节气日不会带上该语义位

必要时在 `LunarDateDescriptor` 层增加轻量只读语义计算属性，供工厂复用。

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarDayFactoryTests`
Expected: FAIL，提示缺少节气语义位

**Step 3: Write minimal implementation**

给 `LunarDateDescriptor` 与 `CalendarDay` 增加节气语义能力，让工厂能够传递该状态。

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarDayFactoryTests`
Expected: PASS

**Step 5: Commit**

```bash
git add CalendarPro/Features/Lunar/LunarDateDescriptor.swift CalendarPro/Features/Calendar/CalendarDay.swift CalendarPro/Features/Calendar/CalendarDayFactory.swift CalendarPro/Features/Calendar/MonthCalendarService.swift CalendarProTests/Calendar/CalendarDayFactoryTests.swift
git commit -m "test(calendar): cover solar term subtitle semantics"
```

### Task 2: 应用节气红字样式

**Files:**
- Modify: `CalendarPro/Views/Popover/CalendarGridView.swift`

**Step 1: Update subtitle color logic**

在 `CalendarGridView.swift` 中按以下优先级调整 `subtitleColor`：
- 假日背景语义优先
- 仅节气时使用红色副标题
- 其他情况维持现状

**Step 2: Keep menu bar untouched**

不要改菜单栏 token 渲染逻辑，确保新样式只在下拉月历生效。

**Step 3: Run targeted tests**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarDayFactoryTests -only-testing:CalendarProTests/LunarServiceTests`
Expected: PASS

**Step 4: Run build verification**

Run: `xcodebuild -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add CalendarPro/Views/Popover/CalendarGridView.swift CalendarPro/Features/Lunar/LunarDateDescriptor.swift CalendarPro/Features/Calendar/CalendarDay.swift CalendarPro/Features/Calendar/CalendarDayFactory.swift CalendarPro/Features/Calendar/MonthCalendarService.swift CalendarProTests/Calendar/CalendarDayFactoryTests.swift docs/plans/2026-04-01-solar-term-calendar-style-design.md docs/plans/2026-04-01-solar-term-calendar-style.md
git commit -m "fix(calendar): highlight solar terms in month grid"
```
