import SwiftUI

struct WeatherStripView: View {
    let weather: WeatherDescriptor
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: weather.iconSystemName)
                .font(.system(size: 18))
                .foregroundStyle(iconColor)
                .frame(width: 28, height: 28)
                .background {
                    Circle()
                        .fill(backgroundFillColor)
                }
                .overlay {
                    Circle()
                        .strokeBorder(borderColor, lineWidth: 0.5)
                }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(weather.temperatureText)
                        .font(.system(size: 16, weight: .bold, design: .rounded))

                    Text(weather.description)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(bodySecondaryColor)
                }

                Text(weather.apparentTemperatureText)
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundStyle(bodySecondaryColor)
            }

            Spacer(minLength: 0)
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
}
