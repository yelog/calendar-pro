# 菜单栏预览与真实菜单栏一致性实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 让“设置 → 菜单栏”中的预览在当前系统外观下尽量与右上角真实菜单栏显示一致。

**Architecture:** 抽出共享的菜单栏文本图像渲染器，统一真实 `NSStatusItem` 和设置页预览的绘制路径。设置页只补充一个轻量的菜单栏背景容器，用于贴近当前浅色或深色外观。

**Tech Stack:** Swift 6, SwiftUI, AppKit `NSStatusItem`, `NSImage`, `XCTest`

---

### Task 1: 抽取共享菜单栏文本渲染器

**Files:**
- Create: `CalendarPro/Features/MenuBar/MenuBarTextImageRenderer.swift`
- Modify: `CalendarPro/App/StatusBarController.swift`
- Test: `CalendarProTests/MenuBar/MenuBarTextImageRendererTests.swift`

**Steps:**
- 新建共享渲染器，接收文本和 `MenuBarTextStyle`，输出 `NSImage`。
- 在渲染器中保留 template image 与自定义彩色 image 的切换逻辑。
- 让 `StatusBarController` 改为调用共享渲染器，而不再内联绘制实现。
- 添加测试，覆盖默认模板模式、自定义文字色、填充背景三类行为。

### Task 2: 改造设置页菜单栏预览

**Files:**
- Modify: `CalendarPro/Views/Settings/MenuBarSettingsView.swift`
- Test: `CalendarProTests/MenuBar/ClockRenderServiceTests.swift`

**Steps:**
- 将顶部预览从 SwiftUI `Text` 改为共享渲染器生成的 `NSImage`。
- 使用当前 `colorScheme` 绘制浅色或深色菜单栏背景条。
- 保持现有文字内容来源和样式偏好不变。
- 仅保留真实菜单栏正常显示态，不模拟点击高亮态。

### Task 3: 验证与回归

**Files:**
- Verify only

**Steps:**
- 运行新增和相关菜单栏测试。
- 执行一次应用构建，确认共享渲染器接入后无编译问题。
- 手动检查设置页预览在浅色/深色模式、自定义文字色、填充背景下与真实菜单栏一致。

**Commands:**
- `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/MenuBarTextImageRendererTests -only-testing:CalendarProTests/ClockRenderServiceTests`
- `xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'`

**Manual Checks:**
- 打开“设置 → 菜单栏”，确认默认样式在当前系统外观下不再固定黑字。
- 切换系统浅色/深色模式，确认预览背景和字色随之变化。
- 开启自定义文字颜色和填充背景，确认预览与右上角真实菜单栏保持一致。
