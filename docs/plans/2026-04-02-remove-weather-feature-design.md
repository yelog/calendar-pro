# Remove Weather Feature Design

**Goal:** 从 Calendar Pro 中彻底移除天气功能，同时保留黄历展示能力。

## Scope

- 删除天气设置项与持久化字段。
- 删除天气 provider、天气视图和 WeatherKit/CoreLocation 依赖。
- 删除 popover 中所有天气注入和展示逻辑。
- 删除工程中的 WeatherKit capability 和定位用途描述。

## Non-Goals

- 不调整黄历逻辑。
- 不改动事件列表、节假日、菜单栏显示和其它设置分组行为。

## Validation

- `rg` 搜索项目内不再有 `WeatherKit`、`showWeather`、`WeatherProvider`、`WeatherStripView` 等引用。
- `xcodebuild -project CalendarPro.xcodeproj -scheme CalendarPro -configuration Debug build` 成功。
