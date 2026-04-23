# Weather Date-Aware Display Design

## Summary

Refine the weather card so it shows the current location and responds to the selected calendar date. Today continues to show current conditions, while non-today dates show that day's forecast.

## Problem Analysis

The current implementation has two structural issues:

1. `WeatherDescriptor` only contains current-condition fields (`temperature`, `apparentTemperature`, `weatherCode`, `isDaytime`), so the UI has no place to render the current location.
2. `RootPopoverView.refreshInfoStrips()` always calls `WeatherService.fetchCurrentWeather()`, and `WeatherService` only requests Open-Meteo `current` data. Because the selected date is ignored and the response is cached for 30 minutes, clicking different dates cannot change the weather card.

## UX Goals

1. Show which location the weather belongs to.
2. Make the weather card react when the user selects another date.
3. Keep the card compact enough to fit the existing popover layout.
4. Preserve the current visual language of the weather strip.

## Interaction Model

### Today

- Show current conditions for the detected location.
- Main row: icon + current temperature + current weather description.
- Secondary row: location name + feels-like temperature.
- Semantics: current conditions.

### Non-today Selected Date

- Show forecast for the selected date for the same detected location.
- Main row: icon + max/min temperature + forecast description.
- Secondary row: location name + forecast label for the selected date.
- Semantics: selected-day forecast.

## UI Structure

Keep the current card shell but adjust the text layout:

- Left: circular icon treatment as-is.
- Right top line:
  - Today: `26°  Light Rain`
  - Other dates: `26° / 20°  Light Rain`
- Right second line:
  - Today: `Hong Kong · Feels like 31°`
  - Other dates: `Hong Kong · Forecast for Apr 24`

This adds location context without making the card meaningfully taller.

## Data Model

Split weather into a snapshot layer and a presentation layer.

### WeatherSnapshot

Represents the fetched weather payload for one detected location.

- `locationName: String`
- `current: CurrentWeather`
- `dailyForecasts: [DailyWeatherForecast]`
- `fetchedAt: Date`

### CurrentWeather

- `temperature: Double`
- `apparentTemperature: Double`
- `weatherCode: Int`
- `isDaytime: Bool`

### DailyWeatherForecast

- `date: Date`
- `weatherCode: Int`
- `maxTemperature: Double`
- `minTemperature: Double`

### WeatherDescriptor

Remain the view-facing model, but expand it so the view can render both current conditions and forecast states.

- `locationName: String`
- `primaryTemperatureText: String`
- `secondaryText: String`
- `description: String`
- `iconSystemName: String`
- `isCurrentConditions: Bool`
- `hasContent: Bool`

## API Design

Update Open-Meteo requests to include both current and daily data.

- `current=temperature_2m,apparent_temperature,weather_code,is_day`
- `daily=weather_code,temperature_2m_max,temperature_2m_min`
- `timezone=auto`

Keep the existing IP geolocation fallback chain, but carry location names forward from the geolocation response:

- `ipwho.is`
- `ipinfo.io`
- `ipapi.co`

The location name should be derived from the most human-readable available combination, preferring city, then region/country.

## Date-Aware Mapping

`WeatherService` should expose a date-aware mapping step:

- fetch or reuse a `WeatherSnapshot`
- build a `WeatherDescriptor` for `selectedDate`

Behavior:

- if `selectedDate` is today: build from `current`
- otherwise: look up matching `DailyWeatherForecast` and build a forecast descriptor
- if forecast for the selected date is unavailable: return empty and hide the strip

## Caching Strategy

- Keep location caching.
- Replace current-condition cache with snapshot cache.
- Cache duration remains 30 minutes.
- Clicking different dates within the cached forecast range must not re-hit the geolocation providers.
- Re-fetch only when:
  - cache expires, or
  - selected date falls outside the cached forecast range

## View Integration

`RootPopoverView.refreshInfoStrips()` should continue to react to date selection changes, but it should request a date-aware descriptor instead of a raw current weather payload.

`WeatherStripView` should render:

- a location-aware secondary line
- current or forecast temperature formatting depending on `isCurrentConditions`

No other popover sections need to change.

## Error Handling

- If location resolution fails: hide weather card.
- If weather fetch fails: hide weather card.
- If selected date forecast is unavailable: hide weather card.

No inline error state is added in this iteration.

## Testing

Add coverage for:

1. decoding location name from geolocation responses
2. decoding current + daily Open-Meteo payloads
3. building a descriptor for today from current conditions
4. building a descriptor for a future date from daily forecast
5. caching snapshot data across multiple date selections
6. falling back between geolocation providers without losing location metadata

## Files to Update

- `CalendarPro/Features/Weather/WeatherService.swift`
- `CalendarPro/Views/Popover/WeatherStripView.swift`
- `CalendarPro/Views/RootPopoverView.swift`
- `CalendarProTests/Weather/WeatherServiceTests.swift`
