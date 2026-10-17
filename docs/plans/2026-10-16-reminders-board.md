# 提醒事项看板实现记录

- 日期：2026-10-16
- 对应设计：`2026-10-16-reminders-board-design.md`
- 状态：已实现，构建与测试通过后补充验证细节

## 变更清单

新增：
- `CalendarPro/Settings/BoardColorPreferences.swift`：颜色偏好结构（12 色 hex）、
  颜色键枚举、预设枚举与四套预设配色。
- `CalendarPro/Features/Events/RemindersBoardModels.swift`：分组/颜色模式枚举、
  优先级映射、时间桶解析、`BoardSnapshot` 纯函数布局、hex 颜色互转。
- `CalendarPro/Views/Popover/RemindersBoardSection.swift`：可折叠分节视图。
- `CalendarProTests/Popover/BoardSnapshotTests.swift`：看板纯函数布局测试。

修改：
- `CalendarPro/Settings/MenuBarPreferences.swift`：新增 7 个看板字段
  （showRemindersBoard、boardEnabledReminderCalendarIDs、boardGroupingMode、
  boardShowCompleted、boardColorMode、boardColorPreferences、boardColorPreset），
  CodingKeys/decode（旧数据补默认）/encode 同步。
- `CalendarPro/Settings/SettingsStore.swift`：新增看板 setter（含列表勾选归一、
  预设套用、逐色转 custom）。
- `CalendarPro/Features/Events/EventService.swift`：新增
  `fetchBoardReminders(enabledCalendarIDs:includeCompleted:)`。
- `CalendarPro/Views/Popover/CalendarPopoverView.swift`：新增看板 props 与
  `remindersBoardSection`（插在日程分节之后）。
- `CalendarPro/Views/RootPopoverView.swift`：`@State boardReminders` + `loadBoard()`，
  挂接 onAppear / 提醒授权 / 偏好 / storeChangeRevision / 跨天刷新与勾选联动。
- `CalendarPro/Views/Settings/EventsSettingsView.swift`：新增「提醒看板」GroupBox
  （开关、列表勾选、分组模式、显示已完成、颜色模式、预设 Picker、颜色网格）。
- `CalendarPro/Resources/Localizable.xcstrings`：36 条中文 key 补 en 翻译。
- `CalendarProTests/Settings/SettingsStoreTests.swift`：看板字段持久化往返、
  列表勾选归一、旧版数据解码补默认等 6 个用例。

## 关键实现决策

1. `BoardSnapshot.make` 比委派签名多 `colorMode` / `colorPreferences` 两个入参：
   行着色属于布局产出（需求第 4 条），收入快照才能整体单测。
2. 行模型为纯值 `RemindersBoardRow`，不持有 `EKReminder`；勾选交互在
   `RemindersBoardSection` 内按 `calendarItemIdentifier` 反查后转发既有回调，
   不改动现有 eventsSection 行为。
3. 时间桶按日级比较（自然日零点），`today+7 天` 零点为 thisWeek 上界（不含第 8 天）。
4. 已完成查询仅在 `boardShowCompleted` 开启时发起，降低大历史库拉取成本。
5. `MenuBarPreferences` 新字段全部带属性默认值并走 `decodeIfPresent`，
   旧版持久化数据无需迁移。
6. 颜色以 `#RRGGBB` hex 存取：`NSColor→hex`（sRGB 归一）用于行模型与测试断言，
   `hex→Color` 扩展供 SwiftUI 渲染，解析失败回退中性灰。
7. 优先级映射独立为 `ReminderBoardPriority(ekPriority:)` 纯函数；
   既有 `ReminderDetailWindowView` 的旧映射（1-4/5/6-9）不在本次范围内，未改动。

## 预设配色取值表

| 键 | classic | warm | cool | highContrast |
| --- | --- | --- | --- | --- |
| overdue 逾期 | #DC2626 | #B91C1C | #DB2777 | #D70015 |
| notOverdue 未逾期 | #2563EB | #D97706 | #0284C7 | #0040DD |
| past 过去 | #DC2626 | #B91C1C | #DB2777 | #D70015 |
| today 今天 | #EA580C | #EA580C | #0891B2 | #C93400 |
| thisWeek 本周 | #2563EB | #CA8A04 | #2563EB | #0040DD |
| later 更晚 | #64748B | #78716C | #7C3AED | #5E5CE6 |
| noDate 无日期 | #9CA3AF | #A8A29E | #94A3B8 | #8E8E93 |
| priorityHigh 高优先级 | #DC2626 | #B91C1C | #DB2777 | #D70015 |
| priorityMedium 中优先级 | #EA580C | #EA580C | #0891B2 | #C93400 |
| priorityLow 低优先级 | #2563EB | #CA8A04 | #2563EB | #0040DD |
| priorityNone 无优先级 | #9CA3AF | #A8A29E | #94A3B8 | #8E8E93 |
| completed 已完成 | #9CA3AF | #A8A29E | #94A3B8 | #8E8E93 |

## 验收修复（2026-10-16 第二轮）

- 已完成行标题颜色：原用系统 Color.secondary，与勾选图标/到期标签的可配置
  completed 色不一致；现标题同样按 `Color(boardColorHex: row.colorHex)` 着色
  （保持划线），「已完成行划线并用 completed 色」对整行成立。
  测试侧补充断言：已完成且无日期的行取 completed 色而非 noDate 色
  （completed 优先级最高），行模型 colorHex 即标题渲染所用值。
- 版本号回退：regen 曾把 pbxproj 的 MARKETING_VERSION 0.2.6→1.0.0、
  CURRENT_PROJECT_VERSION 9→1，直接编辑恢复（未新增文件，未再 regen）。
- 低风险项：设置页颜色网格改为 stride 切行（奇数个数不越界）；分节快照
  每次渲染单次计算；到期格式器按（含时刻+语言）静态缓存；loadBoard 落地
  守卫补列表/已完成偏好快照比对（仿 loadEvents 过期校验）。

## 设置入口拆分（2026-10-16 第三轮）

用户反馈「两个新功能创建两个新的菜单」：看板设置从「日程」页拆出为侧栏
独立「提醒事项」页，原样迁移、不改功能逻辑。

- `CalendarPro/Views/Settings/RemindersSettingsView.swift`（新增）：承载原
  「提醒看板」GroupBox（开关、列表勾选、分组模式、显示已完成、颜色模式、
  预设 Picker、颜色网格）及配套绑定与 hex 转换；permissionRow 为本页复制
  的小工具（避免为迁移做跨文件重构）。
- `CalendarPro/Views/Settings/SettingsRootView.swift`：`SettingsSidebarItem`
  新增 `.reminders`（icon `checklist`，位于 `.events` 之后），
  detailView 挂接 RemindersSettingsView。
- `CalendarPro/Views/Settings/EventsSettingsView.swift`：移除「提醒看板」
  GroupBox 与看板专属绑定/分节，日程源与提醒列表设置保持不变。
- `CalendarPro/Resources/Localizable.xcstrings`：新增 3 条（Reminders、
  Manage Reminders Board、Reminders Detail Description），en/zh-Hans 双语。
- regen 后核对：Package.resolved 保持 Sparkle 2.9.1 未漂移；
  MARKETING_VERSION 0.2.6 / CURRENT_PROJECT_VERSION 9 已恢复。

## 验证

- `ruby tools/generate_xcodeproj.rb` 重建工程（新增源码与测试文件纳入）。
- `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro
  -destination 'platform=macOS' -derivedDataPath .dd` 全量通过
  （统计见提交记录与最终报告）。

## 完成闪烁保留显示（2026-10-17 第四轮）

- `CalendarPro/Features/Events/RemindersBoardModels.swift`：
  `RemindersBoardRow` 新增 `isPendingHide`；`BoardSnapshot.make` 增加
  `retentionSeconds` 参数与 `isWithinRetentionWindow` 纯函数判定。
- `CalendarPro/Features/Events/EventService.swift`：
  `fetchBoardReminders` 增加 `recentCompletedWindowStart`，完成态查询按
  `predicateForCompletedReminders(withCompletionDateStarting:)` 窗口截断。
- `CalendarPro/Settings/MenuBarPreferences.swift`：新增
  `boardCompletedRetentionSeconds`（默认 3）与 CodingKeys/解码兜底/编码。
- `CalendarPro/Settings/SettingsStore.swift`：新增
  `setBoardCompletedRetentionSeconds`。
- `CalendarPro/Views/Settings/RemindersSettingsView.swift`：看板展示组新增
  「完成后保留显示」Picker（0/1/3/5/10 秒）。
- `CalendarPro/Views/Popover/RemindersBoardSection.swift`：新增
  `completedRetentionSeconds` 入参与 `BlinkingCheckboxIcon`（1 秒周期闪烁）；
  待隐藏行仅勾选框闪烁，划线与 completed 色不变。
- `CalendarPro/Views/Popover/CalendarPopoverView.swift` /
  `CalendarPro/Views/RootPopoverView.swift`：透传设置；
  `loadBoard` 按窗口取数并在落地后调度 `scheduleBoardRetentionRefresh`
  （@MainActor Task，先取消旧任务防堆积；勾选完成、外部改动、弹层重开
  统一经 loadBoard 触发，保留期最后一批行到期即被重取移除）。
- `CalendarPro/Resources/Localizable.xcstrings`：新增 6 键
  （完成后保留显示/立即隐藏/1 秒/3 秒/5 秒/10 秒），en 双语。
- 测试：BoardSnapshotTests 4 个保留窗口用例、MenuBarPreferencesTests 2 个、
  SettingsStoreTests 1 个持久化用例与旧数据默认断言。
- 本轮未新增源码/测试文件，未跑 regen。

## 展开区限高统一 240pt（2026-10-17 第五轮）

用户反馈第七条：看板分节展开态内容区需限高 240pt、超出内部滚动。
核实现状：`RemindersBoardSection.boardContent` 已有等价机制
（内部 ScrollView + `frame(maxHeight:)`），原值 200pt，仅统一为 240pt；
收起态不渲染内容区，不受影响。

- `CalendarPro/Views/Popover/RemindersBoardSection.swift`：
  `Metrics.expandedMaxHeight` 200 → 240，注释与文件头同步。
- 与第四轮同文件，独立提交（fix(board)）。
