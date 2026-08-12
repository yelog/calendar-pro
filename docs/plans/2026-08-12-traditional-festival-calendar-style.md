# Traditional Festival Calendar Style Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 在下拉月历中把七夕等传统农历节日显示为与节气一致的红色文字，同时保持普通农历文本及假日背景语义不变。

**Architecture:** 扩展现有 `LunarTextSemantic`，让农历描述明确区分普通日期、传统节日和节气；`CalendarDayFactory` 继续透传该语义，`CalendarGridView` 统一将传统节日与节气映射为现有红字样式。假日 badge 的卡片语义仍保持最高优先级，避免改变法定假日、公众假期和调休日的视觉规则。

**Tech Stack:** Swift 6, SwiftUI, XCTest

---

### Task 1: 覆盖传统节日显示语义

**Files:**
- Modify: `CalendarProTests/Lunar/LunarServiceTests.swift`
- Modify: `CalendarProTests/Calendar/CalendarDayFactoryTests.swift`

**Step 1: Write the failing tests**

为 2026-08-19（农历七月初七）增加断言：

```swift
XCTAssertEqual(result.festivalName, "七夕")
XCTAssertEqual(result.displaySemantic, .festival)
```

并验证 `CalendarDayFactory` 生成的 `CalendarDay` 保留 `.festival` 语义；现有普通农历日期仍为 `.regular`，节气仍为 `.solarTerm`。

**Step 2: Run tests to verify they fail**

Run:

```bash
xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/LunarServiceTests -only-testing:CalendarProTests/CalendarDayFactoryTests
```

Expected: FAIL，因为 `LunarTextSemantic` 尚不存在 `.festival`。

### Task 2: 实现传统节日语义与红字样式

**Files:**
- Modify: `CalendarPro/Features/Lunar/LunarDateDescriptor.swift`
- Modify: `CalendarPro/Views/Popover/CalendarGridView.swift`

**Step 1: Add the semantic case**

将语义定义扩展为：

```swift
enum LunarTextSemantic: Equatable {
    case regular
    case festival
    case solarTerm
}
```

`displaySemantic` 按实际展示文本的优先级返回语义：先判断 `festivalName`，再判断 `solarTermName`，否则返回 `.regular`。

**Step 2: Reuse the existing highlighted subtitle color**

在 `CalendarGridView` 中让 `.festival` 与 `.solarTerm` 共用当前红字逻辑；`semanticStyle` 仍先于农历文本语义返回，以保持假日背景语义优先。

**Step 3: Run targeted tests**

Run:

```bash
xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/LunarServiceTests -only-testing:CalendarProTests/CalendarDayFactoryTests
```

Expected: PASS。

### Task 3: 构建与差异验证

**Files:**
- Verify: `CalendarPro/Features/Lunar/LunarDateDescriptor.swift`
- Verify: `CalendarPro/Views/Popover/CalendarGridView.swift`
- Verify: `CalendarProTests/Lunar/LunarServiceTests.swift`
- Verify: `CalendarProTests/Calendar/CalendarDayFactoryTests.swift`

**Step 1: Run build verification**

Run:

```bash
xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'
```

Expected: `BUILD SUCCEEDED`。

**Step 2: Inspect the final diff**

确认只改变传统农历节日的显示语义与副标题颜色，不改变菜单栏 token、假日 badge、背景色或数据源。

**Step 3: Leave changes uncommitted**

遵循项目约定，未经用户明确要求不执行 commit。
