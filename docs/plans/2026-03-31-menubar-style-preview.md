# 菜单栏样式下拉预览功能实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将菜单栏设置中的样式下拉选项从静态文本改为显示当前时间的预览效果

**Architecture:** 扩展 `ClockRenderService` 添加预览渲染方法，在 `MenuBarSettingsView` 中调用该方法生成预览文本

**Tech Stack:** SwiftUI, DateFormatter, 现有渲染服务

---

## Task 1: 扩展 ClockRenderService 添加样式预览方法

**Files:**
- Modify: `CalendarPro/Features/MenuBar/ClockRenderService.swift:58-111`

**Step 1: 添加预览渲染方法**

在 `ClockRenderService` 中添加公开方法，为指定 token 和 style 生成预览文本：

```swift
func renderPreview(
    token: DisplayTokenKind,
    style: DisplayTokenStyle,
    now: Date = Date(),
    locale: Locale = .autoupdatingCurrent,
    calendar: Calendar = .autoupdatingCurrent,
    timeZone: TimeZone = .autoupdatingCurrent,
    supplementalText: MenuBarSupplementalText = .empty
) -> String {
    let preference = DisplayTokenPreference(token: token, isEnabled: true, order: 0, style: style)
    return renderToken(preference, now: now, locale: locale, calendar: calendar, timeZone: timeZone, supplementalText: supplementalText) ?? ""
}
```

**Step 2: 修改 renderToken 方法访问级别**

将 `renderToken` 方法从 `private` 改为 `internal`，以便预览方法调用：

```swift
func renderToken(
    _ tokenPreference: DisplayTokenPreference,
    now: Date,
    locale: Locale,
    calendar: Calendar,
    timeZone: TimeZone,
    supplementalText: MenuBarSupplementalText
) -> String? {
    // 现有实现不变
}
```

**Step 3: 验证编译**

Run: `xcodebuild -scheme CalendarPro -destination 'platform=macOS' build 2>&1 | head -50`
Expected: Build succeeded

---

## Task 2: 修改 MenuBarSettingsView 使用预览文本

**Files:**
- Modify: `CalendarPro/Views/Settings/MenuBarSettingsView.swift:39-45`
- Modify: `CalendarPro/Views/Settings/MenuBarSettingsView.swift:149-162`

**Step 1: 修改 Picker 使用预览文本**

将第 40-42 行从：
```swift
ForEach(styleOptions(for: token.token), id: \.self) { style in
    Text(styleDisplayName(style)).tag(style)
}
```

改为：
```swift
ForEach(styleOptions(for: token.token), id: \.self) { style in
    Text(stylePreviewText(style, for: token.token)).tag(style)
}
```

**Step 2: 删除旧的 styleDisplayName 方法**

删除第 149-162 行的 `styleDisplayName` 方法。

**Step 3: 添加 stylePreviewText 方法**

添加新的预览文本生成方法：

```swift
private func stylePreviewText(_ style: DisplayTokenStyle, for token: DisplayTokenKind) -> String {
    let now = Date()
    
    switch token {
    case .date:
        return renderer.renderPreview(token: token, style: style, now: now)
    case .time:
        return renderer.renderPreview(token: token, style: style, now: now)
    case .weekday:
        return renderer.renderPreview(token: token, style: style, now: now)
    case .lunar:
        let lunarText = getLunarPreviewText(for: now)
        return lunarText ?? "农历"
    case .holiday:
        let holidayText = getHolidayPreviewText(for: now)
        return holidayText ?? "节假日"
    }
}

private func getLunarPreviewText(for date: Date) -> String? {
    let factory = CalendarDayFactory(calendar: .autoupdatingCurrent, registry: .live)
    guard let day = try? factory.makeDay(for: date, displayedMonth: date, preferences: store.menuBarPreferences) else {
        return nil
    }
    return day.lunarText
}

private func getHolidayPreviewText(for date: Date) -> String? {
    let factory = CalendarDayFactory(calendar: .autoupdatingCurrent, registry: .live)
    guard let day = try? factory.makeDay(for: date, displayedMonth: date, preferences: store.menuBarPreferences) else {
        return nil
    }
    return day.badges.first?.text
}
```

**Step 4: 验证编译和运行**

Run: `xcodebuild -scheme CalendarPro -destination 'platform=macOS' build 2>&1 | head -50`
Expected: Build succeeded

---

## Task 3: 测试验证

**Step 1: 手动测试**

1. 打开应用，进入"设置 -> 菜单栏"
2. 查看显示项的样式下拉选项
3. 验证：
   - 日期样式显示为：03/31, 03/31, 2026/03/31, 03月31日
   - 时间样式显示为：14:30, 14:30, 14:30:45
   - 星期样式显示为：Tue, Tuesday, 周二
   - 农历样式显示为：实际农历文本（如"三月初三"）
   - 节假日样式显示为：实际节假日文本（如有）

**Step 2: 验证功能完整性**

1. 切换样式后确认菜单栏预览更新
2. 确认设置保存后重启应用仍正确

---

## Task 4: 提交更改

**Step 1: 查看更改**

Run: `git diff`
Review all changes

**Step 2: 提交**

```bash
git add CalendarPro/Features/MenuBar/ClockRenderService.swift
git add CalendarPro/Views/Settings/MenuBarSettingsView.swift
git commit -m "feat(settings): 菜单栏样式下拉选项显示实时预览

- 扩展 ClockRenderService 添加 renderPreview 方法
- 将样式下拉选项从静态文本改为当前时间的预览效果
- 支持日期、时间、星期、农历、节假日的实时预览"
```

---

## 回滚计划

如果出现问题，可以通过以下命令回滚：
```bash
git revert HEAD
```