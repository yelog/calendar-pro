import SwiftUI

struct WeatherDetailWindowView: View {
    let overview: WeatherForecastOverview
    let onClose: () -> Void
    let onPreferredHeightChange: ((CGFloat) -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @State private var lastReportedPreferredHeight: CGFloat = 0

    private var currentVisualStyle: WeatherVisualStyle {
        WeatherVisualStyle(iconSystemName: overview.current.iconSystemName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            currentConditionsCard
            forecastSection
            footer
        }
        .padding(PopoverSurfaceMetrics.outerPadding)
        .frame(width: WeatherDetailWindowSizing.width, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(surfaceBackground)
        .background(
            WeatherDetailHeightReporter { height in
                reportPreferredHeightIfNeeded(height)
            }
        )
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(L("Weather Details"))
                    .font(.system(size: 18, weight: .bold, design: .rounded))

                Text(locationSubtitle)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.92))
                    )
            }
            .buttonStyle(.plain)
            .help(L("Close Weather Details"))
        }
    }

    private var currentConditionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: overview.current.iconSystemName)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(currentVisualStyle.primary(for: colorScheme))
                    .frame(width: 48, height: 48)
                    .background {
                        Circle()
                            .fill(currentVisualStyle.iconBackgroundGradient(for: colorScheme))
                    }
                    .overlay {
                        Circle()
                            .strokeBorder(currentVisualStyle.border(for: colorScheme), lineWidth: 0.7)
                    }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(overview.current.temperatureText)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .lineLimit(1)

                        Text(overview.current.description)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Text(L("Current conditions"))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 10) {
                ForEach(currentMetricItems.prefix(6)) { item in
                    WeatherDetailMetricView(item: item)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(currentVisualStyle.heroGradient(for: colorScheme))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(currentVisualStyle.border(for: colorScheme), lineWidth: 0.8)
        }
    }

    private var forecastSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text(L("10-Day Forecast"))
                    .font(.system(size: 13, weight: .bold, design: .rounded))

                Spacer(minLength: 0)

                Text(dateRangeText)
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(overview.dailyForecasts.indices, id: \.self) { index in
                        WeatherForecastRowView(
                            descriptor: overview.dailyForecasts[index],
                            isFirst: index == 0
                        )
                    }
                }
                .padding(.vertical, 1)
            }
            .frame(minHeight: 260, maxHeight: .infinity, alignment: .top)
        }
    }

    private var footer: some View {
        Text(L("Weather data attribution"))
            .font(.system(size: 10.5, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var locationSubtitle: String {
        guard !overview.current.locationName.isEmpty else {
            return L("10-Day Forecast")
        }

        return overview.current.locationName
    }

    private var dateRangeText: String {
        guard let first = overview.dailyForecasts.first?.forecastDate,
              let last = overview.dailyForecasts.last?.forecastDate else {
            return ""
        }

        return "\(formattedDate(first)) - \(formattedDate(last))"
    }

    private var metricColumns: [GridItem] {
        [
            GridItem(.flexible(minimum: 150), spacing: 10),
            GridItem(.flexible(minimum: 150), spacing: 10)
        ]
    }

    private var currentMetricItems: [WeatherDetailMetricItem] {
        [
            overview.current.apparentTemperature.map {
                WeatherDetailMetricItem(
                    id: "apparent",
                    title: L("Feels like"),
                    value: formattedTemperature($0),
                    detail: nil,
                    systemImage: "thermometer"
                )
            },
            precipitationMetric(for: overview.current),
            windMetric(for: overview.current),
            overview.current.humidity.map {
                WeatherDetailMetricItem(
                    id: "humidity",
                    title: L("Humidity"),
                    value: "\($0)%",
                    detail: nil,
                    systemImage: "humidity"
                )
            },
            overview.current.cloudCover.map {
                WeatherDetailMetricItem(
                    id: "cloud-cover",
                    title: L("Cloud cover"),
                    value: "\($0)%",
                    detail: nil,
                    systemImage: "cloud.fill"
                )
            },
            airQualityMetric(for: overview.current),
            overview.current.pm25.map {
                WeatherDetailMetricItem(
                    id: "pm25",
                    title: "PM2.5",
                    value: formattedPM25($0),
                    detail: "ug/m3",
                    systemImage: "aqi.medium"
                )
            }
        ]
        .compactMap { $0 }
    }

    private var surfaceBackground: some View {
        ZStack {
            PopoverSurfaceMetrics.floatingPanelBaseFill(for: colorScheme)
            PopoverSurfaceMetrics.floatingPanelTintOverlay(
                accent: currentVisualStyle.primary(for: colorScheme),
                for: colorScheme
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: PopoverSurfaceMetrics.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PopoverSurfaceMetrics.cornerRadius, style: .continuous)
                .strokeBorder(PopoverSurfaceMetrics.floatingPanelBorderColor(for: colorScheme), lineWidth: 1)
        )
    }

    private func precipitationMetric(for descriptor: WeatherDescriptor) -> WeatherDetailMetricItem? {
        if let probability = descriptor.precipitationProbability {
            return WeatherDetailMetricItem(
                id: "precipitation",
                title: L("Precipitation"),
                value: "\(probability)%",
                detail: descriptor.precipitation.map(formattedPrecipitation),
                systemImage: "umbrella.fill"
            )
        }

        guard let precipitation = descriptor.precipitation else {
            return nil
        }

        return WeatherDetailMetricItem(
            id: "precipitation",
            title: L("Precipitation"),
            value: formattedPrecipitation(precipitation),
            detail: nil,
            systemImage: "umbrella.fill"
        )
    }

    private func windMetric(for descriptor: WeatherDescriptor) -> WeatherDetailMetricItem? {
        guard let windSpeed = descriptor.windSpeed else {
            return nil
        }

        return WeatherDetailMetricItem(
            id: "wind",
            title: L("Wind"),
            value: formattedWindSpeed(windSpeed),
            detail: formattedWindDirection(descriptor.windDirection),
            systemImage: "wind"
        )
    }

    private func airQualityMetric(for descriptor: WeatherDescriptor) -> WeatherDetailMetricItem? {
        guard let airQualityIndex = descriptor.airQualityIndex else {
            return nil
        }

        return WeatherDetailMetricItem(
            id: "air-quality",
            title: L("AQI"),
            value: "\(airQualityIndex)",
            detail: airQualityLevelText(for: airQualityIndex),
            systemImage: "aqi.medium"
        )
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = AppLocalization.locale
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
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
        let labels = windDirectionLabels
        let index = Int((normalized / 45).rounded()) % labels.count
        return labels[index]
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

    private func reportPreferredHeightIfNeeded(_ height: CGFloat) {
        guard abs(height - lastReportedPreferredHeight) > 1 else { return }
        lastReportedPreferredHeight = height
        onPreferredHeightChange?(height)
    }
}

private struct WeatherForecastRowView: View {
    let descriptor: WeatherDescriptor
    let isFirst: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var visualStyle: WeatherVisualStyle {
        WeatherVisualStyle(iconSystemName: descriptor.iconSystemName)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(dayText)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .lineLimit(1)

                Text(dateText)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 50, alignment: .leading)

            Image(systemName: descriptor.iconSystemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(visualStyle.primary(for: colorScheme))
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(compactForecastTemperatureText(descriptor.temperatureText))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .lineLimit(1)

                    Text(descriptor.description)
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    if let precipitation = precipitationText {
                        WeatherForecastInlineMetric(systemImage: "umbrella.fill", text: precipitation)
                    }

                    if let windSpeed = descriptor.windSpeed {
                        WeatherForecastInlineMetric(systemImage: "wind", text: formattedWindSpeed(windSpeed))
                    }

                    if let uvIndex = descriptor.uvIndex {
                        WeatherForecastInlineMetric(systemImage: "sun.max.fill", text: "\(L("UV")) \(Int(round(uvIndex)))")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(visualStyle.backgroundGradient(for: colorScheme))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(visualStyle.border(for: colorScheme), lineWidth: 0.6)
        }
    }

    private var dayText: String {
        if isFirst {
            return L("Today")
        }

        guard let date = descriptor.forecastDate else {
            return ""
        }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = AppLocalization.locale
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter.string(from: date)
    }

    private var dateText: String {
        guard let date = descriptor.forecastDate else {
            return ""
        }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = AppLocalization.locale
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }

    private var precipitationText: String? {
        if let probability = descriptor.precipitationProbability {
            return "\(probability)%"
        }

        return descriptor.precipitation.map(formattedPrecipitation)
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
}

private struct WeatherForecastInlineMetric: View {
    let systemImage: String
    let text: String

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: systemImage)
                .font(.system(size: 8.5, weight: .semibold))

            Text(text)
                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .foregroundStyle(.secondary)
    }
}

private struct WeatherDetailMetricItem: Identifiable {
    let id: String
    let title: String
    let value: String
    let detail: String?
    let systemImage: String
}

private struct WeatherDetailMetricView: View {
    let item: WeatherDetailMetricItem

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: item.systemImage)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(item.value)
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .lineLimit(1)

                    if let detail = item.detail {
                        Text(detail)
                            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
    }
}

private struct WeatherDetailHeightReporter: View {
    let onChange: (CGFloat) -> Void

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .preference(key: WeatherDetailHeightPreferenceKey.self, value: proxy.size.height)
        }
        .onPreferenceChange(WeatherDetailHeightPreferenceKey.self, perform: onChange)
    }
}

private struct WeatherDetailHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
