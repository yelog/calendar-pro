# Open-Meteo Thunderstorm Evidence Filtering Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Use Open-Meteo hourly and precipitation data to prevent dry thunderstorm codes from dominating today and future 10-day forecast rows.

**Architecture:** Extend Open-Meteo decoding with hourly forecasts, store them on `WeatherSnapshot`, and synthesize today's forecast row from remaining hourly data. For future rows, keep normal daily codes unchanged but filter unsupported thunderstorm daily codes through same precipitation-evidence rules.

**Tech Stack:** Swift 6, Foundation, XCTest, URLSession mock protocol.

---

### Task 1: Add Regression Test

**Files:**
- Modify: `CalendarProTests/Weather/WeatherServiceTests.swift`

**Step 1: Write the failing test**

Add a test near `testWeatherServiceForecastOverviewReturnsTenDayForecastStartingToday`:

```swift
func testWeatherServiceForecastOverviewSynthesizesTodayFromRemainingOpenMeteoHourlyData() async {
    WeatherMockURLProtocol.requestHandler = { request in
        switch request.url?.host {
        case "ipwho.is":
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data("{\"success\":true,\"city\":\"Shenzhen\",\"latitude\":22.538,\"longitude\":113.9389}".utf8)
            )
        case "api.open-meteo.com":
            return makeDailyThunderstormHourlyDryResponse(for: request.url!)
        case "air-quality-api.open-meteo.com":
            return makeAirQualityResponse(for: request.url!)
        default:
            throw URLError(.badURL)
        }
    }

    let calendar = makeCalendar()
    let service = WeatherService(session: makeSession(), now: { makeDate(year: 2026, month: 6, day: 22, hour: 10) })

    let overview = await service.forecastOverview(days: 10, calendar: calendar)

    XCTAssertEqual(overview.dailyForecasts.first?.weatherCode, 2)
    XCTAssertEqual(overview.dailyForecasts.first?.temperatureText, "33° / 27°")
    XCTAssertEqual(overview.dailyForecasts.first?.precipitation, 0)
    XCTAssertEqual(overview.dailyForecasts.first?.precipitationProbability, 0)
}
```

Add helper response after `makeTenDayForecastResponse`:

```swift
private func makeDailyThunderstormHourlyDryResponse(for url: URL) -> (HTTPURLResponse, Data) {
    let data = Data(
        """
        {
          "current": {
            "temperature_2m": 31.0,
            "apparent_temperature": 36.0,
            "relative_humidity_2m": 72,
            "precipitation": 0.0,
            "weather_code": 2,
            "wind_speed_10m": 10.0,
            "wind_direction_10m": 120.0,
            "wind_gusts_10m": 18.0,
            "cloud_cover": 55,
            "is_day": 1
          },
          "hourly": {
            "time": ["2026-06-22T09:00", "2026-06-22T10:00", "2026-06-22T11:00", "2026-06-22T12:00", "2026-06-22T13:00"],
            "weather_code": [2, 2, 2, 3, 2],
            "precipitation": [0.0, 0.0, 0.0, 0.0, 0.0],
            "precipitation_probability": [0, 0, 0, 0, 0],
            "rain": [0.0, 0.0, 0.0, 0.0, 0.0],
            "showers": [0.0, 0.0, 0.0, 0.0, 0.0]
          },
          "daily": {
            "time": ["2026-06-22", "2026-06-23"],
            "weather_code": [95, 3],
            "temperature_2m_max": [33.0, 32.0],
            "temperature_2m_min": [27.0, 26.0],
            "precipitation_sum": [0.0, 1.0],
            "precipitation_probability_max": [0, 40],
            "wind_speed_10m_max": [16.0, 14.0],
            "wind_direction_10m_dominant": [135.0, 120.0],
            "wind_gusts_10m_max": [24.0, 20.0],
            "uv_index_max": [8.0, 7.0]
          }
        }
        """.utf8
    )

    return (
        HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!,
        data
    )
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/WeatherServiceTests/testWeatherServiceForecastOverviewSynthesizesTodayFromRemainingOpenMeteoHourlyData`

Expected: FAIL because `OpenMeteoResponse` ignores `hourly` and today's row still uses daily `95`.

### Task 2: Request and Decode Hourly Weather

**Files:**
- Modify: `CalendarPro/Features/Weather/WeatherService.swift`
- Modify: `CalendarProTests/Weather/WeatherServiceTests.swift`

**Step 1: Update URL assertion**

In `testWeatherServiceFetchCurrentWeatherUsesIPWhoLocation`, assert:

```swift
XCTAssertEqual(queryItems.first(where: { $0.name == "hourly" })?.value, "weather_code,precipitation,precipitation_probability,rain,showers")
```

**Step 2: Add hourly query item**

In `openMeteoURL`, add:

```swift
URLQueryItem(name: "hourly", value: "weather_code,precipitation,precipitation_probability,rain,showers"),
```

**Step 3: Add snapshot model**

Add `hourlyForecasts: [HourlyWeatherForecast]` to `WeatherSnapshot` and update both Open-Meteo and QWeather snapshot construction. QWeather should pass `[]`.

Add:

```swift
private struct HourlyWeatherForecast: Sendable {
    let date: Date
    let weatherCode: Int
    let precipitation: Double?
    let precipitationProbability: Int?
    let rain: Double?
    let showers: Double?
}
```

**Step 4: Decode Open-Meteo hourly data**

Add `let hourly: HourlyWeather?` to `OpenMeteoResponse`.

Add nested `HourlyWeather` with arrays for `time`, `weather_code`, `precipitation`, `precipitation_probability`, `rain`, and `showers`, mirroring the existing daily parser and using date format `yyyy-MM-dd'T'HH:mm`.

**Step 5: Store hourly data**

In `fetchOpenMeteoSnapshot`, set:

```swift
hourlyForecasts: result.hourly?.forecasts ?? [],
```

**Step 6: Run tests**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/WeatherServiceTests/testWeatherServiceFetchCurrentWeatherUsesIPWhoLocation`

Expected: PASS.

### Task 3: Synthesize Today's Forecast Row

**Files:**
- Modify: `CalendarPro/Features/Weather/WeatherService.swift`

**Step 1: Route today's row to a new builder**

In `forecastOverview`, replace the map body with logic that calls a new method when `forecast.date` is today.

**Step 2: Add today builder**

Add a helper that filters `snapshot.hourlyForecasts` to `forecast.date` and `hour.date >= now()`.

If no remaining hourly data exists, return `makeForecastDescriptor` unchanged.

If remaining precipitation support is absent, use `snapshot.current.weatherCode`.

Otherwise use the highest-severity hourly weather code.

**Step 3: Add weather severity helper**

Add a small switch-based rank helper that ranks thunderstorm/heavy rain above rain, showers, drizzle, overcast, cloudy, clear.

**Step 4: Run regression test**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/WeatherServiceTests/testWeatherServiceForecastOverviewSynthesizesTodayFromRemainingOpenMeteoHourlyData`

Expected: PASS.

### Task 4: Verify Existing Weather Tests

### Task 4: Filter Dry Thunderstorm Codes

**Files:**
- Modify: `CalendarPro/Features/Weather/WeatherService.swift`
- Modify: `CalendarProTests/Weather/WeatherServiceTests.swift`

**Step 1: Add future-row regression test**

Add a test where the second daily forecast has `weather_code` `96`, `precipitation_sum` `0.2`, `precipitation_probability_max` `14`, and hourly values for that day are dry cloudy codes. Assert that the second row is not `96` and keeps the daily temperature and precipitation summary.

**Step 2: Add weather-code helpers**

Add small helpers for:

```swift
private static func isThunderstormCode(_ code: Int) -> Bool
private static func hasMeaningfulPrecipitation(amounts: [Double?], probabilities: [Int?]) -> Bool
private static func fallbackNonThunderstormCode(from hourlyForecasts: [HourlyWeatherForecast], defaultCode: Int) -> Int
```

Use `> 0.5mm` or `>= 30%` as the evidence threshold.

**Step 3: Apply filtering in descriptor builders**

For today's row, ignore unsupported thunderstorm codes from current/hourly/daily candidates and prefer a non-thunderstorm hourly/current fallback.

For future rows, only filter daily thunderstorm codes; leave non-thunderstorm daily codes unchanged.

**Step 4: Run focused tests**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/WeatherServiceTests/testWeatherServiceForecastOverviewSynthesizesTodayFromRemainingOpenMeteoHourlyData`

Run the new future-row test too.

Expected: PASS.

### Task 5: Verify Existing Weather Tests

**Files:**
- No edits expected.

**Step 1: Run WeatherServiceTests**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/WeatherServiceTests`

Expected: PASS.

**Step 2: Run full build**

Run: `xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'`

Expected: BUILD SUCCEEDED.
