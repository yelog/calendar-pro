# 7Timer Weather Provider Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add 7Timer `civillight` as a selectable weather provider using `https://www.7timer.info/bin/api.pl?lon=<lon>&lat=<lat>&product=civillight&output=json`.

**Architecture:** Treat 7Timer as a no-configuration provider, like wttr.in. The provider adapter lives inside `WeatherService`, converts 7Timer daily-only data into the existing `WeatherSnapshot`, and leaves unavailable fields nil instead of inventing metrics. Because 7Timer `civillight` does not provide current conditions, synthesize current weather from the first forecast day.

**Tech Stack:** Swift 6, Foundation `URLSession`, `Decodable`, existing `XCTest` mock URL protocol tests, SwiftUI settings picker through existing `WeatherProvider.allCases`.

---

### Task 1: Add Provider Preference And Configuration

**Files:**
- Modify: `CalendarPro/Settings/MenuBarPreferences.swift`
- Modify: `CalendarPro/Settings/SettingsStore.swift`
- Modify: `CalendarPro/Features/Weather/WeatherService.swift`
- Modify: `CalendarPro/Resources/Localizable.xcstrings`
- Test: `CalendarProTests/Settings/MenuBarPreferencesTests.swift`
- Test: `CalendarProTests/Settings/SettingsStoreTests.swift`

**Steps:**
1. Add `case sevenTimer` to `WeatherProvider` and display it as `7Timer`.
2. Add `case sevenTimer` to `WeatherProviderConfiguration`, with `isUsable == true`.
3. Map `SettingsStore.weatherProviderConfiguration()` from `.sevenTimer` to `.sevenTimer`.
4. Add localized key `Weather Provider 7Timer` and update `Weather Provider Description` to include 7Timer.
5. Extend settings tests to assert the display name and configuration mapping.

### Task 2: Add 7Timer Network Adapter

**Files:**
- Modify: `CalendarPro/Features/Weather/WeatherService.swift`
- Test: `CalendarProTests/Weather/WeatherServiceTests.swift`

**Steps:**
1. Add `sevenTimerURL(latitude:longitude:)` using host `www.7timer.info`, path `/bin/api.pl`, and query items `lon`, `lat`, `product=civillight`, `output=json`.
2. Add `fetchSevenTimerSnapshot(for:)`, decode `SevenTimerResponse`, require at least one forecast day, synthesize `CurrentWeatherSnapshot` from the first day, and store the snapshot in `cachedSnapshot`.
3. Add the `.sevenTimer` case to `fetchSnapshotFromNetwork()`.
4. Do not call Open-Meteo air quality for 7Timer. 7Timer does not provide AQI/PM2.5.

### Task 3: Map 7Timer Data Into Existing Weather Model

**Files:**
- Modify: `CalendarPro/Features/Weather/WeatherService.swift`
- Test: `CalendarProTests/Weather/WeatherServiceTests.swift`

**Mapping:**
- `clear` -> WMO `0`
- `pcloudy` -> WMO `2`
- `mcloudy`, `cloudy`, `humid`, `fog` -> WMO `3` or `45` for fog
- `lightrain`, `oshower`, `ishower`, `lightsnow`, `rainsnow` -> closest WMO precipitation code
- `rain`, `ts`, `tsrain`, `snow` -> closest existing WMO code
- Unknown weather strings -> WMO `3`

**Current synthesis:**
- `temperature` = first day max temperature
- `apparentTemperature` = same as temperature
- `weatherCode` = mapped first day weather
- `isDaytime` = true
- unavailable metrics = nil

### Task 4: Verify

**Commands:**
- `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/WeatherServiceTests`
- `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/MenuBarPreferencesTests -only-testing:CalendarProTests/SettingsStoreTests`
- `xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'`

**Expected:**
- Weather tests pass.
- Settings tests pass.
- macOS build succeeds.
