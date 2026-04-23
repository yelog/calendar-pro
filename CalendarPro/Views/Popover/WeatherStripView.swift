import SwiftUI

struct WeatherStripView: View {
    private let descriptor: WeatherDescriptor?
    let isLoading: Bool
    let requestedDate: Date
    @Environment(\.colorScheme) private var colorScheme

    init(weather: WeatherDescriptor?, isLoading: Bool = false, requestedDate: Date = Date()) {
        self.descriptor = weather
        self.isLoading = isLoading
        self.requestedDate = requestedDate
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            if isLoading {
                loadingSummarySection
                    .layoutPriority(1)

                ProgressView()
                    .controlSize(.small)
                    .frame(width: 16, height: 16)
            } else {
                summarySection
                    .layoutPriority(1)

                if !metricItems.isEmpty {
                    metricsSection
                        .layoutPriority(0)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(backgroundFillColor)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 0.5)
        }
        .help(stripHelpText)
    }

    private var weather: WeatherDescriptor {
        descriptor ?? .empty
    }

    private var summarySection: some View {
        HStack(spacing: 10) {
            Image(systemName: weather.iconSystemName)
                .font(.system(size: 16))
                .foregroundStyle(iconColor)
                .frame(width: 26, height: 26)
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
                    Text(displayTemperatureText)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)

                    Text(weather.description)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
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

    private var loadingSummarySection: some View {
        HStack(spacing: 10) {
            Image(systemName: "cloud")
                .font(.system(size: 15))
                .foregroundStyle(iconColor)
                .frame(width: 26, height: 26)
                .background {
                    Circle()
                        .fill(iconBackgroundColor)
                }
                .overlay {
                    Circle()
                        .strokeBorder(borderColor, lineWidth: 0.5)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(L("Weather"))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(1)

                Text(verbatim: "\(L("Loading")) · \(loadingDetailText)")
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
        HStack(alignment: .center, spacing: 6) {
            ForEach(metricItems) { item in
                WeatherMetricView(item: item, labelColor: bodySecondaryColor)
            }
        }
        .frame(width: metricsSectionWidth, alignment: .trailing)
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

    private var stripHelpText: String {
        isLoading ? "\(L("Weather")) \(L("Loading"))" : L("Weather data attribution")
    }

    private var loadingDetailText: String {
        let calendar = Calendar.autoupdatingCurrent
        if calendar.isDate(requestedDate, inSameDayAs: Date()) {
            return L("Current conditions")
        }

        return LF("Forecast for %@", formattedCompactForecastDate(requestedDate))
    }

    private var metricItems: [WeatherMetricItem] {
        let candidates: [WeatherMetricItem?]

        if weather.isCurrentConditions {
            candidates = [
                apparentTemperatureMetric,
                windMetric,
                airQualityMetric,
                humidityMetric,
                precipitationMetric,
                windGustMetric
            ]
        } else {
            candidates = [
                precipitationMetric,
                airQualityMetric,
                windMetric,
                uvMetric,
                windGustMetric
            ]
        }

        let limit = weather.isCurrentConditions ? 3 : 2
        return Array(candidates.compactMap { $0 }.prefix(limit))
    }

    private var metricsSectionWidth: CGFloat {
        weather.isCurrentConditions ? 146 : 98
    }

    private var displayTemperatureText: String {
        guard !weather.isCurrentConditions else {
            return weather.temperatureText
        }

        return compactForecastTemperatureText(weather.temperatureText)
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
        if weather.isCurrentConditions {
            return weather.locationName
        }

        guard let forecastDate = weather.forecastDate else {
            return weather.locationName
        }

        let dateText = formattedCompactForecastDate(forecastDate)
        guard !weather.locationName.isEmpty else {
            return dateText
        }

        return "\(dateText) · \(weather.locationName)"
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

    private func compactForecastTemperatureText(_ value: String) -> String {
        let parts = value
            .components(separatedBy: " / ")
            .map { $0.replacingOccurrences(of: "°", with: "") }

        guard parts.count == 2,
              let high = parts.first,
              let low = parts.last,
              !high.isEmpty,
              !low.isEmpty else {
            return value
        }

        return "\(high)/\(low)°"
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

    private func formattedCompactForecastDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = AppLocalization.locale
        formatter.dateFormat = "M/d"
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
        HStack(alignment: .center, spacing: 3) {
            Image(systemName: item.systemImage)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(labelColor)
                .frame(width: 9)

            VStack(alignment: .leading, spacing: 0) {
                Text(item.title)
                    .font(.system(size: 7, weight: .medium, design: .rounded))
                    .foregroundStyle(labelColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(item.value)
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    if shouldShowDetail, let detail = item.detail {
                        Text(detail)
                            .font(.system(size: 7, weight: .medium, design: .rounded))
                            .foregroundStyle(labelColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .help(helpText)
    }

    private var shouldShowDetail: Bool {
        item.id == "air-quality" || item.id == "uv"
    }

    private var helpText: String {
        [item.title, item.value, item.detail].compactMap { $0 }.joined(separator: " ")
    }
}
