# 提醒事项看板（Reminders Board）设计

- 日期：2026-10-16
- 分支：feat/reminders-board
- 状态：已实现（实现记录见 `2026-10-16-reminders-board.md`）

## 背景与目标

日历弹层已有「日程」分节展示选中日期的事件与提醒，但缺少跨日期的全局任务视角。
本设计在弹层内新增一个可折叠的「提醒事项看板」分节：聚合全部（不限日期）提醒事项，
支持按提醒列表 / 按优先级两种分组、完成态开关、两套时间着色体系与多套预设配色，
让用户一眼掌握逾期、今天、本周与远期任务。

## 需求

1. 弹层日程分节之后新增可折叠分节：默认收起，标题栏展示未完成总数，展开后内部
   ScrollView 限高（2026-10-17 起为 240pt，不含分节标题行）。
2. 数据：全量拉取启用的提醒列表中未完成的提醒事项；「显示已完成」开启时追加已完成项。
3. 分组模式：
   - `list`：按提醒列表名分组，组名排序，组头用列表颜色；
   - `priority`：按优先级档（高/中/低/无）分组，组头用优先级颜色，空档跳过。
4. 组内排序：有到期时间者按时间升序在前，无日期者靠后，同档按标题（不区分大小写）。
5. 颜色体系（两种模式）：
   - `overdue`：逾期 / 未逾期双色；
   - `timeBucket`：过去（今天零点前）、今天、本周（今天起 7 天内）、更晚四桶。
   - 恒定规则：无日期恒用 noDate 色；已完成恒用 completed 色。
6. 优先级映射：`EKReminder.priority` 0=无；1-3=高；4-6=中；7-9=低，纯函数实现；
   任务行以着色圆点作优先级标识。
7. 设置项（`MenuBarPreferences`）：开关、看板提醒列表勾选（空=全选，与现有归一
   语义一致）、分组模式、显示已完成、颜色模式、预设与逐色自定义。
   设置入口：设置窗口侧栏独立「提醒事项」页（`RemindersSettingsView`，
   位于「日程」之后；原「日程」页内的看板组已迁出）。
8. 配色预设：经典 / 暖色 / 冷色 / 高对比度 / 自定义；选中预设整套套用，
   逐色修改任意一色后预设自动转 `custom` 并持久化。
9. 任务行交互：完成勾选复用 `EventService.toggleReminderCompletion` 链路。
10. 文案：中文 key + xcstrings 补 en 翻译。

## 架构

```
RootPopoverView (@State boardReminders, loadBoard())
  └─ CalendarPopoverView (remindersBoardSection, 插在 eventsSection 之后)
       └─ RemindersBoardSection (折叠状态、分组渲染、勾选回调)
            └─ BoardSnapshot.make(...)   ← 纯函数布局，可测
EventService.fetchBoardReminders          ← 双查询取全量（复用 fetchReminders 思路）
MenuBarPreferences / SettingsStore        ← 设置模型与持久化
BoardColorPreferences / BoardColorPreset  ← 颜色模型与预设
```

### 数据层

`fetchBoardReminders(enabledCalendarIDs:includeCompleted:)`：
- 列表过滤与 `fetchReminders` 相同（空数组=全选）；
- 不限日期：`predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, ...)`；
- `includeCompleted` 为真时追加 `predicateForCompletedReminders(nil, nil, ...)`，
  按 `calendarItemIdentifier` 去重合并。

### 纯函数布局

`BoardSnapshot.make(reminders:now:calendar:groupingMode:colorMode:colorPreferences:showCompleted:)`
产出分组结构 + 未完成总数。时间桶以 `now` 所在自然日零点为界做日级比较，
避免小时内颜色抖动。

### 刷新链

RootPopoverView 在 onAppear、提醒授权变化、偏好变化、EventKit store 变化、
跨天（dayChangeRevision）与看板勾选后重取看板数据；`showRemindersBoard` 关闭
或未授权时清空。落地前按当前开关校验，避免过期数据回写。

## 权衡与备选

- 取数单查询 vs 双查询：选择与 `fetchReminders` 一致的双查询去重，行为可预期；
  已完成查询在开关关闭时不发起，避免全量历史拉取。
- 行模型携带 `EKReminder` vs 纯值 + id 反查：选择纯值（`RemindersBoardRow`），
  布局保持可 Equatable/可测；UI 层用字典按 id 反查 EKReminder 转发勾选回调。
- 时间桶「本周」按滚动 7 天窗口（今天零点起）而非自然周，语义与需求一致且实现简单。

## 风险

- 已完成提醒全量查询在大历史库下可能较慢：当前按需发起（开关关闭不查询），
  后续可加完成时间下界。
- `predicateForIncompleteReminders` 传 nil 边界依赖 EventKit 文档行为
  （nil 表示不设限），与既有 `fetchReminders` 的 nil-start 用法一致。

## 验收

- 全部单测通过（BoardSnapshotTests + SettingsStoreTests 新增用例）；
- 弹层出现可折叠分节，两种分组、两种着色、四套预设切换生效；
- 逐色修改后预设转自定义并重启保留；勾选完成即时刷新计数。

## 第四轮变更：完成闪烁保留显示（2026-10-17）

用户真机反馈：点击完成提醒事项后行立即消失，缺少「已记录完成」的感知。

- 新增设置项 `boardCompletedRetentionSeconds`（`MenuBarPreferences`，默认 3，
  旧 JSON 缺键解码走默认）；`RemindersSettingsView` 看板展示组新增
  「完成后保留显示」Picker：立即隐藏(0)/1/3/5/10 秒，xcstrings 补 en。
- 快照过滤纯函数化：`BoardSnapshot.make` 增加 `retentionSeconds`；
  未开启显示已完成时，`completionDate`（EventKit 原生完成时间，字段实名 completionDate）落在
  `now - retentionSeconds` 之后（严格大于）的已完成行保留展示并标记
  `isPendingHide`；超期、缺失 completionDate 或 retention=0 时维持旧行为立即隐藏。
  显示已完成模式下全部常驻，无待隐藏标志。
- 取数配套：`EventService.fetchBoardReminders` 增加
  `recentCompletedWindowStart`，关闭显示已完成时按完成时间窗口截断拉取
  已完成提醒，避免为 3 秒窗口拉取全量历史；保留行「到点隐藏」由
  `RootPopoverView.loadBoard` 落地后统一调度的延时重取完成（@MainActor
  Task，单任务句柄先取消防堆积）。
- UI：待隐藏行勾选框（仅勾选框）以 1 秒周期（0.5 淡出 + 0.5 淡入）闪烁，
  行划线与 completed 色样式不变。
- 测试：BoardSnapshotTests 补保留窗口四用例；MenuBarPreferencesTests 补
  默认值与旧 JSON 解码默认；SettingsStoreTests 补 setter 持久化。
