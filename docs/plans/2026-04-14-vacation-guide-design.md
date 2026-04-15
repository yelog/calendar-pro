# Vacation Guide Design

**Date:** 2026-04-14
**Status:** Approved

## Goal

为中国大陆地区提供一个基于法定假日、周末与调休上班规则的年度休假建议功能，帮助用户快速发现 `请 X 休 Y` 的连续休假机会。

## Scope

- 基于现有中国大陆节假日与调休数据，自动生成年度休假建议。
- 在月历 popover 中增加 `休假建议` 入口。
- 打开独立轻量窗口展示年度建议卡片，而不是在主 popover 中硬塞全年视图。
- 支持年份切换、按节日时间顺序展示，以及从建议卡片跳转回月历定位。

## Non-Goals

- 不复刻海报式整年大图。
- 不支持美国、英国等其它地区的通用长周末规划。
- 不集成机酒价格、拥挤度、天气等外部数据。
- 不在 V1 中自动创建请假日历事件、提醒事项或导出分享图片。

## Design

### 1. Feature availability

该功能为 `mainland-cn` 专属能力，仅在以下条件满足时可用：

- `activeRegionIDs` 包含 `mainland-cn`
- `statutory-holidays` 处于启用状态
- 当前年份存在可用的中国大陆放假安排数据

如果 `adjustment-workdays` 被关闭，界面继续可用，但需要明确提示结果可能不完整，因为中国大陆的连续休假建议强依赖调休上班日。

### 2. Entry and presentation

入口放在现有月历头部，新增一个 `休假建议` 按钮。

点击后打开独立轻量窗口，而不是扩大当前 340 宽的 popover 主体。原因：

- 全年规划内容比日历弹层的信息密度高很多
- 需要滚动、年份切换和卡片操作
- 单独窗口更符合现有仓库中详情浮层的使用方式

窗口结构：

- 顶部：标题、年份切换、说明文字
- 主体：按节日分组的建议卡片列表
- 底部：当前节假日数据来源和状态说明

窗口应与现有事件/提醒详情窗口保持一致的浮层行为：

- 高度可在可视区域内尽量向下撑满
- 与事件/提醒详情窗口互斥，任意时刻只显示一个辅助窗口
- 打开窗口时，自动滚动到 popover 当前显示月份对应的建议；如果该月没有建议，则滚动到之后最近的一条
- 辅助窗口 surface 使用实体底板叠加轻量 tint overlay，而不是直接使用带透明尾色的渐变填充，避免桌面内容从窗口底板和卡片区域透出

### 3. Vacation opportunity model

新增独立的休假规划模型：

- `VacationOpportunity`
  - `id`
  - `year`
  - `holidayName`
  - `dateRange`
  - `leaveDaysRequired`
  - `continuousRestDays`
  - `segments`
  - `score`
  - `summary`
  - `note`

- `VacationSegment`
  - `date`
  - `kind`
  - `label`

- `VacationSegmentKind`
  - `weekend`
  - `statutoryHoliday`
  - `leaveRequired`
  - `adjustmentWorkday`
  - `bridgeRestDay`

模型目标是支撑卡片展示、月历定位和后续扩展，而不是为了生成一张静态图片。

### 4. Planning algorithm

新增 `VacationPlanningService`，复用现有 `HolidayResolver` 和周末计算，不重复维护节假日数据。

算法流程：

1. 生成目标年份的逐日工作状态。
2. 将法定假期块作为候选锚点。
3. 向前后搜索可桥接的连续休假窗口。
4. 计算该窗口内需要额外请假的工作日数量。
5. 生成 `请 X 休 Y` 候选方案。
6. 对高度重叠的候选方案去重，保留每个节日最有代表性的 1 到 2 个。

评分设计保持确定性：

- 主指标：`continuousRestDays / leaveDaysRequired`
- 加分：总连续休息天数更长
- 减分：涉及调休上班、跨度过大、需要请假过多
- 最终映射为 1 到 5 星

说明文案不采用娱乐化段子，而是使用模板化中性描述，例如：

- `适合短途出行`
- `适合返乡或长线旅行`
- `适合作为上半年休整点`

### 5. UI content

每张建议卡片展示：

- 节日名称和日期范围
- 大摘要，例如 `请 3 休 8`
- 一条日期分段条，区分周末、法定假、请假、调休上班
- 1 到 5 星性价比
- 简短说明文字
- `定位到月历` 按钮

卡片默认按节日时间顺序排列，避免年度规划时在列表中来回跳读。
卡片背景透明度与事件/提醒详情页保持同一等级，避免休假建议列表出现“雾化发灰”的观感。

### 6. Navigation integration

点击 `定位到月历` 后：

- 关闭休假建议窗口
- 切回现有月历 popover
- 将 `displayedMonth` 切换到建议起始日期所在月份
- 选中建议起始日期

这样用户可以从“规划视图”回到“日常查看视图”，避免两个界面割裂。

打开窗口时的默认定位规则：

- 以 popover 当前显示的月份作为上下文月份
- 优先定位到与该月份有日期交集的建议
- 若该月没有建议，则定位到之后最近的一条
- 若该年后续也没有建议，则回落到列表最后一条

### 7. Empty states and data freshness

当当年放假安排不存在时：

- 不展示空白卡片列表
- 显示明确提示，例如“当年放假安排尚未发布”

当 Holiday Feed 仅有缓存或内置数据时：

- 在底部显示当前数据来源
- 告知用户建议结果基于当前节假日数据生成

## Files Expected To Change

- `CalendarPro/Views/Popover/MonthHeaderView.swift`
- `CalendarPro/Views/Popover/CalendarPopoverView.swift`
- `CalendarPro/Views/Popover/CalendarPopoverViewModel.swift`
- `CalendarPro/Views/RootPopoverView.swift`
- `CalendarPro/App/AppDelegate.swift`
- `CalendarPro/Features/Holidays/HolidayResolver.swift`
- `CalendarPro/Settings/RegionSettingsViewModel.swift`
- `CalendarPro/Infrastructure/LocaleFeatureAvailability.swift`

## Files Expected To Add

- `CalendarPro/Features/VacationPlanning/VacationOpportunity.swift`
- `CalendarPro/Features/VacationPlanning/VacationPlanningService.swift`
- `CalendarPro/Views/Popover/VacationGuideWindowView.swift`
- `CalendarPro/Views/Popover/VacationOpportunityCardView.swift`
- `CalendarPro/App/VacationGuideWindowController.swift`
- `CalendarProTests/VacationPlanning/VacationPlanningServiceTests.swift`

## Risks

- 中国大陆的放假安排具有强年度性，远程节假日数据未更新时无法安全预测。
- `请 X 休 Y` 推荐存在一定主观性，因此评分与文案必须保持规则化、可解释。
- 如果直接塞进主 popover，会显著破坏现有轻量体验，因此窗口形态不能轻易退让。

## Validation

- 2026 年中国大陆可以生成元旦、春节、清明、劳动节、端午、中秋/国庆等建议。
- 调休上班日能正确打断连续休息，不会误算为自然休假。
- 关闭 `statutory-holidays` 后，入口禁用或提示依赖关系。
- 数据缺失时显示清晰空状态，而不是错误结果。
- 从建议卡片跳回月历后，月份和选中日期正确同步。
