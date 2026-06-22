# Open-Meteo Today Hourly Forecast Design

## Goal

Prevent Open-Meteo's 10-day forecast from showing dry thunderstorms when current, hourly, and daily precipitation data do not support that condition.

## Problem

CalendarPro currently renders every 10-day forecast row from Open-Meteo `daily.weather_code`. Open-Meteo's daily weather code is a day summary and can represent the most significant condition for the whole day, not the current or remaining-day condition. For Shenzhen Nanshan, this allows today and future rows to show WMO `95`/`96` thunderstorm even when Open-Meteo's own precipitation amounts and probabilities are near zero.

The app does not request Open-Meteo hourly weather or precipitation fields today, so it cannot reconcile a daily thunderstorm code against the remaining hours of the day.

## Decision

Use hourly Open-Meteo data to synthesize the forecast descriptor for today's row in `forecastOverview`, and filter unsupported Open-Meteo thunderstorm daily codes for future rows. QWeather remains unchanged.

For today's row:

- Keep daily high/low temperature, wind, UV, and daily precipitation summary fields.
- Inspect hourly records from `now` through the end of the selected calendar day.
- Use thunderstorm `weather_code` values only when supported by meaningful precipitation signals.
- If remaining hourly data shows no precipitation and no meaningful precipitation probability, prefer a non-thunderstorm current/hourly weather code over a daily thunderstorm summary.
- Fall back to the existing daily descriptor when hourly data is unavailable.

For future Open-Meteo rows:

- Keep daily high/low temperature, wind, UV, and daily precipitation summary fields.
- If the daily code is not thunderstorm, keep it unchanged.
- If the daily code is thunderstorm and daily/hourly precipitation support is weak, use that day's most representative non-thunderstorm hourly code.
- If no hourly fallback exists, use overcast (`3`) instead of showing an unsupported thunderstorm.

## Data Flow

1. Extend the Open-Meteo forecast request with hourly fields: `weather_code,precipitation,precipitation_probability,rain,showers`.
2. Decode `OpenMeteoResponse.hourly` into `[HourlyWeatherForecast]`.
3. Store hourly forecasts in `WeatherSnapshot`.
4. In `forecastOverview`, detect today's daily row and call a today-specific descriptor builder.
5. For other rows, run a small Open-Meteo thunderstorm evidence filter before building the descriptor.
6. The builders choose the best supported weather code and return a `WeatherDescriptor` preserving daily high/low and summary metrics.

## Selection Rules

Synthesized weather codes should be selected as follows:

1. If there are no remaining hourly forecasts for today, use the existing daily forecast code.
2. Compute precipitation support from hourly `precipitation`, `rain`, `showers`, daily `precipitation_sum`, and precipitation probabilities.
3. If the candidate code is not thunderstorm, keep it.
4. If thunderstorm has precipitation support, keep the most severe supported hourly/daily code.
5. If thunderstorm has no precipitation support, prefer a non-thunderstorm hourly/current fallback.

The first implementation should keep thresholds conservative and simple:

- meaningful amount: `> 0.5mm`
- meaningful probability: `>= 30`

## Testing

Add a regression test where:

- current weather is partly cloudy with zero precipitation.
- daily weather code for today is `95` thunderstorm.
- today's remaining hourly weather codes do not include thunderstorm and precipitation/probability are zero.

Expected behavior:

- `forecastOverview().dailyForecasts.first?.weatherCode` is not `95`.
- The row keeps today's daily high/low temperature.

Add another regression test where a future daily row is `96` thunderstorm, daily precipitation support is weak, and that day's hourly data is cloudy/dry. The future row should not render as thunderstorm.

Also update existing request tests to assert the Open-Meteo URL includes the hourly weather fields.

## Non-Goals

- Do not change QWeather behavior.
- Do not redesign the weather UI.
- Do not introduce provider-specific UI copy in this change.
- Do not solve all timezone edge cases in this patch.
