# Gregorian Observance Festivals Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add rule-based Gregorian observance festivals for Mainland China so Mother's Day and Father's Day display automatically each year.

**Architecture:** Mainland China holiday data continues to load statutory holidays and adjustment workdays from bundled or remote JSON. `MainlandCNProvider` adds calculated `.festival` occurrences for recurring Gregorian weekday rules, exposed through a separate holiday set so users can enable or disable these observance festivals independently. Existing resolver filtering keeps working because calculated records use the same `HolidayOccurrence` model.

**Tech Stack:** Swift 6, Foundation `Calendar`, XCTest, existing `HolidayProvider` and `CalendarDayFactory` pipelines.

---

### Task 1: Add The Holiday Set And Rule Generator

**Files:**
- Modify: `CalendarPro/Features/Holidays/MainlandCNProvider.swift`
- Modify: `CalendarPro/Features/Holidays/HolidayOccurrence.swift`

**Steps:**
1. Add a Mainland China holiday set id for commemorative festivals.
2. Add a calculated source case for Gregorian rules.
3. Generate Mother's Day as the second Sunday in May.
4. Generate Father's Day as the third Sunday in June.
5. Append calculated occurrences to JSON-loaded occurrences.

### Task 2: Keep User Preferences Compatible

**Files:**
- Modify: `CalendarPro/Settings/SettingsStore.swift`
- Test: `CalendarProTests/Settings/SettingsStoreTests.swift`

**Steps:**
1. Add the new holiday set id to explicit Mainland China holiday selections when loading old preferences that only knew `statutory-holidays` and `adjustment-workdays`.
2. Preserve explicit opt-outs for users who disabled all Mainland China holiday sets.
3. Verify persisted preferences are migrated once and remain stable.

### Task 3: Cover Calendar Behavior

**Files:**
- Test: `CalendarProTests/Holidays/MainlandCNProviderTests.swift`
- Test: `CalendarProTests/Calendar/CalendarDayFactoryTests.swift`

**Steps:**
1. Assert `2026-05-10` is generated as `母亲节`.
2. Assert `2026-06-21` is generated as `父亲节`.
3. Assert the calendar grid displays the generated festival badge text.
4. Assert disabling the commemorative set filters the generated festivals out.

### Task 4: Localize Settings Copy

**Files:**
- Modify: `CalendarPro/Resources/Localizable.xcstrings`

**Steps:**
1. Add the display name key for the new set.
2. Provide English and Simplified Chinese values.

### Task 5: Verify

**Commands:**
- `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/MainlandCNProviderTests`
- `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarDayFactoryTests`
- `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/SettingsStoreTests`
- `xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'`
