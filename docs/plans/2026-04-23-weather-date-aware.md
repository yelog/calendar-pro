# Weather Date-Aware Display Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Show the detected location in the weather card and make the weather card switch between current conditions and selected-day forecast.

**Architecture:** Expand weather fetching from a current-only payload to a cached weather snapshot that includes both current and daily forecast data plus location metadata. Map that snapshot into a small `WeatherDescriptor` tailored for the currently selected calendar date so `RootPopoverView` and `WeatherStripView` stay simple.

**Tech Stack:** Swift 6, SwiftUI, URLSession, Open-Meteo API, XCTest

---

### Task 1: Add date-aware weather snapshot tests

**Files:**
- Modify: `CalendarProTests/Weather/WeatherServiceTests.swift`
- Reference: `CalendarPro/Features/Weather/WeatherService.swift`

**Step 1: Write the failing tests**

Add tests for:

```swift
func testWeatherServiceBuildsTodayDescriptorFromCurrentConditions() async
func testWeatherServiceBuildsFutureDescriptorFromDailyForecast() async
func testWeatherServicePreservesLocationNameFromGeolocationProvider() async
func testWeatherServiceReusesCachedSnapshotAcrossDateSelections() async
```

Use mocked responses that include:

```json
{
  "current": {
    "temperature_2m": 26.0,
    "apparent_temperature": 31.0,
    "weather_code": 61,
    "is_day": 1
  },
  "daily": {
    "time": ["2026-04-23", "2026-04-24"],
    "weather_code": [61, 3],
    "temperature_2m_max": [28.0, 27.0],
    "temperature_2m_min": [24.0, 20.0]
  }
}
```

**Step 2: Run tests to verify they fail**

Run:

```bash
xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/WeatherServiceTests
```

Expected: FAIL because the service does not yet expose a date-aware descriptor or decode daily forecast fields.

**Step 3: Commit**

```bash
git add CalendarProTests/Weather/WeatherServiceTests.swift
git commit -m "test(weather): cover date-aware forecast descriptors"
```

---

### Task 2: Expand `WeatherService` into a snapshot + descriptor mapper

**Files:**
- Modify: `CalendarPro/Features/Weather/WeatherService.swift`
- Test: `CalendarProTests/Weather/WeatherServiceTests.swift`

**Step 1: Add snapshot models**

Inside `WeatherService.swift`, add:

```swift
struct WeatherSnapshot: Equatable, Sendable {
    let locationName: String
    let current: CurrentWeather
    let dailyForecasts: [DailyWeatherForecast]
    let fetchedAt: Date
}

struct CurrentWeather: Equatable, Sendable {
    let temperature: Double
    let apparentTemperature: Double
    let weatherCode: Int
    let isDaytime: Bool
}

struct DailyWeatherForecast: Equatable, Sendable {
    let date: Date
    let weatherCode: Int
    let maxTemperature: Double
    let minTemperature: Double
}
```

**Step 2: Expand `WeatherDescriptor` for view rendering**

Replace the current shape with:

```swift
struct WeatherDescriptor: Equatable, Sendable {
    let locationName: String
    let primaryTemperatureText: String
    let secondaryText: String
    let description: String
    let iconSystemName: String
    let isCurrentConditions: Bool

    var hasContent: Bool { !locationName.isEmpty }

    static let empty = WeatherDescriptor(
        locationName: "",
        primaryTemperatureText: "",
        secondaryText: "",
        description: "",
        iconSystemName: "cloud.fill",
        isCurrentConditions: true
    )
}
```

Keep helper formatters for today and forecast states.

**Step 3: Decode location names from geolocation providers**

Update provider response structs so they include readable location metadata:

```swift
private struct IPWhoLocationResponse: Decodable, Sendable {
    let success: Bool?
    let city: String?
    let region: String?
    let country: String?
    let latitude: Double?
    let longitude: Double?
}
```

Do the same for `ipinfo.io` and `ipapi.co`.

Add a helper that builds a display string, preferring:

1. city
2. `city, region`
3. `region, country`
4. country

**Step 4: Decode daily forecast payloads**

Expand `OpenMeteoResponse` with:

```swift
struct DailyWeather: Decodable, Sendable {
    let time: [String]
    let weatherCode: [Int]
    let temperature2mMax: [Double]
    let temperature2mMin: [Double]
}
```

and wire `CodingKeys` for:

```swift
case weatherCode = "weather_code"
case temperature2mMax = "temperature_2m_max"
case temperature2mMin = "temperature_2m_min"
```

**Step 5: Replace current-only fetch with snapshot fetch**

Add:

```swift
func describe(date: Date, calendar: Calendar = .autoupdatingCurrent) async -> WeatherDescriptor
```

Implementation:

1. fetch or reuse a cached `WeatherSnapshot`
2. if `date` is today, map from `snapshot.current`
3. otherwise locate matching `DailyWeatherForecast` and map into a forecast descriptor
4. if no match exists, return `.empty`

Keep the 30-minute cache, but cache the full snapshot instead of current weather only.

**Step 6: Update the Open-Meteo request**

Include:

```swift
URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min")
URLQueryItem(name: "forecast_days", value: "16")
```

**Step 7: Run tests to verify they pass**

Run:

```bash
xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/WeatherServiceTests
```

Expected: PASS.

**Step 8: Commit**

```bash
git add CalendarPro/Features/Weather/WeatherService.swift CalendarProTests/Weather/WeatherServiceTests.swift
git commit -m "feat(weather): add date-aware weather snapshot mapping"
```

---

### Task 3: Make `RootPopoverView` pass the selected date into weather mapping

**Files:**
- Modify: `CalendarPro/Views/RootPopoverView.swift`
- Reference: `CalendarPro/Views/Popover/CalendarPopoverView.swift`

**Step 1: Update weather refresh path**

Replace the current call:

```swift
let descriptor = await weatherService.fetchCurrentWeather()
```

with a date-aware call:

```swift
let descriptor = await weatherService.describe(
    date: date,
    calendar: displayCalendar
)
```

**Step 2: Protect against stale async results**

Capture the requested date and only assign the returned descriptor if the selected date has not changed while the async task was running.

Example shape:

```swift
let requestedDate = date
Task {
    let descriptor = await weatherService.describe(date: requestedDate, calendar: displayCalendar)
    await MainActor.run {
        guard currentWeatherRequestDate == requestedDate else { return }
        weatherDescriptor = descriptor.hasContent ? descriptor : nil
    }
}
```

Do not introduce extra state if an existing `selectedDate` equality check is sufficient.

**Step 3: Run build**

Run:

```bash
xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'
```

Expected: BUILD SUCCEEDED.

**Step 4: Commit**

```bash
git add CalendarPro/Views/RootPopoverView.swift
git commit -m "fix(weather): sync popover weather with selected date"
```

---

### Task 4: Redesign `WeatherStripView` to show location and forecast state

**Files:**
- Modify: `CalendarPro/Views/Popover/WeatherStripView.swift`
- Reference: `CalendarPro/Features/Weather/WeatherService.swift`

**Step 1: Update the card layout**

Render two textual rows:

```swift
VStack(alignment: .leading, spacing: 3) {
    HStack(spacing: 6) {
        Text(weather.primaryTemperatureText)
        Text(weather.description)
    }

    Text(weather.secondaryText)
}
```

**Step 2: Include location in the secondary line**

Display formats:

```swift
// today
"Hong Kong · Feels like 31°"

// selected future day
"Hong Kong · Forecast for Apr 24"
```

Use localized strings for the forecast label.

**Step 3: Keep the existing card shell**

Do not change:

- rounded rectangle container
- left icon circle treatment
- overall spacing model

Only adjust typography to fit the extra location context.

**Step 4: Run build**

Run:

```bash
xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'
```

Expected: BUILD SUCCEEDED.

**Step 5: Commit**

```bash
git add CalendarPro/Views/Popover/WeatherStripView.swift
git commit -m "feat(weather): show location and forecast context in popover"
```

---

### Task 5: Add localized forecast strings and update preview/test call sites

**Files:**
- Modify: `CalendarPro/Resources/Localizable.xcstrings`
- Modify: `CalendarPro/Views/Settings/MenuBarSettingsView.swift`
- Modify: `CalendarProTests/MenuBar/ClockRenderServiceTests.swift`

**Step 1: Add localization keys**

Add:

- `Forecast for %@`
- `Current conditions`

Translations should be provided for English and Simplified Chinese.

**Step 2: Keep menu bar preview simple**

Do not make the menu bar token preview depend on location or selected date. Keep the preview as a static example such as `23°`.

**Step 3: Update tests or call sites impacted by `WeatherDescriptor` changes**

Adjust any compile errors caused by the new descriptor shape.

**Step 4: Run focused tests**

Run:

```bash
xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/WeatherServiceTests -only-testing:CalendarProTests/ClockRenderServiceTests
```

Expected: PASS.

**Step 5: Commit**

```bash
git add CalendarPro/Resources/Localizable.xcstrings CalendarPro/Views/Settings/MenuBarSettingsView.swift CalendarProTests/MenuBar/ClockRenderServiceTests.swift
git commit -m "chore(weather): localize forecast labels"
```

---

### Task 6: Final verification

**Files:**
- Modify: `docs/plans/2026-04-23-weather-date-aware-design.md` if implementation details changed

**Step 1: Run the full test suite**

Run:

```bash
xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'
```

Expected: All tests pass.

**Step 2: Run a final build**

Run:

```bash
xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'
```

Expected: BUILD SUCCEEDED.

**Step 3: Manual verification**

Verify in the running app:

1. Turn on weather in settings.
2. The weather card shows a readable location name.
3. Today shows current temperature + feels-like temperature.
4. Clicking another date updates the card to that day's forecast.
5. Clicking back to today restores current conditions.

**Step 4: Commit**

```bash
git add docs/plans/2026-04-23-weather-date-aware-design.md
git commit -m "test(weather): verify date-aware weather flow"
```
