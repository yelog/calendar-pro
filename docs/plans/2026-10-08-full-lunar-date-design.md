# Issue #5：完整农历日期展示设计

**日期：** 2026-10-08
**来源：** https://github.com/yelog/calendar-pro/issues/5
**状态：** 已实施（自动化验证通过；UI Runner 因系统 SIGKILL 未能完成启动，弹层手动验收仍待进行）
**实施计划：** [2026-10-08-full-lunar-date.md](2026-10-08-full-lunar-date.md)

## 目标

在月历弹层的宜忌上方展示所选日期的完整农历年月日，并修复现有干支年份计算错误。

## 当前代码依据

- `CalendarPro/Features/Lunar/LunarDateDescriptor.swift:38`：`displayText(style:)` 优先返回节日、节气，即使指定 `.yearMonthDay` 也不会稳定返回年月日。
- `CalendarPro/Features/Calendar/CalendarDayFactory.swift:131`：月历副标题格式取自菜单栏农历 token 配置。
- `CalendarPro/Views/Popover/CalendarGridView.swift:93`：副标题为 9 pt 单行文字，不能承担完整日期展示。
- `CalendarPro/Features/Calendar/CalendarDay.swift:110`：选中日期标签过滤普通农历文本。
- `CalendarPro/Views/Popover/CalendarPopoverView.swift:293`：信息区域当前仅在天气或宜忌可见时出现，顺序为天气、宜忌。
- `CalendarPro/Features/Lunar/LunarService.swift:44`：将中国历循环年序号代入了适用于公历年份的干支偏移公式。

## 展示规则

1. 中文功能可用时默认展示完整农历，沿用 `LocaleFeatureAvailability.showLunarFeatures`；英语界面隐藏新增行。
2. 日期来源为 `viewModel.selectedDate ?? timeRefreshCoordinator.currentDate`，与宜忌的日期选择口径一致。
3. 格式为“农历 丙午年八月廿三”；保留闰月前缀。
4. 节日、节气当天仍显示完整年月日，现有节日、节气标签继续单独展示。
5. 信息区域顺序为“天气（可选）→ 完整农历 → 宜忌（可选）”。天气、宜忌均关闭时仍显示完整农历。
6. 完整农历不依赖菜单栏农历 token 是否启用及其格式。
7. 翻月本身沿用现有选中日期语义：未重新选中日期时，完整农历继续对应原选中日期，而不是自动改为新月份首日。
8. 返回今天和自动跟随今天跨日时更新；手动选中的历史日期不因跨日改变。

## 数据与视图结构

### 完整文本

在 `LunarDateDescriptor` 增加 `fullDateText` 计算属性，固定拼接 `yearText + monthText + dayText`。保留 `displayText(style:)` 的节日、节气优先行为；其普通日期 `.yearMonthDay` 分支可复用新属性。

### 干支年

中国历 `DateComponents.year` 为 1…60 的循环年序号，以 1 对应甲子。天干索引使用 `(year - 1) % 10`，地支索引使用 `(year - 1) % 12`。继续依赖中国历决定农历年切换，不能改为按公历元旦或节气立春切年。

### 日期传递

在 `RootPopoverView` 增加 `selectedLunarDateText: String?` 计算属性，按语言规则、有效日期与 `displayCalendar.timeZone` 调用 `LunarService.describe`，将完整文本作为 `lunarDateText` 传给 `CalendarPopoverView`。

计算属性从现有可观察对象派生，不新增 `@State` 缓存或异步加载。农历转换是本地计算；节气解析已具有缓存。无需新增服务依赖或配置迁移。

### 布局

在现有 `CalendarPopoverView` 中增加私有 `lunarDateRow`，与宜忌左侧内容保持接近的水平对齐。标签使用次要颜色，完整日期使用正文颜色和约 12 pt 字号。允许垂直扩展，不缩小到月历格子的字号，不使用单行尾部省略来掩盖内容。

新增无障碍标识 `calendar-popover-lunar-date`，组合朗读标签和完整日期。复用 `CalendarPro/Resources/Localizable.xcstrings` 中已有的 `Lunar` 文案。

## 验证原则

- 为干支年份错误及独立完整日期语义增加有明确日期预期的单元测试。
- 保留现有节日、节气优先展示断言，覆盖新旧展示语义共存。
- 固定 `Asia/Shanghai` 时区和日期，并覆盖春节边界、循环年起点、闰月、节气与不同目标时区。
- 运行现有日历、菜单栏、选中日期同步测试；完整方案完成后执行共享 scheme 测试。
- 手动验证 340 pt 弹层、深浅色、语言与开关组合、跨日、翻月和实际菜单栏弹层高度，并记录截图。

## 完成标准

用户可在宜忌上方稳定查看正确的完整农历日期；在关闭天气和宜忌时仍可查看；节日、节气当天不丢失年月日；新增展示随日期和语言状态更新；全部相关测试通过。

## 实施结果（2026-10-08）

- 已新增 `LunarDateDescriptor.fullDateText`，不改变现有紧凑文本的节日、节气优先级。
- 已修复中国历循环年份到干支文本的索引偏移。
- 已在菜单栏弹层天气行与宜忌行之间接入独立农历文本行；两项均关闭时，该行仍可展示。
- 完整日期根据选中日期或当前日期派生，并使用显示日历时区；沿用 `LocaleFeatureAvailability.showLunarFeatures`。
- 单独运行全部 355 项 `CalendarProTests`：通过。
- `LunarServiceTests`：11 项通过。修复前的循环年份回归测试按预期失败，修复后通过。
- `xcodebuild build -quiet ...`：通过。
- 共享 scheme 测试及 UI 专项测试均在 UI Test Runner 建立连接前被 macOS `SIGKILL`，无法确认 UI 自动化结果。弹层开关、语言、无障碍、深浅色及高度的手动验收尚未完成，不能将完成标准标记为全部通过。

## 后续界面演进（2026-10-08）

本设计先交付的独立农历行，已在 [`2026-10-08-unified-date-summary-design.md`](2026-10-08-unified-date-summary-design.md) 中演进为公历、星期、完整农历与节假日组成的统一日期摘要。完整农历数据及 `fullDateText` 语义保留；旧的独立农历行已被统一摘要取代。后续布局和验证细节以统一摘要设计为准。
