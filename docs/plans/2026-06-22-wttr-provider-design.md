# wttr.in Weather Provider Design

## Goal

Add wttr.in as a third weather provider that users can select without entering an API key or custom host.

## Decision

Add wttr.in as a normal, provider-neutral option beside Open-Meteo and QWeather. The settings UI should expose it in the existing weather provider picker, with no extra configuration fields. Weather UI components should continue to consume `WeatherDescriptor` and `WeatherForecastOverview` so the popover, detail window, and menu bar do not need provider-specific branches.

## Data Source

Use wttr.in JSON output:

```text
https://wttr.in/<latitude>,<longitude>?format=j1&m&lang=<language>
```

Use coordinates rather than location names to avoid wttr.in text geocoding differences. Use metric units through `m`. Use `lang=zh` for Chinese UI and `lang=en` otherwise.

## Runtime Configuration

Add `WeatherProvider.wttrIn` and `WeatherProviderConfiguration.wttrIn`.

`WeatherProviderConfiguration.isUsable` should treat wttr.in like Open-Meteo: always usable once a location is available. `weatherProviderConfiguration(for:)` maps persisted `.wttrIn` preferences to `.wttrIn`.

## Fetching

Extend `WeatherService.fetchSnapshotFromNetwork()` with a wttr.in branch. The fetcher should:

- Build a wttr.in URL from resolved latitude and longitude.
- Decode `format=j1` JSON.
- Convert current conditions into `CurrentWeatherSnapshot`.
- Convert available daily forecasts into `[DailyWeatherForecast]`.
- Convert wttr.in hourly rows into `[HourlyWeatherForecast]` when dates can be derived.
- Leave air quality nil because wttr.in `j1` does not include AQI/PM2.5.
- Cache the resulting `WeatherSnapshot` using the existing service cache.

wttr.in currently returns fewer forecast days than Open-Meteo. `forecastOverview(days: 10)` should return the available rows rather than inventing missing days.

## Field Mapping

Current condition mapping:

- `temp_C` -> current temperature
- `FeelsLikeC` -> apparent temperature
- `weatherCode` -> mapped WMO-like weather code
- `humidity` -> humidity
- `precipMM` -> precipitation
- `cloudcover` -> cloud cover
- `windspeedKmph` -> wind speed
- `winddirDegree` -> wind direction
- `uvIndex` -> available only through descriptor data when supported by the existing model

Daily forecast mapping:

- `date` -> forecast date
- `maxtempC` / `mintempC` -> high and low temperature
- dominant or most severe hourly weather code -> daily weather code
- hourly `precipMM` sum -> precipitation summary
- hourly `chanceofrain` max -> precipitation probability
- hourly `windspeedKmph` max -> wind speed max
- hourly `WindGustKmph` max -> wind gust max
- `uvIndex` -> UV index max

Hourly mapping:

- `date + time` -> hourly date, where `time` is `0`, `300`, `600`, ..., `2100`
- `weatherCode` -> mapped WMO-like weather code
- `precipMM` -> precipitation
- `chanceofrain` -> precipitation probability
- no separate `rain` or `showers` fields, so leave those nil

## Weather Code Mapping

wttr.in exposes WorldWeatherOnline-style condition codes, while CalendarPro uses WMO-like codes for icons and descriptions. Add a small mapper that converts wttr.in codes to existing WMO-like codes.

Initial mapping groups:

- Clear/sunny: `113 -> 0`
- Partly cloudy: `116 -> 2`
- Cloudy/overcast: `119`, `122` -> `3`
- Mist/fog/freezing fog: `143`, `248`, `260` -> `45`/`48`
- Patchy/light drizzle or nearby rain: `176`, `263`, `266`, `293`, `296`, `353` -> `51`/`61`
- Moderate/heavy rain: `299`, `302`, `305`, `308`, `356`, `359` -> `63`/`65`
- Freezing rain/drizzle: `281`, `284`, `311`, `314`, `317`, `350`, `362`, `365` -> `56`/`66`/`67`
- Snow/sleet/ice pellets: `179`, `182`, `185`, `227`, `230`, `320`, `323`, `326`, `329`, `332`, `335`, `338`, `368`, `371`, `374`, `377` -> `71`/`73`/`75`/`77`
- Thunder: `200`, `386`, `389`, `392`, `395` -> `95`/`96`/`99`

Unknown codes should fall back to overcast `3` rather than an invalid descriptor.

## Settings UI

The existing segmented provider picker is driven by `WeatherProvider.allCases`, so adding the enum case should expose wttr.in automatically. Add localization for `Weather Provider wttr.in` and update the provider description to mention all three providers. Do not show QWeather API fields unless `.qWeather` is selected.

## Testing

Add tests for:

- wttr.in provider display name and Codable round trip.
- `SettingsStore` mapping `.wttrIn` to `.wttrIn` runtime configuration.
- wttr.in URL construction using coordinate path, `format=j1`, metric units, and language.
- wttr.in JSON decoding for current conditions and available daily forecasts.
- wttr.in condition code mapping.
- Provider switching remains isolated through `WeatherProviderConfiguration` equality.

## Non-Goals

- Do not add wttr.in API host customization in this change.
- Do not add wttr.in as an automatic fallback for other providers.
- Do not redesign weather UI.
- Do not fake a 10-day forecast when wttr.in returns fewer days.
- Do not add AQI for wttr.in unless the API starts returning it in the selected format.
