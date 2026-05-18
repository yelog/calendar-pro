import SwiftUI

struct CalendarGridView: View {
    let weekdaySymbols: [String]
    let monthDays: [CalendarDay]
    let highlightWeekends: Bool
    let weekendIndices: Set<Int>
    let onSelectDate: (Date) -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 6) {
            LazyVGrid(columns: gridColumns, spacing: 6) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { index, symbol in
                    Text(symbol)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(weekdayHeaderColor(isWeekend: weekendIndices.contains(index)))
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: gridColumns, spacing: 6) {
                ForEach(monthDays) { day in
                    CalendarDayCellView(day: day, highlightWeekends: highlightWeekends)
                        .onTapGesture {
                            onSelectDate(day.date)
                        }
                }
            }
        }
    }

    private func weekdayHeaderColor(isWeekend: Bool) -> Color {
        guard highlightWeekends && isWeekend else { return .secondary }
        return colorScheme == .dark
            ? Color(red: 0.92, green: 0.45, blue: 0.45)
            : Color(red: 0.85, green: 0.35, blue: 0.35)
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    }
}

private struct CalendarDayCellView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    let day: CalendarDay
    let highlightWeekends: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text(day.solarText)
                .font(.system(size: 13, weight: solarTextWeight, design: .rounded))
                .foregroundStyle(solarTextColor)

            let subtitleText: String? = {
                if let badge = day.badges.first, badge.kind == .workingAdjustmentDay {
                    return day.lunarText
                }
                return day.badges.first?.text ?? day.lunarText
            }()
            Text(subtitleText ?? "")
                .font(.system(size: 9, weight: subtitleTextWeight, design: .rounded))
                .foregroundStyle(subtitleColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 34)
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(cellBackgroundColor)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(cellBorderColor, lineWidth: cellBorderWidth)
        }
        .shadow(color: cellShadowColor, radius: cellShadowRadius, y: cellShadowRadius == 0 ? 0 : 1)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 2) {
                if day.isToday {
                    todayBadgeView
                }
                if let indicator = badgeIndicator {
                    badgeView(indicator)
                }
            }
            .offset(x: 4, y: -4)
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(dayIdentifier)
    }

    private func badgeView(_ badgeIndicator: BadgeIndicator) -> some View {
        Text(badgeIndicator.text)
            .font(.system(size: 7, weight: .semibold, design: .rounded))
            .foregroundStyle(badgeIndicator.foreground)
            .padding(.horizontal, 3)
            .padding(.vertical, 1)
            .background {
                Capsule()
                    .fill(badgeIndicator.fill)
            }
            .overlay {
                Capsule()
                    .strokeBorder(badgeIndicator.border, lineWidth: 0.5)
            }
    }

    private var todayBadgeView: some View {
        Circle()
            .fill(colorScheme == .dark ? Color(red: 0.94, green: 0.74, blue: 0.22) : Color(red: 0.86, green: 0.55, blue: 0.08))
            .frame(width: 6, height: 6)
            .accessibilityLabel(Text(L("Today")))
    }

    private var cellBackgroundColor: Color {
        if day.isSelected {
            return colorScheme == .dark
                ? Color(red: 0.48, green: 0.38, blue: 0.10).opacity(0.54)
                : Color(red: 1.0, green: 0.93, blue: 0.70).opacity(0.62)
        }

        if isHovered {
            return selectionBorderColor.opacity(colorScheme == .dark ? 0.12 : 0.08)
        }

        return semanticStyle?.fill ?? .clear
    }

    private var cellBorderColor: Color {
        if day.isSelected {
            return selectionBorderColor
        }

        if isHovered {
            return selectionBorderColor.opacity(0.72)
        }

        if day.isToday {
            return colorScheme == .dark
                ? Color(red: 0.94, green: 0.74, blue: 0.22).opacity(0.42)
                : Color(red: 0.86, green: 0.55, blue: 0.08).opacity(0.32)
        }

        return semanticStyle?.border ?? .clear
    }

    private var cellBorderWidth: CGFloat {
        if day.isSelected {
            return 1.2
        }

        if day.isToday || isHovered || semanticStyle != nil {
            return 1
        }

        return 0
    }

    private var cellShadowColor: Color {
        day.isSelected && colorScheme == .dark ? selectionBorderColor.opacity(0.14) : .clear
    }

    private var cellShadowRadius: CGFloat {
        day.isSelected && colorScheme == .dark ? 6 : 0
    }

    private var selectionBorderColor: Color {
        colorScheme == .dark
            ? Color(red: 0.9, green: 0.75, blue: 0.25).opacity(0.72)
            : Color(red: 0.9, green: 0.67, blue: 0.12).opacity(0.72)
    }

    private var solarTextWeight: Font.Weight {
        if day.isSelected || day.isToday || (highlightWeekends && day.isWeekend && day.isInDisplayedMonth) || day.badges.contains(where: { $0.kind != .festival }) {
            return .semibold
        }

        return day.isInDisplayedMonth ? .medium : .regular
    }

    private var subtitleTextWeight: Font.Weight {
        if day.isSelected || day.isToday || day.badges.contains(where: { $0.kind != .festival }) {
            return .medium
        }

        return .regular
    }

    private var dayIdentifier: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return "calendar-day-\(formatter.string(from: day.date))"
    }

    private var solarTextColor: Color {
        if highlightWeekends && day.isWeekend && day.isInDisplayedMonth {
            return colorScheme == .dark
                ? Color(red: 0.92, green: 0.45, blue: 0.45)
                : Color(red: 0.76, green: 0.20, blue: 0.24)
        }

        if day.isInDisplayedMonth {
            return .primary
        }

        if highlightWeekends && day.isWeekend {
            return colorScheme == .dark
                ? Color(red: 0.92, green: 0.45, blue: 0.45).opacity(0.58)
                : Color(red: 0.76, green: 0.20, blue: 0.24).opacity(0.62)
        }

        if semanticStyle != nil {
            return Color.primary.opacity(colorScheme == .dark ? 0.78 : 0.66)
        }

        return .secondary.opacity(colorScheme == .dark ? 0.5 : 0.62)
    }

    private var subtitleColor: Color {
        if let semanticStyle {
            return day.isInDisplayedMonth ? semanticStyle.subtitle : semanticStyle.subtitle.opacity(colorScheme == .dark ? 0.82 : 0.56)
        }

        if day.lunarTextSemantic == .solarTerm {
            if day.isInDisplayedMonth {
                return colorScheme == .dark
                    ? Color(red: 1.0, green: 0.50, blue: 0.50)
                    : Color(red: 0.78, green: 0.18, blue: 0.22)
            }

            return colorScheme == .dark
                ? Color(red: 1.0, green: 0.50, blue: 0.50).opacity(0.72)
                : Color(red: 0.78, green: 0.18, blue: 0.22).opacity(0.56)
        }

        guard day.isInDisplayedMonth else {
            return .secondary.opacity(colorScheme == .dark ? 0.45 : 0.54)
        }

        guard let badge = day.badges.first else {
            return Color(nsColor: .secondaryLabelColor)
        }

        switch badge.kind {
        case .festival:
            return colorScheme == .dark ? .orange : Color(red: 0.78, green: 0.36, blue: 0.04)
        case .publicHoliday, .statutoryHoliday:
            return colorScheme == .dark ? .red.opacity(0.8) : Color(red: 0.78, green: 0.18, blue: 0.22)
        case .workingAdjustmentDay:
            return colorScheme == .dark ? .blue.opacity(0.8) : Color(red: 0.12, green: 0.36, blue: 0.68)
        }
    }

    private var badgeIndicator: BadgeIndicator? {
        guard let badge = day.badges.first else {
            return nil
        }

        switch badge.kind {
        case .publicHoliday, .statutoryHoliday:
            return BadgeIndicator(
                text: L("OFF"),
                foreground: colorScheme == .dark ? Color(red: 1.0, green: 0.74, blue: 0.76) : Color(red: 0.72, green: 0.16, blue: 0.20),
                fill: colorScheme == .dark ? Color(red: 0.64, green: 0.18, blue: 0.22).opacity(0.32) : Color.red.opacity(0.10),
                border: colorScheme == .dark ? Color(red: 1.0, green: 0.48, blue: 0.52).opacity(0.28) : Color.red.opacity(0.18)
            )
        case .workingAdjustmentDay:
            guard LocaleFeatureAvailability.showWorkingAdjustmentDay else {
                return nil
            }
            return BadgeIndicator(
                text: L("WRK"),
                foreground: colorScheme == .dark ? Color(red: 0.70, green: 0.84, blue: 1.0) : Color(red: 0.12, green: 0.36, blue: 0.68),
                fill: colorScheme == .dark ? Color(red: 0.17, green: 0.48, blue: 0.86).opacity(0.30) : Color.blue.opacity(0.10),
                border: colorScheme == .dark ? Color(red: 0.45, green: 0.72, blue: 1.0).opacity(0.28) : Color.blue.opacity(0.18)
            )
        case .festival:
            return nil
        }
    }

    private var semanticStyle: SemanticStyle? {
        guard let badge = day.badges.first else {
            return nil
        }

        switch badge.kind {
        case .publicHoliday, .statutoryHoliday:
            if colorScheme == .dark {
                return SemanticStyle(
                    fill: Color(red: 0.30, green: 0.10, blue: 0.12).opacity(0.36),
                    border: Color(red: 0.98, green: 0.43, blue: 0.43).opacity(0.18),
                    subtitle: Color(red: 1.0, green: 0.68, blue: 0.68)
                )
            }

            return SemanticStyle(
                fill: Color.red.opacity(0.045),
                border: Color.red.opacity(0.09),
                subtitle: Color(red: 0.78, green: 0.18, blue: 0.22)
            )
        case .workingAdjustmentDay:
            if colorScheme == .dark {
                return SemanticStyle(
                    fill: Color(red: 0.07, green: 0.18, blue: 0.31).opacity(0.42),
                    border: Color(red: 0.45, green: 0.72, blue: 1.0).opacity(0.18),
                    subtitle: Color(red: 0.68, green: 0.82, blue: 1.0)
                )
            }

            return SemanticStyle(
                fill: Color.blue.opacity(0.045),
                border: Color.blue.opacity(0.09),
                subtitle: Color(red: 0.12, green: 0.36, blue: 0.68)
            )
        case .festival:
            return nil
        }
    }
}

private struct BadgeIndicator {
    let text: String
    let foreground: Color
    let fill: Color
    let border: Color
}

private struct SemanticStyle {
    let fill: Color
    let border: Color
    let subtitle: Color
}
