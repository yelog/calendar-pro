# Weather Detail Window Implementation Plan

**Goal:** Replace in-place weather expansion with a denser compact strip and a left-side 10-day weather detail window.

**Architecture:** Extend `WeatherService` with a provider-neutral forecast overview API, keep compact weather rendering inside `WeatherStripView`, and add a narrow `NSPanel` presenter for the side detail window. `RootPopoverView` owns the loading/toggle state and passes snapshots into the panel presenter.

**Tech Stack:** Swift 6, SwiftUI, AppKit `NSPanel`, XCTest, Open-Meteo/QWeather descriptor model.

---

## Product Plan

1. Add a weather overview model that returns current conditions plus up to 10 daily forecasts.
2. Redesign `WeatherStripView` as a dense summary card with a metric grid and a side-panel affordance.
3. Add `WeatherDetailWindowView` for current conditions and the 10-day list.
4. Add `WeatherDetailWindowController` to position a floating panel to the left of the popover.
5. Wire popover callbacks through `CalendarPopoverView`, `RootPopoverView`, `PopoverController`, and UI-test root setup.
6. Add localizations for new labels.
7. Regenerate the Xcode project if new Swift files are added.
8. Run focused tests and a project build.

## Test Plan

1. Write a failing `WeatherServiceTests` case for `forecastOverview(days:calendar:)`.
2. Write a failing sizing test for `WeatherDetailWindowSizing`.
3. Implement the service and sizing helpers.
4. Implement UI and presenter wiring.
5. Run:
   - `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -skip-testing:CalendarProUITests -only-testing:CalendarProTests/WeatherServiceTests`
   - `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -skip-testing:CalendarProUITests -only-testing:CalendarProTests/WeatherDetailWindowSizingTests`
   - `xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'`
