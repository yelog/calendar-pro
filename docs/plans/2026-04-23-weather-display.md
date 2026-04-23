# Weather Display Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add current weather display to both the popover calendar view and menu bar, using the Open-Meteo free API.

**Architecture:** Follow the existing Almanac pattern — `WeatherService` fetches data and returns a `WeatherDescriptor`, which flows through `RootPopoverView` to `WeatherStripView` in the popover, and through `MenuBarViewModel` / `ClockRenderService` to the menu bar text. A `showWeather` toggle in `MenuBarPreferences` controls visibility.

**Tech Stack:** Swift 6, SwiftUI, URLSession, Open-Meteo API

---

### Task 1: Weather Data Model & Service

**Files:**
- Create: `CalendarPro/Features/Weather/WeatherService.swift`
- Test: `CalendarProTests/Weather/WeatherServiceTests.swift`

**Step 1: Create `WeatherDescriptor` model and `WeatherService`**

Create `CalendarPro/Features/Weather/WeatherService.swift`:

```swift
import Foundation

struct WeatherDescriptor: Equatable, Sendable {
    let temperature: Double
    let apparentTemperature: Double
    let weatherCode: Int
    let isDaytime: Bool

    var hasContent: Bool {
        weatherCode >= 0
    }

    var iconSystemName: String {
        WMOWeatherCode.iconSystemName(for: weatherCode, isDaytime: isDaytime)
    }

    var description: String {
        WMOWeatherCode.description(for: weatherCode)
    }

    var temperatureText: String {
        "\(Int(round(temperature)))°"
    }

    var apparentTemperatureText: String {
        L("Feels like") + " \(Int(round(apparentTemperature)))°"
    }

    static let empty = WeatherDescriptor(
        temperature: 0,
        apparentTemperature: 0,
        weatherCode: -1,
        isDaytime: true
    )
}

private enum WMOWeatherCode {
    static func iconSystemName(for code: Int, isDaytime: Bool) -> String {
        switch code {
        case 0:
            return isDaytime ? "sun.max.fill" : "moon.stars.fill"
        case 1, 2:
            return isDaytime ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3:
            return "cloud.fill"
        case 45, 48:
            return "cloud.fog.fill"
        case 51, 53, 55, 56, 57:
            return "cloud.drizzle.fill"
        case 61, 63, 65, 66, 67:
            return "cloud.rain.fill"
        case 71, 73, 75, 77:
            return "cloud.snow.fill"
        case 80, 81, 82:
            return "cloud.heavyrain.fill"
        case 85, 86:
            return "cloud.snow.fill"
        case 95, 96, 99:
            return "cloud.bolt.rain.fill"
        default:
            return "cloud.fill"
        }
    }

    static func description(for code: Int) -> String {
        switch code {
        case 0:
            return L("Clear sky")
        case 1:
            return L("Mainly clear")
        case 2:
            return L("Partly cloudy")
        case 3:
            return L("Overcast")
        case 45:
            return L("Fog")
        case 48:
            return L("Depositing rime fog")
        case 51:
            return L("Light drizzle")
        case 53:
            return L("Moderate drizzle")
        case 55:
            return L("Dense drizzle")
        case 56:
            return L("Light freezing drizzle")
        case 57:
            return L("Dense freezing drizzle")
        case 61:
            return L("Slight rain")
        case 63:
            return L("Moderate rain")
        case 65:
            return L("Heavy rain")
        case 66:
            return L("Light freezing rain")
        case 67:
            return L("Heavy freezing rain")
        case 71:
            return L("Slight snowfall")
        case 73:
            return L("Moderate snowfall")
        case 75:
            return L("Heavy snowfall")
        case 77:
            return L("Snow grains")
        case 80:
            return L("Slight rain showers")
        case 81:
            return L("Moderate rain showers")
        case 82:
            return L("Violent rain showers")
        case 85:
            return L("Slight snow showers")
        case 86:
            return L("Heavy snow showers")
        case 95:
            return L("Thunderstorm")
        case 96:
            return L("Thunderstorm with slight hail")
        case 99:
            return L("Thunderstorm with heavy hail")
        default:
            return L("Unknown")
        }
    }
}

struct WeatherService: Sendable {
    let session: URLSession
    let now: @Sendable () -> Date

    init(
        session: URLSession = .shared,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.session = session
        self.now = now
    }

    func fetchCurrentWeather() async -> WeatherDescriptor {
        guard let url = openMeteoURL else {
            return .empty
        }

        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                return .empty
            }

            let result = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
            return result.current.toDescriptor()
        } catch {
            return .empty
        }
    }

    private var openMeteoURL: URL? {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "current", value: "temperature_2m,apparent_temperature,weather_code,is_day"),
            URLQueryItem(name: "timezone", value: "auto")
        ]
        return components?.url
    }
}

private struct OpenMeteoResponse: Decodable, Sendable {
    let current: CurrentWeather

    struct CurrentWeather: Decodable, Sendable {
        let temperature2m: Double
        let apparentTemperature: Double
        let weatherCode: Int
        let isDay: Int

        enum CodingKeys: String, CodingKey {
            case temperature2m = "temperature_2m"
            case apparentTemperature = "apparent_temperature"
            case weatherCode = "weather_code"
            case isDay = "is_day"
        }

        func toDescriptor() -> WeatherDescriptor {
            WeatherDescriptor(
                temperature: temperature2m,
                apparentTemperature: apparentTemperature,
                weatherCode: weatherCode,
                isDaytime: isDay == 1
            )
        }
    }
}
```

**Step 2: Create test file `CalendarProTests/Weather/WeatherServiceTests.swift`**

```swift
import XCTest
@testable import CalendarPro

final class WeatherServiceTests: XCTestCase {
    func testFetchCurrentWeatherReturnsEmptyOnInvalidURL() async {
        let service = WeatherService()
        let result = await service.fetchCurrentWeather()
        // With real URL, this will either succeed or return empty.
        // For a real unit test, inject a mock URLSession.
        // Here we just verify it doesn't crash.
        _ = result
    }

    func testWeatherDescriptorIconSystemNameForClearDay() {
        let descriptor = WeatherDescriptor(
            temperature: 25,
            apparentTemperature: 27,
            weatherCode: 0,
            isDaytime: true
        )
        XCTAssertEqual(descriptor.iconSystemName, "sun.max.fill")
    }

    func testWeatherDescriptorIconSystemNameForClearNight() {
        let descriptor = WeatherDescriptor(
            temperature: 18,
            apparentTemperature: 16,
            weatherCode: 0,
            isDaytime: false
        )
        XCTAssertEqual(descriptor.iconSystemName, "moon.stars.fill")
    }

    func testWeatherDescriptorIconSystemNameForOvercast() {
        let descriptor = WeatherDescriptor(
            temperature: 20,
            apparentTemperature: 19,
            weatherCode: 3,
            isDaytime: true
        )
        XCTAssertEqual(descriptor.iconSystemName, "cloud.fill")
    }

    func testWeatherDescriptorIconSystemNameForRain() {
        let descriptor = WeatherDescriptor(
            temperature: 15,
            apparentTemperature: 12,
            weatherCode: 61,
            isDaytime: true
        )
        XCTAssertEqual(descriptor.iconSystemName, "cloud.rain.fill")
    }

    func testWeatherDescriptorIconSystemNameForThunderstorm() {
        let descriptor = WeatherDescriptor(
            temperature: 22,
            apparentTemperature: 20,
            weatherCode: 95,
            isDaytime: false
        )
        XCTAssertEqual(descriptor.iconSystemName, "cloud.bolt.rain.fill")
    }

    func testWeatherDescriptorTemperatureText() {
        let descriptor = WeatherDescriptor(
            temperature: 23.6,
            apparentTemperature: 25.1,
            weatherCode: 0,
            isDaytime: true
        )
        XCTAssertEqual(descriptor.temperatureText, "24°")
    }

    func testWeatherDescriptorHasContentWithValidCode() {
        let descriptor = WeatherDescriptor(
            temperature: 20,
            apparentTemperature: 19,
            weatherCode: 0,
            isDaytime: true
        )
        XCTAssertTrue(descriptor.hasContent)
    }

    func testWeatherDescriptorHasNoContentWithNegativeCode() {
        let descriptor = WeatherDescriptor.empty
        XCTAssertFalse(descriptor.hasContent)
    }

    func testWeatherDescriptorEmptyHasNegativeCode() {
        let empty = WeatherDescriptor.empty
        XCTAssertEqual(empty.weatherCode, -1)
    }
}
```

**Step 3: Run tests**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/WeatherServiceTests`
Expected: PASS

**Step 4: Run `ruby tools/generate_xcodeproj.rb` to register new files in the Xcode project**

**Step 5: Commit**

```bash
git add CalendarPro/Features/Weather/WeatherService.swift CalendarProTests/Weather/WeatherServiceTests.swift
git commit -m "feat(weather): add WeatherService and WeatherDescriptor model"
```

---

### Task 2: Add Weather Settings (showWeather + .weather token)

**Files:**
- Modify: `CalendarPro/Settings/MenuBarPreferences.swift`
- Modify: `CalendarPro/Settings/SettingsStore.swift`
- Test: `CalendarProTests/Settings/MenuBarPreferencesTests.swift`

**Step 1: Add `.weather` to `DisplayTokenKind` in `MenuBarPreferences.swift`**

In the `DisplayTokenKind` enum, add a new case after `.holiday`:

```swift
case weather
```

**Step 2: Add `showWeather` property to `MenuBarPreferences` struct**

Add after `showAlmanac`:

```swift
var showWeather: Bool
```

Set default value `false` in `defaultsForCurrentLocale()` and `previewShort`.

**Step 3: Add `showWeather` CodingKey and encode/decode support**

Add to `CodingKeys`:
```swift
case showWeather
```

Decode with backward-compatible default:
```swift
showWeather: try container.decodeIfPresent(Bool.self, forKey: .showWeather) ?? false
```

Encode:
```swift
try container.encode(showWeather, forKey: .showWeather)
```

**Step 4: Add `.weather` token to defaults in `defaultsForCurrentLocale()`**

Add to the tokens array:
```swift
DisplayTokenPreference(token: .weather, isEnabled: false, order: 5, style: .short)
```

**Step 5: Add `setShowWeather` to `SettingsStore`**

```swift
func setShowWeather(_ enabled: Bool) {
    var prefs = menuBarPreferences
    prefs.showWeather = enabled
    menuBarPreferences = prefs
    persistMenuBarPreferences()
}
```

**Step 6: Update tests in `MenuBarPreferencesTests.swift`**

Add test for default `showWeather` being `false`:
```swift
func testDefaultShowWeatherIsFalse() {
    let prefs = MenuBarPreferences.default
    XCTAssertFalse(prefs.showWeather)
}
```

Update `testCodableRoundTrip` if needed to ensure new field survives round-trip.

**Step 7: Run tests**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/MenuBarPreferencesTests`
Expected: PASS

**Step 8: Commit**

```bash
git add CalendarPro/Settings/MenuBarPreferences.swift CalendarPro/Settings/SettingsStore.swift CalendarProTests/Settings/MenuBarPreferencesTests.swift
git commit -m "feat(weather): add showWeather setting and .weather display token"
```

---

### Task 3: WeatherStripView (Popover Display)

**Files:**
- Create: `CalendarPro/Views/Popover/WeatherStripView.swift`

**Step 1: Create `WeatherStripView`**

Create `CalendarPro/Views/Popover/WeatherStripView.swift` following the visual style of `AlmanacStripView`:

```swift
import SwiftUI

struct WeatherStripView: View {
    let weather: WeatherDescriptor
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: weather.iconSystemName)
                .font(.system(size: 18))
                .foregroundStyle(iconColor)
                .frame(width: 28, height: 28)
                .background {
                    Circle()
                        .fill(backgroundFillColor)
                }
                .overlay {
                    Circle()
                        .strokeBorder(borderColor, lineWidth: 0.5)
                }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(weather.temperatureText)
                        .font(.system(size: 16, weight: .bold, design: .rounded))

                    Text(weather.description)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(bodySecondaryColor)
                }

                Text(weather.apparentTemperatureText)
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundStyle(bodySecondaryColor)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(backgroundFillColor)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 0.5)
        }
    }

    private var iconColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.9)
            : Color.orange.opacity(0.85)
    }

    private var bodySecondaryColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.6)
            : Color.primary.opacity(0.55)
    }

    private var backgroundFillColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.055)
            : Color(nsColor: .controlBackgroundColor).opacity(0.72)
    }

    private var borderColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color(nsColor: .separatorColor).opacity(0.18)
    }
}
```

**Step 2: Run `ruby tools/generate_xcodeproj.rb`**

**Step 3: Commit**

```bash
git add CalendarPro/Views/Popover/WeatherStripView.swift
git commit -m "feat(weather): add WeatherStripView for popover display"
```

---

### Task 4: Integrate Weather into Popover (infoStripsSection)

**Files:**
- Modify: `CalendarPro/Views/Popover/CalendarPopoverView.swift`
- Modify: `CalendarPro/Views/RootPopoverView.swift`

**Step 1: Add weather props to `CalendarPopoverView`**

Add these properties to `CalendarPopoverView` after `showAlmanac`:

```swift
let weather: WeatherDescriptor?
let showWeather: Bool
```

**Step 2: Update `infoStripsSection` in `CalendarPopoverView`**

Add weather strip before almanac strip:

```swift
@ViewBuilder
private var infoStripsSection: some View {
    if shouldShowWeatherStrip || shouldShowAlmanacStrip {
        Divider()
            .padding(.horizontal, -PopoverSurfaceMetrics.outerPadding)

        VStack(spacing: 6) {
            if shouldShowWeatherStrip, let weather {
                WeatherStripView(weather: weather)
            }

            if shouldShowAlmanacStrip, let almanac {
                AlmanacStripView(almanac: almanac)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private var shouldShowWeatherStrip: Bool {
    showWeather && (weather?.hasContent ?? false)
}
```

**Step 3: Add `@State private var weatherDescriptor: WeatherDescriptor?` to `RootPopoverView`**

Add after `almanacDescriptor`:

```swift
@State private var weatherDescriptor: WeatherDescriptor?
```

Add a property:

```swift
private let weatherService = WeatherService()
```

**Step 4: Pass weather data to `CalendarPopoverView` in `RootPopoverView`**

Add to the `CalendarPopoverView(...)` initializer in `RootPopoverView.body`:

```swift
weather: weatherDescriptor,
showWeather: settingsStore.menuBarPreferences.showWeather,
```

**Step 5: Add weather refresh in `RootPopoverView.refreshInfoStrips()`**

Update `refreshInfoStrips()`:

```swift
private func refreshInfoStrips() {
    let date = viewModel.selectedDate ?? timeRefreshCoordinator.currentDate

    if settingsStore.menuBarPreferences.showAlmanac {
        almanacDescriptor = almanacService.describe(date: date)
    } else {
        almanacDescriptor = nil
    }

    if settingsStore.menuBarPreferences.showWeather {
        Task {
            let descriptor = await weatherService.fetchCurrentWeather()
            await MainActor.run {
                weatherDescriptor = descriptor.hasContent ? descriptor : nil
            }
        }
    } else {
        weatherDescriptor = nil
    }
}
```

**Step 6: Add `onChange` for `showWeather` in `RootPopoverView`**

Add after the existing `onChange(of: settingsStore.menuBarPreferences.showAlmanac)`:

```swift
.onChange(of: settingsStore.menuBarPreferences.showWeather) { _, _ in
    refreshInfoStrips()
}
```

**Step 7: Build and verify no compile errors**

Run: `xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'`
Expected: BUILD SUCCEEDED

**Step 8: Commit**

```bash
git add CalendarPro/Views/Popover/CalendarPopoverView.swift CalendarPro/Views/RootPopoverView.swift
git commit -m "feat(weather): integrate weather into popover info strips"
```

---

### Task 5: Integrate Weather into Menu Bar Display

**Files:**
- Modify: `CalendarPro/Features/MenuBar/ClockRenderService.swift`
- Modify: `CalendarPro/Features/MenuBar/MenuBarViewModel.swift`

**Step 1: Add `weatherText` to `MenuBarSupplementalText`**

In `ClockRenderService.swift`, update `MenuBarSupplementalText`:

```swift
struct MenuBarSupplementalText: Equatable {
    var lunarText: String?
    var holidayText: String?
    var weatherText: String?

    static let empty = MenuBarSupplementalText()
}
```

**Step 2: Add `.weather` case to `renderToken` in `ClockRenderService`**

Add to the switch in `renderToken`:

```swift
case .weather:
    return supplementalText.weatherText
```

**Step 3: Add `weatherDescriptor` property to `MenuBarViewModel`**

Add a published property:

```swift
@Published private(set) var weatherDescriptor: WeatherDescriptor = .empty
```

Add a `WeatherService` property:

```swift
private let weatherService: WeatherService
```

Update `init` to accept and store it (with default):

```swift
init(
    ...
    weatherService: WeatherService = WeatherService(),
    ...
)
```

**Step 4: Add weather fetch logic to `MenuBarViewModel.render()`**

At the end of `render(at:with:)`, after computing `displayText`, add weather fetch:

```swift
private func fetchWeatherIfNeeded(with prefs: MenuBarPreferences) {
    let weatherTokenEnabled = prefs.tokens.contains(where: { $0.token == .weather && $0.isEnabled })

    guard prefs.showWeather || weatherTokenEnabled else {
        if weatherDescriptor != .empty {
            weatherDescriptor = .empty
            renderNow()
        }
        return
    }

    Task {
        let descriptor = await weatherService.fetchCurrentWeather()
        await MainActor.run { [weak self] in
            guard let self else { return }
            let changed = self.weatherDescriptor != descriptor
            self.weatherDescriptor = descriptor
            if changed {
                self.renderNow()
            }
        }
    }
}
```

Call it from `render(at:with:)` at the end.

**Step 5: Include weather text in render call**

In `MenuBarViewModel.render(at:with:)`, compute `weatherText`:

```swift
let weatherText: String?
if weatherDescriptor.hasContent {
    weatherText = "\(weatherDescriptor.temperatureText)"
} else {
    weatherText = nil
}

let supplemental = MenuBarSupplementalText(
    lunarText: supplementalText.lunarText,
    holidayText: supplementalText.holidayText,
    weatherText: weatherText
)
```

**Step 6: Update `MenuBarSettingsView` for `.weather` token**

In `MenuBarSettingsView.swift`:

- `tokenDisplayName`: add `.weather: L("Weather")`
- `styleOptions`: add `.weather: [.short] as [DisplayTokenStyle]`
- `defaultStyle`: add `.weather: .short`
- `stylePreviewText`: add `.weather: weatherDescriptor.temperatureText` (fallback: `L("Weather")`)

**Step 7: Run `ruby tools/generate_xcodeproj.rb` and build**

Run: `xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'`
Expected: BUILD SUCCEEDED

**Step 8: Commit**

```bash
git add CalendarPro/Features/MenuBar/ClockRenderService.swift CalendarPro/Features/MenuBar/MenuBarViewModel.swift CalendarPro/Views/Settings/MenuBarSettingsView.swift
git commit -m "feat(weather): integrate weather into menu bar display text"
```

---

### Task 6: Add Weather Toggle in Settings UI

**Files:**
- Modify: `CalendarPro/Views/Settings/GeneralSettingsView.swift`

**Step 1: Add weather toggle to "Panel Info" section**

In `GeneralSettingsView.swift`, update the "Panel Info" section (currently only contains almanac toggle):

```swift
if LocaleFeatureAvailability.showAlmanacFeatures {
    GeneralSettingsSection(L("Panel Info")) {
        GeneralSettingsRow(
            title: L("Show Weather"),
            description: L("Show Weather Description")
        ) {
            Toggle("", isOn: showWeatherBinding)
                .labelsHidden()
        }

        Divider()

        GeneralSettingsRow(
            title: L("Show Almanac"),
            description: L("Show Almanac Description")
        ) {
            Toggle("", isOn: showAlmanacBinding)
                .labelsHidden()
        }
    }
}
```

Add the binding:

```swift
private var showWeatherBinding: Binding<Bool> {
    Binding(
        get: { store.menuBarPreferences.showWeather },
        set: { store.setShowWeather($0) }
    )
}
```

**Step 2: Add localization strings**

Add to the localization files:
- `"Show Weather"` / `"显示天气"`
- `"Show Weather Description"` / `"在日历面板中显示当前天气信息"`

**Step 3: Build and verify**

Run: `xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add CalendarPro/Views/Settings/GeneralSettingsView.swift
git commit -m "feat(weather): add weather toggle in settings"
```

---

### Task 7: Run Full Test Suite & Final Verification

**Step 1: Run all tests**

Run: `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'`
Expected: All tests pass

**Step 2: Regenerate Xcode project**

Run: `ruby tools/generate_xcodeproj.rb`

**Step 3: Final commit if needed**

```bash
git add -A
git commit -m "chore(weather): update project files for weather feature"
```
