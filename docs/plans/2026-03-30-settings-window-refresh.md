# 设置窗口改版 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 重构设置窗口布局并修复侧边栏导航点击无响应的问题。

**Architecture:** 在 `SettingsRootView` 中移除对 `NavigationSplitView` 默认选中行为的依赖，改用显式导航状态驱动的双栏壳层。右侧详情区抽象为统一的页面容器，让各设置页以一致的标题、说明和内容卡片结构呈现，同时保持现有设置业务逻辑不变。

**Tech Stack:** SwiftUI, AppKit, XCTest

---

### Task 1: 建立新的设置窗口外层结构

**Files:**
- Modify: `CalendarPro/Views/Settings/SettingsRootView.swift`

**Step 1: 写出新的页面骨架**

在 `SettingsRootView` 中定义：
- 导航项标题、副标题和图标元数据
- 左侧固定宽度导航栏
- 右侧统一详情容器

**Step 2: 使用显式状态替换默认导航选中行为**

将导航切换统一绑定到 `selectedItem`，所有导航点击只通过按钮修改该状态。

**Step 3: 为右侧详情区增加统一标题与滚动容器**

确保每个设置分区共享一致的标题、副标题和内容边距。

**Step 4: 构建验证**

Run: `xcodebuild -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED

### Task 2: 调整通用设置页的信息层级

**Files:**
- Modify: `CalendarPro/Views/Settings/GeneralSettingsView.swift`

**Step 1: 将顶部文案改成摘要与状态卡片结构**

把当前散落的文本整理为简介说明和状态摘要块，提升可读性。

**Step 2: 优化状态信息的排版**

将地区、分隔符、显示项用更清晰的标签和值展示。

**Step 3: 构建验证**

Run: `xcodebuild -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED

### Task 3: 回归验证设置页导航和现有行为

**Files:**
- Verify: `CalendarPro/Views/Settings/SettingsRootView.swift`
- Verify: `CalendarPro/Views/Settings/GeneralSettingsView.swift`
- Verify: `CalendarPro/Views/Settings/MenuBarSettingsView.swift`
- Verify: `CalendarPro/Views/Settings/EventsSettingsView.swift`
- Verify: `CalendarPro/Views/Settings/RegionSettingsView.swift`

**Step 1: 运行测试**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'`
Expected: TEST SUCCEEDED

**Step 2: 检查设置窗口交互**

手动确认点击左侧导航项会切换右侧详情内容。

**Step 3: 保留必要后续项**

如果只剩视觉微调，不新增结构性改动，避免扩大范围。
