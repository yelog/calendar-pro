# Weather Provider and Location Design

## Goal

Improve city search for mainland Chinese users while keeping Open-Meteo as the default weather source, and add explicit user control for switching to QWeather.

## Architecture

`WeatherProvider` is stored in `MenuBarPreferences` so provider choice is a user setting rather than an automatic region heuristic. Open-Meteo remains the default and requires no credentials. QWeather uses a configured API Host stored in preferences and an API Key stored in Keychain via `WeatherCredentialStoring`.

`WeatherService` accepts a `WeatherProviderConfiguration` and routes snapshot loading to either Open-Meteo or QWeather. The public descriptor model stays unchanged so menu bar and popover rendering do not need provider-specific UI branches. Automatic location first asks a `WeatherLocationResolving` implementation backed by CoreLocation, then falls back to the existing IP lookup chain.

## UX

The weather section in General settings exposes a provider segmented control. QWeather Host and Key fields appear only when QWeather is selected. Manual city search now distinguishes no-result and network-failure states instead of silently showing an empty list.

Open-Meteo search receives a mainland-specific Chinese fallback: Chinese queries are scoped to `countryCode=CN`, two-character city names retry with a `市` suffix, and pinyin is used as another fallback. This keeps the no-key default service useful for cases like `厦门`.

## Data and Security

QWeather API Host is non-sensitive and persists with menu bar preferences. QWeather API Key is sensitive and persists in the macOS Keychain. The app does not bundle a shared QWeather credential.

## Verification

Coverage focuses on:

- `厦门` resolving through Open-Meteo fallback to `厦门市`.
- City search empty vs failed states.
- Provider and QWeather configuration codable/persistence behavior.
- Weather service using injected system location before IP lookup.
- Weather service calling QWeather with configured API Host and `X-QW-Api-Key`, including local AQI and PM2.5 parsing.
