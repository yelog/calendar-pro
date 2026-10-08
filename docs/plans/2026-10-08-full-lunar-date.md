# Issue #5 完整农历日期展示 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 在月历弹层的宜忌上方稳定展示选中日期的完整农历，并修复干支年份计算错误。

**Architecture:** `LunarService` 负责正确的中国历转换，`LunarDateDescriptor.fullDateText` 提供不受节日、节气覆盖的年月日。`RootPopoverView` 从选中日期派生文本，`CalendarPopoverView` 将其作为独立信息行展示，并使信息区域的可见性包含该行。

**Tech Stack:** Swift 6、Foundation Calendar、SwiftUI/AppKit、XCTest、Xcode 共享 scheme。

---

## 执行背景与约定

- Issue：https://github.com/yelog/calendar-pro/issues/5
- 设计：[2026-10-08-full-lunar-date-design.md](2026-10-08-full-lunar-date-design.md)
- 工作目录：仓库根目录。
- 本文为待实施计划；下面命令和预期结果不代表已经执行。
- 每个任务内按编号步骤执行；步骤以一次编辑、一次验证或一次结果记录为单位。
- 采用默认行为：中文功能可用时显示，独立于天气、宜忌、菜单栏 token；节日标签维持现有布局。
- 新行顺序：天气 → 完整农历 → 宜忌；已有月历、节日摘要、番茄钟和事件区继续使用原有顺序。
- 本计划只修改现有生产源码和测试文件，因此不需要重新生成 Xcode 工程。实施中若新增或删除 Swift 文件，须运行 `ruby tools/generate_xcodeproj.rb`。
- 执行环境若没有上述 `superpowers:executing-plans` 技能，按本文任务顺序直接执行，记录每项结果。

## Task 1：以回归测试锁定并修复干支年

**Files:**
- Modify: `CalendarPro/Features/Lunar/LunarService.swift:44-51`
- Test: `CalendarProTests/Lunar/LunarServiceTests.swift`

### Step 1：增加固定时区测试辅助方法和年份用例

在现有 `LunarServiceTests` 中增加以下方法，避免影响既有 `makeDate` 辅助方法：

```swift
private func describeShanghaiDate(year: Int, month: Int, day: Int) -> LunarDateDescriptor {
    let timeZone = TimeZone(identifier: "Asia/Shanghai")!
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let date = calendar.date(from: DateComponents(
        year: year, month: month, day: day, hour: 12
    ))!
    return LunarService().describe(date: date, timeZone: timeZone)
}

func testLunarYearTextUsesChineseCalendarCycleYear() {
    let cases: [(Int, Int, Int, String)] = [
        (1984, 2, 2, "甲子年"),
        (2024, 2, 10, "甲辰年"),
        (2026, 2, 4, "乙巳年"),
        (2026, 2, 16, "乙巳年"),
        (2026, 2, 17, "丙午年"),
        (2026, 10, 3, "丙午年")
    ]
    for (year, month, day, expected) in cases {
        let result = describeShanghaiDate(year: year, month: month, day: day)
        XCTAssertEqual(result.yearText, expected, "\(year)-\(month)-\(day)")
    }
}
```

这些预期分别覆盖循环年第 1 年、普通年份、立春尚未过春节、春节前一天、春节当天和普通日期。

### Step 2：运行失败测试

```bash
xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/LunarServiceTests/testLunarYearTextUsesChineseCalendarCycleYear
```

预期：2026 年等用例因当前错误的干支年份失败；若失败原因是构建或环境问题，先解决环境问题再判断红灯有效性。

### Step 3：修正循环年偏移

在 `yearText(for:)` 保留现有天干、地支数组与返回结构，将两个索引改为：

```swift
// Chinese calendar years are numbered 1...60, starting with 甲子.
let ganIndex = (year - 1) % 10
let zhiIndex = (year - 1) % 12
```

保持输入为中国历年份，不改用公历年份；新增注释解释输入含义。

### Step 4：运行农历测试

```bash
xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/LunarServiceTests
```

预期：新增年份用例和所有现有农历用例通过。

## Task 2：增加稳定的完整农历文本

**Files:**
- Modify: `CalendarPro/Features/Lunar/LunarDateDescriptor.swift:15-55`
- Test: `CalendarProTests/Lunar/LunarServiceTests.swift`

### Step 1：增加完整日期与时区边界用例

```swift
func testFullLunarDateRetainsDateOnFestivalsAndSolarTerms() {
    let cases: [(Int, Int, Int, String, String)] = [
        (2026, 10, 3, "丙午年八月廿三", "廿三"),
        (2026, 2, 16, "乙巳年腊月廿九", "廿九"),
        (2026, 2, 17, "丙午年正月初一", "春节"),
        (2026, 9, 25, "丙午年八月十五", "中秋节"),
        (2026, 2, 4, "乙巳年腊月十七", "立春"),
        (2025, 7, 25, "乙巳年闰六月初一", "闰六月")
    ]
    for (year, month, day, fullText, compactText) in cases {
        let result = describeShanghaiDate(year: year, month: month, day: day)
        XCTAssertEqual(result.fullDateText, fullText, "\(year)-\(month)-\(day)")
        XCTAssertEqual(result.displayText(), compactText)
    }
}

func testFullLunarDateUsesRequestedTimeZoneAcrossNewYearBoundary() {
    let date = ISO8601DateFormatter().date(from: "2026-02-16T16:30:00Z")!
    let service = LunarService()
    let shanghai = service.describe(
        date: date, timeZone: TimeZone(identifier: "Asia/Shanghai")!
    )
    let utc = service.describe(date: date, timeZone: TimeZone(secondsFromGMT: 0)!)

    XCTAssertEqual(shanghai.fullDateText, "丙午年正月初一")
    XCTAssertEqual(utc.fullDateText, "乙巳年腊月廿九")
}
```

继续保留原有“`.yearMonthDay` 在立春日返回立春”的测试。测试不能通过调用待测格式化逻辑生成期望值。

### Step 2：运行农历测试，确认缺失 API

运行 Task 1 Step 4 的命令。

预期：编译失败，指出 `LunarDateDescriptor` 没有 `fullDateText` 成员。

### Step 3：实现完整文本属性

在 `LunarDateDescriptor` 中新增：

```swift
var fullDateText: String {
    yearText + monthText + dayText
}
```

将 `displayText(style:)` 的 `.yearMonthDay` 分支返回值改为 `fullDateText`；保留函数开头的节日、节气优先判断。

### Step 4：运行农历测试，确认新旧语义共存

运行 Task 1 Step 4 的命令。

预期：新属性始终返回完整日期；现有紧凑显示继续优先返回节日或节气；所有农历测试通过。

## Task 3：接入派生数据和独立农历行

**Files:**
- Modify: `CalendarPro/Views/RootPopoverView.swift`
- Modify: `CalendarPro/Views/Popover/CalendarPopoverView.swift`
- Reuse: `CalendarPro/Infrastructure/LocaleFeatureAvailability.swift`
- Reuse: `CalendarPro/Resources/Localizable.xcstrings` 中已有 `Lunar` 键

### Step 1：在根视图计算完整农历

在 `RootPopoverView` 增加以下计算属性：

```swift
private var selectedLunarDateText: String? {
    guard LocaleFeatureAvailability.showLunarFeatures else { return nil }
    let date = viewModel.selectedDate ?? timeRefreshCoordinator.currentDate
    return LunarService()
        .describe(date: date, timeZone: displayCalendar.timeZone)
        .fullDateText
}
```

数据来自现有 `@ObservedObject`；避免添加第二套日期状态和手动刷新入口。不要从 `monthDays`、`subtitleText` 或 `lunarText` 反推年月日。

### Step 2：把数据作为视图输入传递

在 `CalendarPopoverView` 的 `almanac` 附近添加：

```swift
let lunarDateText: String?
```

在 `RootPopoverView.popoverContent` 的对应构造参数位置添加：

```swift
lunarDateText: selectedLunarDateText,
```

通过代码引用查询检查 `CalendarPopoverView` 的全部构造点，补齐参数；当前已确认生产调用点为 `RootPopoverView`。若实施时分支新增了预览或测试构造点，也要同步调整。

### Step 3：增加轻量农历行

在 `CalendarPopoverView` 中新增：

```swift
@ViewBuilder
private var lunarDateRow: some View {
    if let lunarDateText {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(L("Lunar"))
                .foregroundStyle(.secondary)
                .fixedSize()
            Text(lunarDateText)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("calendar-popover-lunar-date")
    }
}
```

默认不新增卡片背景；使用现有界面字体和颜色，允许日期在必要时换行。

### Step 4：扩展信息区域可见性和布局

将 `infoStripsSection` 外层条件改为：

```swift
if lunarDateText != nil || shouldShowWeatherStrip || shouldShowAlmanacStrip {
```

在内部 `VStack(spacing: 5)` 中，将 `lunarDateRow` 放到天气条件块之后、宜忌条件块之前。外层分隔线仍只绘制一次。

### Step 5：完成构建检查

```bash
xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'
```

预期：`BUILD SUCCEEDED`，没有遗漏新参数的构造调用。

## Task 4：运行集成回归并完成手动验收

**Existing tests to exercise:**
- `CalendarProTests/Lunar/LunarServiceTests.swift`
- `CalendarProTests/Calendar/CalendarDayFactoryTests.swift`
- `CalendarProTests/MenuBar/ClockRenderServiceTests.swift`
- `CalendarProTests/MenuBar/MenuBarViewModelTests.swift`
- `CalendarProTests/Popover/CalendarPopoverViewModelTests.swift`
- `CalendarProTests/TimeRefreshCoordinatorTests.swift`
- `CalendarProUITests/CalendarPopoverUITests.swift`

### Step 1：运行共享 scheme 的完整测试

```bash
xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'
```

预期：`TEST SUCCEEDED`。共享 scheme 包含单元测试和现有 UI 测试；UI 测试使用 `CALENDAR_PRO_UI_TEST_MODE=popover-window`，仅有月份导航冒烟覆盖，不能替代下方的实际弹层验收。

记录实际执行的命令、结果和失败原因。全部通过后，不在代码未变动的情况下重复运行完整套件。

### Step 2：验证日期内容和交互

| 场景 | 操作 | 预期 |
| --- | --- | --- |
| 普通日期 | 选中 2026-10-03 | 农历 丙午年八月廿三 |
| 节日 | 选中 2026-09-25 | 完整日期为丙午年八月十五，节日标签仍可显示中秋节 |
| 节气 | 选中 2026-02-04 | 完整日期为乙巳年腊月十七，立春不覆盖年月日 |
| 春节边界 | 从 2026-02-16 切换到 2026-02-17 | 乙巳年腊月廿九切换为丙午年正月初一 |
| 闰月 | 选中 2025-07-25 | 乙巳年闰六月初一 |
| 翻月 | 选中日期后翻到相邻月份，不点新日期 | 新行仍显示原选中日期的农历，不因日期离开网格而消失 |
| 返回今天 | 选历史日期后点击今天 | 新行、选中日期和宜忌对应今天 |
| 跨日跟随 | 自动跟随今天状态下跨日或唤醒 | 新行切换到新的今天 |
| 跨日锁定 | 手动选中历史日期后跨日 | 新行仍对应历史日期 |

日期内容以北京时间固定验证。跨日场景结合现有时间协调器测试验证；手动过程可使用调试环境注入时间，不在普通用户会话中直接修改系统时钟。

### Step 3：验证开关、语言及布局

| 场景 | 预期 |
| --- | --- |
| 天气开启、宜忌开启 | 天气 → 农历 → 宜忌 |
| 天气关闭、宜忌开启 | 农历 → 宜忌 |
| 天气开启、宜忌关闭 | 天气 → 农历 |
| 天气关闭、宜忌关闭 | 农历独立可见，分隔线无重复 |
| 菜单栏农历关闭或切换短/完整格式 | 新行仍显示完整农历 |
| 中文切英语，再切回中文 | 英语隐藏新行，中文恢复；不需要重启应用 |
| 跟随系统语言 | 与 `LocaleFeatureAvailability.showLunarFeatures` 一致 |
| 深色、浅色 | 字体对比度和相邻宜忌视觉层级正常 |
| 最长闰月日期 | 340 pt 弹层中年月日完整，无省略号 |
| 六行月历，天气、宜忌、番茄钟、事件均开启 | 实际菜单栏弹层内容、底部按钮仍可访问，无新增裁切 |
| VoiceOver | 可定位 `calendar-popover-lunar-date`，朗读“农历”和完整年月日 |

若实际菜单栏弹层高度出现新增裁切，先确认与基线的差异，再在当前布局内调整新增行间距；若必须修改宿主窗口尺寸策略，记录证据并补充设计后实施。

### Step 4：保留验收截图

至少记录中文浅色、中文深色和关闭天气/宜忌三种实际弹层截图，供 PR 使用。截图选择固定日期，避开私人日程内容。

## Task 5：完善实施记录并整理交付

**Files:**
- Update: `docs/plans/2026-10-08-full-lunar-date.md`
- Update: `docs/plans/2026-10-08-full-lunar-date-design.md`
- Update: `docs/plans/2026-04-01-lunar-solar-terms-design.md`

### Step 1：同步设计背景

在旧节气设计文档中增加后续演进说明并链接本设计：紧凑显示仍按节日、节气优先；完整日期行通过独立 `fullDateText` 保留年月日。将本设计的状态改为已实施，并记录最终 UI 决策与偏离本计划的原因。

### Step 2：补充实际执行记录

在本文末尾记录修改文件、测试命令和实际结果、手动验收完成情况、截图位置。未执行项明确写为未执行，不能以计划中的预期结果代替。

### Step 3：检查最终差异

```bash
git diff --check
git diff --stat
git status --short
```

预期：无空白错误；差异包含本需求的生产代码、回归测试和文档；新增源码文件时工程引用同步完成。

### Step 4：按逻辑整理提交

需要提交时，建议两个提交边界：

1. Task 1：`fix(lunar): correct cyclical year text`
2. Task 2–5：`feat(popover): show full lunar date above almanac`

提交前通过 @git-commit 技能检查并精确暂存对应文件。PR 摘要关联 `Closes #5`，附测试结果、手动验证说明与截图。

## 最终验收清单

- [ ] 干支年份正确，农历年按春节切换。
- [ ] `fullDateText` 在节日、节气和闰月日期均返回完整年月日。
- [ ] 现有紧凑展示的节日、节气优先级继续成立。
- [ ] 新行位于宜忌上方，独立于天气、宜忌和菜单栏农历配置。
- [ ] 选中日期、翻月、返回今天、跨日和语言切换行为符合设计。
- [ ] 340 pt 实际弹层显示完整，深浅色与无障碍验收完成。
- [ ] 构建、单元测试、现有 UI 测试通过。
- [ ] 文档、截图和执行结果记录齐全。

## 实际执行记录

2026-10-08：完成实施。

- 按 TDD 新增 `testLunarYearTextUsesChineseCalendarCycleYear`，先运行确认现有实现对 2024、2026 等日期给出错误干支年份，再修正索引。
- 新增完整日期测试，覆盖普通日、春节、中秋、立春、闰月及时区跨农历新年边界。
- 修改 `LunarService.swift`、`LunarDateDescriptor.swift`、`RootPopoverView.swift` 和 `CalendarPopoverView.swift`；在农历/农历日期行添加无障碍标识。
- 更新本文件、设计说明和既有节气设计文档。

验证结果：

| 命令 | 结果 |
| --- | --- |
| `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/LunarServiceTests/testLunarYearTextUsesChineseCalendarCycleYear`（修复前） | 预期失败，暴露 2024/2026 循环年份错误 |
| `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/LunarServiceTests` | 通过，11 项、0 失败 |
| `xcodebuild build -quiet -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'` | 通过 |
| `xcodebuild test -quiet -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests` | 通过；xcresult 摘要确认 355 项、0 失败 |
| `xcodebuild test -quiet -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'` | 未通过：355 项单测通过后，UI Runner 在 bootstrap 建立连接前被系统 SIGKILL |
| `xcodebuild test -quiet -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProUITests` | 未通过：UI Runner 同样在 bootstrap 阶段被系统 SIGKILL |
| `git diff --check` | 通过 |

尚待手动验收：实际菜单栏弹层的四种天气/宜忌开关组合、日期切换、英语隐藏与中文恢复、深浅色、最长农历日期布局、VoiceOver 和六行月历下的弹层高度。当前环境的 UI Runner 无法启动，未生成界面验收截图。全套验证不能记为全部通过。

## 后续 UI 演进

2026-10-08：独立农历行已由[统一日期摘要设计](2026-10-08-unified-date-summary-design.md)取代。`fullDateText` 完整农历语义及年干支修复保持不变；新摘要将其与公历、星期和节日/休班标签合并显示。
