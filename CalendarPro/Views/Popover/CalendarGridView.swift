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

            LazyVGrid(columns: gridColumns, spacing: 5) {
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
        Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)
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

            subtitleLine
        }
        .frame(maxWidth: .infinity, minHeight: 36)
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(cellBackgroundColor)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(cellBorderColor, lineWidth: cellBorderWidth)
        }
        .shadow(color: cellShadowColor, radius: cellShadowRadius, y: cellShadowRadius == 0 ? 0 : 1)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 2) {
                if day.isToday {
                    todayBadgeView
                }
                if let indicator = badgeIndicator {
                    badgeView(indicator)
                }
            }
            .offset(x: 3, y: -5)
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(accessibilityLabelText))
        .accessibilityIdentifier(dayIdentifier)
    }

    private var subtitleLine: some View {
        HStack(spacing: supplementalBadgeText == nil ? 0 : 2) {
            Text(day.subtitleText ?? "")
                .font(.system(size: 9, weight: subtitleTextWeight, design: .rounded))
                .foregroundStyle(subtitleColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .layoutPriority(1)

            if let supplementalBadgeText {
                supplementalBadgeView(supplementalBadgeText)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func badgeView(_ badgeIndicator: BadgeIndicator) -> some View {
        Text(badgeIndicator.text)
            .font(.system(size: 7.5, weight: .bold, design: .rounded))
            .foregroundStyle(badgeIndicator.foreground)
            .frame(minWidth: 16, minHeight: 16)
            .background {
                Capsule()
                    .fill(badgeIndicator.fill)
            }
            .overlay {
                Capsule()
                    .strokeBorder(badgeIndicator.border, lineWidth: 0.5)
            }
    }

    private func supplementalBadgeView(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 7.5, weight: .semibold, design: .rounded))
            .foregroundStyle(supplementalBadgeForegroundColor)
            .lineLimit(1)
            .minimumScaleFactor(0.76)
            .padding(.horizontal, 3)
            .frame(height: 11)
            .background {
                Capsule()
                    .fill(supplementalBadgeFillColor)
            }
            .overlay {
                Capsule()
                    .strokeBorder(supplementalBadgeBorderColor, lineWidth: 0.5)
            }
    }

    private var todayBadgeView: some View {
        Text(todayMarkerText)
            .font(.system(size: 7.5, weight: .bold, design: .rounded))
            .foregroundStyle(todayBadgeForegroundColor)
            .frame(minWidth: 16, minHeight: 16)
            .background {
                Capsule()
                    .fill(todayBadgeFillColor)
            }
            .overlay {
                Capsule()
                    .strokeBorder(todayBadgeBorderColor, lineWidth: 0.5)
            }
            .accessibilityLabel(Text(L("Today")))
    }

    private var cellBackgroundColor: Color {
        if day.isSelected {
            return selectedBackgroundColor
        }

        if day.isToday {
            return todayBackgroundColor
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
            return todayBorderColor
        }

        return semanticStyle?.border ?? .clear
    }

    private var cellBorderWidth: CGFloat {
        if day.isSelected {
            return 1.35
        }

        if day.isToday || isHovered || semanticStyle != nil {
            return 1
        }

        return 0
    }

    private var cellShadowColor: Color {
        guard day.isSelected else { return .clear }
        return colorScheme == .dark
            ? selectionBorderColor.opacity(0.16)
            : Color.black.opacity(0.045)
    }

    private var cellShadowRadius: CGFloat {
        day.isSelected ? 4 : 0
    }

    private var selectedBackgroundColor: Color {
        colorScheme == .dark
            ? Color(red: 0.54, green: 0.42, blue: 0.08).opacity(0.68)
            : Color(red: 1.0, green: 0.90, blue: 0.55).opacity(0.88)
    }

    private var todayBackgroundColor: Color {
        colorScheme == .dark
            ? Color(red: 0.48, green: 0.34, blue: 0.06).opacity(0.32)
            : Color(red: 1.0, green: 0.92, blue: 0.62).opacity(0.30)
    }

    private var selectionBorderColor: Color {
        colorScheme == .dark
            ? Color(red: 0.98, green: 0.78, blue: 0.22).opacity(0.82)
            : Color(red: 0.90, green: 0.61, blue: 0.07).opacity(0.86)
    }

    private var todayBorderColor: Color {
        colorScheme == .dark
            ? Color(red: 0.94, green: 0.74, blue: 0.22).opacity(0.58)
            : Color(red: 0.86, green: 0.55, blue: 0.08).opacity(0.48)
    }

    private var todayBadgeFillColor: Color {
        colorScheme == .dark
            ? Color(red: 0.95, green: 0.58, blue: 0.12).opacity(0.92)
            : Color(red: 0.95, green: 0.55, blue: 0.08)
    }

    private var todayBadgeForegroundColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.82) : .white
    }

    private var todayBadgeBorderColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.18)
            : Color(red: 0.72, green: 0.36, blue: 0.03).opacity(0.26)
    }

    private var todayMarkerText: String {
        AppLocalization.languageCode == "zh" ? L("Today") : "T"
    }

    private var solarTextWeight: Font.Weight {
        if day.isSelected || day.isToday || (highlightWeekends && day.isWeekend && day.isInDisplayedMonth) || day.badges.contains(where: { $0.kind != .festival }) {
            return .semibold
        }

        return day.isInDisplayedMonth ? .medium : .regular
    }

    private var supplementalBadgeText: String? {
        CalendarDayDisplayMetadata.supplementalIndicatorText(for: day)
    }

    private var subtitleTextWeight: Font.Weight {
        if day.isSelected || day.isToday || day.badges.contains(where: { $0.kind != .festival }) {
            return .medium
        }

        return .regular
    }

    private var supplementalBadgeForegroundColor: Color {
        let baseColor = colorScheme == .dark
            ? Color(red: 1.0, green: 0.72, blue: 0.42)
            : Color(red: 0.68, green: 0.31, blue: 0.02)
        return day.isInDisplayedMonth ? baseColor : baseColor.opacity(colorScheme == .dark ? 0.62 : 0.52)
    }

    private var supplementalBadgeFillColor: Color {
        let opacity = day.isInDisplayedMonth ? 0.13 : 0.08
        return colorScheme == .dark
            ? Color(red: 1.0, green: 0.58, blue: 0.18).opacity(opacity + 0.04)
            : Color(red: 1.0, green: 0.58, blue: 0.18).opacity(opacity)
    }

    private var supplementalBadgeBorderColor: Color {
        let opacity = day.isInDisplayedMonth ? 0.20 : 0.12
        return colorScheme == .dark
            ? Color(red: 1.0, green: 0.72, blue: 0.42).opacity(opacity)
            : Color(red: 0.82, green: 0.38, blue: 0.04).opacity(opacity)
    }

    private var accessibilityLabelText: String {
        var components = [day.solarText]
        if let subtitleText = day.subtitleText, !subtitleText.isEmpty {
            components.append(subtitleText)
        }
        components.append(contentsOf: day.supplementalBadges.map(\.text))
        if day.isToday {
            components.append(L("Today"))
        }
        if let indicator = badgeIndicator {
            components.append(indicator.text)
        }
        return components.joined(separator: ", ")
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
                foreground: colorScheme == .dark ? Color(red: 1.0, green: 0.78, blue: 0.80) : Color.white,
                fill: colorScheme == .dark ? Color(red: 0.78, green: 0.24, blue: 0.28).opacity(0.78) : Color(red: 0.90, green: 0.20, blue: 0.25),
                border: colorScheme == .dark ? Color(red: 1.0, green: 0.54, blue: 0.58).opacity(0.24) : Color(red: 0.70, green: 0.14, blue: 0.18).opacity(0.22)
            )
        case .workingAdjustmentDay:
            guard LocaleFeatureAvailability.showWorkingAdjustmentDay else {
                return nil
            }
            return BadgeIndicator(
                text: L("WRK"),
                foreground: colorScheme == .dark ? Color(red: 0.76, green: 0.88, blue: 1.0) : Color.white,
                fill: colorScheme == .dark ? Color(red: 0.18, green: 0.50, blue: 0.92).opacity(0.80) : Color(red: 0.20, green: 0.50, blue: 0.92),
                border: colorScheme == .dark ? Color(red: 0.50, green: 0.76, blue: 1.0).opacity(0.24) : Color(red: 0.10, green: 0.34, blue: 0.72).opacity(0.22)
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
                    fill: Color(red: 0.34, green: 0.10, blue: 0.13).opacity(0.46),
                    border: Color(red: 0.98, green: 0.43, blue: 0.43).opacity(0.26),
                    subtitle: Color(red: 1.0, green: 0.68, blue: 0.68)
                )
            }

            return SemanticStyle(
                fill: Color.red.opacity(0.095),
                border: Color.red.opacity(0.18),
                subtitle: Color(red: 0.78, green: 0.18, blue: 0.22)
            )
        case .workingAdjustmentDay:
            if colorScheme == .dark {
                return SemanticStyle(
                    fill: Color(red: 0.07, green: 0.18, blue: 0.31).opacity(0.50),
                    border: Color(red: 0.45, green: 0.72, blue: 1.0).opacity(0.26),
                    subtitle: Color(red: 0.68, green: 0.82, blue: 1.0)
                )
            }

            return SemanticStyle(
                fill: Color.blue.opacity(0.085),
                border: Color.blue.opacity(0.16),
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
