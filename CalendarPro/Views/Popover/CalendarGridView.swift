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
                .font(.system(size: 13, weight: day.isToday ? .semibold : .regular, design: .rounded))
                .foregroundStyle(solarTextColor)

            let subtitleText: String? = {
                if let badge = day.badges.first, badge.kind == .workingAdjustmentDay {
                    return day.lunarText
                }
                return day.badges.first?.text ?? day.lunarText
            }()
            Text(subtitleText ?? "")
                .font(.system(size: 9, weight: .regular, design: .rounded))
                .foregroundStyle(subtitleColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 34)
        .padding(.vertical, 2)
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
            .font(.system(size: 8, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.96))
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background {
                Capsule()
                    .fill(badgeIndicator.fill)
            }
            .overlay {
                Capsule()
                    .strokeBorder(badgeIndicator.fill.opacity(colorScheme == .dark ? 0.55 : 0.2), lineWidth: 0.5)
            }
            .shadow(color: badgeIndicator.shadow, radius: colorScheme == .dark ? 6 : 0, y: 1)
    }

    private var todayBadgeView: some View {
        Text(L("Today"))
            .font(.system(size: 8, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.96))
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background {
                Capsule()
                    .fill(colorScheme == .dark ? Color(red: 0.9, green: 0.75, blue: 0.25) : Color(red: 0.95, green: 0.6, blue: 0.1))
            }
            .overlay {
                Capsule()
                    .strokeBorder(Color.orange.opacity(colorScheme == .dark ? 0.55 : 0.2), lineWidth: 0.5)
            }
            .shadow(color: Color.orange.opacity(colorScheme == .dark ? 0.28 : 0), radius: colorScheme == .dark ? 6 : 0, y: 1)
    }

    private var cellBackgroundColor: Color {
        if day.isToday {
            return colorScheme == .dark ? Color(red: 0.45, green: 0.35, blue: 0.08) : Color(red: 1.0, green: 0.92, blue: 0.65)
        }

        return semanticStyle?.fill ?? .clear
    }

    private var cellBorderColor: Color {
        if day.isToday {
            return colorScheme == .dark ? Color(red: 0.9, green: 0.75, blue: 0.25).opacity(0.5) : Color(red: 0.85, green: 0.65, blue: 0.15).opacity(0.4)
        }

        if day.isSelected {
            return selectionBorderColor
        }

        if isHovered {
            return selectionBorderColor
        }

        return semanticStyle?.border ?? .clear
    }

    private var cellBorderWidth: CGFloat {
        if day.isSelected || day.isToday || isHovered {
            return 1
        }

        return semanticStyle == nil ? 0 : 1
    }

    private var cellShadowColor: Color {
        return semanticStyle?.shadow ?? .clear
    }

    private var cellShadowRadius: CGFloat {
        return semanticStyle == nil || colorScheme == .light ? 0 : 8
    }

    private var selectionBorderColor: Color {
        colorScheme == .dark
            ? Color(red: 0.9, green: 0.75, blue: 0.25).opacity(0.72)
            : Color(red: 0.9, green: 0.67, blue: 0.12).opacity(0.72)
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
                : Color(red: 0.85, green: 0.35, blue: 0.35)
        }

        if day.isInDisplayedMonth {
            return .primary
        }

        if highlightWeekends && day.isWeekend {
            return colorScheme == .dark
                ? Color(red: 0.92, green: 0.45, blue: 0.45).opacity(0.5)
                : Color(red: 0.85, green: 0.35, blue: 0.35).opacity(0.4)
        }

        if semanticStyle != nil {
            return Color.primary.opacity(colorScheme == .dark ? 0.78 : 0.6)
        }

        return .secondary.opacity(0.5)
    }

    private var subtitleColor: Color {
        if let semanticStyle {
            return day.isInDisplayedMonth ? semanticStyle.subtitle : semanticStyle.subtitle.opacity(colorScheme == .dark ? 0.82 : 0.68)
        }

        if day.lunarTextSemantic == .solarTerm {
            if day.isInDisplayedMonth {
                return colorScheme == .dark
                    ? Color(red: 1.0, green: 0.50, blue: 0.50)
                    : Color.red.opacity(0.82)
            }

            return colorScheme == .dark
                ? Color(red: 1.0, green: 0.50, blue: 0.50).opacity(0.72)
                : Color.red.opacity(0.58)
        }

        guard day.isInDisplayedMonth else {
            return .secondary.opacity(0.45)
        }

        guard let badge = day.badges.first else {
            return .secondary
        }

        switch badge.kind {
        case .festival:
            return .orange
        case .publicHoliday, .statutoryHoliday:
            return .red.opacity(0.8)
        case .workingAdjustmentDay:
            return .blue.opacity(0.8)
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
                fill: colorScheme == .dark ? Color(red: 0.86, green: 0.25, blue: 0.30) : Color.red.opacity(0.88),
                shadow: Color.red.opacity(colorScheme == .dark ? 0.28 : 0)
            )
        case .workingAdjustmentDay:
            guard LocaleFeatureAvailability.showWorkingAdjustmentDay else {
                return nil
            }
            return BadgeIndicator(
                text: L("WRK"),
                fill: colorScheme == .dark ? Color(red: 0.17, green: 0.50, blue: 0.94) : Color.blue.opacity(0.88),
                shadow: Color.blue.opacity(colorScheme == .dark ? 0.26 : 0)
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
                    fill: Color(red: 0.26, green: 0.09, blue: 0.11).opacity(0.72),
                    border: Color(red: 0.98, green: 0.43, blue: 0.43).opacity(0.28),
                    subtitle: Color(red: 1.0, green: 0.73, blue: 0.73),
                    shadow: Color.red.opacity(0.18)
                )
            }

            return SemanticStyle(
                fill: Color.red.opacity(0.08),
                border: Color.red.opacity(0.12),
                subtitle: Color.red.opacity(0.82),
                shadow: .clear
            )
        case .workingAdjustmentDay:
            if colorScheme == .dark {
                return SemanticStyle(
                    fill: Color(red: 0.07, green: 0.18, blue: 0.31).opacity(0.78),
                    border: Color(red: 0.45, green: 0.72, blue: 1.0).opacity(0.28),
                    subtitle: Color(red: 0.70, green: 0.85, blue: 1.0),
                    shadow: Color.blue.opacity(0.18)
                )
            }

            return SemanticStyle(
                fill: Color.blue.opacity(0.08),
                border: Color.blue.opacity(0.12),
                subtitle: Color.blue.opacity(0.82),
                shadow: .clear
            )
        case .festival:
            return nil
        }
    }
}

private struct BadgeIndicator {
    let text: String
    let fill: Color
    let shadow: Color
}

private struct SemanticStyle {
    let fill: Color
    let border: Color
    let subtitle: Color
    let shadow: Color
}
