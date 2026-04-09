# Locale Awareness & Internationalization Design

**Date:** 2026-04-09
**Status:** Approved

## Goal

Make CalendarPro functional for English-speaking users (US, UK) by fixing all hardcoded Chinese locale assumptions, adding locale-aware date/time formatting, and providing US/UK holiday data.

## Scope

- **P0:** Fix core locale bugs — hardcoded `zh_CN`/`zh_Hans` locales, Chinese date templates, weekend detection, 12/24h time, badge text, summary text. Add `.xcstrings` String Catalog. Auto-hide Chinese-only features for non-Chinese locales.
- **P1:** Add US Federal Holidays and UK Bank Holidays providers with 2025-2026 data.
- **Out of scope:** UI layout adjustments, full string localization of all Settings views, localization of EventDetailWindowView/ReminderDetailWindowView beyond date formatting.

## Design Decisions

### 1. Localization Infrastructure: String Catalog (.xcstrings)

Use Xcode 15+ String Catalogs. Create `CalendarPro/Resources/Localizable.xcstrings` with all user-facing strings. Use `String(localized:)` in SwiftUI views and `NSLocalizedString` in non-UI code.

### 2. Chinese-Only Features: Auto-Hide by Locale

Non-Chinese locale → hide lunar calendar, almanac (宜忌), solar terms, 调休 badges, Chinese date format styles in menu bar config. Implemented via `LocaleFeatureAvailability` utility.

### 3. Default Values: Locale-Aware

`MenuBarPreferences.defaultsForCurrentLocale()` auto-selects:
- `zh-*` → mainland-cn, Monday
- `en-US` → us, Sunday
- `en-GB` → uk, Monday
- Other → empty, Monday

### 4. Date/Time Formatting: Locale-Neutral Templates

Replace all `"M月d日 EEEE"` with `"MMMdEEEE"`, `"yyyy年"` with `"y"`, `"M月"` with `"MMM"`. Use `DateFormatter.dateStyle`/`timeStyle` instead of fixed format strings for ClockRenderService.

### 5. Weekend Detection: Index-Based

Replace string comparison `["周日", "周六"]` with `Calendar` weekday index check.

### 6. Holiday Providers: Existing Protocol

US and UK providers follow `HolidayProvider` protocol, use `BundledHolidayDataLoader`, data in JSON format matching existing schema.

## Files to Create

- `CalendarPro/Infrastructure/LocaleFeatureAvailability.swift`
- `CalendarPro/Features/Holidays/UnitedStatesProvider.swift`
- `CalendarPro/Features/Holidays/UnitedKingdomProvider.swift`
- `CalendarPro/Resources/Holidays/us/us-2025.json`
- `CalendarPro/Resources/Holidays/us/us-2026.json`
- `CalendarPro/Resources/Holidays/uk/uk-2025.json`
- `CalendarPro/Resources/Holidays/uk/uk-2026.json`
- `CalendarPro/Resources/Localizable.xcstrings`

## Files to Modify

- `CalendarPro/Features/MenuBar/ClockRenderService.swift` — locale-aware date/time/weekday rendering
- `CalendarPro/Views/Popover/CalendarPopoverViewModel.swift` — weekday symbols locale
- `CalendarPro/Views/Popover/MonthHeaderView.swift` — locale-aware year/month format
- `CalendarPro/Views/Popover/MonthPickerView.swift` — locale-aware month names + year format
- `CalendarPro/Views/Popover/CalendarGridView.swift` — weekend detection fix + badge localization
- `CalendarPro/Views/Popover/CalendarPopoverView.swift` — date template fix + footer button localization
- `CalendarPro/Views/Popover/EventCardView.swift` — time format locale-aware + all-day/untimed localization
- `CalendarPro/Views/Popover/EventListView.swift` — time format locale-aware + section header localization
- `CalendarPro/Views/Popover/EventDetailWindowView.swift` — date template fix
- `CalendarPro/Views/Popover/ReminderDetailWindowView.swift` — date template fix
- `CalendarPro/Settings/MenuBarPreferences.swift` — locale-aware defaults + localized summary text
- `CalendarPro/Features/Holidays/HolidayProviderRegistry.swift` — register US/UK providers
- `CalendarPro/Features/Holidays/MainlandCNProvider.swift` — localized displayName
- `CalendarPro/Features/Holidays/HongKongProvider.swift` — localized displayName
- Various Settings views — conditional display of Chinese features
