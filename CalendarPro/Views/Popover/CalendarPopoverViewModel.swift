import Foundation

@MainActor
final class CalendarPopoverViewModel: ObservableObject {
    @Published private(set) var displayedMonth: Date

    init(displayedMonth: Date = .now) {
        self.displayedMonth = displayedMonth
    }

    func showPreviousMonth(using calendar: Calendar) {
        displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
    }

    func showNextMonth(using calendar: Calendar) {
        displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
    }

    func resetToToday() {
        displayedMonth = .now
    }

    func weekdaySymbols(using calendar: Calendar) -> [String] {
        let formatter = DateFormatter()
        formatter.locale = calendar.locale ?? .autoupdatingCurrent
        let symbols = formatter.shortStandaloneWeekdaySymbols
            ?? formatter.shortWeekdaySymbols
            ?? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

        let firstWeekdayIndex = max(0, calendar.firstWeekday - 1)
        return Array(symbols[firstWeekdayIndex...] + symbols[..<firstWeekdayIndex])
    }
}
