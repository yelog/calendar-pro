# App Language Switch Design

**Date:** 2026-04-09
**Status:** Approved

## Goal

Add an in-app language switch for CalendarPro with three options: Follow System, Simplified Chinese, and English.

## Scope

- Add a persisted app language setting.
- Make user-facing strings follow the selected app language instead of always following the system.
- Make date/time formatting and locale-sensitive behavior follow the selected app language.
- Make Chinese-only features follow the resolved app language rather than the system locale alone.

## Non-Goals

- Full refactor of every localization call site in one pass.
- Adding more than Chinese and English.
- Translating lunar, solar-term, and traditional festival data into English.

## Design

### 1. AppLanguage setting

Introduce an `AppLanguage` enum with:
- `followSystem`
- `simplifiedChinese`
- `english`

Persist it in `SettingsStore` using `UserDefaults`.

### 2. Central localization provider

Introduce a small app-level localization layer that resolves:
- the active language code
- the active `Locale`
- a localized string lookup function

This layer will be the single source of truth for:
- UI strings
- date/time formatting
- locale-sensitive feature availability

### 3. UI integration

Add a new language picker to `GeneralSettingsView` with three options:
- Follow System
- 简体中文
- English

Changing the picker updates published settings state immediately so SwiftUI views refresh without relaunch.

### 4. String lookup strategy

Current code uses `String(localized:)`, which resolves against the main bundle language selection and does not support an arbitrary app-level override by itself.

To support in-app switching, add a helper that resolves strings from the selected language bundle. New and migrated UI code should use that helper.

### 5. Locale-sensitive formatting

Replace direct `Locale.current` / `Locale.autoupdatingCurrent` reads in app-facing formatting paths with the resolved app locale.

This includes:
- menu bar rendering
- calendar headers
- month picker
- weekday symbols
- event/reminder detail date formatting
- locale-aware defaults for week start and holiday region

### 6. Chinese-only features

Update `LocaleFeatureAvailability` to read the resolved app language. This ensures users can manually switch to Chinese and still see lunar/almanac features even if the OS language is English.

## Files Expected To Change

- `CalendarPro/Settings/SettingsStore.swift`
- `CalendarPro/Views/Settings/GeneralSettingsView.swift`
- `CalendarPro/Infrastructure/LocaleFeatureAvailability.swift`
- `CalendarPro/Features/MenuBar/MenuBarViewModel.swift`
- `CalendarPro/Features/MenuBar/ClockRenderService.swift`
- `CalendarPro/Views/Popover/CalendarPopoverViewModel.swift`
- `CalendarPro/Views/Popover/MonthHeaderView.swift`
- `CalendarPro/Views/Popover/MonthPickerView.swift`
- `CalendarPro/Views/Popover/CalendarPopoverView.swift`
- `CalendarPro/Views/Popover/EventDetailWindowView.swift`
- `CalendarPro/Views/Popover/ReminderDetailWindowView.swift`
- `CalendarPro/Settings/MenuBarPreferences.swift`
- `CalendarPro/Resources/Localizable.xcstrings`

## Risks

- Partial migration can create mixed-language UI if any string path still bypasses the helper.
- Some system-provided labels may remain system-localized.
- Locale defaults must avoid unexpectedly rewriting existing user preferences.
