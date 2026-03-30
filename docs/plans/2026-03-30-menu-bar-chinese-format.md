# Menu Bar Chinese Format Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为菜单栏日期和星期新增可选中文显示样式，并保证设置可持久化。

**Architecture:** 在现有 `DisplayTokenStyle` 上新增两个样式枚举值，避免引入新的配置结构。渲染层为日期和星期增加定向分支，设置页按 token 收敛可选样式集合，并用测试覆盖渲染和持久化。

**Tech Stack:** Swift, SwiftUI, Foundation, XCTest, Xcodebuild

---

### Task 1: 为中文日期和中文星期补充失败测试

**Files:**
- Modify: `CalendarProTests/MenuBar/ClockRenderServiceTests.swift`
- Modify: `CalendarProTests/Settings/MenuBarPreferencesTests.swift`
- Modify: `CalendarProTests/Settings/SettingsStoreTests.swift`

**Step 1: Write the failing test**

在 `ClockRenderServiceTests` 添加中文日期与中文星期断言，在设置测试中添加新样式编码与持久化断言。

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/ClockRenderServiceTests -only-testing:CalendarProTests/MenuBarPreferencesTests -only-testing:CalendarProTests/SettingsStoreTests`

Expected: FAIL，提示新样式枚举或渲染逻辑尚不存在。

### Task 2: 扩展样式枚举、菜单栏渲染与设置 UI

**Files:**
- Modify: `CalendarPro/Settings/MenuBarPreferences.swift`
- Modify: `CalendarPro/Features/MenuBar/ClockRenderService.swift`
- Modify: `CalendarPro/Views/Settings/MenuBarSettingsView.swift`

**Step 1: Write minimal implementation**

新增 `DisplayTokenStyle` 的中文样式枚举值，补充日期与星期渲染分支，并让设置页按 token 提供对应样式列表。

**Step 2: Run test to verify it passes**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/ClockRenderServiceTests -only-testing:CalendarProTests/MenuBarPreferencesTests -only-testing:CalendarProTests/SettingsStoreTests`

Expected: PASS

### Task 3: 运行回归验证

**Files:**
- Modify: `docs/plans/2026-03-30-menu-bar-chinese-format-design.md`
- Modify: `docs/plans/2026-03-30-menu-bar-chinese-format.md`

**Step 1: Run focused verification**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/ClockRenderServiceTests -only-testing:CalendarProTests/MenuBarPreferencesTests -only-testing:CalendarProTests/SettingsStoreTests`

Expected: PASS

**Step 2: Note outcome**

记录测试结果与任何残留风险。
