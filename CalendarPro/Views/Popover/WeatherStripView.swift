import SwiftUI

struct WeatherStripView: View {
    let weather: WeatherDescriptor
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            summarySection

            if !metricItems.isEmpty {
                metricsSection
            }
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
        .help(L("Weather data attribution"))
    }

    private var summarySection: some View {
        HStack(spacing: 10) {
            Image(systemName: weather.iconSystemName)
                .font(.system(size: 18))
                .foregroundStyle(iconColor)
                .frame(width: 28, height: 28)
                .background {
                    Circle()
                        .fill(iconBackgroundColor)
                }
                .overlay {
                    Circle()
                        .strokeBorder(borderColor, lineWidth: 0.5)
                }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(weather.temperatureText)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)

                    Text(weather.description)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(bodySecondaryColor)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Text(detailText)
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundStyle(bodySecondaryColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metricsSection: some View {
        LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 6) {
            ForEach(metricItems) { item in
                WeatherMetricView(item: item, labelColor: bodySecondaryColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private var iconBackgroundColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.07)
            : Color.orange.opacity(0.10)
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

    private var metricColumns: [GridItem] {
        [
            GridItem(.flexible(minimum: 0), spacing: 8),
            GridItem(.flexible(minimum: 0), spacing: 0)
        ]
    }

    private var metricItems: [WeatherMetricItem] {
        let candidates: [WeatherMetricItem?]

        if weather.isCurrentConditions {
            candidates = [
                apparentTemperatureMetric,
                windMetric,
                humidityMetric,
                airQualityMetric,
                precipitationMetric,
                windGustMetric
            ]
        } else {
            candidates = [
                windMetric,
                precipitationMetric,
                airQualityMetric,
                uvMetric,
                windGustMetric
            ]
        }

        return Array(candidates.compactMap { $0 }.prefix(4))
    }

    private var apparentTemperatureMetric: WeatherMetricItem? {
        guard let apparentTemperature = weather.apparentTemperature else {
            return nil
        }

        return WeatherMetricItem(
            id: "apparent",
            title: L("Feels like"),
            value: formattedTemperature(apparentTemperature),
            detail: nil,
            systemImage: "thermometer"
        )
    }

    private var windMetric: WeatherMetricItem? {
        guard let windSpeed = weather.windSpeed else {
            return nil
        }

        return WeatherMetricItem(
            id: "wind",
            title: L("Wind"),
            value: formattedWindSpeed(windSpeed),
            detail: formattedWindDirection(weather.windDirection),
            systemImage: "wind"
        )
    }

    private var humidityMetric: WeatherMetricItem? {
        guard let humidity = weather.humidity else {
            return nil
        }

        return WeatherMetricItem(
            id: "humidity",
            title: L("Humidity"),
            value: "\(humidity)%",
            detail: nil,
            systemImage: "humidity"
        )
    }

    private var precipitationMetric: WeatherMetricItem? {
        if let probability = weather.precipitationProbability {
            return WeatherMetricItem(
                id: "precipitation",
                title: L("Precipitation"),
                value: "\(probability)%",
                detail: weather.precipitation.map(formattedPrecipitation),
                systemImage: "umbrella.fill"
            )
        }

        guard let precipitation = weather.precipitation else {
            return nil
        }

        return WeatherMetricItem(
            id: "precipitation",
            title: L("Precipitation"),
            value: formattedPrecipitation(precipitation),
            detail: nil,
            systemImage: "umbrella.fill"
        )
    }

    private var airQualityMetric: WeatherMetricItem? {
        if let airQualityIndex = weather.airQualityIndex {
            return WeatherMetricItem(
                id: "air-quality",
                title: L("AQI"),
                value: "\(airQualityIndex)",
                detail: airQualityLevelText(for: airQualityIndex),
                systemImage: "aqi.medium"
            )
        }

        guard let pm25 = weather.pm25 else {
            return nil
        }

        return WeatherMetricItem(
            id: "pm25",
            title: "PM2.5",
            value: formattedPM25(pm25),
            detail: "ug/m3",
            systemImage: "aqi.medium"
        )
    }

    private var uvMetric: WeatherMetricItem? {
        guard let uvIndex = weather.uvIndex else {
            return nil
        }

        return WeatherMetricItem(
            id: "uv",
            title: L("UV"),
            value: "\(Int(round(uvIndex)))",
            detail: uvLevelText(for: uvIndex),
            systemImage: "sun.max.fill"
        )
    }

    private var windGustMetric: WeatherMetricItem? {
        guard let windGusts = weather.windGusts else {
            return nil
        }

        return WeatherMetricItem(
            id: "gusts",
            title: L("Gusts"),
            value: formattedWindSpeed(windGusts),
            detail: nil,
            systemImage: "wind"
        )
    }

    private var detailText: String {
        let suffix: String

        if weather.isCurrentConditions {
            suffix = L("Current conditions")
        } else if let forecastDate = weather.forecastDate {
            suffix = LF("Forecast for %@", formattedForecastDate(forecastDate))
        } else {
            suffix = ""
        }

        guard !weather.locationName.isEmpty else {
            return suffix
        }

        guard !suffix.isEmpty else {
            return weather.locationName
        }

        return "\(weather.locationName) · \(suffix)"
    }

    private func formattedTemperature(_ value: Double) -> String {
        "\(Int(round(value)))°"
    }

    private func formattedWindSpeed(_ value: Double) -> String {
        "\(Int(round(value))) km/h"
    }

    private func formattedPrecipitation(_ value: Double) -> String {
        if value < 0.05 {
            return "0 mm"
        }

        if value < 10 {
            return String(format: "%.1f mm", value)
        }

        return "\(Int(round(value))) mm"
    }

    private func formattedPM25(_ value: Double) -> String {
        "\(Int(round(value)))"
    }

    private func formattedWindDirection(_ degrees: Double?) -> String? {
        guard let degrees else {
            return nil
        }

        let normalized = (degrees.truncatingRemainder(dividingBy: 360) + 360)
            .truncatingRemainder(dividingBy: 360)
        let index = Int((normalized / 45).rounded()) % windDirectionLabels.count
        return windDirectionLabels[index]
    }

    private var windDirectionLabels: [String] {
        [
            L("Wind Direction N"),
            L("Wind Direction NE"),
            L("Wind Direction E"),
            L("Wind Direction SE"),
            L("Wind Direction S"),
            L("Wind Direction SW"),
            L("Wind Direction W"),
            L("Wind Direction NW")
        ]
    }

    private func airQualityLevelText(for value: Int) -> String {
        switch value {
        case ...50:
            return L("AQI Level Good")
        case 51...100:
            return L("AQI Level Moderate")
        case 101...150:
            return L("AQI Level Unhealthy Sensitive")
        case 151...200:
            return L("AQI Level Unhealthy")
        case 201...300:
            return L("AQI Level Very Unhealthy")
        default:
            return L("AQI Level Hazardous")
        }
    }

    private func uvLevelText(for value: Double) -> String {
        switch Int(round(value)) {
        case ...2:
            return L("UV Level Low")
        case 3...5:
            return L("UV Level Moderate")
        case 6...7:
            return L("UV Level High")
        case 8...10:
            return L("UV Level Very High")
        default:
            return L("UV Level Extreme")
        }
    }

    private func formattedForecastDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLocalization.locale
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter.string(from: date)
    }
}

private struct WeatherMetricItem: Identifiable {
    let id: String
    let title: String
    let value: String
    let detail: String?
    let systemImage: String
}

private struct WeatherMetricView: View {
    let item: WeatherMetricItem
    let labelColor: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Image(systemName: item.systemImage)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(labelColor)
                .frame(width: 11)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundStyle(labelColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(item.value)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    if let detail = item.detail {
                        Text(detail)
                            .font(.system(size: 8, weight: .medium, design: .rounded))
                            .foregroundStyle(labelColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
