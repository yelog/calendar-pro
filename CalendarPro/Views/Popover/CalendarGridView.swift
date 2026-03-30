import SwiftUI

struct CalendarGridView: View {
    let weekdaySymbols: [String]
    let monthDays: [CalendarDay]
    let onSelectDate: (Date) -> Void

    var body: some View {
        VStack(spacing: 6) {
            LazyVGrid(columns: gridColumns, spacing: 6) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: gridColumns, spacing: 6) {
                ForEach(monthDays) { day in
                    CalendarDayCellView(day: day)
                        .onTapGesture {
                            onSelectDate(day.date)
                        }
                }
            }
        }
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    }
}

private struct CalendarDayCellView: View {
    let day: CalendarDay

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 2) {
                Text(day.solarText)
                    .font(.system(size: 13, weight: day.isToday ? .semibold : .regular, design: .rounded))
                    .foregroundStyle(day.isInDisplayedMonth ? Color.primary : Color.secondary.opacity(0.5))

                Text(day.badges.first?.text ?? day.lunarText ?? "")
                    .font(.system(size: 9, weight: .regular, design: .rounded))
                    .foregroundStyle(subtitleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 34)
            .padding(.vertical, 2)

            if let badge = day.badges.first, badge.kind == .statutoryHoliday || badge.kind == .publicHoliday {
                Text("休")
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(
                        Capsule()
                            .fill(Color.red.opacity(0.85))
                    )
                    .offset(x: 2, y: -2)
            }

            if let badge = day.badges.first, badge.kind == .workingAdjustmentDay {
                Text("班")
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(0.85))
                    )
                    .offset(x: 2, y: -2)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 34)
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(cellBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(dayIdentifier)
    }

    private var cellBackground: some View {
        Group {
            if day.isSelected {
                Color.accentColor.opacity(0.3)
            } else if day.isToday {
                Color.orange.opacity(0.18)
            } else if let badge = day.badges.first {
                switch badge.kind {
                case .statutoryHoliday, .publicHoliday:
                    Color.red.opacity(0.08)
                case .workingAdjustmentDay:
                    Color.blue.opacity(0.08)
                case .festival:
                    Color.clear
                }
            } else {
                Color.clear
            }
        }
    }

    private var dayIdentifier: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return "calendar-day-\(formatter.string(from: day.date))"
    }

    private var subtitleColor: Color {
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
}
