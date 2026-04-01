# Lunar Solar Terms Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为 Calendar Pro 的农历展示补上二十四节气解析与显示能力，并保持“传统节日 > 节气 > 普通农历文本”的优先级。

**Architecture:** 在 `Features/Lunar` 内新增 `SolarTermResolver`，按太阳视黄经求出节气发生时刻并做年份级缓存。节气统一按北京时间（`Asia/Shanghai`）落到自然日，避免中文农历在跨时区环境下漂移。`LunarService` 在现有农历转换与传统节日解析基础上再合并节气结果，`LunarDateDescriptor.displayText()` 统一决定最终展示文本，调用方无需新增分支。

**Tech Stack:** Swift, Foundation, SwiftUI domain models, XCTest

---

### Task 1: 为节气显示补测试，先锁定行为

**Files:**
- Modify: `CalendarProTests/Lunar/LunarServiceTests.swift`
- Modify: `CalendarProTests/Calendar/CalendarDayFactoryTests.swift`

**Step 1: Write the failing test**

在 `LunarServiceTests.swift` 添加断言，覆盖：
- `2026-02-04` 显示 `立春`
- `2026-03-05` 显示 `惊蛰`
- `2026-05-05` 显示 `立夏`
- `2027-02-04` 显示 `立春`，证明不是硬编码固定日期
- 非节气普通日继续显示农历日文本

在 `CalendarDayFactoryTests.swift` 添加断言，覆盖：
- 月历格子在节气当天也会把 `lunarText` 渲染成节气名

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/LunarServiceTests -only-testing:CalendarProTests/CalendarDayFactoryTests`
Expected: FAIL，提示当前没有节气解析能力

**Step 3: Write minimal implementation**

先不要修改展示层，只补足能让这些测试通过的农历描述结果。

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/LunarServiceTests -only-testing:CalendarProTests/CalendarDayFactoryTests`
Expected: PASS

**Step 5: Commit**

```bash
git add CalendarProTests/Lunar/LunarServiceTests.swift CalendarProTests/Calendar/CalendarDayFactoryTests.swift
git commit -m "test(lunar): cover solar term display behavior"
```

### Task 2: 新增 `SolarTermResolver` 并接入 `LunarService`

**Files:**
- Create: `CalendarPro/Features/Lunar/SolarTermResolver.swift`
- Modify: `CalendarPro/Features/Lunar/LunarService.swift`
- Modify: `CalendarPro/Features/Lunar/LunarDateDescriptor.swift`
- Modify: `CalendarPro.xcodeproj/project.pbxproj`

**Step 1: Add the resolver type**

在 `SolarTermResolver.swift` 中创建：
- `SolarTerm` 枚举
- `SolarTermOccurrence` 结构
- 太阳视黄经计算函数
- 二分求根逻辑
- 按公历年缓存节气时刻的逻辑

**Step 2: Extend the descriptor**

在 `LunarDateDescriptor.swift` 中新增：

```swift
let solarTermName: String?
```

并将 `displayText()` 改为：

```swift
if let festivalName { return festivalName }
if let solarTermName { return solarTermName }
```

之后再回落到原来的农历样式。

**Step 3: Wire it into LunarService**

在 `LunarService.swift` 中注入 `SolarTermResolver`，并在 `describe(...)` 返回值里填充 `solarTermName`。

**Step 4: Update the Xcode project**

把 `SolarTermResolver.swift` 加入 `Features/Lunar` group 和主 target 的 Sources。

**Step 5: Run targeted tests**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/LunarServiceTests -only-testing:CalendarProTests/CalendarDayFactoryTests`
Expected: PASS

**Step 6: Commit**

```bash
git add CalendarPro/Features/Lunar/SolarTermResolver.swift CalendarPro/Features/Lunar/LunarService.swift CalendarPro/Features/Lunar/LunarDateDescriptor.swift CalendarPro.xcodeproj/project.pbxproj
git commit -m "feat(lunar): add solar term resolver"
```

### Task 3: 做构建与回归确认

**Files:**
- Modify: `docs/plans/2026-04-01-lunar-solar-terms-design.md`
- Modify: `docs/plans/2026-04-01-lunar-solar-terms.md`

**Step 1: Run targeted tests**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/LunarServiceTests -only-testing:CalendarProTests/CalendarDayFactoryTests`
Expected: PASS

**Step 2: Run build verification**

Run: `xcodebuild -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED

**Step 3: Manual verification checklist**

检查：
- 月历 2026 年 2 月 4 日显示 `立春`
- 月历 2026 年 3 月 5 日显示 `惊蛰`
- 月历 2026 年 5 月 5 日显示 `立夏`
- 春节仍显示 `春节` 而不是普通农历文本

**Step 4: Commit**

```bash
git add CalendarPro/Features/Lunar/SolarTermResolver.swift CalendarPro/Features/Lunar/LunarService.swift CalendarPro/Features/Lunar/LunarDateDescriptor.swift CalendarProTests/Lunar/LunarServiceTests.swift CalendarProTests/Calendar/CalendarDayFactoryTests.swift CalendarPro.xcodeproj/project.pbxproj docs/plans/2026-04-01-lunar-solar-terms-design.md docs/plans/2026-04-01-lunar-solar-terms.md
git commit -m "feat(lunar): show solar terms in lunar text"
```
