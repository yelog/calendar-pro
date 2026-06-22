# wttr.in Weather Provider Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add wttr.in as a selectable, no-configuration weather provider.

**Architecture:** Extend the existing provider enum and runtime provider configuration with `.wttrIn`, then add a wttr.in fetch/decode path in `WeatherService` that maps wttr.in JSON into the existing `WeatherSnapshot` model. Keep UI provider-neutral by continuing to feed `WeatherDescriptor` and `WeatherForecastOverview`.

**Tech Stack:** Swift 6, Foundation, SwiftUI settings bindings, XCTest, URLSession mock protocol, wttr.in `format=j1` JSON.

---

### Task 1: Add Provider Persistence and Display Tests

**Files:**
- Modify: `CalendarProTests/Settings/MenuBarPreferencesTests.swift`
- Modify: `CalendarProTests/Settings/SettingsStoreTests.swift`

**Step 1: Write the failing display-name test**

Add an assertion to the existing provider display-name test:

```swift
XCTAssertEqual(WeatherProvider.wttrIn.displayName, "wttr.in")
```

**Step 2: Write the failing Codable round-trip test**

Update the weather provider Codable round-trip test so the preferences use `.wttrIn` and assert the decoded value remains `.wttrIn`.

**Step 3: Write the failing SettingsStore mapping test**

Extend `testSetWeatherProviderAndQWeatherConfiguration` or add a small new test:

```swift
store.setWeatherProvider(.wttrIn)
XCTAssertEqual(store.menuBarPreferences.weatherProvider, .wttrIn)
XCTAssertEqual(store.weatherProviderConfiguration(), .wttrIn)
```

**Step 4: Run tests to verify failure**

Run:

```bash
xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/MenuBarPreferencesTests -only-testing:CalendarProTests/SettingsStoreTests
```

Expected: compile failure because `.wttrIn` does not exist.

**Step 5: Implement provider enum and settings mapping**

Modify `CalendarPro/Settings/MenuBarPreferences.swift`:

```swift
case wttrIn = "wttrIn"
```

Add display-name case:

```swift
case .wttrIn:
    return L("Weather Provider wttr.in")
```

Modify `CalendarPro/Features/Weather/WeatherService.swift`:

```swift
case wttrIn
```

Update `weatherProvider` and `isUsable` accordingly.

Modify `CalendarPro/Settings/SettingsStore.swift` so `.wttrIn` maps to `.wttrIn`.

**Step 6: Add localization**

Modify `CalendarPro/Resources/Localizable.xcstrings` with key `Weather Provider wttr.in` for English and Simplified Chinese. Update `Weather Provider Description` to mention wttr.in.

**Step 7: Run tests to verify pass**

Run the command from Step 4.

Expected: PASS.

---

### Task 2: Add wttr.in Request and Decode Tests

**Files:**
- Modify: `CalendarProTests/Weather/WeatherServiceTests.swift`

**Step 1: Write failing wttr.in service test**

Add a test near the existing provider tests:

```swift
func testWttrProviderFetchesCurrentAndDailyWeatherWithoutConfiguration() async {
    WeatherMockURLProtocol.requestHandler = { request in
        switch request.url?.host {
        case "ipwho.is":
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data("{\"success\":true,\"city\":\"Shenzhen\",\"latitude\":22.538,\"longitude\":113.9389}".utf8)
            )
        case "wttr.in":
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
            XCTAssertEqual(request.url?.path, "/22.538,113.9389")
            XCTAssertEqual(components?.queryItems?.first(where: { $0.name == "format" })?.value, "j1")
            XCTAssertNotNil(components?.queryItems?.first(where: { $0.name == "m" }) )
            XCTAssertEqual(components?.queryItems?.first(where: { $0.name == "lang" })?.value, AppLocalization.languageCode == "zh" ? "zh" : "en")
            return makeWttrResponse(for: request.url!)
        default:
            throw URLError(.badURL)
        }
    }

    let service = WeatherService(
        session: makeSession(),
        now: { makeDate(year: 2026, month: 6, day: 22, hour: 10) },
        providerConfiguration: .wttrIn
    )

    let overview = await service.forecastOverview(days: 10, calendar: makeCalendar())

    XCTAssertEqual(overview.current.locationName, "Shenzhen")
    XCTAssertEqual(overview.current.temperatureText, "32°")
    XCTAssertEqual(overview.current.weatherCode, 0)
    XCTAssertEqual(overview.current.humidity, 71)
    XCTAssertEqual(overview.current.precipitation, 0)
    XCTAssertEqual(overview.current.windSpeed, 18)
    XCTAssertEqual(overview.dailyForecasts.count, 2)
    XCTAssertEqual(overview.dailyForecasts.first?.temperatureText, "31° / 27°")
}
```

**Step 2: Add fixture helper**

Add `makeWttrResponse(for:)` after existing weather response helpers. Use a compact fixture with `current_condition`, `nearest_area`, and two `weather` days. Include hourly rows at `900`, `1200`, and `1500`.

**Step 3: Run test to verify failure**

Run:

```bash
xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/WeatherServiceTests/testWttrProviderFetchesCurrentAndDailyWeatherWithoutConfiguration
```

Expected: compile failure or `.empty` because wttr.in fetch is not implemented.

---

### Task 3: Implement wttr.in Fetch and Decode

**Files:**
- Modify: `CalendarPro/Features/Weather/WeatherService.swift`

**Step 1: Add wttr.in branch**

Update `fetchSnapshotFromNetwork()`:

```swift
case .wttrIn:
    return await fetchWttrSnapshot(for: location)
```

**Step 2: Add URL builder**

Add:

```swift
private func wttrURL(latitude: Double, longitude: Double) -> URL? { ... }
```

Build `https://wttr.in/<lat>,<lon>` with query items `format=j1`, `m`, and `lang`.

**Step 3: Add response models**

Add private Decodable models:

- `WttrResponse`
- `WttrCurrentCondition`
- `WttrWeatherDay`
- `WttrHourlyWeather`
- `WttrTextValue`

Use string parsing helpers because wttr.in returns most numeric fields as strings.

**Step 4: Add snapshot conversion**

Implement:

```swift
private func fetchWttrSnapshot(for location: LocationMetadata) async -> WeatherSnapshot?
```

Decode `WttrResponse`, convert it to `WeatherSnapshot`, cache it, and return it.

**Step 5: Convert daily and hourly data**

For each `weather` day:

- Parse `date` with `yyyy-MM-dd`.
- Map hourly rows into `HourlyWeatherForecast`.
- Choose the daily weather code using highest severity among hourly mapped codes.
- Sum hourly precipitation for daily precipitation.
- Use max hourly `chanceofrain` for precipitation probability.

**Step 6: Run wttr test**

Run the test from Task 2 Step 3.

Expected: PASS.

---

### Task 4: Add wttr.in Weather Code Mapper Tests

**Files:**
- Modify: `CalendarProTests/Weather/WeatherServiceTests.swift`
- Modify: `CalendarPro/Features/Weather/WeatherService.swift`

**Step 1: Write mapper assertions through fixture behavior**

Add fixture variants or focused service tests that verify:

- `113` maps to `0`
- `116` maps to `2`
- `122` maps to `3`
- `176` maps to a rain code, preferably `61`
- `386` maps to `95`

If direct mapper visibility would require widening access, keep assertions through service fixtures instead of making production helpers public.

**Step 2: Implement minimal mapper table**

Add a private mapper, for example:

```swift
private enum WttrWeatherCodeMapper {
    static func weatherCode(for code: String) -> Int { ... }
}
```

Use grouped switch cases matching the design doc.

**Step 3: Run WeatherServiceTests**

Run:

```bash
xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/WeatherServiceTests
```

Expected: PASS.

---

### Task 5: Final Verification

**Files:**
- No additional files expected.

**Step 1: Run settings tests**

Run:

```bash
xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/MenuBarPreferencesTests -only-testing:CalendarProTests/SettingsStoreTests
```

Expected: PASS.

**Step 2: Run weather tests**

Run:

```bash
xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/WeatherServiceTests
```

Expected: PASS.

**Step 3: Build app**

Run:

```bash
xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'
```

Expected: `** BUILD SUCCEEDED **`.

**Step 4: Inspect status and diff**

Run:

```bash
git status --short
git diff --stat
```

Expected: only wttr.in provider files and docs changed.
