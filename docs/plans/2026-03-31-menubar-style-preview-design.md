# 菜单栏样式下拉预览功能设计

## 背景

用户在设置"菜单栏-显示项"时，下拉选项（如"中文月日"）无法直观展示实际效果。用户需要选择后才能看到预览结果，体验不够友好。

## 需求

将下拉选项的静态文本（如"中文月日"）替换为当前时间的实际预览效果（如"03月31日"），让用户在选择前就能看到真实效果。

## 设计决策

### 预览更新时机
- **决策**：打开下拉菜单时生成一次预览文本
- **理由**：性能更好，实现简单，用户体验已足够

### 显示方式
- **决策**：直接替换原有文本
- **示例**："中文月日" → "03月31日"
- **理由**：更直观简洁

## 技术方案

### 涉及文件
- `CalendarPro/Views/Settings/MenuBarSettingsView.swift` - 主要修改
- `CalendarPro/Features/MenuBar/ClockRenderService.swift` - 可能复用渲染逻辑

### 实现细节

**修改 `MenuBarSettingsView`：**

1. 将 `styleDisplayName(_ style:)` 方法改为 `stylePreviewText(style:for:)`
2. 使用当前时间生成实际预览文本
3. 在 Picker 中使用预览文本

**预览文本示例：**

| Token | Style | 预览文本 |
|-------|-------|---------|
| date | numeric | 03/31 |
| date | short | 03/31 |
| date | full | 2026/03/31 |
| date | chineseMonthDay | 03月31日 |
| weekday | short | Tue |
| weekday | full | Tuesday |
| weekday | chineseWeekday | 周二 |
| time | numeric | 14:30 |
| time | short | 14:30 |
| time | full | 14:30:45 |
| lunar | * | (农历预览) |
| holiday | * | (节假日预览) |

### 不涉及
- 数据模型变更
- 存储格式变更
- 用户交互流程变更

## 风险评估

- **低风险**：仅修改视图层显示逻辑，不影响数据存储和业务逻辑
- **性能影响**：每次视图刷新会重新计算预览文本，但开销可忽略

## 测试要点

1. 各样式预览文本显示正确
2. 时间随系统时间更新
3. 不同时区/语言环境下预览正确
4. 保存设置后实际菜单栏显示与预览一致