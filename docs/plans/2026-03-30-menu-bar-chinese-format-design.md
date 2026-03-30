# Menu Bar Chinese Format Design

## Overview
为菜单栏新增可选的中文日期和中文星期样式。

## Requirements

1. 日期支持新的可选样式 `03月30日`
2. 星期支持新的可选样式 `周一`
3. 新样式必须是显式可选项，不随系统语言自动切换
4. 现有设置数据保持兼容，默认值不变

## Architecture

### 1. Preferences Model

继续复用 `DisplayTokenStyle`，为其新增两个枚举值：

- `chineseMonthDay`
- `chineseWeekday`

这样可以避免引入新的持久化结构，也不需要做设置迁移。

### 2. Rendering

`ClockRenderService` 针对两个新样式增加专门分支：

- 日期 `chineseMonthDay` 固定输出 `MM月dd日`
- 星期 `chineseWeekday` 固定输出 `周日` 到 `周六`

中文格式不依赖当前系统 locale，确保用户选中后始终得到中文展示。

### 3. Settings UI

`MenuBarSettingsView` 改为按 token 提供样式选项：

- 日期：数字 / 简写 / 完整 / 中文月日
- 星期：简写 / 完整 / 中文周
- 其他 token 保持现有通用选项

这样可以避免在星期里显示无意义的“中文月日”，也避免在日期里显示“中文周”。

## Error Handling

- 对旧配置保持兼容，未选中新样式时继续沿用当前渲染逻辑
- 若某 token 持久化了当前 UI 不提供的旧样式值，设置页回退到该 token 的默认展示样式

## Testing

- 为 `ClockRenderService` 增加中文日期和中文星期渲染测试
- 为 `MenuBarPreferences` 增加新样式的 Codable round-trip 测试
- 为 `SettingsStore` 增加新样式的持久化测试
