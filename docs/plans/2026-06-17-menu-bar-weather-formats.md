# Menu Bar Weather Formats Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Let users display weather in the menu bar with common compact formats, gated by the existing weather switch.

**Architecture:** Reuse the existing weather display token and `DisplayTokenStyle` persistence. Add weather-specific styles, format `WeatherDescriptor` into menu bar text in `MenuBarViewModel`, and disable the Weather token controls when the global weather switch is off.

**Tech Stack:** Swift 6, SwiftUI, Combine, XCTest, macOS menu bar rendering.

---

### Task 1: Add Weather Styles

**Files:**
- Modify: `CalendarPro/Settings/MenuBarPreferences.swift`
- Test: `CalendarProTests/Settings/MenuBarPreferencesTests.swift`

**Steps:**
1. Add weather-specific `DisplayTokenStyle` cases for temperature, condition plus temperature, temperature plus PM2.5, temperature plus AQI, and feels-like temperature.
2. Keep `.short` as the legacy/default style for existing saved weather tokens.
3. Add Codable round-trip coverage for at least one new weather style.

### Task 2: Format Menu Bar Weather Text

**Files:**
- Modify: `CalendarPro/Features/MenuBar/MenuBarViewModel.swift`
- Test: `CalendarProTests/MenuBar/MenuBarViewModelTests.swift`

**Steps:**
1. Read the enabled weather token style from `MenuBarPreferences.tokens`.
2. Convert `WeatherDescriptor` to text based on style.
3. Fall back to `temperatureText` when optional metrics such as PM2.5, AQI, or apparent temperature are missing.
4. Keep empty descriptors from rendering weather text.

### Task 3: Update Settings UI

**Files:**
- Modify: `CalendarPro/Views/Settings/MenuBarSettingsView.swift`
- Modify: `CalendarPro/Resources/Localizable.xcstrings`

**Steps:**
1. Return weather-specific style options for the Weather token.
2. Show localized labels/previews for the new weather formats.
3. Disable the Weather token toggle and style picker when `menuBarPreferences.showWeather` is false.
4. Show a short hint explaining that weather must be enabled in General settings first.

### Task 4: Verify

**Commands:**
- `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/MenuBarViewModelTests -only-testing:CalendarProTests/MenuBarPreferencesTests`
- `xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'`

**Expected:**
- Targeted tests and build succeed.
