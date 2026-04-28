# Weather Expanded Details Implementation Plan

**Goal:** Let users click the weather strip to reveal the detailed weather data already available from the current Open-Meteo path.

**Architecture:** Keep weather fetching in `WeatherService` and keep the expanded/collapsed interaction local to `WeatherStripView`. The compact row remains unchanged visually, while expanded state reuses the same descriptor fields in a denser metric grid.

**Tech Stack:** Swift 6, SwiftUI, XCTest, Open-Meteo forecast and air-quality APIs.

---

## Requirement Analysis

- Current weather path can already provide more than the compact UI shows. `WeatherService` requests current temperature, apparent temperature, relative humidity, precipitation, weather code, cloud cover, wind speed, wind direction, wind gusts and day/night, plus daily forecast and Open-Meteo air-quality data.
- Before this change, `cloud_cover` was requested but not decoded, and `WeatherStripView` intentionally capped visible metrics to 3 for current conditions and 2 for forecasts.
- The weather strip should therefore support a low-friction drill-down instead of adding another fetch path or a separate detail window.

## UI/UX Design

- Default state stays compact so the calendar popover keeps its existing height and scanability.
- Clicking anywhere on the weather strip toggles expansion when more metrics are available.
- A trailing chevron communicates expand/collapse state without adding text-heavy controls.
- Expanded state shows a three-column metric grid below the summary row.
- Current conditions can show feels-like, humidity, precipitation, wind, gusts, cloud cover, AQI and PM2.5 when available.
- Forecast dates can show precipitation, wind, gusts, AQI, PM2.5 and UV when available.
- Loading and empty states remain non-interactive.

## Implementation Plan

1. Extend `WeatherDescriptor` and current weather snapshots with `cloudCover`.
2. Decode Open-Meteo `cloud_cover` from the existing `current` payload.
3. Split weather metrics into compact and full metric lists in `WeatherStripView`.
4. Add local `@State` expansion, click handling, chevron affordance and accessibility labeling.
5. Render the expanded metrics as a compact SwiftUI `LazyVGrid`.
6. Add `Cloud cover` localization.
7. Update weather service tests to verify decoded cloud cover.
8. Run focused weather tests, then build the app scheme.

## Verification

- `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/Weather/WeatherServiceTests`
- `xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'`

---

## 2026-04-28 Visual Refinement

### Design Analysis

- The first expanded version kept compact metrics in the header and repeated the same metrics again in the expanded grid. This made the card feel noisy and reduced the user's ability to distinguish summary from detail.
- A three-column expanded grid was too dense for a 340 pt popover. Long values such as `17 km/h 东南`, `16% 0.6 mm`, and air-quality labels competed for width and produced uneven rows.
- Today and forecast states had different metric counts, so the same grid system created different visual weights. Today looked crowded, while forecast looked sparse.
- The chevron affordance was visually correct, but the expanded body needed a clearer information architecture.

### Optimized Interaction Design

- Collapsed state: show the weather icon, temperature, condition, location/date, and at most two quick metrics. This keeps scanning fast and prevents the summary row from becoming a miniature dashboard.
- Expanded state: keep the same summary header but hide quick metrics, then show all available metrics in a two-column details grid below it. This removes duplication and gives each metric enough horizontal space.
- Expansion remains instant with no layout animation to avoid popover height jitter.
- The component stays a single card; metric rows are plain content, not nested cards.

### Implementation Plan

1. Reduce compact metrics to two items in `WeatherStripView`.
2. Hide compact metrics while expanded to remove duplicated information.
3. Increase summary icon and primary typography so the header reads as the anchor of the card.
4. Replace the three-column details grid with a two-column grid using wider tracks.
5. Increase metric row height, spacing and font sizes for better legibility in Chinese and mixed unit strings.
6. Build and run focused weather tests.
