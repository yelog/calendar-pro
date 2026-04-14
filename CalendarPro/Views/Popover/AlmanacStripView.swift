import SwiftUI

struct AlmanacStripView: View {
    let almanac: AlmanacDescriptor
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !almanac.recommends.isEmpty {
                almanacRow(
                    label: L("Recommended"),
                    items: almanac.recommends,
                    style: .recommended
                )
            }

            if !almanac.avoids.isEmpty {
                almanacRow(
                    label: L("Avoid"),
                    items: almanac.avoids,
                    style: .avoid
                )
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
    }

    private func almanacRow(
        label: String,
        items: [String],
        style: AlmanacRowStyle
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(style.badgeForeground)
                .padding(.horizontal, label.count > 2 ? 9 : 0)
                .frame(minWidth: 26, minHeight: 26)
                .background {
                    Capsule(style: .continuous)
                        .fill(style.badgeFill)
                }
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(style.badgeStroke, lineWidth: 0.6)
                }
                .fixedSize()

            Text(itemsText(items))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(bodyTextColor)
                .lineSpacing(3)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func itemsText(_ items: [String]) -> String {
        items.joined(separator: "、")
    }

    private var bodyTextColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.88)
            : Color.primary.opacity(0.86)
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

private struct AlmanacRowStyle {
    let badgeFill: Color
    let badgeStroke: Color
    let badgeForeground: Color

    static let recommended = AlmanacRowStyle(
        badgeFill: Color(red: 0.76, green: 0.30, blue: 0.20),
        badgeStroke: Color(red: 0.88, green: 0.47, blue: 0.34).opacity(0.9),
        badgeForeground: Color.white.opacity(0.98)
    )

    static let avoid = AlmanacRowStyle(
        badgeFill: Color(red: 0.23, green: 0.16, blue: 0.14),
        badgeStroke: Color(red: 0.42, green: 0.31, blue: 0.27).opacity(0.95),
        badgeForeground: Color(red: 0.98, green: 0.92, blue: 0.88)
    )
}
