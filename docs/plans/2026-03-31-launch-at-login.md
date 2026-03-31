# 开机启动设置实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为 Calendar Pro 增加“登录后自动启动”设置，并在 macOS 系统层真实注册或取消注册当前应用

**Architecture:** 新增一个可注入的开机启动控制器封装 `SMAppService.mainApp`，由 `SettingsStore` 统一管理状态、错误提示和切换逻辑，设置页的“通用”页面只负责展示与触发

**Tech Stack:** SwiftUI, Combine, ServiceManagement, XCTest

---

### Task 1: 新增开机启动控制器抽象

**Files:**
- Create: `CalendarPro/App/LaunchAtLoginController.swift`

**Step 1: 定义协议和状态枚举**

创建 `LaunchAtLoginControlling` 协议，暴露读取当前状态和设置开关的方法，并定义用于 UI 显示的状态枚举。

**Step 2: 添加系统实现**

在同一文件中添加 `SystemLaunchAtLoginController`，内部使用 `SMAppService.mainApp.status`、`register()`、`unregister()` 完成状态查询与变更。

**Step 3: 添加状态文案映射**

把 `.enabled`、`.notRegistered`、`.requiresApproval`、`.notFound` 映射为稳定的内部状态，避免视图层直接依赖系统枚举。

### Task 2: 扩展 SettingsStore 管理开机启动状态

**Files:**
- Modify: `CalendarPro/Settings/SettingsStore.swift`

**Step 1: 增加发布状态**

新增：
- `@Published private(set) var launchAtLoginEnabled: Bool`
- `@Published private(set) var launchAtLoginStatusMessage: String?`

**Step 2: 注入 controller**

给 `SettingsStore` 增加 `launchAtLoginController` 依赖，默认使用系统实现，初始化时同步一次真实状态。

**Step 3: 实现切换方法**

新增 `setLaunchAtLoginEnabled(_:)`，内部执行系统注册调用，并在成功后刷新状态、失败后回滚和设置错误文案。

### Task 3: 在通用设置页新增 UI

**Files:**
- Modify: `CalendarPro/Views/Settings/GeneralSettingsView.swift`

**Step 1: 增加状态摘要卡片**

在现有摘要区中加入“开机启动”摘要，让通用页首页即可看见当前状态。

**Step 2: 新增启动行为分组**

增加新的 `GroupBox("启动行为")`，其中包含开关、辅助说明和错误提示文案。

**Step 3: 绑定 SettingsStore**

用自定义 `Binding` 接到 `store.launchAtLoginEnabled` 和 `store.setLaunchAtLoginEnabled(_:)`。

### Task 4: 补充单元测试

**Files:**
- Modify: `CalendarProTests/Settings/SettingsStoreTests.swift`
- Create: `CalendarProTests/App/LaunchAtLoginControllerTests.swift`

**Step 1: 为 SettingsStore 添加 fake controller**

在测试文件里增加 fake，实现可配置当前状态、下一次调用是否失败。

**Step 2: 覆盖状态同步与错误回滚**

新增测试覆盖：
- 初始化读取已开启状态
- 开启成功
- 关闭成功
- 开启失败回滚
- 关闭失败回滚

**Step 3: 覆盖状态映射**

为系统状态到内部状态的映射添加单测，确保 UI 文案依赖的状态稳定。

### Task 5: 项目集成与验证

**Files:**
- Modify: `CalendarPro.xcodeproj/project.pbxproj`

**Step 1: 将新增源码和测试文件加入 target**

把 `LaunchAtLoginController.swift` 和对应测试加入工程。

**Step 2: 运行测试**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'`
Expected: Tests passed

**Step 3: 运行构建**

Run: `xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'`
Expected: Build succeeded

## 执行说明

用户已明确要求直接实施，因此本计划在当前会话内继续执行，不额外停在计划评审阶段。
