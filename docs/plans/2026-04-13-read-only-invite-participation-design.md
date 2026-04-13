# 只读群组邀请参与状态展示设计

**日期：** 2026-04-13

**目标：** 让通过邮件群组收到、在系统日历中表现为只读的会议，在 CalendarPro 中不再显示误导性的个人参会状态与回复入口，整体行为尽量贴近 Apple Calendar。

## 背景

当前代码已经具备邀请状态展示与回复能力：

1. 列表卡片会在右上角显示当前用户参与状态图标。
2. 详情页头部会显示 `Accepted` / `Maybe` / `Declined` 徽标。
3. 详情页会在满足条件时显示 `Response` 区块与三态回复按钮。

这套设计在普通邀请上成立，但对“发给邮件群组、当前用户只是群组成员之一”的会议，会出现和 Apple Calendar 不一致的行为：Apple Calendar 将其视为只读事件，而 CalendarPro 仍展示当前用户的 `Accepted` 状态，甚至可能展示回复入口。

## 问题根因

### 1. 当前用户参与上下文判断过宽

`hasCurrentUserParticipationContext` 目前只要满足“不是 organizer 且事件存在 attendees”，就会把事件当作和当前用户参与状态有关。这能覆盖少数 provider 不显式暴露 self attendee 的邀请，但也会把群组邀请误判为个人可响应邀请。

### 2. 原始参与状态被直接升级为用户可感知状态

`currentUserParticipationChoice` 在没有显式 self attendee 时，会继续读取运行时 `participationStatus`。这意味着只要 EventKit 暴露了某个原始状态值，UI 就会把它当成“当前用户自己的参会状态”进行展示。

### 3. 可修改能力判断过于乐观

`canModifyCurrentUserParticipationChoice` 当前除读取运行时能力外，还把对象是否响应 `setParticipationStatus:` 当成可修改依据。该条件更像是“对象具备该 setter”，并不等于“当前事件允许当前用户修改响应状态”。

### 4. UI 层没有只读语义收口

`EventCardView` 和 `EventDetailWindowView` 当前都直接消费上述参与状态辅助属性，没有统一的“这条邀请虽然有原始状态，但对当前用户而言应视为只读”的展示语义，因此最终与 Apple Calendar 分叉。

## 对现有设计的修正

`docs/plans/2026-04-11-event-participation-status-design.md` 中有一条旧假设：

1. 当事件不支持修改参与状态时，如果仍能拿到当前状态，则退回只读状态展示。

本次设计将其收紧为：

1. 对“只读群组邀请 / 不可针对当前用户单独响应”的场景，不再展示个人参与状态。
2. 只保留只读提示与参会人列表等客观会议信息。

## 方案对比

### 方案 A：保留当前状态，但标记为只读

- 优点：保留更多底层原始信息。
- 缺点：用户会自然追问“既然显示我已接受，为什么又不能改”，仍然存在误导。

### 方案 B：跟随 Apple Calendar，隐藏个人状态，只保留只读语义

- 优点：最符合用户心智，和系统行为一致。
- 优点：清楚区分“会议信息存在”与“这是我可操作的个人邀请状态”。
- 缺点：会丢弃部分 EventKit 返回但对用户没有行动价值的原始状态值。

### 方案 C：只隐藏按钮，保留头部与列表中的 `Accepted`

- 优点：改动最小。
- 缺点：核心误导仍然存在，只是从“能不能点”变成“为什么显示成我的状态”。

## 选定方案

采用方案 B。

## UI/UX 规则

### 列表卡片

1. 只读群组邀请不显示当前用户参与状态 token。
2. 会议平台图标、参会人数等客观 metadata 继续显示。
3. 普通可响应邀请仍按现有规则显示参与状态图标。

### 详情页头部

1. 只读群组邀请不显示 `Accepted` / `Maybe` / `Declined` 徽标。
2. 普通可响应邀请仍在头部展示当前状态摘要。

### 详情页响应区

1. 可响应邀请：显示 `Accept` / `Maybe` / `Decline` 按钮。
2. 只读群组邀请：不显示三态按钮，改为只读提示，例如 `This event is read-only`。
3. 完全无当前用户参与上下文的普通事件：不显示该区块。

### 参会人列表

1. 继续展示 `attendees` 列表及各 attendee 的 `participantStatus`。
2. 这部分属于会议信息，不等同于当前用户自己的响应状态，不受本次隐藏规则影响。

## 共享语义设计

为避免视图层继续拼凑多个布尔判断，本次新增一个共享展示语义：

```swift
enum EventParticipationPresentation: Equatable {
    case hidden
    case readOnly
    case editable(currentChoice: EventParticipationChoice?)
}
```

其职责如下：

1. `hidden`
   - 当前事件没有可靠的“当前用户参与”语义。
   - UI 不显示个人参与状态，也不显示响应区。

2. `readOnly`
   - 底层事件具备某种邀请/参与痕迹，但对当前用户而言不应作为可响应个人邀请展示。
   - UI 不显示 `Accepted` 徽标，不显示三态按钮，只显示只读提示。

3. `editable(currentChoice)`
   - 当前事件可作为当前用户的个人邀请展示。
   - `currentChoice == nil` 表示待回复邀请；仍应显示响应按钮。
   - `currentChoice != nil` 表示已有状态；列表和头部可显示对应状态。

### 判定原则

1. organizer 不进入个人响应展示流。
2. 仅凭“attendees 不为空”不能再推导出当前用户参与上下文。
3. “可针对当前用户单独响应”优先于“底层是否存在原始 participationStatus”。
4. 若事件被判定为只读，则只读语义优先级高于原始状态值。

## 实现方向

1. 在 `CalendarItem.swift` 的 `EKEvent` 扩展中集中产出 `EventParticipationPresentation`。
2. 将 `currentUserParticipationChoice` 收敛为面向列表展示的便捷属性：只有在 `editable(.some(choice))` 时才返回值。
3. 详情页通过 `EventParticipationPresentation` 决定：
   - 头部是否显示状态徽标
   - 是否显示三态按钮
   - 是否显示只读提示
4. 列表卡片通过同一语义决定是否渲染参与状态 metadata。

## 风险与处理

1. **不同源对“可响应”能力暴露不一致**
   - 处理：优先信任 EventKit 明确暴露的可响应能力；若无法确认，则宁可不显示个人状态，也不要误导成“已接受”。

2. **已有可读不可写场景可能被一起隐藏**
   - 处理：第一版明确优先对齐 Apple Calendar 的保守展示；若后续发现真实用户场景需要保留某类只读状态，再单独扩展展示枚举，而不是恢复宽松推断。

3. **详情页底部只读提示需要新增本地化文案**
   - 处理：在 `Localizable.xcstrings` 中新增统一文案，避免硬编码。

## 验证方式

1. 群组邮件邀请在 Apple Calendar 中为只读时，CalendarPro 列表不再显示当前用户 `Accepted` 图标。
2. 同类事件详情头部不再显示 `Accepted` 徽标。
3. 同类事件详情中不再显示 `Accept / Maybe / Decline` 按钮，而是显示只读提示。
4. 同类事件的参会人列表仍正常显示。
5. 普通可响应邀请的状态展示与回复能力保持不变。
