import SwiftUI

struct WeatherStripView: View {
    private let descriptor: WeatherDescriptor?
    let isLoading: Bool
    let requestedDate: Date
    let isDetailPresented: Bool
    let isDetailLoading: Bool
    let onOpenDetails: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    init(
        weather: WeatherDescriptor?,
        isLoading: Bool = false,
        requestedDate: Date = Date(),
        isDetailPresented: Bool = false,
        isDetailLoading: Bool = false,
        onOpenDetails: (() -> Void)? = nil
    ) {
        self.descriptor = weather
        self.isLoading = isLoading
        self.requestedDate = requestedDate
        self.isDetailPresented = isDetailPresented
        self.isDetailLoading = isDetailLoading
        self.onOpenDetails = onOpenDetails
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

                if !compactMetricItems.isEmpty {
                    metricsGrid
                }

                if canOpenDetails {
                    detailAffordance
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(backgroundFillColor)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 0.5)
        }
        .help(stripHelpText)
        .contentShape(Rectangle())
        .onTapGesture {
            guard canOpenDetails else { return }
            onOpenDetails?()
        }
        .accessibilityAddTraits(canOpenDetails ? .isButton : [])
        .accessibilityLabel(accessibilityLabel)
    }

    private var weather: WeatherDescriptor {
        descriptor ?? .empty
    }

    private var summarySection: some View {
        HStack(spacing: 9) {
            Image(systemName: weather.iconSystemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 32, height: 32)
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
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)

                    Text(weather.description)
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(bodySecondaryColor)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Text(detailText)
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(bodySecondaryColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var loadingSummarySection: some View {
        HStack(spacing: 9) {
            Image(systemName: "cloud")
                .font(.system(size: 15))
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

    private var metricsGrid: some View {
        LazyVGrid(columns: compactMetricColumns, alignment: .leading, spacing: 5) {
            ForEach(compactMetricItems) { item in
                WeatherCompactMetricView(item: item, labelColor: bodySecondaryColor)
            }
        }
        .frame(width: 134, alignment: .leading)
    }

    @ViewBuilder
    private var detailAffordance: some View {
        if isDetailLoading {
            ProgressView()
                .controlSize(.small)
                .frame(width: 16, height: 18)
        } else {
            Image(systemName: "sidebar.left")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isDetailPresented ? Color.accentColor : bodySecondaryColor)
                .frame(width: 14, height: 18)
                .accessibilityHidden(true)
        }
    }

    private var compactMetricColumns: [GridItem] {
        [
            GridItem(.flexible(minimum: 58), spacing: 6),
            GridItem(.flexible(minimum: 58), spacing: 6)
        ]
    }

    private var iconColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.9)
            : Color.orange.opacity(0.72)
    }

    private var bodySecondaryColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.62)
            : Color.primary.opacity(0.52)
    }

    private var iconBackgroundColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.07)
            : Color.orange.opacity(0.075)
    }

    private var backgroundFillColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.055)
            : Color(nsColor: .controlBackgroundColor).opacity(0.46)
    }

    private var borderColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color(nsColor: .separatorColor).opacity(0.12)
    }

    private var stripHelpText: String {
        if isLoading {
            return "\(L("Weather")) \(L("Loading"))"
        }

        guard canOpenDetails else {
            return L("Weather data attribution")
        }

        return isDetailPresented ? L("Close Weather Details") : L("Open Weather Details")
    }

    private var accessibilityLabel: String {
        if isLoading {
            return "\(L("Weather")) \(L("Loading"))"
        }

        let metricsText = compactMetricItems
            .map { [$0.title, $0.value, $0.detail].compactMap { $0 }.joined(separator: " ") }
            .joined(separator: ", ")

        return [L("Weather"), weather.temperatureText, weather.description, detailText, metricsText]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    private var loadingDetailText: String {
        let calendar = Calendar.autoupdatingCurrent
        if calendar.isDate(requestedDate, inSameDayAs: Date()) {
            return L("Current conditions")
        }

        return LF("Forecast for %@", formattedCompactForecastDate(requestedDate))
    }

    private var compactMetricItems: [WeatherMetricItem] {
        let candidates: [WeatherMetricItem?]

        if weather.isCurrentConditions {
            candidates = [
                apparentTemperatureMetric,
                precipitationMetric,
                windMetric,
                humidityMetric,
                airQualityMetric,
                cloudCoverMetric
            ]
        } else {
            candidates = [
                precipitationMetric,
                windMetric,
                uvMetric,
                airQualityMetric,
                windGustMetric
            ]
        }

        return Array(candidates.compactMap { $0 }.prefix(4))
    }

    private var canOpenDetails: Bool {
        !isLoading && weather.hasContent && onOpenDetails != nil
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
        airQualityIndexMetric ?? pm25Metric
    }

    private var airQualityIndexMetric: WeatherMetricItem? {
        if let airQualityIndex = weather.airQualityIndex {
            return WeatherMetricItem(
                id: "air-quality",
                title: L("AQI"),
                value: "\(airQualityIndex)",
                detail: airQualityLevelText(for: airQualityIndex),
                systemImage: "aqi.medium"
            )
        }

        return nil
    }

    private var pm25Metric: WeatherMetricItem? {
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

    private var cloudCoverMetric: WeatherMetricItem? {
        guard let cloudCover = weather.cloudCover else {
            return nil
        }

        return WeatherMetricItem(
            id: "cloud-cover",
            title: L("Cloud cover"),
            value: "\(cloudCover)%",
            detail: nil,
            systemImage: "cloud.fill"
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

private struct WeatherCompactMetricView: View {
    let item: WeatherMetricItem
    let labelColor: Color

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            Image(systemName: item.systemImage)
                .font(.system(size: 8.5, weight: .medium))
                .foregroundStyle(labelColor)
                .frame(width: 10)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.system(size: 7.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(labelColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                Text(compactValueText)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, minHeight: 20, alignment: .leading)
        .help(helpText)
    }

    private var compactValueText: String {
        guard item.id == "air-quality" || item.id == "uv",
              let detail = item.detail else {
            return item.value
        }

        return "\(item.value) \(detail)"
    }

    private var helpText: String {
        [item.title, item.value, item.detail].compactMap { $0 }.joined(separator: " ")
    }
}
