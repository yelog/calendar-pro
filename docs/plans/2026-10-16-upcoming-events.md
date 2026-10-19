# 近期日程版块实现记录

**日期：** 2026-10-16
**设计文档：** [2026-10-16-upcoming-events-design.md](2026-10-16-upcoming-events-design.md)

## 改动清单

### 新增

- `CalendarPro/Views/Popover/UpcomingEventsSection.swift`：
  `UpcomingSnapshot` 纯函数（按天分组升序 + 天头文案）与
  `UpcomingEventsSection` 可折叠分节视图（标题行 + 计数、内部滚动内容区、
  滚动到底自动加载、条目复用 `EventCardView`）。
- `CalendarProTests/Popover/UpcomingSnapshotTests.swift`：跨天分组升序、
  同一天全天在前/按时间排序、空输入、无开始日期条目忽略，以及
  `EventService.reminder(isDueWithin:)` 的窗口过滤与每日/每周递归近似展开用例。
- `docs/plans/2026-10-16-upcoming-events-design.md`、本实现记录。

### 修改

- `CalendarPro/Settings/MenuBarPreferences.swift`：新增 5 个字段
  （`showUpcomingSection` / `upcomingDayLimit` / `upcomingIncludeReminders` /
  `upcomingEnabledCalendarIDs` / `upcomingEnabledReminderCalendarIDs`），
  CodingKeys、解码缺省回退与编码同步补齐，默认构造与 preview 同步。
- `CalendarPro/Settings/SettingsStore.swift`：新增
  `setShowUpcomingSection` / `setUpcomingDayLimit` /
  `setUpcomingIncludeReminders` / `setUpcomingCalendarEnabled` /
  `setUpcomingReminderCalendarEnabled`，日历勾选沿用"空数组=全选"归一逻辑。
- `CalendarPro/Features/Events/EventService.swift`：新增
  `fetchUpcomingCalendarItems` 与私有 `fetchUpcomingReminders`；
  静态 `reminder(_:isDueWithin:windowEnd:calendar:)` 复用单日递归判定
  `isOccurrence` 做按天近似展开。
- `CalendarPro/Views/Popover/CalendarPopoverView.swift`：新增 5 个入参与
  `onLoadMoreUpcoming` 回调，在 `eventsSection` 之后插入新分节；
  现有日程分节行为不变。
- `CalendarPro/Views/RootPopoverView.swift`：新增
  `upcomingItems` / `isLoadingUpcoming` / `upcomingWindowDays` /
  `upcomingRequestID` 状态与 `loadUpcoming` / `handleLoadMoreUpcoming` /
  `clearLoadedUpcoming`；onAppear、授权变化、设置变化、store 变更、
  选中日期变化、跨天均触发重取；提醒完成切换后同步刷新。
- `CalendarPro/Views/Settings/EventsSettingsView.swift`：新增「未来日程」
  分组（开关、时间上限 Picker、包含提醒 Toggle、日历勾选组、
  提醒列表勾选组）及对应 Binding。
- `CalendarPro/Resources/Localizable.xcstrings`：新增 13 个 key 的
  en 与 zh-Hans 文案（`Upcoming Events`、`Show Upcoming Section` 等）。
- `CalendarProTests/Settings/SettingsStoreTests.swift`：新增未来日程设置
  持久化往返与"重新勾选恢复空数组=全选"两个用例。
- `CalendarProTests/Settings/MenuBarPreferencesTests.swift`：新增默认值与
  旧数据解码回退两个用例。
- `CalendarProTests/MenuBar/ClockRenderServiceTests.swift`：4 处
  `MenuBarPreferences` 成员逐一构造补齐新字段（成员逐一初始化器变更的连带修复）。
- `CalendarPro.xcodeproj`：`ruby tools/generate_xcodeproj.rb` 重建，纳入新文件。

## 验证

```bash
ruby tools/generate_xcodeproj.rb
xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro \
  -destination 'platform=macOS' -derivedDataPath .dd
# BUILD SUCCEEDED

xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro \
  -destination 'platform=macOS' -derivedDataPath .dd
# CalendarProTests.xctest: Executed 385 tests, with 0 failures (0 unexpected)
# CalendarProUITests.xctest: 1 test passed
# TEST SUCCEEDED
```

备注：首次完整运行时 UI 用例 `testPopoverRendersMonthNavigation` 在应用启动
`runningForeground` 等待处超时（尚未触及弹层断言），单独重跑与随后完整重跑均
通过，判定为启动激活时序抖动，与本功能无关。

## 验收修复记录（2026-10-16）

验收审查确认两项问题，本节记录修复：

- pbxproj 版本号回退：重建工程时 `tools/generate_xcodeproj.rb` 写死
  `MARKETING_VERSION = 1.0.0` / `CURRENT_PROJECT_VERSION = 1`，覆盖了上游
  直接维护的 0.2.6/9。修复为直接编辑 `project.pbxproj` 四处恢复
  0.2.6/9（未再跑 regen，未改动上游脚本；注意后续再重建工程需先修正脚本
  版本号来源，此处不代改）。
- 多天事件产生过去天组：EventKit 窗口谓词为重叠语义，原过滤只查
  `endDate > now`，开始早于今天未结束的多天事件会进入列表并按其 startDate
  分出过去天组。修复为按设计语义补 `startDate >= 窗口起点`，逻辑抽为静态
  纯函数 `EventService.event(_:isWithinUpcomingWindow:now:enabledCalendarIDs:)`
  （未挂载日历的事件仅在“全部日历”语义下纳入，避免夹具强解包），
  并补 3 条单测覆盖“昨天开始今天未结束”“昨天开始明天结束”排除与
  “今天开始进行中”保留。
- 顺带（低severity）：`UpcomingEventsSection` 的快照改为 body 内单次求值，
  标题计数与展开内容共用同一份分组结果，避免重复排序分组。

验证：`xcodebuild build` 热身后单测
`Executed 388 tests, with 0 failures (0 unexpected)`（含 3 条新边界用例）。
UI 用例因本机 Runner 冷启动被杀（testmanagerd 提前终止，属既有环境问题，
与本次改动无关，UI 测试代码未变动）未能运行，如实记录。

## 滚动自动加载改造（2026-10-16）

分页触发从「点击底部加载更多按钮」改为「滚动到底自动加载」，窗口渐进扩展
逻辑（首窗 30 天，每次 +30 天至上限 30/90/180/全部）不变：

- `UpcomingEventsSection`：列表容器由 `VStack` 改为 `LazyVStack`（普通
  VStack 一次性物化全部子视图，末尾哨兵的 onAppear 会在展开瞬间立即触发）；
  移除「加载更多」按钮，改为末尾 1pt `Color.clear` 哨兵挂 `onAppear` 触发
  扩窗回调。加载中哨兵被进度指示替换、达上限时 `hasMore` 为 false，两种
  情况哨兵都不在视图层级内防重复触发；一次加载结束后哨兵重新插入并再次
  触发 onAppear，内容不足一屏时连续加载至占满视口或达上限。
- `RootPopoverView.handleLoadMoreUpcoming`：新增 `isLoadingUpcoming`
  在-flight 守卫（既有 `upcomingRequestID` 竞态守卫不变）。
- `Localizable.xcstrings`：删除不再被引用的 `Load More` key（en 与 zh-Hans）。

验证：`xcodebuild build` 热身后
`xcodebuild test ... -skip-testing:CalendarProUITests`，单测
`Executed 388 tests, with 0 failures (0 unexpected)`，TEST SUCCEEDED；
UI 测试因本机 Runner 环境问题按基线跳过（与本次改动无关，UI 测试代码未
变动），触发链路以人工滚动验证为准。

## 近期日程五项改造（2026-10-16 第二批）

在滚动自动加载（f445374）基础上完成五项变更，逐项独立提交：

### 1. 更名「未来日程」→「近期日程」（commit 4d34c20）

- `Localizable.xcstrings`：版块相关 10 个含 Upcoming 的用户可见 key 全部
  更名（`Upcoming Events`→`Recent Events` 等），en/zh-Hans 取值同步，
  「未来日程」措辞统一改为「近期日程」；菜单栏「即将到来」指示器
  （`UpcomingEventMonitor` 的 `Upcoming` key）属独立功能不更名。
- 代码标识符（`UpcomingEventsSection`、`upcomingDayLimit` 等）与 JSON
  存储字段名不动，避免破坏已存用户设置解码。

### 2. 带时间提醒默认包含（commit 81a4ab0）

- `upcomingIncludeReminders` 默认值 false→true（默认构造、preview、解码
  回退三处）。解码兼容：已存 JSON 显式 false 经 `decodeIfPresent` 保持
  false，仅缺失 key 的历史数据与新用户走 true。
- 勾选路径核验（读码结论，无 bug）：`fetchUpcomingCalendarItems` 的
  includeReminders 分支 → `fetchUpcomingReminders`（未完成过滤、
  `predicateForIncompleteReminders` 起始 nil 兜递归基准、本地窗口过滤、
  按 `calendarItemIdentifier` 去重）→ 设置页开关经
  `setUpcomingIncludeReminders` → `loadUpcoming` 生效，提醒列表勾选组
  仅在开关开启时显示。

### 3. 设置拆页（commit f174d60）

- 新增 `UpcomingEventsSettingsView.swift` 原样迁移近期日程设置组；
  `EventsSettingsView` 移除该组（保留菜单栏指示器设置，属菜单栏功能）；
  `SettingsSidebarItem` 新增 upcoming 项（日程之后，clock 图标）。
- 新增 `Configure Recent Events` / `Recent Events Detail Description`
  两个 key；`ruby tools/generate_xcodeproj.rb` 重建工程。
- regen 副作用核对：脚本写死的 MARKETING_VERSION/CURRENT_PROJECT_VERSION
  覆盖为 1.0.0/1，已直接改回 0.2.6/9；Package.resolved 本次为被删除
  （非上批的 Sparkle 升版），已按原样恢复，Sparkle 保持 2.9.1 未漂移；
  scheme 差异仅为 regen 目标 UUID 轮换，与既往 regen 提交一致。

### 4. 默认展开可配置（commit 035aa41）

- 新增 `upcomingDefaultExpanded`（默认 true），解码回退/编码/CodingKeys
  同步；属性带默认值，既有成员逐一构造调用点零改动。
- `UpcomingEventsSection` 显式 init 以 `State(initialValue:)` 取设置值，
  弹层重开按设置取初态，会话内手动折叠不持久化；「近期日程」设置页
  新增「默认展开版块」开关。（实现描述修正：`State(initialValue:)` 只在
  视图首次创建时生效，弹层重开取新设置值实际由 body 的 onAppear 重置
  展开态实现，见下文「验收修复记录（第二批）」。）

### 5. 双向窗口 + 打开刷新（commit 35f7bd2）

- 窗口模型 [今天, 今天+N] → [pastStart, futureEnd]：初始 pastStart=
  今天零点；`RootPopoverView` 以 `upcomingPastDays/upcomingFutureDays`
  两个 `@State` 记端点，弹层重开保留已扩展端点、只重取数据。
- `EventService.fetchUpcomingCalendarItems` 入参改 pastStart/futureEnd；
  静态过滤 `event(isWithinUpcomingWindow:)` 去掉 `endDate > now` 守卫
  （改 `endDate > windowStart` 挡异常时长），窗口内已结束事件纳入以
  支持回看过去；开始早于过去端点的多天事件仍整体排除。该调整超出委派
  书「不改函数本身」的字面要求：若保留 `endDate > now`，已结束的过去
  事件永远被过滤，「上滚查看过去日程」不成立（初始 pastStart=今天零点
  也将失去意义），故做最小语义适配并在函数头注明。
- 顶部对称 1pt 哨兵向过去扩窗（每次 -30 天，无天数硬上限），底部哨兵
  向未来扩窗与设置上限不变；两端各自 isLoading/达界防重：过去端以
  「扩窗带不回条目即视为历史起点」置 `isUpcomingPastExhausted`（数据源/
  设置变化与跨天复位），未来端沿用 dayLimit hasMore；加载中哨兵被进度
  行替换 + in-flight 忽略触发，全量重查天然串行化，请求 ID 竞态守卫不变。
- `UpcomingSnapshot` 过去天同样分组，新增「昨天」天头（`Recent Yesterday`）。
- 打开刷新核验（读码结论）：`PopoverController` 一次性创建并复用
  contentViewController，弹层每次 show 时内容视图重新挂载触发
  `RootPopoverView.onAppear → loadUpcoming()` 重取，属既有链路未改；
  已扩展端点因 `@State` 存活而保留。属静态核验，未做真机弹层时序验证。

### 新增测试

- `MenuBarPreferencesTests`：显式 false 解码保留 1 条；默认值/旧数据
  回退断言补 `upcomingIncludeReminders=true`、`upcomingDefaultExpanded`。
- `SettingsStoreTests`：持久化往返补包含提醒翻转与默认展开字段。
- `UpcomingSnapshotTests`：过去天组与未来天组升序共存、昨天天头文案、
  多天事件在开始日所在组单次展示 3 条；窗口过滤新增「过去端点扩展后
  已结束事件纳入」，原 3 条改签名后断言不变。

## 近期日程五项改造验证

```bash
xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro \
  -destination 'platform=macOS' -derivedDataPath .dd
# BUILD SUCCEEDED（每批次提交前均单独通过）

xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro \
  -destination 'platform=macOS' -derivedDataPath .dd \
  -skip-testing:CalendarProUITests
# Executed 393 tests, with 0 failures (0 unexpected)（基线 388 + 新增 5）
```

UI 测试因本机 Runner 环境问题按基线跳过（与本次改动无关，UI 测试代码
未变动）；弹层滚动加载链路以人工验证为准。

## 验收修复记录（第二批，2026-10-16）

动态工作流验收核实三项问题，逐项独立提交修复：

### 1. en 文案残留（commit bc905f6）

- `Localizable.xcstrings`：key `Choose Calendars for Recent` 的 en 值
  `Choose Calendars for Upcoming` 改为 `Choose Calendars for Recent
  Events`；key `Choose Reminder Lists for Recent` 同理改为 `Choose
  Reminder Lists for Recent Events`。为第二批更名时的漏改项，
  zh-Hans 取值本就正确不动。

### 2. 默认展开设置弹层重开不生效（commit 532971d）

- 根因（验收探针证实）：`PopoverController` 一次性创建并复用
  `PopoverSizingHostingController`，弹层重开时 `UpcomingEventsSection`
  视图实例存活，`State(initialValue:)` 只在视图首次创建时取值；
  onAppear 虽重新触发但 `@State` 不重置。
- 修法：`UpcomingEventsSection` body 挂 onAppear（内容视图重新挂载即
  触发），按传入的 `defaultExpanded` 重置 `isExpanded`。分节视图此前
  未挂 onAppear（哨兵的 onAppear 是子视图私有修饰），无合并冲突。
  打开期间手动折叠不触发 onAppear，不受影响——弹层每次打开取设置
  初值、打开期间手动折叠即时生效的语义不变。
- 同步修正代码状态注释、init 函数头与本记录第 4 条中「视图重建时
  重新取初值」的不准确描述。

### 3. dayLimit=0 未来端哨兵无限循环（commit cd9a66f）

- 根因（验收核实）：dayLimit=0 时 `hasMoreFuture` 恒 true，扩窗带不回
  新条目时哨兵重新插入再触发，永久 Loading 且 EventKit 查询窗口
  越滚越大。
- 修法（与过去端 `isUpcomingPastExhausted` 对称）：
  - `RootPopoverView` 新增纯函数
    `isUpcomingFutureWindowExhausted(items:previousFutureEnd:newFutureEnd:)`：
    本轮扩窗带不回任何开始日期落在扩展区间 [旧端点, 新端点) 内的
    条目时置位（左闭右开；无开始日期条目不参与判定）。
  - `loadUpcoming` 增加 `futureExtensionBoundary` 参数（与过去端
    `pastExtensionBoundary` 对称），`handleLoadMoreUpcomingFuture`
    扩窗前捕获旧未来端点传入，结果到达后据此置位/保留标记。
  - 复位时机与过去端完全一致：授权变化、提醒授权变化、设置变化、
    store 变更、跨天共 5 处（选中日期变化两端均不复位，保持对称）。
  - `UpcomingEventsSection` 新增 `hasMoreFuture` 入参（exhaustion
    来源，与 `hasMorePast` 同型）；原 dayLimit 组合判定改名
    `canLoadMoreFuture = hasMoreFuture && (dayLimit == 0 ||
    windowDays < dayLimit)`，哨兵渲染分支与 onAppear 守卫随之收紧；
    `CalendarPopoverView` 透传 `hasMoreUpcomingFuture`。
- 可测性评估：判定逻辑可纯函数化（输入条目数组 + 区间两端，无
  `@State` 依赖），已抽为静态函数并补 6 条单测：区间命中不达界、
  全旧条目达界、空结果达界、左闭端点计入、右开端点不计入、无开始
  日期条目忽略。
- 已知取舍（PR 说明用）：未来端存在超过一个扩窗步幅（30 天）空档的
  事件时提前停止加载，与过去端「带不回即历史起点」启发式对称，仅
  无限制（dayLimit=0）模式受影响。
- 明确不改项：长多天事件跨扩窗边界误触发过去端 exhaustion 属已裁定
  的可接受取舍，本批未动其过滤语义。

### 验证

```bash
xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro \
  -destination 'platform=macOS' -derivedDataPath .dd
# BUILD SUCCEEDED（三批改动各提交前均单独通过）

xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro \
  -destination 'platform=macOS' -derivedDataPath .dd \
  -skip-testing:CalendarProUITests
# Executed 405 tests, with 0 failures (0 unexpected)
```

备注：基线 3f041df 实际含 399 条测试函数（此前记录的 393 为上一批
当时的数字，其后批次的用例增量未回填），405 = 399 + 本批新增 6 条，
`xcodebuild` 总数与源码 `func test` 计数一致，无跳过或统计口径差异。
已知的偶发 flaky 用例 `testStoreChangeRevisionIncrementsOnNotification`
本轮未复现。UI 测试按基线跳过（本机 Runner 环境问题，UI 测试代码未
变动）；弹层重开展开态与无限循环链路以人工验证为准。

## 条数分页交互模型重构（2026-10-17）

针对用户三条反馈（打开即自动连续加载=默认加载全部；改为每页 10 条的
条数分页；弹层打开重置到第一页并回顶），把「双向时间窗渐进」重构为
「条数分页」，推翻时间窗渐进与端点跨打开保留两项旧决定：

### 数据层（RootPopoverView）

- 状态更换：`upcomingPastDays/upcomingFutureDays`（窗口天数）与
  `isUpcomingPastExhausted/isUpcomingFutureExhausted`（达界标记）删除，
  改为 `upcomingFutureCursor/upcomingPastCursor`（下一页查询窗边界游标，
  nil=该方向尽头）与 `upcomingResetGeneration`（重置代数，驱动分节
  回滚滚动位置）。
- 新增纯静态函数 `advanceUpcomingPage(direction:windowItems:windowStart:
  windowEnd:collectedCount:loadedIdentifiers:pageSize:futureLimitEnd:
  isResumingWindow:)`（显式 nonisolated，供单测非主线程调用）：单窗
  切片 + 游标推进一并输出（本窗取走条目/窗内去重前条数/页满标记 +
  下一窗游标 + 是否尽头）。原 `isUpcomingFutureWindowExhausted` 删除。
- 页装配循环 `loadUpcomingPage(direction:)`：从游标起逐 30 天窗查询
  （EventKit 薄层沿用 `fetchUpcomingCalendarItems` 谓词与过滤，窗口
  半开区间逐窗平铺），每窗过一遍纯函数，直到凑满 10 条、探明尽头或
  触达单页 12 窗循环上限（仍未凑满返回已有并视为尽头）。页满时游标
  停在当前窗起点，下一页复查同一窗按 `selectionIdentifier` 身份去重
  续接页界——页界同刻条目不重不漏；递归提醒逐窗重复返回同一对象
  同样被身份去重吸收，且「仅含重复的过去窗」不算空窗尽头。
- 未来尽头=游标触达设置上限（30/90/180/全部换算绝对日期，0=无界）；
  过去端无下限，空窗即尽头（沿用原启发式），页满后的同窗复查零新
  条目不算尽头。多天事件语义沿用：`startDate` 早于窗起点的多天事件
  不纳入（现行过滤不变），过去页铺开后在其开始日分组出现。
- `resetUpcomingPaginationAndLoadFirstPage()`：清空条目、两端游标回到
  当天零点、递增重置代数并装载第一页（未来方向从当天零点起 10 条，
  含今天全天；过去方向初始 0 条）。授权/提醒授权/设置/store 变更与
  跨天的重取统一走本方法；选中日期变化不再触碰近期日程（内容与选日
  无关，原 `loadUpcoming()` 调用删除）；提醒勾选完成改为从已加载分页
  中按身份移除（游标与滚动位置不动，全量重取留给下次打开/刷新）。

### 交互层（UpcomingEventsSection / CalendarPopoverView）

- 顶部自动哨兵（`loadPastTrigger`）删除；改为顶部常驻锚（GeometryReader
  偏移探针 + 回顶目标）+ 状态行：加载中显示进度，否则尚有更早条目时
  显示"下拉加载更早日程"提示（新增本地化 key
  `Pull Down to Load Earlier Events`，en/zh-Hans 同步）。
- 下拉过拉检测：探针读顶部锚在滚动坐标空间的 minY，超过约 40 pt 且
  已武装时触发一次 `onLoadMorePast`，触发后解除武装、回弹到阈值内
  重新武装（加载中不触发）。选型说明：`onScrollGeometryChange` 需
  macOS 15+（编译探针证实），工程部署目标 14.0，故用 GeometryReader
  探针。
- 底部哨兵沿用，`canLoadMoreFuture`（dayLimit 组合判定）简化为
  `hasMoreFuture`（尽头判定已含设置上限与循环保护）。
- 弹层打开重置：分节 `onAppear`（重挂载触发）合并展开态重置与分页
  重置（先重置分页再触发首载，均在 `onResetPagination` 回调内完成）；
  `onChange(of: resetGeneration)` 驱动 `ScrollViewReader` 显式
  `scrollTo` 回到列表顶锚（数据重置后偏移残留的修正）。
- 透传层：`upcomingWindowDays/upcomingDayLimit` 两入参删除，新增
  `upcomingResetGeneration` 与 `onResetUpcomingPagination`；
  `hasMoreUpcomingPast/Future` 语义改为「游标非 nil」。

### 测试

- `UpcomingSnapshotTests`：删除 6 条未来端扩窗达界用例；新增 12 条
  分页切片/游标推进用例：页满复查同窗、稀疏窗推进、未来空窗不尽头、
  上限尽头、跨页续接跳过已加载、同刻条目跨页界不重不漏、过去向取
  最近一批、过去空窗尽头、仅含已加载递归提醒的过去窗推进、复查窗
  零新条目推进、过去窗耗尽推进、页大小边界（已满不取）。

### 验证

```bash
xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro \
  -destination 'platform=macOS' -derivedDataPath .dd
# BUILD SUCCEEDED

xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro \
  -destination 'platform=macOS' -derivedDataPath .dd \
  -skip-testing:CalendarProUITests
# Executed 411 tests, with 0 failures (0 unexpected)
```

备注：411 = 基线 405 − 删除 6（扩窗达界）+ 新增 12（分页切片/游标）。
已知 flaky 用例 `testStoreChangeRevisionIncrementsOnNotification` 本轮
未复现。UI 测试按基线跳过（本机 Runner 环境问题，UI 测试代码未变动）。
下拉过拉触发、弹层打开重置与回顶属运行时交互链路，静态验证编译与
单测覆盖纯函数部分，交互链路以人工验证为准（无新增源文件，未跑 regen）。

## 条数分页验收修复（2026-10-17 第三批）

增量验收工作流核实三条问题（均为条数分页重构 48d2b4a 引入或暴露），
逐项独立提交修复：

### 1. 双方向共享竞态 ID 导致并发互相作废（commit faeb199）

- 根因：单一 `upcomingRequestID` 被两方向共享，各方向入口只 guard 自己
  的 isLoading，跨方向不互斥；后发加载无条件覆盖共享 ID，先发方向完成
  块竞态校验失败后连同 isLoading 复位一起跳过——先发方向永久 Loading
  （哨兵/下拉入口被守卫拦截，直至弹层重开才恢复）。
- 修法：ID 拆为 `upcomingPastRequestID` / `upcomingFutureRequestID` 两
  个方向竞态域，各方向入口自增自己的 ID、完成块只校验并复位本方向的
  游标与在途标记，跨方向互不作废；重置（`resetUpcomingPaginationAnd
  LoadFirstPage`）与清空（`clearLoadedUpcoming`）统一递增两个 ID 作废
  所有在途加载。两方向真并发（下拉加载过去的同时哨兵加载未来）成为
  合法状态，各自的进度行/哨兵互不干扰。首屏第一页装载属未来方向域
  （从当天零点起），用 future ID。

### 2. 过去方向页满游标跳窗，丢窗内剩余条目（commit 7c3aa6d）

- 根因（数值复现）：`advanceUpcomingPage` 页满分支对两方向统一返回
  `nextWindowStart = windowStart`，但过去窗为 [windowStart, windowEnd)
  且游标=窗上界——页满后下一次查询窗变为 [windowStart-30天, windowStart)，
  本窗剩余条目（单窗 12 条取走 10 条剩 2 条）永不复查，且下一窗为空会
  误判历史尽头（missing 2 条）；未来方向同场景正常。
- 修法（方向感知的页满复查游标）：页满分支未来方向复查游标=windowStart
  （现状正确，回归对照），过去方向复查游标=windowEnd（复查同一窗）。
- 契约修正：页满即退出装配循环（collected.count 达页大小先于循环条件
  判断失效），`isResumingWindow` 在生产接线的复查路径此前恒为 false，
  纯函数「复查窗零新条目不算过去端尽头」的豁免分支永不可达。新增分
  方向 `isUpcomingPastResumingWindow` / `isUpcomingFutureResumingWindow`
  状态：上一次页装配以页满收尾（未尽头）时由完成块置位，下一次装载
  首窗按同窗复查处理；复查耗尽、尽头或触达循环上限收尾时归 false；
  重置/清空归 false。同刻与页界条目由 `loadedIdentifiers` 身份去重吸收。
- 测试：新增 3 条（套件 27→30）。`testPastPageFullResumesWindowAt
  WindowEnd`（纯函数过去方向页满 nextWindowStart==windowEnd）；`testPast
  CrossPullRetrievesAllItemsFromSingleWindow`（镜像生产循环替身
  `mirrorLoadPage` 跑两轮下拉：单窗 12 条第一拉取 10 条页满、第二拉复
  查同窗拿剩余 2 条拿全 12 条，修复前第二拉带不回任何条目即误判尽头，
  修复后尽头判定在更早空窗处才成立）；`testFutureCrossPullRetrieves
  AllItemsFromSingleWindow`（未来方向同场景回归对照，复查后触达设置
  上限判尽头）。替身与生产循环的窗界构造/循环条件/标记传递逐一镜像，
  生产 @State 接线本身无法单测。

### 3. 空态分支丢失下拉入口（commit f3c0e38）

- 根因：items 为空且不在加载时渲染静态空态 Text，整个 ScrollView（含
  GeometryReader 下拉探针与过去端提示行）不进视图层级——未来无条目
  （首屏+360 天全空）时无法下拉加载过去。
- 修法：空态文案移入 ScrollView 内渲染（列表顶部行之后，抽为
  `emptyStateRow`），下拉探针、提示行与底部哨兵照常挂载；过去方向
  加载回来条目后正常进按天分组列表。加载中仍显示进度行、空态文案
  暂隐，与既有分支语义一致。

### 验证

```bash
xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro \
  -destination 'platform=macOS' -derivedDataPath .dd
# BUILD SUCCEEDED（三个修复各提交前均单独通过）

xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro \
  -destination 'platform=macOS' -derivedDataPath .dd \
  -skip-testing:CalendarProUITests
# Executed 414 tests, with 0 failures (0 unexpected)
```

备注：414 = 基线 411 + 本批新增 3。已知 flaky 用例
`testStoreChangeRevisionIncrementsOnNotification` 本轮未复现。UI 测试
按基线跳过（本机 Runner 环境问题，UI 测试代码未变动）。无新增源文件，
未跑 regen。

### 人工验证项（@State/视图编排层无法单测）

- 修复 1：下拉加载过去的进行中触发底部哨兵（或反向），两方向互不
  作废、各自 Loading 正常收尾；加载中改设置/授权/跨天，在途结果被
  丢弃且无永久 Loading。
- 修复 2：单窗条目数超过页大小（如一天内 12 个事件）时下拉两次能
  拿全 12 条、不出现「提前无更早」；未来方向连续滚动回归正常。
- 修复 3：未来无任何条目的日历，展开近期日程显示空态文案与「下拉
  加载更早日程」提示，下拉能加载过去条目。

## 未确定项 / 后续可迭代

- 下拉过拉触发、打开重置回顶等交互链路以人工验证为准（见上）。
- 递归提醒按天近似展开（见设计文档限制），如需精确支持例外日期需引入
  EventKit 逐展开查询或本地完整递归求解。

## 用户反馈批次二（2026-10-17：六项）

用户真机反馈与代码质量点名，六项逐项独立提交：

### 1. 更名「近期日程」→「全部日程」（commit 239aeb3）

- `Localizable.xcstrings`：上一轮产生的 Recent* 系 13 个 key 原位再次
  更名（`Recent Events`→`All Events`、`No Recent Events`→`No Events`、
  `Recent Today/Yesterday/Tomorrow`→`All Today/All Yesterday/All
  Tomorrow`、`Show Recent Section`→`Show All Events Section`、
  `Configure Recent Events`→`Configure All Events`、`Recent Day Limit`
  →`All Events Day Limit`、`Choose Calendars/Reminder Lists for Recent`
  →`... for All Events`、`Include Reminders in Recent`→`Include
  Reminders in All Events`、`Recent Events Detail Description`→`All
  Events Detail Description`），en/zh-Hans 取值同步，「近期日程」措辞
  统一为「全部日程」；key 原位更名不重排，控制 diff 范围。
- 代码标识符（`UpcomingEventsSection`、`upcomingDayLimit` 等）与 JSON
  存储字段名不动；测试引用同步。

### 2. 过去方向加载改顶部显式入口行（commit 1350f92）

- 下拉过拉探针方案整体删除（GeometryReader 偏移探针、
  `PastPullOffsetKey`、武装状态、下拉提示行及 `Pull Down to Load
  Earlier Events` key、滚动坐标空间）。推翻原因：macOS SwiftUI
  ScrollView 无弹性过拉，真机触控板拖动穿透到弹窗移动、鼠标滚轮到顶
  无过拉偏移，40 pt 触发阈值从未达成，入口实际失效。
- 改为列表最顶部常驻「加载更早」入口行：hasMorePast 时渲染
  chevron.up +「加载更早日程」按钮行（`.plain` Button，鼠标/触控板/
  完全键盘访问同一控件），点击触发 `handleLoadMoreUpcomingPast`；
  加载中被进度行替换，尽头后不渲染；空态文案仍在 ScrollView 内渲染，
  入口行不因未来无条目丢失（承接 f3c0e38 语义）。回顶锚保留。

### 3. 弹层打开复位改显式时序通道（commit 2e31906）

- 调查结论（行为证据判断）：分节 `onAppear` 重开不触发。若触发，
  `resetUpcomingPaginationAndLoadFirstPage` 会清空条目并回装第一页，
  用户不可能仍看到已加载页；真机反馈「重开后已加载页与滚动位置原样
  保留」即证明未触发。机制：`PopoverController` 一次性创建并复用
  contentViewController，NSPopover 关闭/重开不以 SwiftUI 可感知的
  方式卸载/重挂内容视图，onAppear 首次后不再重复（与「首屏正常装载」
  并存一致）。上一批 532971d 探针「onAppear 会重新触发」的结论按本批
  真机证据修正。未加一次性诊断日志（GUI 菜单栏交互无法在本环境驱动）。
- 修法：`CalendarPopoverViewModel` 新增 `popoverPresentationGeneration`
  与 `markPopoverPresented()`；`showPopover` 在 show 前递增（与
  refreshNow/checkAndResetIfNeeded 同一接线位置）；
  `RootPopoverView` onChange 该代数触发复位，`onAppear` 保留一次首载
  兜底（双路由由分方向请求 ID 守卫吸收）；分节展开态重置改由
  `presentationGeneration` 入参 onChange 驱动，分节 onAppear 整体删除，
  `onResetPagination` 回调链（分节→CalendarPopoverView→RootPopoverView）
  随之删除；scrollTo 回顶仍由 resetGeneration 驱动。
- 新增单测 `testMarkPopoverPresentedIncrementsPresentationGeneration`。

### 4. 分节限高 240pt（commit a5aaffb）

- `Metrics.expandedMaxHeight` 200→240，对齐看板分支取值；只约束展开态
  内容区（不含标题行），超出在分节内滚动，收起态不受影响。

### 5. 弹层位置约束（commit d85ce8b）

- 根因调查：NSPopover 默认不可拖（`popoverShouldDetach` 默认 false 且
  macOS 14 起弃用），但近期 macOS 的弹层私有窗口（_NSPopoverWindow）
  支持按背景拖动；弹层为锚定窗口，被拖出屏幕顶部后无自动回弹，月份头
  被裁切。判定为用户拖动弹层窗口所致，非 ScrollView 未消费拖拽。
- 修法（PopoverController 最小 diff，仅位置/拖动约束）：新增
  `popoverDidShow`，将弹层窗口 `isMovableByWindowBackground` 与
  `isMovable` 置 false，从根上禁止拖动；每次 show 的系统定位是程序式
  设 frame，不受影响。该改动可同款 cherry-pick 到看板分支。

### 6. 去 AI 味注释清理（commit b6d7837）

- 分支 diff 涉及的全部 swift 文件注释统一英文、稀疏只讲 why；删除
  模板化文件头/函数头（参数返回副作用清单）与实现历史类注释（修复
  记录/验收发现/数值复现叙事），历史留在 commit message 与本文档；
  公共契约保留一行英文摘要；测试夹具中文标题字面量改英文。不重命名
  标识符、不做结构性重构。
- 自查：5 个新增文件 `grep -P '^\s*//.*[\x{4e00}-\x{9fff}]'`（含
  `///` 同式）0 命中；分支 diff 全部 swift 文件中文注释行为 0。注释
  行数 376→293（-83）。

### 验证

```bash
xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro \
  -destination 'platform=macOS' -derivedDataPath .dd
# BUILD SUCCEEDED（六项各自提交前均单独通过）

xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro \
  -destination 'platform=macOS' -derivedDataPath .dd \
  -skip-testing:CalendarProUITests
# Executed 415 tests, with 0 failures (0 unexpected)
```

备注：415 = 基线 414 + 1（弹层展示代数单测）。已知 flaky 用例
`testStoreChangeRevisionIncrementsOnNotification` 本轮未复现。UI 测试
按基线跳过（本机 Runner 环境问题，UI 测试代码未变动）。无新增源文件，
未跑 regen。

### 人工验证项（视图时序/窗口层无法单测）

- 入口行：鼠标/触控板点击与 Tab 聚焦回车触发加载更早；加载中转进度；
  尽头后消失；空态（未来无条目）下入口行可用。
- 显式复位通道：打开弹层加载若干页并滚动后关闭，重新点击菜单栏图标，
  分页回到第一页、滚动回顶、展开态按「默认展开版块」设置取初值。
- 位置约束：拖拽弹层窗口应无法移动弹层；多屏与换屏锚定行为不变。
- 更名：弹层分节标题、设置侧栏与「全部日程」设置页文案为「全部日程」。
