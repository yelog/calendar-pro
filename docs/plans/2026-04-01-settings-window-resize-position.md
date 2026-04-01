# Settings Window Resize And Position Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 让设置窗口支持原生缩放、保留上次尺寸，并在每次打开时居中到当前触发所在的屏幕。

**Architecture:** 在 `AppDelegate` 中把设置窗口行为收拢为“恢复尺寸 + 计算目标屏幕 + 手动居中”的窗口层逻辑，避免把多屏定位散落到 SwiftUI 视图里。`SettingsRootView` 只负责填满父窗口，`GeneralSettingsView` 和 `MenuBarSettingsView` 增加轻量响应式布局，保证最小窗口尺寸下仍可用。

**Tech Stack:** AppKit, SwiftUI, XCTest-compatible build verification

---

### Task 1: 打开设置窗口的原生缩放能力与屏幕居中逻辑

**Files:**
- Modify: `CalendarPro/App/AppDelegate.swift`

**Step 1: Write the failing test**

先在实现前明确需要满足：
- 设置窗口 style mask 含 `.resizable`
- 窗口已存在时再次打开会重新定位
- 目标屏幕不再依赖 `NSScreen.main`

**Step 2: Run build to capture current baseline**

Run: `xcodebuild -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED

**Step 3: Write minimal implementation**

在 `AppDelegate.swift`：
- 为设置窗口增加 `.resizable`
- 设置默认尺寸、最小尺寸
- 增加 frame autosave name
- 恢复 autosaved frame 后重新居中到目标屏幕
- 提取“获取目标屏幕”和“居中窗口到屏幕”的辅助函数

**Step 4: Run build to verify it passes**

Run: `xcodebuild -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add CalendarPro/App/AppDelegate.swift
git commit -m "feat(settings): support resizable settings window"
```

### Task 2: 移除视图层固定尺寸并补自适应布局

**Files:**
- Modify: `CalendarPro/Views/Settings/SettingsRootView.swift`
- Modify: `CalendarPro/Views/Settings/GeneralSettingsView.swift`
- Modify: `CalendarPro/Views/Settings/MenuBarSettingsView.swift`

**Step 1: Write the failing layout expectation**

先以实现目标为准：
- `SettingsRootView` 不再固定 `840x560`
- `GeneralSettingsView` 在窄宽度下可降为单列卡片
- `MenuBarSettingsView` 的显示项布局能在窄宽度下换行为上下结构

**Step 2: Run build to verify current layout compiles before edits**

Run: `xcodebuild -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED

**Step 3: Write minimal implementation**

在 SwiftUI 视图中：
- 让根视图充满父内容区
- 用 `GeometryReader` 或等价的宽度判断切换 `General` 网格列数
- 让 `MenuBar` 的每个 token 行按可用宽度切换布局

**Step 4: Run build to verify it passes**

Run: `xcodebuild -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add CalendarPro/Views/Settings/SettingsRootView.swift CalendarPro/Views/Settings/GeneralSettingsView.swift CalendarPro/Views/Settings/MenuBarSettingsView.swift
git commit -m "feat(settings): adapt settings layout to window resizing"
```

### Task 3: 文档与回归验证

**Files:**
- Modify: `docs/plans/2026-04-01-settings-window-resize-position-design.md`
- Modify: `docs/plans/2026-04-01-settings-window-resize-position.md`

**Step 1: Manual verification**

检查：
- 设置窗口可拉伸
- 关闭重开后尺寸保留
- 在扩展屏上打开时出现在当前屏幕中间
- 再次打开已存在窗口时也能回到当前屏幕中间
- `General` 与 `MenuBar` 页在最小尺寸下无重叠

**Step 2: Run build verification**

Run: `xcodebuild -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add docs/plans/2026-04-01-settings-window-resize-position-design.md docs/plans/2026-04-01-settings-window-resize-position.md CalendarPro/App/AppDelegate.swift CalendarPro/Views/Settings/SettingsRootView.swift CalendarPro/Views/Settings/GeneralSettingsView.swift CalendarPro/Views/Settings/MenuBarSettingsView.swift
git commit -m "feat(settings): center resizable window on active screen"
```
