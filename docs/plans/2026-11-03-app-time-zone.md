# 应用时区 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 实现 issue #9 的应用级时区设置及一致的日期显示、查询和编辑。

**Architecture:** SettingsStore 独立保存可选 IANA 标识，共享有效 Calendar/TimeZone。SwiftUI 使用宿主环境，Foundation 显式传参；EventKit 在边界层区分绝对时间与浮动/日期语义。编辑保持快照，刷新使用现有请求标识和时间协调器。

**Tech Stack:** Swift 6、SwiftUI、AppKit、Foundation、EventKit、XCTest。

---

### Task 1: 设置与上下文

创建 `CalendarPro/Infrastructure/AppTimeContext.swift`；修改 `CalendarPro/Settings/SettingsStore.swift`、`CalendarPro/Views/Settings/GeneralSettingsView.swift`、`CalendarPro/Views/Settings/SettingsRootView.swift`、`CalendarPro/Views/Settings/MenuBarSettingsView.swift` 与 `CalendarPro/Resources/Localizable.xcstrings`。

1. 添加时区持久化、有效时区/日历计算及搜索匹配测试。
2. 实现 nil=系统、校验 IANA、无效存储回退和可搜索选择器，显示所选时区当前时间。
3. 通过 `.appTimeContext(store)` 注入两个 SwiftUI 环境值；更新预览。

### Task 2: EventKit 边界

修改 `CalendarPro/Features/Events/CalendarItem.swift`、`EventService.swift`、`RemindersBoardModels.swift`；按需创建 `CalendarItemDateResolver.swift`，补充 `CalendarProTests/Events/` 测试。

1. 添加显式时区、floating、date-only 提醒以及全天事件映射测试。
2. 提供 `CalendarItem.startDate(using:)`、`endDate(using:)`、`timelineDate(using:)` 和共享日期解析器；保留旧属性以兼容既有测试，实时调用方改用显式日历。
3. 事件服务注入日历 provider；每次查询捕获同一快照，覆盖系统/应用窗口并按解析后日期过滤；排序/循环提醒使用同一日历。
4. 保存请求携带编辑日历和原始元信息，定时新建绑定时区，全天/floating 写入正确映射，仅改文字保留原始数据。
5. 提醒看板缓存纳入时区，解析和文本格式使用同一日历。

### Task 3: 详情与编辑器

修改 `CalendarPro/App/EventDetailWindowController.swift`、`CalendarPro/Views/Popover/EventDetailWindowView.swift`、`ReminderDetailWindowView.swift`、`CalendarItemComposerView.swift`；补充已有编辑器测试。

1. 控制器接受可选 SettingsStore（保留测试默认构造），详情通过环境实时更新。
2. 编辑器接受 `calendar: Calendar = .autoupdatingCurrent` 并捕获固定快照；详情和控件明确格式化时区。
3. 使用共享解析器回填浮动/全天日期，保存未修改范围和提醒原组件；显示编辑时区。

### Task 4: 应用集成与刷新

修改 `CalendarPro/App/AppDelegate.swift`、`StatusBarController.swift`、`PopoverController.swift`、`CalendarPro/Features/MenuBar/`、`CalendarPro/Views/RootPopoverView.swift`、`CalendarPopoverViewModel.swift` 及月历/时间轴/近期事项子视图。

1. 组合根注入同一 settings provider；新的设置发布接入显示、查询和协调器刷新。
2. 月历年月和用户选日按原年月日重建，跟随今天重新定位；异步旧结果失效。
3. 所有 UI 日期格式、时间轴定位、近期分组使用环境日历及显式解析接口。
4. 黄历、假期指南和番茄钟当日统计同步上下文，保留天气与节气领域规则。

### Task 5: 验证与记录

1. 新增源码/测试后运行 `ruby tools/generate_xcodeproj.rb`。
2. 运行 `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -derivedDataPath /tmp/calendar-pro-time-zone-derived-data -only-testing:CalendarProTests CODE_SIGNING_ALLOWED=NO`，预期相关测试通过；定位并说明任何原有无关失败。
3. 运行 UI 冒烟测试验证设置和主要界面；检查 `git diff --check`。
4. 更新设计/实施记录、跨天编辑时区假设和必要变更说明。本任务不执行 commit 或 push。

## 实施记录

### 提交前验证

按用户明确要求，将应用时区设置、UTC 偏移展示与偏移搜索作为一个逻辑提交。完整单元测试 533/533 通过（0 失败），结果包：`/tmp/calendar-pro-time-zone-locked-derived-data/Logs/Test/Test-CalendarPro-2026.11.03_17-32-56-+0800.xcresult`。本地化目录保留新增内容和既有译文，清除了 Xcode 生成的无关排序/格式变化；`git diff --check` 通过。UI 自动化运行环境限制见下方记录。

### 补充实施：按 UTC 偏移搜索

搜索文本纳入当前偏移标签，支持 `+8:00`、`UTC+8:00`、负偏移及半小时/四十五分钟偏移。筛选方法接收日期，界面传入与选项显示相同的 TimelineView 日期；沿用名称、IANA 搜索、大小写忽略及首尾空白处理。更新了中英文搜索提示，保留跟随系统入口。

新增 3 项测试覆盖东八区完整偏移匹配、UTC 前缀/大小写/空白、正负非整点与零偏移、无效偏移和纽约冬夏令时结果变化。SettingsStoreTests 与 AppTimeZoneIntegrationTests 共 60/60 通过，字符串目录校验及 `git diff --check` 通过。结果包：`/tmp/calendar-pro-time-zone-locked-derived-data/Logs/Test/Test-CalendarPro-2026.11.03_16-53-17-+0800.xcresult`。

手动检查：搜索 `+8:00` 与 `UTC+8:00` 应得到相同的命名时区列表，包含上海和新加坡、不含东京或 `UTC+8:45` 的 Eucla；再搜索 `+5:45`、`-3:30`，核对每行显示值与筛选输入一致。清空后恢复完整列表。

### 补充实施：时区选项显示 UTC 偏移

1. 在 `CalendarPro/Infrastructure/AppTimeContext.swift` 的 AppTimeZoneCatalog 添加接收明确日期的偏移格式化方法，使用该时区实际秒偏移生成 `UTC±H:mm`。
2. 在 `CalendarPro/Views/Settings/GeneralSettingsView.swift` 为全部选项（包括跟随系统）添加右侧偏移列和固定宽度的选中标记；列表共享每分钟更新的当前日期。
3. 在 `CalendarProTests/Settings/SettingsStoreTests.swift` 补充零、正负、半小时、四十五分钟、同一 IANA 时区冬夏差异的测试，运行 SettingsStoreTests 和 AppTimeZoneIntegrationTests；检查原生布局及 `git diff --check`。

此补充仅增强选项展示，不改变时区保存与选择逻辑，不增加源文件或依赖。

已完成。新增 2 项测试覆盖零、正负、半小时、四十五分钟、最大常用正偏移及纽约冬/夏令时；先验证测试缺少新 API 而失败，再实现格式化与界面。SettingsStoreTests 与 AppTimeZoneIntegrationTests 共 57/57 通过；原生下拉选项渲染探针 1/1 通过，检查了右侧偏移列与勾选对齐。临时探针已移除，未修改系统权限、版本或依赖。

截图：`/Users/yelog/.codex/visualizations/2026/11/03/01a1a061-8b86-7080-aa79-b1cfe2a95fb0/calendar-pro-time-zone-offset-picker.png`。相关测试结果包：`/tmp/calendar-pro-time-zone-locked-derived-data/Logs/Test/Test-CalendarPro-2026.11.03_16-37-48-+0800.xcresult`。

手动检查：打开通用设置的时区列表，确认跟随系统行显示实际系统偏移；搜索 Shanghai、Kathmandu、St_Johns 和 New_York，分别检查整数、45 分钟、负半小时偏移；勾选任一时区后偏移列应保持右对齐，关闭重开与搜索仍正常。

### 首轮实施

2026-11-03 完成全部功能代码及回归测试。新增 AppTimeContext、CalendarItemDateResolver 和 AppTimeZoneIntegrationTests。通用设置提供时区搜索、UTC 和跟随系统选项；状态栏、预览、月历、节假日、日程时间轴、近期列表、提醒看板与详情都使用明确上下文，编辑器固定打开时的快照。假期指南、黄历及番茄钟新统计的日期归属同步应用日历，已有统计不迁移。

保留现有版本 `0.2.8` / build `11`、依赖锁定和 scheme。已运行工程生成器；最终工程仅保留 3 个新增源码/测试文件的引用，避免生成器顺带重设版本或升级依赖。未修改 feed、appcast 或发布脚本，未 commit/push。

### 验证结果

- 聚焦测试：修复 SDK 边界后 254/254 通过。
- 最终完整单元测试：528/528 通过，0 失败、0 跳过。包含后续新增的 UTC、午夜发布顺序、不同来源日历的浮动提醒、夏令时及节假日民用日期回归。
- 原生 SwiftUI/AppKit 设置页渲染通过，已检查时区名称、IANA 标识、所选时区当前时间、中文格式及布局。临时渲染探针已移除，截图保存在工作区外的 Codex visualizations 目录。
- `git diff --check` 通过。测试未写入用户真实 EventKit 数据库，临时偏好域及应用已清理。

最终测试命令：

```bash
xcodebuild test -quiet \
  -project CalendarPro.xcodeproj -scheme CalendarPro \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/calendar-pro-time-zone-locked-derived-data \
  -onlyUsePackageVersionsFromResolvedFile \
  -only-testing:CalendarProTests \
  CONFIGURATION_BUILD_DIR=/tmp/calendar-pro-time-zone-native-render-products \
  CODE_SIGNING_ALLOWED=NO
```

结果包：`/tmp/calendar-pro-time-zone-locked-derived-data/Logs/Test/Test-CalendarPro-2026.11.03_16-26-58-+0800.xcresult`。

UI 测试已补充：搜索并切换时区、打开月历即时跨年刷新、重启后恢复，以及两个相差一天时区的年月显示。原始运行器缺少 XCTest.framework；仅在临时构建产物中修复加载路径和本地签名后，运行器仍在启用 macOS automation mode 时超时，未运行 UI 断言。原生控制的备用路径也因本机未授权 Accessibility 而不可用，未更改系统权限。相关问题亦见既有 2026-10-19 实施记录。

### 手动验收步骤

1. 运行新构建，打开通用设置，分别搜索并选择 Asia/Shanghai、America/Los_Angeles、UTC，再切回跟随系统；核对预览、状态栏与月历日期/星期一致，重启后保留选择。
2. 在日期边界附近验证今天高亮、近期分组、提醒看板及菜单栏提示同步更新；浏览另一个日期后换区，所选年月日应保留。
3. 使用可删除的测试日历/提醒清单，分别检查固定时区会议、floating 事件、单日/多日全天事件、日期提醒和定时提醒。在系统时区与应用时区不同时验证查询、详情与编辑显示一致。
4. 打开编辑器后修改全局时区，确认编辑器提示及控件仍用打开时快照。仅改标题/备注保存后，比较 EventKit 原始起止/时区或提醒日期组件；再主动修改日期，确认保存后仍在正确日期。
5. 验证定时与全天转换不会多覆盖一天；纽约夏令时不存在的时间应提示错误，重复时段保留实际持续时间。番茄钟剩余秒数不随换区变化。
6. 在具备 UI automation 权限的机器运行共享 scheme 的 CalendarProUITests，补充实际交互截图。真实 iCloud/Exchange 写入及同步未在本次自动验证范围内执行。
