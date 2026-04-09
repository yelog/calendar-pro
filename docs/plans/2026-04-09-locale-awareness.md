# Locale Awareness Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make CalendarPro usable for English-speaking locales by removing hardcoded Chinese locale assumptions and adding US/UK holiday data.

**Architecture:** Keep the existing app structure and holiday provider model. Fix locale-sensitive rendering in place, add a small locale capability helper, then extend the holiday registry with bundled US/UK providers and datasets.

**Tech Stack:** Swift 6, SwiftUI, Xcode String Catalog, Xcodeproj generator, bundled JSON holiday resources.

---

### Task 1: Locale Capability Guardrails

**Files:**
- Create: `CalendarPro/Infrastructure/LocaleFeatureAvailability.swift`
- Modify: `CalendarPro/Views/Settings/GeneralSettingsView.swift`
- Modify: `CalendarPro/Views/Settings/MenuBarSettingsView.swift`

**Steps:**
1. Add a locale helper that answers whether Chinese-only features should be shown.
2. Hide almanac controls for non-Chinese locales.
3. Filter Chinese-only menu bar date styles for non-Chinese locales.

### Task 2: Locale-Aware Date And Time Rendering

**Files:**
- Modify: `CalendarPro/Features/MenuBar/ClockRenderService.swift`
- Modify: `CalendarPro/Views/Popover/CalendarPopoverViewModel.swift`
- Modify: `CalendarPro/Views/Popover/MonthHeaderView.swift`
- Modify: `CalendarPro/Views/Popover/MonthPickerView.swift`
- Modify: `CalendarPro/Views/Popover/CalendarPopoverView.swift`
- Modify: `CalendarPro/Views/Popover/EventCardView.swift`
- Modify: `CalendarPro/Views/Popover/EventListView.swift`
- Modify: `CalendarPro/Views/Popover/EventDetailWindowView.swift`
- Modify: `CalendarPro/Views/Popover/ReminderDetailWindowView.swift`

**Steps:**
1. Replace hardcoded `zh_CN` / `zh_Hans` locale usage with `Locale.autoupdatingCurrent` where appropriate.
2. Replace Chinese date templates with locale-neutral templates.
3. Use locale-aware time formatting instead of fixed `HH:mm` strings.

### Task 3: Weekend Highlighting And Localized Labels

**Files:**
- Create: `CalendarPro/Resources/Localizable.xcstrings`
- Modify: `CalendarPro/Views/Popover/CalendarGridView.swift`
- Modify: `CalendarPro/Views/RootPopoverView.swift`
- Modify: `CalendarPro/Settings/MenuBarPreferences.swift`

**Steps:**
1. Replace hardcoded Chinese badge and summary strings with catalog-backed strings.
2. Switch weekend header highlighting from string matching to weekday index logic.
3. Make default week start and active region locale-aware.

### Task 4: US And UK Holidays

**Files:**
- Create: `CalendarPro/Features/Holidays/UnitedStatesProvider.swift`
- Create: `CalendarPro/Features/Holidays/UnitedKingdomProvider.swift`
- Create: `CalendarPro/Resources/Holidays/us/us-2025.json`
- Create: `CalendarPro/Resources/Holidays/us/us-2026.json`
- Create: `CalendarPro/Resources/Holidays/uk/uk-2025.json`
- Create: `CalendarPro/Resources/Holidays/uk/uk-2026.json`
- Modify: `CalendarPro/Features/Holidays/HolidayProviderRegistry.swift`
- Modify: `CalendarPro/Features/Holidays/MainlandCNProvider.swift`
- Modify: `CalendarPro/Features/Holidays/HongKongProvider.swift`

**Steps:**
1. Add bundled providers for US federal holidays and UK bank holidays.
2. Register them in the shared holiday registry.
3. Localize provider and holiday set display names.

### Task 5: Project Integration And Verification

**Files:**
- Modify: `tools/generate_xcodeproj.rb`
- Modify: `CalendarPro.xcodeproj/project.pbxproj`
- Modify: `CalendarPro.xcodeproj/xcshareddata/xcschemes/CalendarPro.xcscheme`

**Steps:**
1. Update the Xcode project generator so it preserves `tyme4swift` and includes `.xcstrings` resources.
2. Regenerate the Xcode project.
3. Run `xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'`.
