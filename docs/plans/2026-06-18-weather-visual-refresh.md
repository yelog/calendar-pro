# Weather Visual Refresh Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add weather-aware color, gradient, and card styling so the compact weather strip and detail window feel less monochrome while preserving CalendarPro's macOS utility tone.

**Architecture:** Keep all data and window lifecycle code unchanged. Add a small SwiftUI-only `WeatherVisualStyle` helper that derives colors from the existing `WeatherDescriptor.iconSystemName`, then apply it to the weather strip, current conditions card, metric icons, and forecast rows.

**Tech Stack:** Swift 6, SwiftUI, existing `WeatherDescriptor` and `PopoverSurfaceMetrics` styling.

---

## Task 1: Weather Visual Style Helper

**Files:**
- Modify: `CalendarPro/Views/Popover/WeatherStripView.swift`
- Modify: `CalendarPro/Views/Popover/WeatherDetailWindowView.swift`

**Steps:**
1. Add a private `WeatherVisualStyle` value type in `WeatherStripView.swift` so both weather views in the same target can use it.
2. Map existing SF Symbol names to tone families: sunny, night, rainy, stormy, snowy, cloudy, and neutral.
3. Expose `primary`, `secondary`, `background`, `border`, `iconBackground`, and `backgroundGradient(for:)` helpers.
4. Keep contrast high in dark mode and use low-saturation gradients in light mode.

## Task 2: Compact Weather Strip Refresh

**Files:**
- Modify: `CalendarPro/Views/Popover/WeatherStripView.swift`

**Steps:**
1. Replace fixed orange/gray colors with `WeatherVisualStyle`.
2. Increase icon presence with a weather-tinted circular gradient.
3. Use a subtle rounded gradient fill and tinted border for the strip.
4. Tint compact metric icons with the weather accent while keeping labels readable.

## Task 3: Detail Window Refresh

**Files:**
- Modify: `CalendarPro/Views/Popover/WeatherDetailWindowView.swift`

**Steps:**
1. Use the current weather visual style for the floating panel tint.
2. Turn the current conditions card into a weather-aware hero card with a soft gradient.
3. Apply per-row weather accent colors to forecast icons and row backgrounds.
4. Keep existing layout, sizing, and data flow unchanged.

## Task 4: Validation

**Commands:**
1. Run `xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'`.
2. If build time is excessive, at minimum verify Swift compilation errors from the build output and report any skipped validation.

**Manual check:**
- Weather strip should no longer appear black/white-only.
- Sunny, rainy, cloudy, night, and snow/storm icons should produce visibly distinct but restrained tones.
- Text remains readable in light and dark modes.
