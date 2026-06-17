# QWeather Guidance Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Show contextual guidance when users select QWeather so they can create an account, API Host, and API Key.

**Architecture:** Keep the change local to the weather settings UI. Add non-blocking helper copy and a developer portal link under the QWeather Host and Key fields, reusing SwiftUI and existing localization patterns.

**Tech Stack:** Swift 6, SwiftUI, macOS Settings UI, String Catalog localization.

---

### Task 1: Add QWeather Help UI

**Files:**
- Modify: `CalendarPro/Views/Settings/GeneralSettingsView.swift`

**Steps:**
1. Add a compact helper block inside the existing `weatherProvider == .qWeather` section.
2. Include one sentence explaining that QWeather requires an account, project API Host, and API Key.
3. Include a `Link` to `https://dev.qweather.com/`.
4. Include short Host and Key field hints.

### Task 2: Add Localized Copy

**Files:**
- Modify: `CalendarPro/Resources/Localizable.xcstrings`

**Steps:**
1. Add English and Simplified Chinese strings for the guidance sentence.
2. Add English and Simplified Chinese strings for the developer portal link.
3. Add English and Simplified Chinese strings for Host and Key hints.

### Task 3: Verify Build

**Command:**
- `xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'`

**Expected:**
- Build succeeds with no localization or SwiftUI compile errors.
