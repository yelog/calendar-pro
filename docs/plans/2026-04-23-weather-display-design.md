# Weather Display — Design

## Summary

Add current weather display to CalendarPro, showing in both the menu bar status text and the popover calendar view, using the Open-Meteo free API with IP-based geolocation.

## Data Source

**Open-Meteo** (https://open-meteo.com)

- Completely free, no API key required, open source
- IP-based geolocation by default (no CoreLocation permission needed)
- Endpoint: `https://api.open-meteo.com/v1/forecast?current=temperature_2m,apparent_temperature,weather_code,is_day`
- Refresh interval: every 30 minutes via `TimeRefreshCoordinator`

## Data Model

```
WeatherDescriptor (Equatable)
├── temperature: Double          // Current temperature (°C)
├── apparentTemperature: Double  // Feels-like temperature (°C)
├── weatherCode: Int             // WMO weather code
├── isDaytime: Bool              // Day/night (affects icon choice)
└── hasContent: Bool             // Whether valid data is available
```

## Architecture

Follow the existing Almanac pattern (Service → Descriptor → View):

1. **`Features/Weather/WeatherService.swift`** — API client + `WeatherDescriptor` model
2. **`Views/Popover/WeatherStripView.swift`** — Weather card in popover
3. **Settings changes** — `showWeather` toggle in `MenuBarPreferences`

## Popover Display

- Location: `infoStripsSection` area in `CalendarPopoverView`, above `AlmanacStripView`
- Layout: horizontal card — SF Symbol weather icon + temperature + apparent temperature
- Style: reuses `AlmanacStripView` rounded card visual style for consistency
- Controlled by `showWeather` toggle (default: `false`)

## Menu Bar Display

- Add `.weather` case to `DisplayTokenKind`
- Render weather icon + temperature as text (e.g. `☀️ 23°`) in `ClockRenderService` / `MenuBarViewModel`
- User can reorder and toggle `.weather` token in settings

## Settings

- `MenuBarPreferences.showWeather: Bool` (default `false`, same as `showAlmanac`)
- `SettingsStore.setShowWeather(_ enabled: Bool)` method
- Settings UI: weather toggle placed next to the almanac toggle

## Data Flow

```
TimeRefreshCoordinator (30min tick)
  → WeatherService.fetchCurrentWeather()
    → Open-Meteo API (IP geolocation)
      → WeatherDescriptor
        → RootPopoverView.weatherDescriptor (@State)
          → CalendarPopoverView → infoStripsSection → WeatherStripView
        → MenuBarViewModel → DisplayToken (.weather) → StatusBarController
```

## Error Handling

- Network failure: silent degradation, hide weather strip (consistent with almanac behavior)
- No alert or error message to user
- Retry on next refresh tick

## File Changes

### New Files
- `CalendarPro/Features/Weather/WeatherService.swift`
- `CalendarPro/Views/Popover/WeatherStripView.swift`

### Modified Files
- `CalendarPro/Settings/MenuBarPreferences.swift` — add `showWeather`, `.weather` token
- `CalendarPro/Settings/SettingsStore.swift` — add `setShowWeather`
- `CalendarPro/Views/RootPopoverView.swift` — integrate weather state
- `CalendarPro/Views/Popover/CalendarPopoverView.swift` — render `WeatherStripView` in `infoStripsSection`
- `CalendarPro/Features/MenuBar/MenuBarViewModel.swift` — include weather in display text
- `CalendarPro/Features/MenuBar/ClockRenderService.swift` — render weather token
- Settings UI files — add weather toggle
