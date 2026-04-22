# 菜单栏字体样式设置实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 在“设置 → 菜单栏”中新增加粗、文字颜色和填充背景样式，并应用到真实菜单栏状态项。

**Architecture:** 样式作为 `MenuBarPreferences` 的一部分持久化；设置页负责编辑和预览；状态栏控制器根据样式选择系统模板绘制或自定义彩色绘制。

**Tech Stack:** Swift 6, SwiftUI, AppKit `NSStatusItem`, `XCTest`

---

### Task 1: 扩展偏好模型

**Files:**
- Modify: `CalendarPro/Settings/MenuBarPreferences.swift`
- Test: `CalendarProTests/Settings/MenuBarPreferencesTests.swift`

**Steps:**
- 新增 `MenuBarTextStyle`，包含加粗、可选文字色、填充开关和填充色。
- 给 `MenuBarPreferences` 新增 `textStyle`，默认 `.default`。
- 在自定义 `Codable` 中对旧配置使用 `decodeIfPresent`。
- 添加默认值、旧配置解码和自动对比文字色测试。

### Task 2: 扩展设置存储

**Files:**
- Modify: `CalendarPro/Settings/SettingsStore.swift`
- Test: `CalendarProTests/Settings/SettingsStoreTests.swift`

**Steps:**
- 添加 `setMenuBarTextBold`、`setMenuBarTextColorHex`、`setMenuBarFilledBackground`、`setMenuBarFillColorHex`、`resetMenuBarTextStyle`。
- 每个方法更新 `menuBarPreferences` 后立即持久化。
- 添加样式持久化和重置测试。

### Task 3: 实现设置页 UI

**Files:**
- Modify: `CalendarPro/Views/Settings/MenuBarSettingsView.swift`
- Modify: `CalendarPro/Resources/Localizable.xcstrings`

**Steps:**
- 在预览下方新增“字体样式”分组。
- 添加加粗、文字色、填充背景和重置控件。
- 让顶部预览应用同一份 `MenuBarTextStyle`。
- 增加必要本地化文案。

### Task 4: 实现状态栏绘制

**Files:**
- Modify: `CalendarPro/App/StatusBarController.swift`

**Steps:**
- 订阅 `displayText` 和 `menuBarPreferences.textStyle`。
- 默认继续生成 template image，保留系统菜单栏自适应颜色。
- 自定义颜色或填充背景时生成彩色 image，绘制文字和圆角填充。
- 维护 tooltip 和辅助功能 label。

### Task 5: 验证

**Commands:**
- `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/CalendarProDerivedData-MenubarStyle -skip-testing:CalendarProUITests -only-testing:CalendarProTests/MenuBarPreferencesTests -only-testing:CalendarProTests/SettingsStoreTests`
- `xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/CalendarProDerivedData-MenubarStyleBuild`

**Manual Checks:**
- 打开“设置 → 菜单栏”，确认预览、加粗、文字颜色、填充背景和重置控件工作正常。
- 开启填充背景后确认菜单栏文字显示为圆角胶囊。
- 重启应用后确认样式设置仍然保留。
