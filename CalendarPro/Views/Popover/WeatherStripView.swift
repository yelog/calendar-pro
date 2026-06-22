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
                .fill(visualStyle.backgroundGradient(for: colorScheme))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(visualStyle.border(for: colorScheme), lineWidth: 0.7)
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

    private var visualStyle: WeatherVisualStyle {
        WeatherVisualStyle(iconSystemName: weather.iconSystemName)
    }

    private var summarySection: some View {
        HStack(spacing: 9) {
            Image(systemName: weather.iconSystemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(visualStyle.primary(for: colorScheme))
                .frame(width: 32, height: 32)
                .background {
                    Circle()
                        .fill(visualStyle.iconBackgroundGradient(for: colorScheme))
                }
                .overlay {
                    Circle()
                        .strokeBorder(visualStyle.border(for: colorScheme), lineWidth: 0.6)
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
                .foregroundStyle(visualStyle.primary(for: colorScheme))
                .frame(width: 28, height: 28)
                .background {
                    Circle()
                        .fill(visualStyle.iconBackgroundGradient(for: colorScheme))
                }
                .overlay {
                    Circle()
                        .strokeBorder(visualStyle.border(for: colorScheme), lineWidth: 0.6)
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
                WeatherCompactMetricView(
                    item: item,
                    labelColor: bodySecondaryColor,
                    iconColor: visualStyle.secondary(for: colorScheme)
                )
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

    private var bodySecondaryColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.62)
            : Color.primary.opacity(0.52)
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

struct WeatherVisualStyle {
    private enum Tone {
        case sunny
        case night
        case rainy
        case stormy
        case snowy
        case cloudy
        case neutral
    }

    private let tone: Tone

    init(iconSystemName: String) {
        if iconSystemName.contains("bolt") {
            tone = .stormy
        } else if iconSystemName.contains("snow") || iconSystemName.contains("sleet") {
            tone = .snowy
        } else if iconSystemName.contains("rain") || iconSystemName.contains("drizzle") || iconSystemName.contains("umbrella") {
            tone = .rainy
        } else if iconSystemName.contains("moon") {
            tone = .night
        } else if iconSystemName.contains("cloud") || iconSystemName.contains("fog") || iconSystemName.contains("smoke") {
            tone = .cloudy
        } else if iconSystemName.contains("sun") {
            tone = .sunny
        } else {
            tone = .neutral
        }
    }

    func primary(for colorScheme: ColorScheme) -> Color {
        switch tone {
        case .sunny:
            return colorScheme == .dark ? Color(red: 1.00, green: 0.80, blue: 0.30) : Color(red: 0.88, green: 0.46, blue: 0.05)
        case .night:
            return colorScheme == .dark ? Color(red: 0.74, green: 0.78, blue: 1.00) : Color(red: 0.34, green: 0.35, blue: 0.78)
        case .rainy:
            return colorScheme == .dark ? Color(red: 0.45, green: 0.78, blue: 1.00) : Color(red: 0.06, green: 0.48, blue: 0.82)
        case .stormy:
            return colorScheme == .dark ? Color(red: 0.84, green: 0.72, blue: 1.00) : Color(red: 0.47, green: 0.28, blue: 0.80)
        case .snowy:
            return colorScheme == .dark ? Color(red: 0.72, green: 0.92, blue: 1.00) : Color(red: 0.04, green: 0.58, blue: 0.76)
        case .cloudy:
            return colorScheme == .dark ? Color(red: 0.76, green: 0.84, blue: 0.94) : Color(red: 0.32, green: 0.46, blue: 0.62)
        case .neutral:
            return colorScheme == .dark ? Color.white.opacity(0.88) : Color.accentColor
        }
    }

    func secondary(for colorScheme: ColorScheme) -> Color {
        primary(for: colorScheme).opacity(colorScheme == .dark ? 0.72 : 0.78)
    }

    func border(for colorScheme: ColorScheme) -> Color {
        primary(for: colorScheme).opacity(colorScheme == .dark ? 0.22 : 0.20)
    }

    func backgroundGradient(for colorScheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: backgroundColors(for: colorScheme),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    func heroGradient(for colorScheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: heroColors(for: colorScheme),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    func iconBackgroundGradient(for colorScheme: ColorScheme) -> LinearGradient {
        let primary = primary(for: colorScheme)
        return LinearGradient(
            colors: [
                primary.opacity(colorScheme == .dark ? 0.24 : 0.17),
                primary.opacity(colorScheme == .dark ? 0.09 : 0.07)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func backgroundColors(for colorScheme: ColorScheme) -> [Color] {
        let primary = primary(for: colorScheme)
        if colorScheme == .dark {
            return [primary.opacity(0.16), Color.white.opacity(0.045)]
        }

        return [primary.opacity(0.105), Color(nsColor: .controlBackgroundColor).opacity(0.58)]
    }

    private func heroColors(for colorScheme: ColorScheme) -> [Color] {
        let primary = primary(for: colorScheme)
        if colorScheme == .dark {
            return [primary.opacity(0.26), Color.white.opacity(0.055), primary.opacity(0.10)]
        }

        return [primary.opacity(0.18), Color.white.opacity(0.72), primary.opacity(0.08)]
    }
}

private struct WeatherCompactMetricView: View {
    let item: WeatherMetricItem
    let labelColor: Color
    let iconColor: Color

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            Image(systemName: item.systemImage)
                .font(.system(size: 8.5, weight: .medium))
                .foregroundStyle(iconColor)
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
