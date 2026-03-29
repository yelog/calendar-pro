import SwiftUI

struct CalendarGridView: View {
    let weekdaySymbols: [String]
    let monthDays: [CalendarDay]

    var body: some View {
        VStack(spacing: 8) {
            LazyVGrid(columns: gridColumns, spacing: 8) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: gridColumns, spacing: 8) {
                ForEach(monthDays) { day in
                    CalendarDayCellView(day: day)
                }
            }
        }
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    }
}

private struct CalendarDayCellView: View {
    let day: CalendarDay

    var body: some View {
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
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(day.isToday ? Color.accentColor.opacity(0.18) : Color.clear)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(dayIdentifier)
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
            return .red
        case .workingAdjustmentDay:
            return .blue
        }
    }
}
