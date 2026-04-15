import CoreGraphics
import SwiftUI

enum PopoverSurfaceMetrics {
    static let width: CGFloat = 340
    static let outerPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 10
    static let cornerRadius: CGFloat = 16

    static func floatingPanelBaseFill(for colorScheme: ColorScheme) -> Color {
        if colorScheme == .dark {
            return Color(red: 0.12, green: 0.12, blue: 0.13)
        }

        return Color(nsColor: .windowBackgroundColor)
    }

    static func floatingPanelTintOverlay(accent: Color, for colorScheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: [
                colorScheme == .dark ? Color.white.opacity(0.03) : Color.white.opacity(0.18),
                accent.opacity(colorScheme == .dark ? 0.08 : 0.05)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func floatingPanelBorderColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.12)
            : Color(nsColor: .separatorColor).opacity(0.18)
    }

    static func elevatedCardFillColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(nsColor: .controlBackgroundColor).opacity(0.92)
            : Color(nsColor: .windowBackgroundColor).opacity(0.97)
    }

    static func elevatedCardBorderColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color(nsColor: .separatorColor).opacity(0.18)
    }
}
