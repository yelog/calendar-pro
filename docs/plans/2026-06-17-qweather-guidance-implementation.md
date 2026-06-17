# QWeather Guidance Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Show contextual guidance when users select QWeather and store its API Key without triggering macOS Keychain prompts.

**Architecture:** Add non-blocking helper copy and a clickable QWeather Console link under the Host and Key fields. Persist the QWeather API Key as part of `MenuBarPreferences` in `UserDefaults`, remove the Keychain-backed credential store, and intentionally do not migrate old Keychain entries to avoid any Keychain access.

**Tech Stack:** Swift 6, SwiftUI, macOS Settings UI, String Catalog localization.

---

### Task 1: Add QWeather Help UI

**Files:**
- Modify: `CalendarPro/Views/Settings/GeneralSettingsView.swift`

**Steps:**
1. Add a compact helper block inside the existing `weatherProvider == .qWeather` section.
2. Include one sentence explaining that QWeather requires an account, project API Host, and API Key.
3. Include a `Link` to `https://console.qweather.com/`.
4. Include short Host and Key field hints.

### Task 2: Add Localized Copy

**Files:**
- Modify: `CalendarPro/Resources/Localizable.xcstrings`

**Steps:**
1. Add English and Simplified Chinese strings for the guidance sentence.
2. Add English and Simplified Chinese strings for the developer portal link.
3. Add English and Simplified Chinese strings for Host and Key hints.

### Task 3: Verify Build

**Files:**
- Modify: `CalendarPro/Settings/MenuBarPreferences.swift`
- Modify: `CalendarPro/Settings/SettingsStore.swift`
- Modify: `CalendarProTests/Settings/MenuBarPreferencesTests.swift`
- Modify: `CalendarProTests/Settings/SettingsStoreTests.swift`

**Steps:**
1. Add `qWeatherAPIKey` to `MenuBarPreferences` with a default empty string.
2. Decode missing `qWeatherAPIKey` as an empty string for existing preferences.
3. Encode `qWeatherAPIKey` with other menu bar preferences.
4. Remove `WeatherCredentialStoring`, `KeychainWeatherCredentialStore`, and `Security` imports.
5. Update `SettingsStore.setQWeatherAPIKey` to store the trimmed key in `menuBarPreferences` and persist preferences.
6. Update tests to verify the key round-trips through preferences, not a credential store.

### Task 4: Verify Build

**Command:**
- `xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'`

**Expected:**
- Build succeeds with no localization or SwiftUI compile errors.
