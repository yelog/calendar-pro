# Weather Detail Window Design

## Requirement Analysis

The current weather strip is too sparse for the amount of horizontal space it owns. It shows the icon, temperature, condition, location, and one quick metric, leaving the center of the card visually empty. The previous click-to-expand behavior also expands inside the calendar popover, which competes with the month grid, Pomodoro strip, and event list.

The better split is:

- The calendar popover keeps a dense, glanceable weather summary.
- A separate left-side weather panel handles planning-level information.
- The data model stays provider-neutral so Open-Meteo and QWeather continue to share the same UI path.

## UX Direction

The compact strip should answer "Do I need to care right now?" without reading a dashboard. It should use the existing space for three to four small metrics such as feels-like, precipitation, wind, humidity, AQI, PM2.5, or UV, depending on what the provider returns for the selected day.

Clicking the strip opens a floating weather detail panel on the left side of the popover. This preserves the calendar as the primary surface and gives forecast information enough room to breathe. The panel should close with the popover and should not require app activation just to inspect weather.

## Visual Design

The compact strip remains one card, not a card inside a card. It uses a stronger left summary anchor and a small metric grid on the right. The trailing affordance points toward the left panel so the interaction reads as "open beside this popover", not "expand downward".

The detail panel uses the existing floating panel language: rounded surface, subtle material-like tint, close button in the top right, and dense but readable rows. The top area focuses on current weather; the body shows 10 days of forecast rows with weekday/date, icon, high/low temperature, precipitation chance, wind speed, and optional UV or air-quality context.

## Architecture

`WeatherService` exposes a `WeatherForecastOverview` that contains the current descriptor and up to 10 daily forecast descriptors. The popover view owns loading state and asks the existing cached `WeatherService` for the overview only when the user opens the detail panel.

`WeatherDetailWindowController` owns a narrow `NSPanel` bridge for placement and lifecycle. SwiftUI owns all detail content through `WeatherDetailWindowView`.

## Interaction Rules

- Weather strip click opens the side panel when weather content is available.
- Clicking the strip again closes the side panel.
- Opening weather detail closes event detail and vacation guide panels.
- Closing the popover closes the weather detail panel.
- Weather loading or unavailable states do not create empty detail panels.

## Verification

- Unit test `WeatherService.forecastOverview(days:calendar:)` with a 10-day fixture.
- Unit test the weather detail sizing helper.
- Run focused weather tests and app build.
