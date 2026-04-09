import SwiftUI

struct YearPickerView: View {
    let displayedYear: Int
    let currentYear: Int
    let onSelectYear: (Int) -> Void
    let onDismiss: () -> Void

    private let yearRange: Int = 10

    var body: some View {
        VStack(spacing: 12) {
            headerBar
            yearGrid
        }
        .padding(.vertical, 8)
    }

    private var headerBar: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.primary.opacity(0.07))
                    )
            }
            .buttonStyle(.plain)

            Spacer()

            Text(String(localized: "Select Year"))
                .font(.system(.subheadline, design: .rounded).weight(.semibold))

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.primary.opacity(0.07))
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var yearGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: 8) {
            ForEach(years, id: \.self) { year in
                YearCellView(
                    year: year,
                    isSelected: year == displayedYear,
                    isCurrent: year == currentYear,
                    onSelect: { onSelectYear(year) }
                )
            }
        }
        .padding(.horizontal, 4)
    }

    private var years: [Int] {
        let start = currentYear - yearRange
        let end = currentYear + yearRange
        return Array(start...end)
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
    }
}

private struct YearCellView: View {
    @Environment(\.colorScheme) private var colorScheme

    let year: Int
    let isSelected: Bool
    let isCurrent: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            Text(String(year))
                .font(.system(size: 15, weight: isSelected ? .semibold : .regular, design: .rounded))
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(cellBackgroundColor)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(cellBorderColor, lineWidth: cellBorderWidth)
                }
        }
        .buttonStyle(.plain)
    }

    private var textColor: Color {
        if isSelected {
            return .white
        }
        return .primary
    }

    private var cellBackgroundColor: Color {
        if isSelected {
            return Color.accentColor
        }
        if isCurrent {
            return Color.orange.opacity(colorScheme == .dark ? 0.18 : 0.12)
        }
        return Color.primary.opacity(0.05)
    }

    private var cellBorderColor: Color {
        if isSelected {
            return Color.accentColor.opacity(colorScheme == .dark ? 0.5 : 0.3)
        }
        if isCurrent {
            return Color.orange.opacity(colorScheme == .dark ? 0.35 : 0.25)
        }
        return .clear
    }

    private var cellBorderWidth: CGFloat {
        isSelected || isCurrent ? 1 : 0
    }
}
