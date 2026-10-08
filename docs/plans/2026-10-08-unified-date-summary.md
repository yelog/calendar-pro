# 统一所选日期摘要 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将公历、完整农历和节假日整合为月历下方的自适应摘要，默认单行、溢出时分行，并保证翻月后的日期信息一致。

**Architecture:** 在 Calendar feature 中按目标日期生成独立摘要数据；RootPopoverView 派生并传递摘要；独立 SwiftUI 摘要组件负责单行、分组折行和标签流式排列。复用已有农历与节假日解析，保留完整日期和配置语义。

**Tech Stack:** Swift 6、Foundation、SwiftUI ViewThatFits / Layout、AppKit、XCTest、macOS 14+。

---

## 背景及执行规则

- 设计：[2026-10-08-unified-date-summary-design.md](2026-10-08-unified-date-summary-design.md)。
- 本计划建立在工作区已实现的 Issue #5 完整农历功能上；当前生产代码、测试和计划文档尚未提交。开始实施前记录 `git status --short`，保留这些改动。
- 本次计划编写只增加文档。下面代码为实施约定和关键实现，不表示已应用或测试通过。
- 每个 Step 为一次小范围编辑或验证，按 Task 顺序推进，不启动并行代理。
- `executing-plans` 若不可用，直接按本文顺序执行并记录结果。
- 新增 Swift 文件后运行 `ruby tools/generate_xcodeproj.rb`。生成器会重建工程目录并写入默认版本值，执行前记录当前版本、签名、包锁定信息，生成后检查差异并恢复非本任务产生的配置偏移。
- 日期/布局业务边界使用有效回归测试；简单样式修改以实际界面验收为主，不为颜色和 padding 编写镜像测试。

## 文件清单

### 新增

- `CalendarPro/Features/Calendar/SelectedDateSummary.swift`
- `CalendarPro/Views/Popover/SelectedDateSummaryView.swift`
- `CalendarProTests/Calendar/SelectedDateSummaryTests.swift`
- `CalendarProTests/Popover/SelectedDateSummaryLayoutTests.swift`

### 修改

- `CalendarPro/Features/Calendar/CalendarDay.swift`
- `CalendarPro/Views/RootPopoverView.swift`
- `CalendarPro/Views/Popover/CalendarPopoverView.swift`
- `CalendarPro/Resources/Localizable.xcstrings`
- `CalendarProTests/Calendar/CalendarDayFactoryTests.swift`
- `CalendarPro.xcodeproj/project.pbxproj`（通过生成器更新）
- 本次两份设计/实施文档及前次完整农历两份文档的后续演进说明。

## Task 1：明确标签语义及公历格式化

**Files:** `CalendarPro/Features/Calendar/CalendarDay.swift`、`CalendarProTests/Calendar/CalendarDayFactoryTests.swift`、`CalendarPro/Views/Popover/CalendarPopoverView.swift`。

### Step 1：扩充有实际意义的 metadata 测试

1. 修改 `testSelectedDayMetadataChipsClassifyDateInfoForPresentation` 的状态预期为 `.dayOff`。
2. 新增固定日期补班用例（例如大陆数据 2026-10-10，实施时先核对本地 fixture），断言状态为 `.workday` 且显示“班”。
3. 对同一天重复节日来源断言标签文本去重；同时确保保留节日名称和休假状态两个不同含义。
4. 新增跨年公历标题测试与时区午夜边界测试，显式传入 calendar/locale/timeZone。

### Step 2：扩展语义枚举和格式化接口

把 `Chip.Style.status` 替换为以下状态，不修改 `BadgeKind`：

```swift
enum Style: String, Equatable {
    case primary
    case supplemental
    case dayOff
    case workday
}
```

`selectedDayMetadataChips` 中，假期状态构造 `.dayOff`，补班状态构造 `.workday`。保留当前 `appendUnique` 的去重规则。

给现有标题方法追加默认参数，保持原有调用兼容：

```swift
static func selectedDaySummaryTitle(
    for date: Date,
    calendar: Calendar = .autoupdatingCurrent,
    locale: Locale = .autoupdatingCurrent,
    includesYear: Bool = false
) -> String
```

年月日模板使用 `includesYear ? "yMMMd" : "MMMd"`，星期仍用 `EEE`；两个 DateFormatter 均显式设置 `timeZone = calendar.timeZone`。

### Step 3：同步旧视图的枚举引用并验证

在旧视图尚未迁移之前，更新 `.status` 比较和 switch 分支以维持可编译；休假复用原红色，补班采用与网格接近的深浅色蓝色。后续 Task 3 将这些逻辑迁移到新组件。

```bash
xcodebuild test -quiet -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarDayFactoryTests
```

预期：现有节日、去重、紧凑日期断言及新增状态、年份、时区用例全部通过。

## Task 2：生成不依赖当前网格的摘要数据

**Files:** 新增 `SelectedDateSummary.swift`、`SelectedDateSummaryTests.swift`。

### Step 1：建立最小模型和工厂接口

```swift
struct SelectedDateSummary: Equatable {
    let date: Date
    let solarDateText: String
    let weekdayText: String
    let fullSolarDateText: String
    let lunarDateText: String?
    let chips: [CalendarDayDisplayMetadata.Chip]
}

struct SelectedDateSummaryFactory {
    let calendar: Calendar
    let registry: HolidayProviderRegistry

    func make(
        selectedDate: Date?,
        currentDate: Date,
        displayedMonth: Date,
        preferences: MenuBarPreferences,
        locale: Locale,
        showsLunarDate: Bool,
        offText: String,
        workText: String
    ) -> SelectedDateSummary
}
```

只暴露组合真正需要的数据。公历和星期分开是为了不同文字层级；`fullSolarDateText` 专供无障碍朗读，始终有年份。

### Step 2：编写日期、配置和翻月回归测试

用固定 `Asia/Shanghai` Gregorian 日历、固定 locale 和 `.default` fixture registry。关键测试：

| 测试名 | 断言 |
| --- | --- |
| `testOrdinaryDayIncludesSolarAndFullLunarDateWithoutChips` | 2026-02-24（沿用已有普通日 fixture）公历存在、农历为丙午年正月初八、标签为空 |
| `testSummaryRetainsHolidayOutsideDisplayedGrid` | 选中 2026-10-01、显示 2026-12，国庆节和休状态继续存在 |
| `testSummaryIncludesYearWhenDisplayedYearDiffers` | 选中 2026-10-01、显示 2027-01，标题包含 2026 |
| `testNilSelectionUsesCurrentDate` | nil 选择使用注入 currentDate，三种信息同日 |
| `testEnglishSummaryKeepsSolarDateWithoutLunarDate` | showsLunarDate=false 时仅农历为 nil，公历存在 |
| `testSummaryIgnoresMenuBarLunarStyleAndEnabledState` | token 的 short/full/disabled 不改变完整农历 |
| `testSummaryRespectsHolidayPreferences` | 关闭纪念日集合后不出现被禁用标签 |
| `testSummaryPreservesSolarTermAndSupplementalFestival` | 2026-06-21 保留既有夏至、父亲节和休状态语义 |
| `testSummaryUsesOneTimeZoneForSolarAndLunarDate` | 同一 UTC 时刻跨春节边界时，公历与农历一致 |

不要从待测工厂生成期望值；使用固定日期与文字预期。继续运行已有 `LunarServiceTests` 保证干支修复和节气规则不回退。

### Step 3：实现工厂

有效日期与年判断的核心逻辑：

```swift
let date = selectedDate ?? currentDate
let includesYear = !calendar.isDate(date, equalTo: displayedMonth, toGranularity: .year)
let lunar = LunarService().describe(date: date, timeZone: calendar.timeZone)
let day = try? CalendarDayFactory(
    calendar: calendar,
    registry: registry,
    now: { currentDate }
).makeDay(
    for: date,
    displayedMonth: displayedMonth,
    preferences: preferences,
    selectedDate: date
)
let chips = day.map {
    CalendarDayDisplayMetadata.selectedDayMetadataChips(
        for: $0,
        offText: offText,
        workText: workText
    )
} ?? []
```

格式化工具统一 calendar、locale、timeZone。以 `yMMMd` / `MMMd` 生成日期，以 `EEE` 生成视觉星期；无障碍完整日期使用带年份及完整星期的本地化模板。可把格式化小方法放在现有 `CalendarDayDisplayMetadata` 中复用，避免复制 DateFormatter 设置。

完整农历仅由 `showsLunarDate` 控制。标签继续通过配置后的 `CalendarDay` 生成，不把 `festivalName` 额外注入 chips。假期解析失败只降级标签，保留公历和农历；使用现有协议可构造失败 provider 时补测试，不为测试引入新的生产服务抽象。

### Step 4：注册新增文件并运行针对性测试

```bash
ruby tools/generate_xcodeproj.rb
```

检查生成差异，保留原版本、签名和包解析配置。然后执行：

```bash
xcodebuild test -quiet -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/SelectedDateSummaryTests -only-testing:CalendarProTests/CalendarDayFactoryTests -only-testing:CalendarProTests/LunarServiceTests
```

预期：上述日期/配置测试通过，翻月后不再依赖 `monthDays.first`。

## Task 3：实现自适应摘要视图

**Files:** 新增 `CalendarPro/Views/Popover/SelectedDateSummaryView.swift`、`CalendarProTests/Popover/SelectedDateSummaryLayoutTests.swift`；修改 `Localizable.xcstrings`。

### Step 1：实现两组内容及单行候选

新组件输入为 `let summary: SelectedDateSummary`。日期组包含公历日期、星期、可选农历前缀和完整年月日；标签组复用 metadata chips。

关键布局结构：

```swift
var body: some View {
    ViewThatFits(in: .horizontal) {
        HStack(alignment: .center, spacing: 8) {
            dateLine
            if !summary.chips.isEmpty {
                singleLineChips
            }
        }
        .fixedSize(horizontal: true, vertical: false)

        VStack(alignment: .leading, spacing: 5) {
            adaptiveDateGroup
            if !summary.chips.isEmpty {
                wrappingChips
            }
        }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(accessibilityText))
    .accessibilityIdentifier("calendar-popover-selected-date-summary")
}
```

以上子视图均在同一文件内实现。`dateLine` 的文本采用设计文档字体；`singleLineChips` 中标签测理想宽度。单行候选不放 `Spacer`、不加无限宽 frame，也不使用 minimumScaleFactor 或截断后假装容纳。

### Step 2：实现日期组的最终回退

`adaptiveDateGroup` 再使用 `ViewThatFits(in: .horizontal)`：

1. 首选完整 `dateLine.fixedSize(horizontal: true, vertical: false)`。
2. 最终使用 leading VStack 放公历组和农历组；文字 `fixedSize(horizontal: false, vertical: true)`，允许必要时内部换行。

在英语界面没有农历时不生成空行或农历前缀。农历全文既不省略也不只放 help tooltip。

### Step 3：实现标签流式换行

同文件新增 `SummaryChipFlowLayout: Layout`，局部使用，不创建全局 UI 布局框架。

要求：

- 水平间距 4 pt、行间距 5 pt，按原顺序从左到右排布。
- 测量子视图理想尺寸；单个标签宽于可用宽度时，按可用宽度重新测量允许多行的标签。
- `sizeThatFits` 与 `placeSubviews` 使用相同的测量和行规划结果；放置使用实际 `bounds.origin`。
- `proposal.width == nil` / infinity 时作为自然单行测量；0 和窄宽度不出现负值或无限高度。
- 标签高度改为最小高度，不使用会裁切多行文字的固定高度；不保留旧 `.truncationMode(.tail)`。

行规划核心可提取为同文件 internal helper（输入已测量 `[CGSize]`、可用宽度和间距，输出 offsets/size），供真实边界测试使用：

```text
初始化 x=0, y=0, rowHeight=0
依次读取 itemSize：
  如果当前行非空，且 x + spacing + itemWidth > availableWidth：
    y += rowHeight + rowSpacing，重置 x 与 rowHeight
  否则当前行非空时 x += spacing
  记录 (x, y)
  x += itemWidth，更新 rowHeight
总高度为最后一行的 y + rowHeight；空列表为零
```

### Step 4：测试换行边界

`SelectedDateSummaryLayoutTests` 验证布局规划，不依赖不同系统字体的固定像素：

- 恰好填满一行不换行，例如 widths `[40, 20]`、spacing=4、width=64。
- 少 1 pt 时第二项移到下一行。
- 不同高度标签下一行从前行最大高度后开始，不发生覆盖。
- 空标签列表不增加行高；单个长标签重新测量后不超出可用宽度。
- 多行顺序与输入一致；非零 bounds 原点正确加到放置坐标。

实际 ViewThatFits 分支选择和文字可见性使用预览/手动验收，不用与实现完全相同的“字符串长度阈值测试”。

### Step 5：迁移标签颜色及无障碍语义

从旧摘要搬迁标签绘制和深浅色辅助方法：`.primary`、`.supplemental` 沿用原配色；`.dayOff` 红色；`.workday` 蓝色。保留“休/班”文本，标签无 Button/hover 点击暗示。

复用 `Lunar`、`OFF`、`WRK`，为完整朗读新增英文键和中文值：

| key | en | zh-Hans |
| --- | --- | --- |
| Day off | Day off | 休息日 |
| Adjusted working day | Adjusted working day | 补班日 |

朗读文本顺序固定为完整公历（含星期）、可选农历、标签。状态根据 `.dayOff` / `.workday` 转换为完整文案，不能通过 `chip.text == "休"` 推断。

整体只生成一个朗读元素，防止 `ViewThatFits` 两套候选导致重复朗读。原 metadata 和 lunar 行标识由新的稳定摘要标识替代，若有依赖旧标识的 UI 测试或脚本同步调整。

### Step 6：注册新增文件并构建

```bash
ruby tools/generate_xcodeproj.rb
xcodebuild build -quiet -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'
xcodebuild test -quiet -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/SelectedDateSummaryLayoutTests
```

逐条执行，检查工程生成差异。预期构建与布局边界测试通过。

## Task 4：根视图接入与清理旧布局

**Files:** `CalendarPro/Views/RootPopoverView.swift`、`CalendarPro/Views/Popover/CalendarPopoverView.swift`。

### Step 1：在根视图派生摘要

以计算属性 `selectedDateSummary` 替换 `selectedLunarDateText`：

```swift
private var selectedDateSummary: SelectedDateSummary {
    SelectedDateSummaryFactory(calendar: displayCalendar, registry: .live).make(
        selectedDate: viewModel.selectedDate,
        currentDate: timeRefreshCoordinator.currentDate,
        displayedMonth: viewModel.displayedMonth,
        preferences: settingsStore.menuBarPreferences,
        locale: AppLocalization.locale,
        showsLunarDate: LocaleFeatureAvailability.showLunarFeatures,
        offText: L("OFF"),
        workText: L("WRK")
    )
}
```

复用既有可观察 SettingsStore、ViewModel 和时间协调器；不缓存第二份 selectedDate。验证设置语言/节日源更新能使摘要重新派生。

### Step 2：改造弹层输入和插入位置

`CalendarPopoverView` 的 `lunarDateText: String?` 改为 `selectedDateSummary: SelectedDateSummary`。在 `calendarView` 中月历之后显示 `SelectedDateSummaryView(summary: selectedDateSummary)`。

完整依赖查询后同步全部构造点，当前生产调用点为 RootPopoverView。

### Step 3：移除重复日期 UI

删除确认已无调用的旧代码：

- `selectedDayInfoSection`
- `lunarDateRow`
- `selectedCalendarDay` 及旧 `selectedDayMetadataChips` 计算属性
- 已迁往新组件的标签颜色、绘制、无障碍及日期标题包装方法

保留公共 `CalendarDayDisplayMetadata` 及网格使用的方法。删除旧摘要 `.padding(.top, -3)`，沿用父容器 8 pt spacing。

### Step 4：恢复信息条区域职责

`infoStripsSection` 显示条件变为 `shouldShowWeatherStrip || shouldShowAlmanacStrip`，内容只保留天气和宜忌。

天气/宜忌可见时沿用此区顶部的一条分隔线，该线现在位于整个摘要之后；两者均关闭时不新增空分隔线。番茄钟/事件区域已有边界继续工作，检查没有相邻双分隔线。

### Step 5：构建与相关回归

```bash
xcodebuild build -quiet -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'
xcodebuild test -quiet -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/SelectedDateSummaryTests -only-testing:CalendarProTests/SelectedDateSummaryLayoutTests -only-testing:CalendarProTests/CalendarDayFactoryTests -only-testing:CalendarProTests/CalendarPopoverViewModelTests -only-testing:CalendarProTests/LunarServiceTests
```

预期：无旧构造参数残留、无枚举分支遗漏，日期和布局回归通过。

## Task 5：真实视觉与行为验收

**Files:** `SelectedDateSummaryView.swift` 的开发预览、两份新文档中的验收记录。

### Step 1：准备固定摘要预览

使用纯数据模型构造预览，不访问用户日历权限或实时天气。覆盖 308 pt 正常净宽和更窄宽度、深浅色、国庆、普通日、长标签、多标签、跨年、闰月、英语。

预览必须使用生产 `SelectedDateSummaryView`，不能用临时 HTML 或近似视图代替实际 SwiftUI 布局。预览渲染只能证明组件表现，实际 NSPopover 高度仍需单独检查。

### Step 2：视觉验收矩阵

| 场景 | 验收标准 |
| --- | --- |
| 国庆截图样例 | 308 pt 中日期+农历+国庆节+休单行，文字完整 |
| 普通日 | 公历、星期、完整农历同一行，位置稳定 |
| 长节日 / 多标签 | 整个标签组下移，标签按完整项换行 |
| 超长单个标签 | 单标签内部换行，背景随高度增长 |
| 日期组超宽 | 公历与农历上下显示，无裁切 |
| 深色 / 浅色 | 日期层级自然，休红班蓝均清晰 |
| 无农历的英语界面 | 公历摘要仍在，无空白行 |
| 六行月历且信息区全开 | 实际弹层底部可访问，无新增裁切 |

截图至少保存：国庆单行、长标签折行、浅色、英语/关闭信息条。记录截图位置，并避免私人日程内容。

### Step 3：交互与可访问性验收

- 选中日期→翻到不包含该日期的月份：节日与农历不消失、不换日。
- 翻到另一年：公历补年份；返回同一年恢复紧凑标题。
- 返回今天和跨日自动跟随：摘要与业务日期一致；手动历史选择不会被跨日覆盖。
- 四种天气/宜忌开关组合：摘要均存在，不被天气卡片拆开。
- 菜单栏农历 token 关闭/切换格式：摘要不受影响。
- 修改地区/禁用节日集：标签正确变化，完整年月日保留。
- 中文→英语→中文：无需重启；通过现有 SettingsStore 通知更新。
- VoiceOver 只朗读一次完整摘要，休/班使用完整含义；标签不被识别为按钮。

### Step 4：运行全部回归

```bash
xcodebuild test -quiet -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'
```

前次环境曾出现 UI Runner 在 bootstrap 阶段被系统 SIGKILL；本次仍应尝试完整测试。如果再次出现启动错误，记录 xcresult，单独确认单元测试结果，避免反复无变化重试或为绕过环境错误修改发布配置。

```bash
xcodebuild test -quiet -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests
```

仅在完整结果未能明确证明单元测试通过时执行单独命令。UI Runner 失败不是 UI 测试通过，也不是新功能断言失败。手动验收未执行项必须明确保留。

## Task 6：文档、差异和交付

### Step 1：更新前次设计的后续说明

在 `2026-10-08-full-lunar-date-design.md` 和 `2026-10-08-full-lunar-date.md` 添加后续演进链接：完整农历语义保留，展示位置演进为统一日期摘要，原独立农历行被本设计替代。保留历史实施和测试记录。

### Step 2：记录实际结果

新文档填写最终文件列表、测试数量/命令/xcresult、截图位置、手动验证结果和任何布局偏离。不把前次 355 项通过当作本次验证结果。

### Step 3：检查差异

逐条执行：

```bash
git diff --check
git diff --stat
git status --short
```

检查工程版本与配置无意外变化、旧代码无残留、没有隐藏日期信息、无多余源文件遗漏工程注册。

### Step 4：提交边界（需要提交时）

使用 @git-commit，建议按两部分组织：

1. `refactor(calendar): build date summaries independently of the visible grid`
2. `feat(popover): unify solar lunar and holiday date summary`

当前工作区包含前次 Issue #5 实现，提交前核对基线并只暂存对应逻辑改动。用户未要求提交时保留工作区改动。

## 完成清单

- [x] 摘要默认尝试单行、普通日显示公历、完整农历作为独立字段传入。
- [x] 加入标签流式折行布局规划器和日期组回退；布局边界测试通过。
- [x] 摘要由选中日期生成，不从当前网格查标签；跨公历年标题包含年份。
- [x] 休/班语义类型、颜色和 VoiceOver 文案已实现。
- [x] 日期工厂覆盖天气、宜忌开关之外的业务数据，农历不受 token 样式影响；地区/节日过滤仍复用现有工厂。
- [x] 新增 Swift 文件注册到 Xcode 工程；构建、373 项单测、1 项 UI 冒烟测试通过。
- [ ] 真实菜单栏弹层的实际单行宽度、长标签断行、两种外观和最终窗口高度尚未手动验收，也未生成截图。
- [x] 实施计划、设计说明与前次农历/节气文档的演进记录已更新。

## 文档参考

- [ViewThatFits](https://developer.apple.com/documentation/swiftui/viewthatfits)
- [fixedSize(horizontal:vertical:)](https://developer.apple.com/documentation/swiftui/view/fixedsize(horizontal:vertical:))
- [Layout](https://developer.apple.com/documentation/swiftui/layout)

已通过 Context7 核对上述机制：ViewThatFits 按理想尺寸选择首个可容纳候选；自定义 Layout 必须实现一致的测量和放置。项目最低 macOS 14，支持这些 API。

## 实际执行记录

2026-10-08：已实施核心功能与自动化测试。

- `CalendarDayDisplayMetadata.Chip.Style` 拆分为 `.dayOff` / `.workday`；日期标题可在跨公历年时包含年份，日期格式化显式使用日历时区。
- 新增 `SelectedDateSummary` 和 `SelectedDateSummaryFactory`。目标日期使用 `selectedDate ?? currentDate`；可见月历网格中的日期复用现有 day 数据，离开网格后仍能独立解析节日；固定使用 Gregorian 格式化公历，不依赖 locale 的默认日历。
- 新增 `SelectedDateSummaryView`，默认尝试一行，之后尝试“日期组 + 标签流”；标签通过自定义 `Layout` 在宽度不足时换行。保留完整农历与单标签内容，加入日期完整朗读和休/班的英文、中文 accessibility 文案。
- `CalendarPopoverView` 已删除原公历节日摘要和独立农历行；摘要在月历下方稳定显示，天气、宜忌仍保留原顺序并位于摘要后的分隔区。
- Xcode 项目手动增加四个 Swift 文件引用；未执行会递归删除并重建工程目录的 `tools/generate_xcodeproj.rb`，当前版本 `0.2.4 (7)` 与其他工程配置保持不变。
- 新增 `CalendarProTests/Calendar/SelectedDateSummaryTests.swift` 与 `CalendarProTests/Popover/SelectedDateSummaryLayoutTests.swift`；扩展状态、年份、时区测试；UI 冒烟测试确认 `calendar-popover-selected-date-summary` 存在。

验证结果：

| 命令 / 检查 | 结果 |
| --- | --- |
| `xcodebuild build -quiet -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'` | 通过 |
| 摘要、布局、CalendarDayFactory、LunarService 针对性测试 | 42 项通过 |
| `xcodebuild test -quiet -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests` | 373 项通过；xcresult: `Test-CalendarPro-2026.10.08_15-42-11-+0800.xcresult` |
| `xcodebuild test -quiet -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProUITests` | 1 项通过；xcresult: `Test-CalendarPro-2026.10.08_15-42-45-+0800.xcresult` |
| 最终可见网格复用后的 `SelectedDateSummaryTests`、`SelectedDateSummaryLayoutTests`、`CalendarDayFactoryTests` | 31 项通过；xcresult: `Test-CalendarPro-2026.10.08_15-45-57-+0800.xcresult` |
| `git diff --check` | 通过 |
| `Localizable.xcstrings` JSON 解析 | 通过 |

一次增量 build/test 并行执行曾发生测试 bundle 暂时不存在的 Xcode 构建竞态；随后串行测试通过。未将该瞬时失败当作代码失败。

**未完成的手动验收：** 当前环境未打开真实菜单栏 popover 核对视觉效果，因此未声称 308 pt 下国庆样例确实保持单行，也未核验长文本换行、实际六行日历窗口高度、深浅色、英语切换后的真实视图及 VoiceOver 操作；尚未生成截图。可在 Xcode UI Runner 可用的桌面会话手动验证上述 Task 5 矩阵。当前 UI 测试仅确认自动化窗口中摘要 accessibility identifier 存在，不覆盖真实菜单栏容器高度和外观。
