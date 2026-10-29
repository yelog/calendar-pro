# Cross-Day Event Editing Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 补齐全天和定时日程的起止日期编辑，保证仅修改其他字段不会缩短既有范围，并统一日期转换、校验和全天切换行为。

**Architecture:** 用 `CalendarEventScheduleDraft` 集中管理编辑过程中的日期规则，内部保留 EventKit 半开区间，界面将全天结束转换为最后覆盖日。新建和编辑复用统一请求构造，`EventService` 在修改事件前验证范围，现有刷新和写入链继续使用。SwiftUI 通过显式 Binding 调用草稿方法，避免多个 `onChange` 互相校正。

**Tech Stack:** Swift 6、SwiftUI、AppKit `NSPanel`、EventKit、XCTest、String Catalog、生成式 Xcode 工程；macOS 14+。

---

## 执行约定

- 本文记录实施计划及实际执行结果。
- 模板中的 `executing-plans` 若在实施环境不可用，直接按本文逐项执行、验证，不把缺少该技能视为业务阻塞，也不自动安装技能。
- 产品规则以 [设计文档](2026-10-29-cross-day-event-editing-design.md) 为准。以下路径、命令均相对于仓库根目录。
- 按任务顺序执行；日期转换与状态存在依赖，不拆成并行编辑同一组文件的工作。
- 业务测试先写失败用例，再实现最小逻辑。每个任务内部按测试、实现、验证拆分为小步；不为纯布局装饰编写与实现同构的测试。
- 不自动 commit、push、发布或修改用户真实事件。需要系统日历写入验证时使用明确隔离的测试日历/测试事件。
- 计划中的行为变化视为一个完整交付，不能只移除保存分支而留下全天切换仍使用定时时间的中间版本。

## 必须维持的契约

| 契约 | 标准 |
| --- | --- |
| 未改日期的编辑 | 请求的原始 `startDate`、`endDate`、`isAllDay` 精确不变 |
| 全天结束控件 | 表示最后覆盖日，包含当天 |
| 全天持久化 | 以最后覆盖日的下一日边界作为排他结束 |
| 定时事件 | 保存完整日期时间，`endDate > startDate` |
| 日期平移 | 使用日历日运算；保留规则由编辑动作决定 |
| 非法结束 | 保留输入、就近报错、禁用保存，不自动补一小时 |
| 时区 | 同次编辑使用固定系统日历/时区快照，不修改既有事件的 `timeZone` |
| 其他字段 | 不重建原事件，不改变提醒、重复规则、地点、参会人、URL |

## 任务 1：准备工程基线与测试注册

**Files:**

- Read: `AGENTS.md`
- Read: `tools/generate_xcodeproj.rb`
- Read/Modify: `CalendarPro.xcodeproj/project.pbxproj`
- Preserve: `CalendarPro.xcodeproj/xcshareddata/xcschemes/CalendarPro.xcscheme`
- Preserve: `CalendarPro.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`（存在时）
- Create: `CalendarPro/Features/Events/CalendarEventScheduleDraft.swift`
- Create: `CalendarProTests/Events/CalendarEventScheduleDraftTests.swift`
- Create: `CalendarProTests/Events/CalendarItemComposerTests.swift`

**Step 1：记录起点。**

运行 `git status --short` 和 `xcodebuild -version`，记录已有改动及工具版本。实施时重新读取项目约定；不得覆盖其他工作。

**Step 2：备份生成器会覆盖的工程信息。**

在 `/private/var/folders/d9/5sfcnz292bvbdh3nv19rvhc40000gn/T/opencode` 下创建本任务临时目录，完整备份 `.xcodeproj`；记录应用各 configuration 的版本、构建号、签名、权限描述和包依赖配置。计划编写时版本为 `0.2.7 (10)`，执行时以工作区实际值为准。

**Step 3：添加最小类型与测试文件后注册。**

先让新增文件有正确的 imports、类型声明和首个行为测试，再运行：

```bash
ruby tools/generate_xcodeproj.rb
```

生成器会删除并重建工程目录，不能跳过备份。生成后基于备份保留原配置、scheme 和锁定依赖，仅纳入新增 Swift 文件引用及必要 Sources 条目。不要借此升级包、变更版本号或重写其他构建设置；不要用 git reset/checkout 丢弃未知修改。

**Step 4：检查生成结果。**

```bash
git diff -- CalendarPro.xcodeproj
xcodebuild -list -project CalendarPro.xcodeproj
```

预期：三个新文件分别进入正确 target，原 `CalendarPro` scheme 可用；工程语义差异仅与本次新增文件有关。后续任务只编辑这些已注册文件，无需反复重建工程。

**完成标准：** 新文件能参与编译，工程原配置和锁文件已保留，测试失败来自待实现行为而非缺失 target 或依赖。

## 任务 2：建立日期草稿与全天显示/保存契约

**Files:**

- Modify: `CalendarPro/Features/Events/CalendarEventScheduleDraft.swift`
- Modify: `CalendarPro/Features/Events/EventService.swift` / `CalendarEventCreationRequest`
- Test: `CalendarProTests/Events/CalendarEventScheduleDraftTests.swift`
- Test: `CalendarProTests/Events/CalendarItemComposerTests.swift`

**Step 1：先编写日期往返测试。**

使用固定 Gregorian 日历、固定时区、固定日期，不访问系统日历数据库。至少包括：

| 用例 | 输入 | 预期 |
| --- | --- | --- |
| 单日全天 | `[11/18 00:00, 11/19 00:00)` | 展示结束 11/18，覆盖 1 天 |
| 两日全天 | `[11/18 00:00, 11/20 00:00)` | 展示结束 11/19，覆盖 2 天 |
| 标题更新 | 上一范围，仅修改标题 | 最终请求仍结束于 11/20 00:00 |
| 非标准全天边界 | 结束不在零点的有效输入 | 未编辑时间时保留精确原值；展示覆盖到结束所在日 |
| 年份变化 | `[2026/12/31, 2027/01/03)` | 展示结束 2027/01/02，覆盖 3 天 |
| 原始定时事件 | 包含非零秒、跨夜起止 | 未编辑时原始 Date 精确不变 |

关键回归测试示例；`makeDate` 辅助方法接收固定日历：

```swift
func testRequestPreservesMultiDayAllDayRangeWhenOnlyTitleChanges() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))
    let start = try XCTUnwrap(calendar.date(from: DateComponents(
        year: 2026, month: 11, day: 18
    )))
    let end = try XCTUnwrap(calendar.date(from: DateComponents(
        year: 2026, month: 11, day: 20
    )))
    let schedule = CalendarEventScheduleDraft(
        startDate: start,
        endDate: end,
        isAllDay: true,
        calendar: calendar
    )

    let request = try CalendarEventCreationRequest.make(
        title: "Updated title",
        calendarIdentifier: "personal",
        schedule: schedule,
        notes: "Unchanged notes"
    )

    XCTAssertEqual(request.startDate, start)
    XCTAssertEqual(request.endDate, end)
    XCTAssertTrue(request.isAllDay)
}
```

**Step 2：执行最小失败测试。**

使用后文的统一 DerivedData 路径和测试命令，只运行 `CalendarEventScheduleDraftTests`、`CalendarItemComposerTests`。预期在实现前因缺少接口或行为不符失败；不得声称私有 `save()` 已被该测试直接调用。

**Step 3：实现纯值类型和读取规则。**

接口约定如下，方法体按本任务和后续任务的明确规则实现：

| 接口 | 职责 |
| --- | --- |
| `init(startDate:endDate:isAllDay:calendar:)` | 原样保存 Date 和全天标记，捕获固定日历，不归一化 |
| `startDate`、`endDate`、`isAllDay` | 外部只读，内部通过显式动作修改 |
| `displayedEndDate` | 全天返回最后覆盖日，定时返回实际结束 |
| `coveredDayCount` | 全天按日历日差计算；非法时不生成有效天数提示 |
| `validationError` | 可比较的领域错误；有效时为 nil |
| `setStartDay(_:)`、`setEndDay(_:)` | 分别处理日期编辑 |
| `setStartTime(hour:minute:)`、`setEndTime(hour:minute:)` | 分别处理时分编辑 |
| `setAllDay(_:)` | 一次性执行模式转换和缓存恢复 |

结束日算法先取 `endDay = calendar.startOfDay(for: endDate)`：结束等于 `endDay` 时，末日为 `endDay` 的前一日；否则末日为 `endDay`。日加减通过 `calendar.date(byAdding: .day, ...)` 完成。日期计算失败返回领域错误，不以开始时间或默认一天兜底。

**Step 4：增加统一请求构造入口。**

在现有 `CalendarEventCreationRequest` 增加：

```swift
static func make(
    title: String,
    calendarIdentifier: String,
    schedule: CalendarEventScheduleDraft,
    notes: String?
) throws -> CalendarEventCreationRequest
```

构造前校验草稿，构造时直接复制内部原始边界，不再次加一天、截断时分或推断跨天。保留现有成员初始化、`makeDefault`、`makeEditing` 的调用兼容性。

**Step 5：运行本任务测试至通过。**

预期：单日、多日、跨年、原始秒值以及非标准导入边界的往返测试通过。这时只建立日期契约，不单独交付尚未接入的 UI。

## 任务 3：实现显式日期联动和全天切换

**Files:**

- Modify: `CalendarPro/Features/Events/CalendarEventScheduleDraft.swift`
- Test: `CalendarProTests/Events/CalendarEventScheduleDraftTests.swift`

**Step 1：补充开始/结束动作测试。**

| 用例 | 动作 | 预期 |
| --- | --- | --- |
| 两天全天开始后移 | 11/18 改为 11/20 | 覆盖变为 11/20、21，存储结束 11/22 |
| 修改全天末日 | 最后覆盖日从 11/19 改为 11/21 | 存储结束 11/22 |
| 单日全天 | 末日选开始当天 | 合法，存储结束为次日 |
| 定时开始改日期 | 11/18 22:00—11/19 09:00，开始日后移一天 | 11/19 22:00—11/20 09:00 |
| 定时开始改时分 | 上一原范围开始改为 23:00 | 结束变为次日 10:00，实际持续时间不变 |
| 结束早于开始 | 直接选同日更早时刻 | 输入保留，草稿非法，不自动改为一小时后 |
| 非法范围的开始修正 | 结束被改早后，再把开始调到结束之前 | 仅更新开始、保留结束，恢复合法后可保存 |
| 重新选择当前日期/分钟 | 原 Date 含秒值 | 原 Date 精确不变 |

**Step 2：补充全天转换测试。**

- `11/18 09:00—10:00` 转全天，得到 `[11/18, 11/19)`。
- `11/18 22:00—11/19 09:00` 转全天，得到 `[11/18, 11/20)`。
- `11/18 22:00—11/19 00:00` 转全天，只覆盖 11/18。
- 定时 → 全天 → 定时，日期未实际变化时恢复原始两端 Date，包含秒值。
- 全天下仅重新选择当前日期不使缓存失效；实际修改日期才使缓存失效。
- 原全天事件或缓存已失效时转定时，采用开始日 09:00 至最后覆盖日 10:00。
- 连续开关多次不累计增加或减少一天。
- 范围非法时请求切换全天，草稿保持原状并提示先修正日期。

**Step 3：补充夏令时与失败原子性测试。**

固定 `America/New_York`，覆盖 2026-03-08 和 2026-11-01：

- 全天平移后两端仍是各自日边界，覆盖天数不变，不假定一天总是 24 小时。
- 跨夏令时的定时日期平移保留本地时分；修改开始时分则保留实际持续秒数。
- 选择春季不存在的 02:30 会报错，整次联动不改变原草稿。
- 新选择秋季重复的 01:30 使用 `.first`；原本位于第二次 01:30 的事件只改标题或来回切换时仍保留原瞬间。

**Step 4：实现动作，保持赋值原子性。**

- 全天开始日：先求原覆盖天数，再用新开始日和日历日加法计算新排他结束。
- 定时开始日：求新旧开始日的日历日差，两端分别移到相应日期并保留本地时分秒。
- 定时开始时分：计算新的开始瞬间和原持续时间，再计算新的结束。
- 直接修改结束：只改结束，保留无效顺序供校正。
- 原始范围非法时，开始修改不尝试保留负持续时间或负覆盖天数，只更新开始以便修正；全天转换则返回范围错误，不覆盖原草稿。
- 修改方法可抛出日期组合错误；先算完整结果再赋值，失败不留下半更新状态。
- 时间组合明确使用严格匹配和 `.first`，并回查年月日时分秒，防止 Foundation 结果跳到另一天。
- 只有一次定时范围缓存；进入全天时捕获，全天日期实际改变时清除，退出全天时消费。

**Step 5：运行模型测试至通过。**

预期：所有交互和夏令时用例通过，不依赖机器当天日期或系统时区。

## 任务 4：让服务层拒绝非法范围

**Files:**

- Modify: `CalendarPro/Features/Events/EventService.swift` / `CalendarEventCreationRequest`、`createEvent`、`updateEvent`
- Modify: `CalendarPro/Features/Events/CalendarEventScheduleDraft.swift` / 共享范围错误
- Test: `CalendarProTests/Events/EventServiceTests.swift`

**Step 1：为请求验证补充失败测试。**

覆盖结束早于开始、结束等于开始、合法跨夜、合法多日全天，以及未改时间的非标准全天有效范围。断言领域错误类型，不断言当前语言的错误全文。

**Step 2：实现统一范围校验。**

在请求增加 `validateSchedule() throws`，草稿与请求共用同一个顺序判断和领域错误：

```swift
guard endDate > startDate else {
    throw isAllDay
        ? CalendarEventScheduleError.invalidAllDayRange
        : CalendarEventScheduleError.endMustBeAfterStart
}
```

全天标准日边界由明确日期编辑生成；服务验证不把未编辑的有效导入范围强行截为当前时区零点。

**Step 3：接入新建、更新的写入前验证。**

授权与可写日历检查后、创建/修改任何事件字段前执行 `try request.validateSchedule()`。移除两处 `max(request.endDate, request.startDate)`，有效请求的日期直接赋值。

保持更新原 `EKEvent`、`.thisEvent`、原有错误处理与刷新逻辑。不要清空或重建未编辑字段，不修改既有 `timeZone`。

**Step 4：运行 `EventServiceTests` 与模型测试。**

预期：请求边界验证通过，已有默认创建、编辑回填、提醒事项用例继续通过。无需为了校验测试引入完整 EventKit mock 或绕过系统授权。

**完成标准：** 代码审查确认范围校验发生在任何 `event` 字段赋值之前，单元测试证明有效范围不被修正、非法范围被拒绝。实际持久化验证留到任务 8。

## 任务 5：接入编辑器并补齐起止日期控件

**Files:**

- Modify: `CalendarPro/Views/Popover/CalendarItemComposerView.swift`
- Modify: `CalendarPro/Views/Popover/EventDetailWindowView.swift` / `visibleEndDate`
- Test: `CalendarProTests/Events/CalendarItemComposerTests.swift`
- Test: `CalendarProTests/Events/EventServiceTests.swift`

**Step 1：补充编辑初始化与请求组合测试。**

通过不持久化的 `EKEvent` 测试对象验证 `.editEvent` 回填多日全天和跨夜定时范围，之后用统一请求工厂生成最终保存请求并断言边界不变。保留已有时间轴双击新建、默认时间、提醒事项初始化测试。

测试明确覆盖“初始化 → 草稿 → 请求工厂”实际使用链；不声称它覆盖了鼠标点击，实际表单提交由任务 8 手动验证。

**Step 2：用一个草稿替代三份独立日期状态。**

- `@State startDate`、`endDate`、`isAllDay` 替换为 `@State eventSchedule`。
- `InitialValues` 返回或构建该草稿；新建模式继续接收现有时间轴 `initialTimeRange`。
- 日期选择器和格式化接收草稿的固定日历快照。共用控件为提醒事项提供兼容默认值。
- 删除开始和结束上的自动校正 `onChange`，删除 `ensureEndDateAfterStart()`。
- 使用显式 `Binding(get:set:)` 分别调用模型的日期、时分、全天动作；成功清除该区域输入错误，计算失败显示错误。

控件接口需要保留原始用户选择，不能只更换绑定后继续在控件内部调用 `settingDate` / `settingTime`：

| 控件 | 新增输入/动作 | 行为 |
| --- | --- | --- |
| `CalendarComposerDateButton` / `CalendarComposerMonthPicker` | 固定 `calendar`，可选 `onSelectDay: (Date) throws -> Void` | 日历和 Today 返回所选日；事件模式交由草稿组合，提醒默认路径继续保留原时分 |
| `CalendarComposerTimeButton` | 可选 `onSelectTime: (Int, Int) throws -> Void` | 网格和自定义文本都返回原始小时、分钟，草稿严格组合日期；提醒默认路径保持兼容 |

控件仍从绑定读取当前值；自定义动作存在时不再执行默认 Date 赋值。只有回调成功后关闭弹层；日期/时间组合抛错时保留弹层并显示就近错误。模型成功接受但形成倒序范围时，由主表单显示范围错误。原始 `02:30` 不得先被默认 Foundation 行为转为 `03:00` 后再送入校验。

**Step 3：改为固定两行日期结构。**

全天每行一个日期控件；定时每行日期加时间控件。复用现有 `CalendarComposerDateButton`、`CalendarComposerMonthPicker` 和 `CalendarComposerTimeButton`，不增加跨天开关。

日期控件支持紧凑的带年份本地化显示；时间已经和日期同行时只显示 `HH:mm`，避免结束控件重复展示日期。提供以下可访问性标识：

- `calendar-item-composer-all-day-toggle`
- `calendar-item-composer-start-date`
- `calendar-item-composer-end-date`
- `calendar-item-composer-start-time`
- `calendar-item-composer-end-time`
- `calendar-item-composer-schedule-summary`
- `calendar-item-composer-schedule-error`
- `calendar-item-composer-save-button`

**Step 4：统一摘要、校验和保存。**

- 顶部日程摘要从当前草稿计算；全天有效范围显示覆盖天数和“含结束当天”。
- 提醒事项顶部摘要从当前 `dueDate` 计算。
- 日期区域就近显示模型校验和日期组合错误。
- 保存禁用条件包含空标题、无可写日历、无效范围、未纠正输入错误、正在保存；提醒事项不受隐藏的日程草稿状态影响。
- `save()` 再次校验当前类型所需条件。
- 事件分支只调用 `CalendarEventCreationRequest.make(...)` 和 `onSaveEvent`。删除原全天 `start + 1 day` 覆盖分支，不在工厂之后再改日期。

**Step 5：复用详情页的覆盖末日算法。**

`EventDetailWindowView.visibleEndDate` 复用草稿提供的纯日期辅助方法，保持定时结束原值，避免详情和编辑器分别实现全天末日规则。此步骤只统一范围解释，不调整详情页其他功能。

**Step 6：运行关联测试并完成一次本地表单检查。**

确认两种模式都能打开两端日期弹层；定时事件从当天改为次日结束后仍显示所选日期。仅修改标题生成的请求保留多日全天范围。提醒事项含时间/不含时间编辑正常。

## 任务 6：适配面板高度与键盘操作

**Files:**

- Modify: `CalendarPro/Views/Popover/CalendarItemComposerView.swift`
- Modify: `CalendarPro/App/EventDetailWindowController.swift` / `showComposer`、`showEditor`
- Verify: `CalendarPro/App/EventDetailWindowSizing.swift`
- Test/Verify: `CalendarProTests/App/EventDetailWindowSizingTests.swift`
- Verify: `CalendarProTests/CalendarProTests.swift` / `PopoverControllerTests`

**Step 1：向编辑器传递可用高度。**

控制器复用 `availableHeight(anchoredTo:)` 和现有最小高度规则，传入 `maximumHeight`，并给新建、编辑入口都连接 `onPreferredHeightChange` 至已有 `resizePanelIfNeeded`。

**Step 2：固定标题、操作区，中部内容受限滚动。**

使用私有高度测量辅助，测量表单自然高度及标题/底部/间距/外边距的总高度。中部视口按 `max(0, min(contentHeight, maximumHeight - chromeHeight))` 约束；向控制器报告完整自然高度，由控制器继续限制最终面板高度。

备注编辑区域使用明确的有界高度，避免 `TextEditor` 或嵌套 `ScrollView` 参与测量时无限扩张。测量变更通过下一轮主线程更新，沿用超过 1pt 才调整的规则，不在布局回调里同步触发重入布局。

**Step 3：检查键盘路径。**

焦点顺序依次是标题、全天、开始日期、开始时间、结束日期、结束时间、日历、备注、操作按钮；全天隐藏的时分不参与焦点。Esc 关闭当前日期/时间弹层，主编辑器取消行为保持一致；非法范围时 Return 不得触发保存，时间弹层 Return 只确认当前时间输入。

**Step 4：运行现有窗口与控制器测试，手动检查两种高度。**

窗口验证至少包含正常可用高度和约 360pt 可用高度，全天/定时切换以及错误提示出现时，底部按钮均在可见区域。原提醒编辑器、只读详情和其他共用面板没有尺寸或关闭行为回归。

若现有 sizing 算法无需修改，不为保持覆盖率而添加重复测试；若修改尺寸计算，则为新增条件补行为测试。

## 任务 7：补齐中英文本地化与设计记录

**Files:**

- Modify: `CalendarPro/Resources/Localizable.xcstrings`
- Modify: `docs/plans/2026-04-28-add-calendar-item-creation.md`
- Modify: `docs/plans/2026-04-29-edit-delete-calendar-items.md`
- Update: `docs/plans/2026-10-29-cross-day-event-editing-design.md`
- Update: `docs/plans/2026-10-29-cross-day-event-editing.md`

**Step 1：复用既有键，增加必要文案。**

既有 `All Day`、`Start`、`End`、`Title is required.` 继续使用。新增键与预期文案：

| Key | 简体中文 | English |
| --- | --- | --- |
| `Start Date` | 开始日期 | Start Date |
| `End Date` | 结束日期 | End Date |
| `Start Time` | 开始时间 | Start Time |
| `End Time` | 结束时间 | End Time |
| `All-Day Range Summary` | 共 N 天，含结束当天 | N day(s), including the end date |
| `All-Day End Before Start` | 结束日期不能早于开始日期。 | The end date cannot be before the start date. |
| `Event End Must Be After Start` | 结束时间必须晚于开始时间。 | The end must be after the start. |
| `Event Local Time Does Not Exist` | 所选日期不存在该时间，请选择其他时间。 | This time does not exist on the selected date. Choose another time. |
| `Unable to Calculate Event Dates` | 无法计算所选日期，请重新选择。 | Unable to calculate the selected dates. Choose the dates again. |

天数必须使用 String Catalog 复数或单复数键；不要实际输出英文 `day(s)`。参数格式使用项目既有 `LF` 惯例。无效范围不显示看似有效的“共 N 天”。

**Step 2：用 Python JSON 解析检查目录结构。**

```bash
python3 -m json.tool CalendarPro/Resources/Localizable.xcstrings > /dev/null
```

预期：退出码 0，新增键均包含 `zh-Hans` 和 `en`，占位符与代码参数一致。

**Step 3：补充旧设计的后续说明。**

在新建、编辑旧计划追加日期和新设计链接，注明起止日期与全天保存规则已由本次设计补齐，不重写历史实施记录。实施完成后在本计划追加实际变更、命令结果、截图位置和未完成验证项，更新设计状态。

## 任务 8：最终验证与交付

**Files:**

- Verify: `CalendarPro/Features/Events/CalendarEventScheduleDraft.swift`
- Verify: `CalendarPro/Features/Events/EventService.swift`
- Verify: `CalendarPro/Views/Popover/CalendarItemComposerView.swift`
- Verify: `CalendarPro/Views/Popover/EventDetailWindowView.swift`
- Verify: `CalendarPro/App/EventDetailWindowController.swift`
- Update: 本计划执行记录

### 自动化命令

统一使用本任务专用 DerivedData 路径。每条命令可独立复制执行：

```bash
xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -derivedDataPath /private/var/folders/d9/5sfcnz292bvbdh3nv19rvhc40000gn/T/opencode/CalendarProDerivedData-cross-day-editing -only-testing:CalendarProTests/CalendarEventScheduleDraftTests -only-testing:CalendarProTests/CalendarItemComposerTests
```

```bash
xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -derivedDataPath /private/var/folders/d9/5sfcnz292bvbdh3nv19rvhc40000gn/T/opencode/CalendarProDerivedData-cross-day-editing -only-testing:CalendarProTests/EventServiceTests -only-testing:CalendarProTests/EventDetailWindowSizingTests -only-testing:CalendarProTests/PopoverControllerTests
```

```bash
xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -derivedDataPath /private/var/folders/d9/5sfcnz292bvbdh3nv19rvhc40000gn/T/opencode/CalendarProDerivedData-cross-day-editing
```

```bash
xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -derivedDataPath /private/var/folders/d9/5sfcnz292bvbdh3nv19rvhc40000gn/T/opencode/CalendarProDerivedData-cross-day-editing -only-testing:CalendarProTests
```

```bash
git diff --check
```

先运行最小测试，集成完成后运行一次相关回归、构建与完整单元测试。均通过后不因没有新信息而循环重跑。现有 `CalendarPopoverUITests` 可作为已有导航行为的补充检查，但不能把其通过当作新日期控件已经自动验收的证据。

### 手动验收矩阵

真实日历验证使用专门测试日历。若当前环境未获授权，记录未验证项；不要为了完成手动验收改变用户的权限设置或编辑截图中的真实事件。

| 编号 | 操作 | 通过标准 |
| --- | --- | --- |
| M1 | 在 Apple Calendar 建立明确覆盖 11/18、19 的全天测试事件，记录 EventKit 边界；本应用只改标题保存 | 边界仍为 `[11/18, 11/20)`，两端日期未变 |
| M2 | 将 M1 的界面结束日改为 11/21 | 写入结束 11/22 零点，两应用均覆盖 18—21 日 |
| M3 | 建立单日全天并反复打开、保存 | 一直为一天，不累计增减日期 |
| M4 | 新建 11/18 22:00 至 11/19 09:00，分别修改起止日期 | 两端均可选，跨夜正确；保存重新打开范围一致 |
| M5 | 直接将结束改到开始之前 | 错误就近出现，更新按钮和 Return 保存被阻止，输入没有被改成开始后一小时 |
| M6 | 结束改回有效范围 | 错误消失，可以保存；此前保存错误不污染新日期输入 |
| M7 | 定时 → 全天 → 定时；再测试全天期间实际改日期 | 前者精确恢复原定时；后者使用已选日期和规定默认时分 |
| M8 | 定时事件结束于次日 00:00 后切全天 | 不额外覆盖次日 |
| M9 | 编辑跨月、跨年全天和定时事件 | 年份清晰，显示末日与实际保存一致 |
| M10 | 小高度窗口、长标题、较长备注、日期错误 | 表单可滚动，取消与更新一直可达，日期/时间弹层仍可操作 |
| M11 | 简体中文、英文、浅色、深色和键盘导航 | 日期无截断，1 day/2 days 正确，可访问性名称区分起止，弹层焦点正确 |
| M12 | 提醒事项含时间/不含时间、新建默认一小时、时间轴双击新建 | 原有默认日期时间和编辑行为正常 |
| M13 | 只读日历、重复事件的一次实例、带提醒/地点/URL 的测试事件 | 只读仍受限制，重复写入范围仍为 `.thisEvent`，未编辑属性保留 |
| M14 | 带明确时区与 `timeZone == nil` 的事件仅改标题 | `timeZone` 与原始起止均不变 |
| M15 | 修改开始日期使事件离开当前选择日，保存后关闭再打开对应日期 | 当前列表/详情刷新正确，无旧范围残留 |

至少保存多日全天、跨夜定时、范围错误、小高度窗口的截图；浅色和深色各有样本。系统日历往返以字段和覆盖日期验收，不要求两个客户端的标签文本完全相同。

### 最终交付清单

- 日期草稿和统一请求构造已被实际新建、编辑保存路径使用。
- 全天固定一天的覆盖分支、`max` 范围修正和自动补一小时逻辑已移除。
- 多日全天只改其他字段时原始日期保持不变。
- 起止日期均可编辑，非法范围保留输入并阻止保存。
- 全天转换、午夜边界、夏令时和中英文本地化符合设计。
- 工程版本、构建配置、依赖锁定没有无关变化。
- 相关测试和构建实际执行并记录；真实日历验证的完成情况如实说明。
- 未自动提交、发布或修改用户原有事件。

## 执行记录

2026-10-29：完成代码调查、设计和实施计划。随后完成 `CalendarEventScheduleDraft`、统一事件请求构造、服务层范围校验、编辑器起止日期/时间控件、中英文本地化、详情页覆盖末日复用及浮动面板高度适配。补充午夜结束、秋季夏令时、无效全天结束显示及“编辑初始化→请求”范围回归测试。

工程生成器会重写与本任务无关的工程设置；按仓库约定备份后已恢复原工程、scheme 和 `Package.resolved`，只手动注册三个 Swift 文件。`xcodebuild -list -project CalendarPro.xcodeproj` 成功，scheme 与 targets 正常。

验证记录：首次目标测试定位并修复编辑器重复辅助方法、时间弹层快捷键/API、测试主线程隔离和时间格式化器引用等编译问题。草稿套件 18 项通过。编辑器套件最初发现 EventKit 全天测试对象按本机时区规范化边界；测试改为与事件实际回读的原始边界比较。

- `xcodebuild build -quiet ... -derivedDataPath /private/var/folders/d9/5sfcnz292bvbdh3nv19rvhc40000gn/T/opencode/CalendarProDerivedData-cross-day-editing`：通过。Xcode 提示匹配到 arm64 与 x86_64 两个目的地并使用 arm64；测试 target 另有既有脚本阶段每次运行的警告。
- 关联回归测试（`CalendarEventScheduleDraftTests`、`CalendarItemComposerTests`、`EventServiceTests`、`EventDetailWindowSizingTests`、`PopoverControllerTests`）：57 项通过，0 项失败。
- 完整 `CalendarProTests`：468 项中 467 项通过，1 项失败。失败为 `BoardSnapshotTests.testGroupingByPriorityOrdersHighMediumLowNoneAndSkipsEmptyGroups()`，断言固定期待中文 `["高", "中", "低", "无"]`，而当前英文测试 locale 实际返回 `["High", "Medium", "Low", "None"]`（`CalendarProTests/Popover/BoardSnapshotTests.swift:115`）。该用例不涉及日程编辑，本次未改动它。
- `python3 -m json.tool CalendarPro/Resources/Localizable.xcstrings` 与最终 `git diff --check`：通过。

自动化测试不会写入用户真实日历。尚未使用隔离测试日历完成 EventKit 持久化往返，也未完成两种面板高度、颜色模式及键盘路径的人工检查；不以未执行项宣称通过。未提交更改。
