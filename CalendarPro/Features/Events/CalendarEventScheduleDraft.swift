import Foundation

enum CalendarEventScheduleError: Error, Equatable, LocalizedError {
    case invalidAllDayRange
    case endMustBeAfterStart
    case localTimeDoesNotExist
    case unableToCalculateDates

    var errorDescription: String? {
        switch self {
        case .invalidAllDayRange:
            return L("All-Day End Before Start")
        case .endMustBeAfterStart:
            return L("Event End Must Be After Start")
        case .localTimeDoesNotExist:
            return L("Event Local Time Does Not Exist")
        case .unableToCalculateDates:
            return L("Unable to Calculate Event Dates")
        }
    }
}

struct CalendarEventScheduleDraft: Equatable {
    private struct TimedRange: Equatable {
        let startDate: Date
        let endDate: Date
    }

    private(set) var startDate: Date
    private(set) var endDate: Date
    private(set) var isAllDay: Bool
    let calendar: Calendar

    private var timedRangeBeforeAllDay: TimedRange?
    private(set) var inputError: CalendarEventScheduleError?

    init(startDate: Date, endDate: Date, isAllDay: Bool, calendar: Calendar = .current) {
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.calendar = calendar
        self.timedRangeBeforeAllDay = nil
        self.inputError = nil
    }

    var validationError: CalendarEventScheduleError? {
        guard endDate > startDate else {
            return isAllDay ? .invalidAllDayRange : .endMustBeAfterStart
        }
        return nil
    }

    mutating func setInputError(_ error: CalendarEventScheduleError?) {
        inputError = error
    }

    var displayedEndDate: Date? {
        Self.displayedEndDate(startDate: startDate, endDate: endDate, isAllDay: isAllDay, calendar: calendar)
    }

    static func displayedEndDate(
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        calendar: Calendar
    ) -> Date? {
        guard isAllDay else {
            return endDate > startDate ? endDate : nil
        }

        let endDay = calendar.startOfDay(for: endDate)
        if endDate == endDay {
            return calendar.date(byAdding: .day, value: -1, to: endDay)
        }
        return endDay
    }

    static func endDate(forDisplayedEndDate selectedEndDay: Date, isAllDay: Bool, calendar: Calendar) -> Date? {
        guard isAllDay else { return selectedEndDay }
        return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: selectedEndDay))
    }

    static func coveredDayCount(
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        calendar: Calendar
    ) -> Int? {
        guard isAllDay,
              let displayedEndDate = displayedEndDate(
                startDate: startDate,
                endDate: endDate,
                isAllDay: true,
                calendar: calendar
              ),
              let dayDifference = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: startDate),
                to: calendar.startOfDay(for: displayedEndDate)
              ).day,
              dayDifference >= 0 else {
            return nil
        }
        return dayDifference + 1
    }

    var coveredDayCount: Int? {
        Self.coveredDayCount(startDate: startDate, endDate: endDate, isAllDay: isAllDay, calendar: calendar)
    }

    mutating func setStartDay(_ selectedDay: Date) throws {
        let newStartDay = calendar.startOfDay(for: selectedDay)
        let oldStartDay = calendar.startOfDay(for: startDate)
        guard !calendar.isDate(newStartDay, inSameDayAs: oldStartDay) else {
            inputError = nil
            return
        }

        if isAllDay {
            guard let coveredDayCount else {
                startDate = newStartDay
                timedRangeBeforeAllDay = nil
                inputError = nil
                return
            }

            guard let newEndDate = calendar.date(byAdding: .day, value: coveredDayCount, to: newStartDay) else {
                throw CalendarEventScheduleError.unableToCalculateDates
            }

            startDate = newStartDay
            endDate = newEndDate
            timedRangeBeforeAllDay = nil
            inputError = nil
            return
        }

        guard let dayDifference = calendar.dateComponents([.day], from: oldStartDay, to: newStartDay).day else {
            throw CalendarEventScheduleError.unableToCalculateDates
        }

        guard validationError == nil else {
            let components = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: startDate)
            guard let correctedStart = strictDate(
                on: newStartDay,
                hour: components.hour ?? 0,
                minute: components.minute ?? 0,
                second: components.second ?? 0,
                nanosecond: components.nanosecond ?? 0
            ) else {
                throw CalendarEventScheduleError.localTimeDoesNotExist
            }
            startDate = correctedStart
            inputError = nil
            return
        }

        let startComponents = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: startDate)
        let endComponents = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: endDate)
        guard let newStartDate = strictDate(
            on: newStartDay,
            hour: startComponents.hour ?? 0,
            minute: startComponents.minute ?? 0,
            second: startComponents.second ?? 0,
            nanosecond: startComponents.nanosecond ?? 0
        ),
        let shiftedEndDay = calendar.date(byAdding: .day, value: dayDifference, to: calendar.startOfDay(for: endDate)),
        let newEndDate = strictDate(
            on: shiftedEndDay,
            hour: endComponents.hour ?? 0,
            minute: endComponents.minute ?? 0,
            second: endComponents.second ?? 0,
            nanosecond: endComponents.nanosecond ?? 0
        ) else {
            throw CalendarEventScheduleError.localTimeDoesNotExist
        }

        guard newEndDate > newStartDate else {
            throw CalendarEventScheduleError.endMustBeAfterStart
        }

        startDate = newStartDate
        endDate = newEndDate
        inputError = nil
    }

    mutating func setEndDay(_ selectedDay: Date) throws {
        let selectedDayStart = calendar.startOfDay(for: selectedDay)
        let currentEndDay = isAllDay ? displayedEndDate : endDate
        if let currentEndDay, calendar.isDate(selectedDayStart, inSameDayAs: currentEndDay) {
            inputError = nil
            return
        }

        if isAllDay {
            guard let newEndDate = Self.endDate(forDisplayedEndDate: selectedDayStart, isAllDay: true, calendar: calendar) else {
                throw CalendarEventScheduleError.unableToCalculateDates
            }
            endDate = newEndDate
            timedRangeBeforeAllDay = nil
            inputError = nil
            return
        }

        let components = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: endDate)
        guard let newEndDate = strictDate(
            on: selectedDayStart,
            hour: components.hour ?? 0,
            minute: components.minute ?? 0,
            second: components.second ?? 0,
            nanosecond: components.nanosecond ?? 0
        ) else {
            throw CalendarEventScheduleError.localTimeDoesNotExist
        }
        endDate = newEndDate
        inputError = nil
    }

    mutating func setStartTime(hour: Int, minute: Int) throws {
        guard (0...23).contains(hour), (0...59).contains(minute) else {
            throw CalendarEventScheduleError.localTimeDoesNotExist
        }

        let currentHour = calendar.component(.hour, from: startDate)
        let currentMinute = calendar.component(.minute, from: startDate)
        guard hour != currentHour || minute != currentMinute else {
            inputError = nil
            return
        }

        let duration = endDate.timeIntervalSince(startDate)
        guard let newStartDate = strictDate(
            on: calendar.startOfDay(for: startDate),
            hour: hour,
            minute: minute,
            second: 0,
            nanosecond: 0
        ) else {
            throw CalendarEventScheduleError.localTimeDoesNotExist
        }

        let newEndDate = duration > 0 ? newStartDate.addingTimeInterval(duration) : endDate
        guard duration <= 0 || newEndDate > newStartDate else {
            throw CalendarEventScheduleError.endMustBeAfterStart
        }
        startDate = newStartDate
        endDate = newEndDate
        if let timedRangeBeforeAllDay,
           calendar.isDate(newStartDate, inSameDayAs: timedRangeBeforeAllDay.startDate),
           newEndDate == timedRangeBeforeAllDay.endDate {
            self.timedRangeBeforeAllDay = TimedRange(startDate: newStartDate, endDate: newEndDate)
        } else {
            timedRangeBeforeAllDay = nil
        }
        inputError = nil
    }

    mutating func setEndDate(_ selectedDate: Date) {
        endDate = selectedDate
        inputError = nil
    }

    mutating func setEndTime(hour: Int, minute: Int) throws {
        guard (0...23).contains(hour), (0...59).contains(minute) else {
            throw CalendarEventScheduleError.localTimeDoesNotExist
        }

        let currentHour = calendar.component(.hour, from: endDate)
        let currentMinute = calendar.component(.minute, from: endDate)
        guard hour != currentHour || minute != currentMinute else {
            inputError = nil
            return
        }

        guard let newEndDate = strictDate(
            on: calendar.startOfDay(for: endDate),
            hour: hour,
            minute: minute,
            second: 0,
            nanosecond: 0
        ) else {
            throw CalendarEventScheduleError.localTimeDoesNotExist
        }

        endDate = newEndDate
        inputError = nil
    }

    mutating func setAllDay(_ newValue: Bool) throws {
        guard newValue != isAllDay else { return }

        let lastCoveredDay: Date?
        if isAllDay {
            lastCoveredDay = displayedEndDate
        } else {
            let endDay = calendar.startOfDay(for: endDate)
            if endDate == endDay {
                lastCoveredDay = calendar.date(byAdding: .day, value: -1, to: endDay)
            } else {
                lastCoveredDay = endDay
            }
        }

        guard validationError == nil,
              let lastCoveredDay,
              let lastDayEnd = calendar.date(
                byAdding: .day,
                value: 1,
                to: calendar.startOfDay(for: lastCoveredDay)
              ) else {
            throw validationError ?? CalendarEventScheduleError.unableToCalculateDates
        }

        if newValue {
            let timedRange = TimedRange(startDate: startDate, endDate: endDate)
            startDate = calendar.startOfDay(for: startDate)
            endDate = lastDayEnd
            isAllDay = true
            timedRangeBeforeAllDay = timedRange
            inputError = nil
            return
        }

        let allDayStart = startDate
        if let timedRangeBeforeAllDay {
            startDate = timedRangeBeforeAllDay.startDate
            endDate = timedRangeBeforeAllDay.endDate
        } else {
            let firstDay = calendar.startOfDay(for: allDayStart)
            let defaultEndDay = lastCoveredDay
            guard let defaultStart = strictDate(on: firstDay, hour: 9, minute: 0, second: 0, nanosecond: 0),
                  let defaultEnd = strictDate(on: defaultEndDay, hour: 10, minute: 0, second: 0, nanosecond: 0) else {
                throw CalendarEventScheduleError.localTimeDoesNotExist
            }
            startDate = defaultStart
            endDate = defaultEnd
        }

        isAllDay = false
        timedRangeBeforeAllDay = nil
        inputError = nil
    }

    private func strictDate(
        on day: Date,
        hour: Int,
        minute: Int,
        second: Int,
        nanosecond: Int
    ) -> Date? {
        let dayStart = calendar.startOfDay(for: day)
        let dayComponents = calendar.dateComponents([.era, .year, .month, .day], from: dayStart)
        guard let precedingDay = calendar.date(byAdding: .day, value: -1, to: dayStart),
              let precedingInstant = calendar.date(byAdding: .second, value: 1, to: precedingDay) else { return nil }

        var matchingComponents = dayComponents
        matchingComponents.calendar = calendar
        matchingComponents.timeZone = calendar.timeZone
        matchingComponents.hour = hour
        matchingComponents.minute = minute
        matchingComponents.second = second
        matchingComponents.nanosecond = nanosecond

        guard let result = calendar.nextDate(
            after: precedingInstant,
            matching: matchingComponents,
            matchingPolicy: .strict,
            repeatedTimePolicy: .first,
            direction: .forward
        ) else {
            return nil
        }

        let resultComponents = calendar.dateComponents(
            [.era, .year, .month, .day, .hour, .minute, .second, .nanosecond],
            from: result
        )
        guard resultComponents.era == matchingComponents.era,
              resultComponents.year == matchingComponents.year,
              resultComponents.month == matchingComponents.month,
              resultComponents.day == matchingComponents.day,
              resultComponents.hour == hour,
              resultComponents.minute == minute,
              resultComponents.second == second,
              resultComponents.nanosecond == nanosecond else {
            return nil
        }

        return result
    }
}
