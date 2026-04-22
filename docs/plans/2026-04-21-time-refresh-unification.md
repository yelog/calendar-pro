# 时间刷新统一实施计划

**目标：** 为菜单栏、弹层时间线和“今天”相关渲染建立一个共享的本地时间刷新协调器。

**架构：** 新增 `TimeRefreshCoordinator` 作为主线程可观察服务，统一负责整分钟对齐、秒级刷新、系统时间通知和睡眠/激活后的立即重同步。现有视图订阅它的 `currentDate`，不再各自维护 timer。

**技术栈：** Swift 6、Combine、SwiftUI、AppKit notifications、XCTest。

**状态：** 已实施。

---

### Task 1: 共享协调器

**文件：**
- 新增：`CalendarPro/Infrastructure/TimeRefreshCoordinator.swift`
- 测试：`CalendarProTests/TimeRefreshCoordinatorTests.swift`

**步骤：**
1. 创建 `RefreshGranularity` 和 `TimeRefreshCoordinator`。
2. 提供 `currentDate`、`granularity`、`start()`、`stop()`、`setGranularity(_:)`、`refreshNow()`。
3. 分钟级刷新在每次触发后重新计算下一次整分钟边界。
4. 监听系统时钟、时区、跨天、应用激活、睡眠唤醒和会话激活通知。
5. 增加 delay 计算与通知刷新测试。

### Task 2: 菜单栏接入

**文件：**
- 修改：`CalendarPro/Features/MenuBar/MenuBarViewModel.swift`
- 修改：`CalendarPro/App/StatusBarController.swift`
- 测试：`CalendarProTests/MenuBar/MenuBarViewModelTests.swift`

**步骤：**
1. 将 `TimeRefreshCoordinator` 注入 `MenuBarViewModel`。
2. 用 coordinator 订阅替换本地 timer 调度。
3. 保留地区、设置变化后的重新渲染行为。
4. 从 `StatusBarController` 传入共享 coordinator。
5. 通过转发 helper 保留既有 `delayUntilNextMinuteBoundary` 测试覆盖。

### Task 3: 弹层接入

**文件：**
- 修改：`CalendarPro/App/PopoverController.swift`
- 修改：`CalendarPro/App/AppDelegate.swift`
- 修改：`CalendarPro/Views/RootPopoverView.swift`
- 修改：`CalendarPro/Views/Popover/CalendarPopoverView.swift`
- 修改：`CalendarPro/Views/Popover/EventListView.swift`
- 修改：`CalendarPro/Views/Popover/CalendarPopoverViewModel.swift`

**步骤：**
1. 将共享 coordinator 传入弹层根视图。
2. 用 coordinator 的 `currentDate` 处理回到今天、首次选中今天和月历今日高亮。
3. 移除 `EventListView` 本地 60 秒 timer。
4. 用共享 `currentDate` 驱动日程时间线 marker。
5. 弹层显示前立即刷新 coordinator。

### Task 4: 工程同步与验证

**文件：**
- 修改：`CalendarPro.xcodeproj/project.pbxproj`

**步骤：**
1. 因新增 Swift 文件，运行 `ruby tools/generate_xcodeproj.rb`。
2. 运行菜单栏、弹层 ViewModel、日程 item 和新 coordinator 的聚焦测试。
3. 运行跳过 UI 测试的全量单元测试。

**验证结果：**
- 聚焦测试通过。
- `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -derivedDataPath <tmp> -skip-testing:CalendarProUITests` 通过，187 个单元测试 0 失败。
