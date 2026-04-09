import SwiftUI

struct MonthPickerView: View {
    let displayedYear: Int
    let displayedMonth: Int
    let currentMonth: Int
    let onSelectMonth: (Int) -> Void
    let onDismiss: () -> Void
    let onEnterYearSelection: () -> Void

    private let months: [String] = {
        let formatter = DateFormatter()
        formatter.locale = AppLocalization.locale
        return formatter.monthSymbols
    }()

    var body: some View {
        VStack(spacing: 12) {
            headerBar
            monthGrid
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

            Button(action: onEnterYearSelection) {
                Text(yearDisplayText)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
            }
            .buttonStyle(.plain)

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

    private var yearDisplayText: String {
        let formatter = DateFormatter()
        formatter.locale = AppLocalization.locale
        formatter.setLocalizedDateFormatFromTemplate("y")
        var components = DateComponents()
        components.year = displayedYear
        if let date = Calendar(identifier: .gregorian).date(from: components) {
            return formatter.string(from: date)
        }
        return "\(displayedYear)"
    }

    private var monthGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: 8) {
            ForEach(1...12, id: \.self) { month in
                MonthCellView(
                    month: month,
                    monthName: months[month - 1],
                    isSelected: month == displayedMonth,
                    isCurrent: month == currentMonth,
                    onSelect: { onSelectMonth(month) }
                )
            }
        }
        .padding(.horizontal, 4)
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
    }
}

private struct MonthCellView: View {
    @Environment(\.colorScheme) private var colorScheme

    let month: Int
    let monthName: String
    let isSelected: Bool
    let isCurrent: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            Text(monthName)
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
