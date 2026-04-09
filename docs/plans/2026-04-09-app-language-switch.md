# App Language Switch Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add an in-app language switch with Follow System, Simplified Chinese, and English, and make strings plus locale-sensitive formatting respect that choice.

**Architecture:** Persist an `AppLanguage` value in settings, resolve a single active app locale from it, and route string lookup plus date/time formatting through that resolved locale. Keep the implementation minimal by centralizing language logic in a small helper instead of duplicating per-view state.

**Tech Stack:** Swift 6, SwiftUI, String Catalog (`.xcstrings`), UserDefaults.

---

### Task 1: Add App Language State

**Files:**
- Modify: `CalendarPro/Settings/SettingsStore.swift`
- Modify: `CalendarPro/Settings/MenuBarPreferences.swift`

**Steps:**
1. Add `AppLanguage` enum with `followSystem`, `simplifiedChinese`, `english`.
2. Persist the value in `SettingsStore`.
3. Expose a published property and setter.

### Task 2: Add Central Localization Helper

**Files:**
- Create: `CalendarPro/Infrastructure/AppLanguage.swift`
- Create: `CalendarPro/Infrastructure/AppLocalization.swift`
- Modify: `CalendarPro/Infrastructure/LocaleFeatureAvailability.swift`

**Steps:**
1. Resolve active language code and locale from app settings.
2. Add a string lookup helper that reads from the selected language bundle.
3. Make locale-based feature checks use the resolved app language.

### Task 3: Add Language Picker UI

**Files:**
- Modify: `CalendarPro/Views/Settings/GeneralSettingsView.swift`
- Modify: `CalendarPro/Resources/Localizable.xcstrings`

**Steps:**
1. Add a new settings row for app language.
2. Provide three picker options and localized labels.
3. Bind it to `SettingsStore.appLanguage`.

### Task 4: Route Strings Through App Localization

**Files:**
- Modify: `CalendarPro/Views/Settings/*.swift`
- Modify: `CalendarPro/Views/Popover/*.swift`
- Modify: `CalendarPro/App/*.swift`
- Modify: `CalendarPro/Features/Events/*.swift`

**Steps:**
1. Replace direct `String(localized:)` use in high-visibility screens with the helper.
2. Keep changes scoped to user-facing strings already migrated into the string catalog.

### Task 5: Route Date/Time Formatting Through App Locale

**Files:**
- Modify: `CalendarPro/Features/MenuBar/ClockRenderService.swift`
- Modify: `CalendarPro/Features/MenuBar/MenuBarViewModel.swift`
- Modify: `CalendarPro/Views/Popover/CalendarPopoverViewModel.swift`
- Modify: `CalendarPro/Views/Popover/MonthHeaderView.swift`
- Modify: `CalendarPro/Views/Popover/MonthPickerView.swift`
- Modify: `CalendarPro/Views/Popover/CalendarPopoverView.swift`
- Modify: `CalendarPro/Views/Popover/EventDetailWindowView.swift`
- Modify: `CalendarPro/Views/Popover/ReminderDetailWindowView.swift`

**Steps:**
1. Pass the resolved app locale into formatting code.
2. Stop reading locale directly from the system in these paths.
3. Preserve POSIX formatters where they are used for stable identifiers only.

### Task 6: Build And Verify

**Files:**
- Modify: `CalendarPro.xcodeproj/project.pbxproj` if new files are added and generator requires it.

**Steps:**
1. Regenerate the Xcode project if needed.
2. Run `xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'`.
3. Commit with a single focused message.
