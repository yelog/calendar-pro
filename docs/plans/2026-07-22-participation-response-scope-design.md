# 会议回复范围判定设计

## 背景

日程详情中的参会状态操作会根据 `EKEvent.isRecurringParticipationSeries` 决定是否展示“应用回复范围”。现有实现将 `occurrenceDate != nil` 视为重复日程。部分日历提供方会在非重复邀请上填充该字段，导致用户点击接受、暂定或拒绝后被要求选择“仅本次”或“整个系列”。

## 决策

回复范围只由 `recurrenceRules` 是否非空决定：

- 非重复邀请：直接以 `EKSpan.thisEvent` 保存回复，不显示范围选择。
- 重复邀请：保留现有“仅本次 / 整个系列 / 取消”选择；两个保存范围继续分别使用 `EKSpan.thisEvent` 和 `EKSpan.futureEvents`。

`occurrenceDate` 不再参与回复范围判断。它描述实例日期，不能可靠证明该邀请属于可操作的重复系列。

## 验证

在 `CalendarItemTests` 中覆盖有、无重复规则的模型状态。`occurrenceDate` 是 EventKit 只读属性，无法在未保存的测试事件上构造；实现中不再读取它，因此代码审查与非重复用例共同保证该字段不会改变结果。
