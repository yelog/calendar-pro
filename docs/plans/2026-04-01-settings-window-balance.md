# 设置窗口色彩平衡 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 统一设置窗口左右分栏的色彩基底和正文边距，修复当前左侧明显偏灰、右侧偏亮的布局失衡问题。

**Architecture:** 继续沿用现有自定义双栏 `SettingsRootView`，只调整容器层配色、分隔线强度和导航项状态样式。右侧各设置页保持业务结构不变，统一滚动内容区域的水平边距，并轻微降低卡片对比度。

**Tech Stack:** SwiftUI, AppKit semantic colors

---

### Task 1: 调整设置窗口外层壳层

**Files:**
- Modify: `CalendarPro/Views/Settings/SettingsRootView.swift`

**Step 1: 调整根容器背景与侧边栏边界**

将根背景统一为 `windowBackgroundColor`，移除显式 `Divider()`，改成侧边栏尾部的弱分隔线。

**Step 2: 收紧侧边栏视觉重量**

移除未选中导航项常驻描边，只保留选中态的浅色填充与描边。

**Step 3: 构建检查**

Run: `xcodebuild -project CalendarPro.xcodeproj -scheme CalendarPro -destination "platform=macOS" build`
Expected: BUILD SUCCEEDED

### Task 2: 统一右侧页面内容边距和卡片对比

**Files:**
- Modify: `CalendarPro/Views/Settings/GeneralSettingsView.swift`
- Modify: `CalendarPro/Views/Settings/MenuBarSettingsView.swift`
- Modify: `CalendarPro/Views/Settings/EventsSettingsView.swift`
- Modify: `CalendarPro/Views/Settings/RegionSettingsView.swift`

**Step 1: 统一滚动内容区边距**

将各设置页滚动内容统一到 30pt 左右边距，确保与标题区对齐。

**Step 2: 轻微减弱摘要卡片对比**

保留信息卡片结构，但减弱填充和描边强度，避免右侧再次显得过亮过硬。

**Step 3: 再次构建验证**

Run: `xcodebuild -project CalendarPro.xcodeproj -scheme CalendarPro -destination "platform=macOS" build`
Expected: BUILD SUCCEEDED
