# 会议平台支持扩展设计

**日期：** 2026-04-11

**目标：** 基于当前 `MeetingLinkDetector`、列表卡片 metadata 和详情页加入会议按钮能力，系统评估中国市场与国际常见会议平台的可支持性，并给出分阶段的产品化扩展方案。

## 背景

当前 CalendarPro 已经为会议事件提供了两层能力：

1. 在事件详情中识别会议链接并显示加入会议按钮。
2. 在事件卡片中显示会议 metadata，并对 Microsoft Teams 提供品牌化图标。

随着 Teams 体验已经初步跑通，下一步问题不再是“是否支持会议链接”，而是：

1. 其他会议平台是否已经被代码识别。
2. 哪些平台能够稳定做到与 Teams 类似的体验。
3. 哪些平台只能提供基础支持，不能承诺品牌化或高置信度识别。
4. 应该按什么优先级扩展，以兼顾中国市场和国际常见平台。

## 当前代码现状

### 检测层

`CalendarPro/Features/Events/MeetingLinkDetector.swift`

当前检测实现特点：

1. 平台识别入口是 `MeetingLinkDetector.detect(in:)`。
2. 检测顺序依次为：
   - `event.url`
   - `event.notes`
   - `event.location`
3. 检测方式是纯 URL regex 匹配。
4. 当前 `MeetingLink` 模型仅包含：
   - `url`
   - `platform`
   - `iconName`

当前已内置识别的平台：

1. Microsoft Teams
2. Zoom
3. Google Meet
4. Webex
5. Feishu
6. Tencent Meeting
7. DingTalk

### 详情页加入按钮

`CalendarPro/Views/Popover/EventDetailWindowView.swift`

当前行为：

1. 只要 `meetingLink` 不为 `nil`，就显示 `JoinMeetingButton`。
2. 按钮行为统一为 `NSWorkspace.shared.open(meetingLink.url)`。
3. 按钮图标统一取 `meetingLink.iconName`。
4. 按钮标题统一取 `LF("Join %@ Meeting", meetingLink.platform)`。

这意味着当前所有平台都共享同一套按钮模板，而不是平台专属模板。

### 列表卡片会议 metadata

`CalendarPro/Views/Popover/EventCardView.swift`

当前行为：

1. 会议 metadata 来源于 `CalendarItem.meetingLink`。
2. 只有 Teams 做了品牌图标特判。
3. 其他平台当前都退化为通用 SF Symbol。

## 问题定义

需要先明确“像 Teams 一样支持”的含义。本文中将其拆为四个等级：

### Level 0：不支持

- 无法可靠识别会议链接。

### Level 1：基础支持

- 能识别出平台链接。
- 能在详情页展示加入按钮。
- 能打开该链接。

### Level 2：产品化支持

- Level 1 全部成立。
- 列表卡片和详情按钮具备平台专属命名和图标。
- 不会出现不自然文案，例如 `Tencent Meeting Meeting`。

### Level 3：高置信度支持

- Level 2 全部成立。
- 覆盖常见邀请格式、国际/地区域名变体和主要 URL 形态。
- 假阳性较低，用户能稳定预期其识别结果。

当前 Teams 处于 Level 2 的起点，其余平台大多处于 Level 1。

## 中国市场平台分析

### 腾讯会议

**当前代码情况：**

- 已有 regex：`https?://meeting\.tencent\.com/...`
- 已有基础测试：`CalendarProTests/Events/MeetingLinkDetectorTests.swift`

**可支持性判断：**

- Level 1：已具备
- Level 2：未具备
- Level 3：部分可达

**原因：**

1. 腾讯会议在日历邀请中出现标准 URL 的情况较常见。
2. 当前架构已经能识别并展示加入按钮。
3. 但品牌图标、专属按钮标题、国际域名变体尚未建模。

**主要缺口：**

1. 当前标题模板会生成 `Join Tencent Meeting Meeting`。
2. 卡片与详情页都没有腾讯会议品牌表达。
3. 尚未覆盖 `voovmeeting.com` 等国际化变体。

**结论：**

腾讯会议是中国市场里最值得优先补齐的平台，适合进入第一阶段实现。

### 飞书会议

**当前代码情况：**

- 已有 regex：`https?://(meetings|vc)\.feishu\.cn/...`
- 已有基础测试

**可支持性判断：**

- Level 1：已具备
- Level 2：未具备
- Level 3：可达到中高水平

**原因：**

1. 飞书会议链接在邀请正文中相对稳定。
2. 当前 detector 已覆盖两个主要域名。
3. 与腾讯会议一样，缺的是平台建模与品牌化渲染，而不是基础检测路径。

**主要缺口：**

1. 无品牌图标。
2. 缺少平台专属按钮文案和图标风格。
3. 未对不同邀请模版做更系统的样例测试。

**结论：**

飞书会议同样适合第一阶段实现，优先级与腾讯会议并列。

### 钉钉会议

**当前代码情况：**

- 已有 regex：`https?://meeting\.dingtalk\.com/...`
- 已有基础测试

**可支持性判断：**

- Level 1：代码上已具备
- Level 2：可实现
- Level 3：风险较高

**原因：**

1. 钉钉在很多场景里更偏会议号、App 内跳转或 deep link，而不是统一稳定的公开 web join URL。
2. 即使当前 regex 有效，也未必能覆盖真实邀请里的主要路径。
3. 如果过早宣称与 Teams 等价，实际命中率可能不达预期。

**主要缺口：**

1. 缺乏足够多的真实邀请样例。
2. 当前纯 URL regex 架构对钉钉这种平台的上限较低。
3. 品牌化和文案问题与腾讯/飞书相同。

**结论：**

钉钉会议可以支持，但建议排在腾讯会议和飞书之后，作为第二阶段平台。

## 国际常见平台分析

### 已有基础支持的平台

#### Zoom

- 当前已支持基础识别。
- 由于 Zoom 邀请中标准 join URL 非常稳定，适合升级到 Level 2/3。
- 建议纳入第一阶段品牌化补齐。

#### Google Meet

- 当前已支持基础识别。
- `meet.google.com/<token>` 形态稳定，适合升级到 Level 2/3。
- 需要修复按钮标题，避免 `Join Google Meet Meeting`。

#### Webex

- 当前已支持基础识别。
- 企业环境中常见，且 URL 结构整体可预测。
- 建议纳入第一阶段，但补充 `wbxmjs/joinservice` 等路径覆盖。

### 建议新增的一线国际平台

#### Whereby

- join URL 结构通常为 `whereby.com/<room>`。
- 检测成本低，产品语义清晰。
- 适合第二阶段新增。

#### GoTo Meeting

- 常见形态包括 `meet.goto.com/<id>` 与旧版 `global.gotomeeting.com/join/<id>`。
- 可识别，但需同时覆盖新旧格式。
- 适合第二阶段新增。

#### VooV Meeting

- 是腾讯会议国际化品牌。
- 与中国市场目标相关，也适合第二阶段纳入。

### 不建议优先做一等平台的平台

#### Slack Huddles / Calls

- 公开 join URL 不稳定。
- 很多场景依赖工作区内部跳转。
- 更适合 generic link，而不是平台专属支持。

#### Jitsi Meet

- `meet.jit.si` 官方域名可识别。
- 但大量自建实例使用自定义域名，通用识别不可靠。
- 适合作为低优先级或仅支持官方域名。

#### Skype consumer / Teams consumer / Meet Now

- 邀请形态不如企业版 Teams 标准化。
- 当前产品价值和用户收益有限。

#### BlueJeans

- 具备一定历史 URL 规律，但现实价值已经较低。

## 方案对比

### 方案 A：沿用字符串平台名，逐个补规则和 if/else

**优点：**

- 改动最少。

**缺点：**

- `EventCardView` 与 `EventDetailWindowView` 会持续堆积平台特判。
- 文案、图标、URL 规则会散落在多处。
- 难以扩展到中国市场和国际多平台并存的状态。

### 方案 B：引入 typed platform model，统一平台元信息

**优点：**

- 检测、文案、图标、品牌化渲染都可由单一模型驱动。
- 可自然支持平台分层与 fallback。
- 适合未来继续扩展。

**缺点：**

- 初始重构成本高于字符串特判。

### 方案 C：只增强 regex，不做 UI 平台化

**优点：**

- 能快速增加可识别平台数量。

**缺点：**

- 仍然只能停留在“基础支持”。
- 用户感知不到“我们真的支持了这些平台”。

## 选定方案

采用方案 B。

即：先把平台从字符串升级为统一建模，再在这个模型上分阶段扩展中国市场与国际平台支持。

## 架构设计

### 平台模型

建议把 `MeetingLink` 从简单字符串容器升级为平台驱动模型，例如：

1. `MeetingPlatform` 枚举或配置对象。
2. 每个平台定义：
   - `displayName`
   - `joinButtonTitle`
   - `cardBadgeStyle`
   - `detailIconStyle`
   - `patterns`
   - `supportTier`

### 检测职责

`MeetingLinkDetector.swift` 负责：

1. 从 `event.url`、`notes`、`location` 中提取会议 URL。
2. 以平台模型为中心匹配 URL。
3. 返回包含平台语义的 `MeetingLink`。

### 视图职责

#### `EventCardView.swift`

负责：

1. 根据平台显示品牌图标或 fallback 图标。
2. 统一渲染平台 badge，而不是硬编码 Teams 特判。

#### `EventDetailWindowView.swift`

负责：

1. 显示平台专属加入按钮标题。
2. 使用平台驱动的图标或品牌标识。
3. 对低置信度平台提供 generic fallback，例如 `Open Meeting Link`。

## 分阶段实施范围

### 第一阶段：高收益平台产品化

目标：把“已经能识别”的高价值平台升级为真正的一等支持。

范围：

1. Microsoft Teams
2. Tencent Meeting
3. Feishu
4. Zoom
5. Google Meet
6. Webex

交付内容：

1. typed platform model
2. 平台专属按钮标题
3. 列表卡片品牌化图标
4. 平台测试样例补齐

### 第二阶段：扩展 URL 变体与次一级平台

范围：

1. VooV Meeting
2. Whereby
3. GoTo Meeting
4. Webex 额外路径形态
5. 钉钉会议的进一步样例验证和补强

### 第三阶段：低置信度平台 fallback 策略

范围：

1. Slack Huddles
2. Jitsi 官方域名 / 自建实例区分
3. consumer 平台与其他长尾平台

交付目标：

1. 只在高置信度平台上使用品牌化支持。
2. 对模糊场景明确退回 generic meeting link 打开逻辑。

## 风险与处理

1. **误把“已识别 URL”当成“已完整支持平台”**
   - 处理：引入 support tier 概念，在模型中明确区分。

2. **平台按钮标题不自然**
   - 处理：由平台模型提供 `joinButtonTitle`，而不是统一字符串拼接。

3. **品牌图标资源扩散成大量硬编码**
   - 处理：将平台图标映射集中在平台模型或独立品牌视图工厂中。

4. **钉钉 / Jitsi 等平台误判率高**
   - 处理：优先只做高置信度平台，低置信度场景退回 generic fallback。

## 验证方式

1. 腾讯会议、飞书、Zoom、Google Meet、Webex 的事件详情页显示自然的加入按钮标题。
2. 会议卡片可以按平台显示品牌化图标，而不是仅 Teams 特判。
3. `MeetingLinkDetectorTests` 覆盖中国市场与国际平台的主要 URL 形态。
4. 对低置信度平台不会误显示错误品牌按钮。
5. 现有 Teams 能力不回退。

## 结论

从代码层面看，腾讯会议、飞书、钉钉已经具备基础识别入口，但只有 Teams 达到了部分产品化支持。

最合理的方向不是继续追加字符串 regex 和视图特判，而是先完成平台模型抽象，再优先补齐：

1. 腾讯会议
2. 飞书会议
3. Zoom
4. Google Meet
5. Webex

钉钉、VooV、Whereby、GoTo Meeting 则作为第二阶段扩展。低置信度平台统一采用 generic fallback，避免错误承诺。
