import Foundation

@MainActor
final class CalendarPopoverViewModel: ObservableObject {
    enum SelectionMode {
        case calendar
        case year
        case month
    }

    @Published private(set) var displayedMonth: Date
    @Published private(set) var selectedDate: Date?
    @Published private(set) var selectedEventIdentifier: String?
    @Published private(set) var selectionMode: SelectionMode = .calendar
    @Published internal(set) var lastClosedTime: Date?

    init(displayedMonth: Date = .now) {
        self.displayedMonth = displayedMonth
    }

    var displayedYear: Int {
        Calendar.current.component(.year, from: displayedMonth)
    }

    var displayedMonthNumber: Int {
        Calendar.current.component(.month, from: displayedMonth)
    }

    var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    var currentMonthNumber: Int {
        Calendar.current.component(.month, from: Date())
    }

    func enterYearSelection() {
        selectionMode = .year
    }

    func enterMonthSelection() {
        selectionMode = .month
    }

    func dismissPicker() {
        selectionMode = .calendar
    }

    func selectYear(_ year: Int, calendar: Calendar) {
        let components = calendar.dateComponents([.month, .day], from: displayedMonth)
        var newComponents = DateComponents()
        newComponents.year = year
        newComponents.month = components.month ?? 1
        newComponents.day = 1
        displayedMonth = calendar.date(from: newComponents) ?? displayedMonth
        selectionMode = .month
    }

    func selectMonth(_ month: Int, calendar: Calendar) {
        let year = calendar.component(.year, from: displayedMonth)
        var newComponents = DateComponents()
        newComponents.year = year
        newComponents.month = month
        newComponents.day = 1
        displayedMonth = calendar.date(from: newComponents) ?? displayedMonth
        selectionMode = .calendar
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

    func popoverDidClose() {
        lastClosedTime = Date()
    }

    func checkAndResetIfNeeded() {
        guard let closedTime = lastClosedTime else { return }
        let interval = Date().timeIntervalSince(closedTime)
        if interval > 300 {
            resetToToday()
            selectDate(Date())
            lastClosedTime = nil
        }
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
