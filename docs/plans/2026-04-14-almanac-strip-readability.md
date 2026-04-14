# Improve Almanac Strip Readability Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 优化 popover 黄历宜忌条的视觉层级和可读性，让类型更醒目、正文更易读。

**Architecture:** 保持现有黄历数据链路不变，只调整 `AlmanacStripView` 的视图结构与排版规则，并在 `CalendarPopoverView` 侧避免无内容黄历条占位。

**Tech Stack:** Swift, SwiftUI, macOS

---

### Task 1: 重构黄历条行布局

**Files:**
- Modify: `CalendarPro/Views/Popover/AlmanacStripView.swift`

### Task 2: 增加空内容隐藏逻辑

**Files:**
- Modify: `CalendarPro/Views/Popover/CalendarPopoverView.swift`

### Task 3: 验证构建和界面回归

**Files:**
- Verify only

Run:
- `xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'`
