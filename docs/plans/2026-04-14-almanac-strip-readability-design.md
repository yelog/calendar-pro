# Improve Almanac Strip Readability Design

**Date:** 2026-04-14
**Status:** Approved

## Goal

提升 popover 黄历宜忌条的层级与可读性，让用户先看到 `宜/忌` 类型，再自然阅读后续事项内容。

## Scope

- 调整黄历条的视觉层级与排版结构。
- 将 `宜/忌` 做成固定语义徽章，正文改为普通阅读色。
- 将事项分隔符改为中文顿号，并允许正文最多展示两行。
- 在没有黄历内容时隐藏空白卡片。

## Non-Goals

- 不修改 `AlmanacService` 的计算逻辑和数据来源。
- 不调整月历网格、事件列表、底部按钮等其它 popover 区块。
- 不新增黄历相关设置项或交互。

## Design

### 1. 类型和内容分层

每一行黄历信息拆成两部分：

- 左侧为固定尺寸的圆形语义徽章，分别显示 `宜` 和 `忌`。
- 右侧为事项正文，使用普通浅色文字承载具体内容。

这样可以保留类型辨识度，同时避免整段语义色造成的阅读疲劳。

### 2. 排版和阅读节奏

正文不再强制单行缩放，而是改为：

- 最多显示两行
- 超出时尾部截断
- 使用中文顿号 `、` 连接事项

这比当前的整行压缩更适合中文阅读，也能覆盖事项较多的日期。

### 3. 容器样式

保留当前黄历条的独立卡片位置和整体风格，但微调：

- 略增内边距和行间距
- 保持轻量背景和细描边
- 让内容更像一块信息面板，而不是两行状态字

### 4. 空内容处理

如果某一天只存在 `宜` 或只存在 `忌`，则仅渲染对应一行。

如果 `宜` 和 `忌` 都为空，则直接隐藏黄历条，避免出现无信息的占位背景。

## Files Expected To Change

- `CalendarPro/Views/Popover/AlmanacStripView.swift`
- `CalendarPro/Views/Popover/CalendarPopoverView.swift`

## Validation

- 黄历条在普通内容、长内容、仅单行内容时都能保持清晰排版。
- `showAlmanac` 开启且内容为空时，不显示空白黄历卡片。
- `xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'` 成功。
