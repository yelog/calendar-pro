import Foundation

@MainActor
final class CalendarPopoverViewModel: ObservableObject {
    @Published private(set) var displayedMonth: Date
    @Published private(set) var selectedDate: Date?
    @Published private(set) var selectedEventIdentifier: String?

    init(displayedMonth: Date = .now) {
        self.displayedMonth = displayedMonth
    }

    func selectDate(_ date: Date) {
        selectedDate = date
        selectedEventIdentifier = nil
    }

    func clearSelectedDate() {
        selectedDate = nil
        selectedEventIdentifier = nil
    }

    func selectEvent(identifier: String) {
        selectedEventIdentifier = identifier
    }

    func toggleEventSelection(identifier: String) -> Bool {
        if selectedEventIdentifier == identifier {
            selectedEventIdentifier = nil
            return false
        }

        selectedEventIdentifier = identifier
        return true
    }

    func clearSelectedEvent() {
        selectedEventIdentifier = nil
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
