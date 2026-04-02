# Remove Weather Feature Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 从应用中移除天气功能，并保持黄历与现有面板其它功能正常。

**Architecture:** 清理设置模型、popover 注入链路、天气服务与天气视图，并同步清理 Xcode 工程中的 WeatherKit 和定位配置；黄历相关对象保持不变。

**Tech Stack:** Swift, SwiftUI, Xcode project settings

---

### Task 1: 删除天气设置与状态

**Files:**
- Modify: `CalendarPro/Settings/MenuBarPreferences.swift`
- Modify: `CalendarPro/Settings/SettingsStore.swift`
- Modify: `CalendarPro/Views/Settings/GeneralSettingsView.swift`

### Task 2: 删除天气展示链路

**Files:**
- Modify: `CalendarPro/Views/Popover/CalendarPopoverView.swift`
- Modify: `CalendarPro/Views/RootPopoverView.swift`
- Delete: `CalendarPro/Features/Weather/WeatherService.swift`
- Delete: `CalendarPro/Views/Popover/WeatherStripView.swift`

### Task 3: 清理工程配置

**Files:**
- Modify: `CalendarPro.xcodeproj/project.pbxproj`
- Modify: `tools/generate_xcodeproj.rb`

### Task 4: 验证

**Files:**
- Verify only

Run:
- `rg -n "WeatherKit|showWeather|WeatherProvider|WeatherStripView|NSLocation" CalendarPro tools/generate_xcodeproj.rb CalendarPro.xcodeproj/project.pbxproj`
- `xcodebuild -project CalendarPro.xcodeproj -scheme CalendarPro -configuration Debug build`
