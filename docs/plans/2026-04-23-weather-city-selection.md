# Implementation: Weather Manual City Selection

## Completed Tasks
- [x] Add `WeatherLocation` and `LocationMode` models to `MenuBarPreferences`.
- [x] Implement `CitySearchService` for Open-Meteo Geocoding API.
- [x] Update `SettingsStore` with setters for location mode and manual location.
- [x] Update `WeatherService` to support optional manual location and skip geolocation when provided.
- [x] Add location selection UI to `GeneralSettingsView`.
- [x] Wire up `RootPopoverView` and `MenuBarViewModel` to respect manual location settings.
- [x] Add localization for new strings.
- [x] Add comprehensive unit tests.
- [x] Regenerate Xcode project.

## Verification
- Verified persistence of location mode and manual city selection.
- Verified weather service uses manual coordinates when mode is set to manual.
- Verified search results display and selection logic.
- All relevant unit tests passed (SettingsStore, MenuBarPreferences, WeatherService, CitySearchService).
