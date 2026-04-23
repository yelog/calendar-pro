# Weather Manual City Selection Design

## Overview
Support manual city selection for weather information, allowing users to override the automatic IP-based geolocation fallback.

## Requirements
- Support switching between "Automatic" (IP-based) and "Manual" location modes.
- Provide a searchable city database (using Open-Meteo Geocoding API).
- Persist the selected city and location mode in app preferences.
- Update weather display immediately when location changes.

## Architecture

### Data Models
- `LocationMode`: Enum with `.automatic` and `.manual`.
- `WeatherLocation`: Struct containing `latitude`, `longitude`, `name`, and optional `country`/`admin1`.

### Services
- `CitySearchService`: Encapsulates calls to `geocoding-api.open-meteo.com/v1/search`.
- `WeatherService`: Updated to accept an optional `manualLocation`. If present, it skips IP geolocation fallback.

### UI Components
- `WeatherLocationSettings`: A new view in `GeneralSettingsView` containing:
    - Segmented picker for `LocationMode`.
    - Search field for cities (visible in manual mode).
    - Results list for selecting a city.
    - Current location indicator.

### Data Flow
1. User searches for a city in Settings.
2. `CitySearchService` fetches matching results.
3. User selects a result; `SettingsStore` updates `MenuBarPreferences`.
4. `SettingsStore` persists changes to `UserDefaults`.
5. `RootPopoverView` and `MenuBarViewModel` detect preference changes.
6. `WeatherService` instances are updated/recreated with the new location.
7. Weather is re-fetched for the new coordinates.

## Testing
- Unit tests for `CitySearchService` (mocking API responses).
- Unit tests for `WeatherService` manual location priority.
- Round-trip Codable tests for `MenuBarPreferences` with new fields.
- Integration tests for `SettingsStore` persistence.
