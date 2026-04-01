# 农历节气显示设计

**日期：** 2026-04-01

**目标：** 为 Calendar Pro 的农历展示链路补充二十四节气支持，使月历与菜单栏在命中节气时能显示“立春”“惊蛰”“立夏”等文本，而不是只显示普通农历日。

## 背景

当前项目的农历模块只覆盖两类信息：

1. 农历年、月、日文本
2. 少量传统农历节日，如春节、端午、中秋

因此即使某一天恰好是二十四节气之一，界面仍只会显示“正月十七”“三月十九”这类普通农历文本，不会出现“立春”“惊蛰”“立夏”。

## 问题原因

代码路径已经明确：

1. [`LunarService`](/Users/yelog/workspace/swift/calendar-pro/CalendarPro/Features/Lunar/LunarService.swift) 只负责农历转换和传统节日命中
2. [`TraditionalFestivalResolver`](/Users/yelog/workspace/swift/calendar-pro/CalendarPro/Features/Lunar/TraditionalFestivalResolver.swift) 只维护传统农历节日
3. [`LunarDateDescriptor`](/Users/yelog/workspace/swift/calendar-pro/CalendarPro/Features/Lunar/LunarDateDescriptor.swift) 只有 `festivalName`，没有节气字段
4. [`CalendarDayFactory`](/Users/yelog/workspace/swift/calendar-pro/CalendarPro/Features/Calendar/CalendarDayFactory.swift) 只是消费 `displayText()`，本身没有节气逻辑

所以问题不是“展示层漏判”，而是数据模型和解析层完全没有节气入口。

## 用户确认的显示规则

优先级按以下顺序处理：

1. 传统农历节日
2. 节气
3. 普通农历文本

这意味着：

- 普通日期继续显示“初七”“廿三”等农历日
- 节气日显示“立春”“惊蛰”“立夏”等节气名
- 若极少数情况下传统节日与节气冲突，优先显示传统节日

## 方案对比

### 方案 A：新增本地 `SolarTermResolver`，按太阳黄经近似求节气时刻

- 在本地根据太阳视黄经达到每 `15°` 整倍数的时刻计算二十四节气
- 将结果按公历年缓存
- 在 `LunarService` 中统一合并节日与节气结果

**优点：**
- 不依赖网络
- 和现有 `Features/Lunar` 架构一致
- 不需要维护逐年静态数据表

**缺点：**
- 需要实现并维护一套近似天文计算逻辑

### 方案 B：维护逐年节气 JSON 数据

- 为每年维护 24 个节气日期

**优点：**
- 逻辑最直接

**缺点：**
- 扩展性差
- 数据维护成本高
- 与当前农历模块“计算式而非喂表式”的风格不一致

### 方案 C：依赖系统格式化器或远程接口

- 尝试由 Foundation/ICU 直接返回节气名，或通过远程接口查询

**优点：**
- 本地代码可能更少

**缺点：**
- 当前 Foundation 格式化能力无法直接产出节气名
- 远程接口会引入网络依赖和离线退化

## 选定方案

采用方案 A：新增本地 `SolarTermResolver`。

## 架构设计

### 数据模型

扩展 [`LunarDateDescriptor`](/Users/yelog/workspace/swift/calendar-pro/CalendarPro/Features/Lunar/LunarDateDescriptor.swift)：

- 新增 `solarTermName: String?`

保持 `festivalName` 不变，通过 `displayText()` 统一应用优先级。

### 解析链路

1. `LunarService.describe(...)` 继续先计算农历年月日
2. 同时调用 `TraditionalFestivalResolver` 获取传统节日
3. 再调用新增的 `SolarTermResolver` 获取节气
4. 结果统一写入 `LunarDateDescriptor`

### 节气计算方式

`SolarTermResolver` 采用低成本但稳定的本地近似算法：

1. 用太阳视黄经近似公式计算某一时刻的太阳黄经
2. 对每个节气目标角度（`0° / 15° / 30° ...`）做二分搜索
3. 求出该公历年的 24 个节气发生时刻
4. 将这些时刻按年份缓存，避免月历渲染时重复计算

这样可以避免“世纪常数公式”在个别年份出现的一天误差，例如 2026 年惊蛰这类边界日期。

### 展示层影响

展示层不需要新增条件分支：

- 月历网格仍然读取 `CalendarDay.lunarText`
- 菜单栏农历 token 仍然读取 `LunarService.describe(...).displayText(...)`

只要 `displayText()` 正确纳入节气优先级，现有调用点会自动获得节气支持。

## 风险与处理

1. **节气算法精度不足**
   - 处理：不用简单日期经验公式，改用太阳黄经迭代求解；测试覆盖多个节气和跨年份边界。

2. **月历渲染频繁触发重复计算**
   - 处理：按公历年缓存节气时刻，避免每个日期重新推导 24 次。

3. **节气与传统节日优先级冲突**
   - 处理：在 `displayText()` 中统一固定为“传统节日 > 节气 > 普通农历文本”。

4. **时区导致节气落日偏移**
   - 处理：节气统一按北京时间（`Asia/Shanghai`）归属自然日，保证中文农历语义稳定，不随设备所在时区漂移。

## 验证方式

1. 验证 2026-02-04 显示“立春”。
2. 验证 2026-03-05 显示“惊蛰”。
3. 验证 2026-05-05 显示“立夏”。
4. 验证传统节日仍优先显示，如 2026-02-17 继续显示“春节”。
5. 验证非节气非节日日期继续显示普通农历日文本。
6. 运行 `LunarServiceTests` 与 `CalendarDayFactoryTests`，再做整项目构建。
