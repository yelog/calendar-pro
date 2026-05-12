import XCTest
@testable import CalendarPro

@MainActor
final class PomodoroStatsStoreTests: XCTestCase {
    func testRecordsFocusLifecycleEvents() {
        let store = makeStore()

        store.recordFocusStarted()
        store.recordFocusCompleted()
        store.recordFocusSkipped()
        store.recordFocusInterrupted()

        let today = store.summary(forRecentDays: 1)
        XCTAssertEqual(today.focusStartedCount, 1)
        XCTAssertEqual(today.completedFocusCount, 1)
        XCTAssertEqual(today.completedFocusMinutes, 25)
        XCTAssertEqual(today.focusSkippedCount, 1)
        XCTAssertEqual(today.focusInterruptedCount, 1)
    }

    func testPersistsStatsToUserDefaults() {
        let suiteName = "PomodoroStatsStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = PomodoroStatsStore(userDefaults: defaults, now: { Date(timeIntervalSince1970: 0) })
        store.recordFocusStarted()
        store.recordFocusCompleted()

        let reloaded = PomodoroStatsStore(userDefaults: defaults, now: { Date(timeIntervalSince1970: 0) })
        XCTAssertEqual(reloaded.summary(forRecentDays: 1).completedFocusCount, 1)
        XCTAssertEqual(reloaded.summary(forRecentDays: 1).completedFocusMinutes, 25)
    }

    func testRecentDaysIncludesZeroRecordDays() {
        let now = makeDate(year: 2026, month: 5, day: 12)
        let store = makeStore(now: { now })

        store.recordFocusStarted()
        store.recordFocusCompleted()

        let days = store.stats(forRecentDays: 7)
        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(days.last?.focusCompletedCount, 1)
        XCTAssertEqual(days.dropLast().reduce(0) { $0 + $1.focusCompletedCount }, 0)
    }

    func testSummaryCalculatesRatesAndBestDay() {
        let clock = PomodoroTestClock(makeDate(year: 2026, month: 5, day: 11))
        let store = makeStore(now: { clock.value })

        store.recordFocusStarted()
        store.recordFocusCompleted()
        clock.value = makeDate(year: 2026, month: 5, day: 12)
        store.recordFocusStarted()
        store.recordFocusStarted()
        store.recordFocusSkipped()

        let summary = store.summary(forRecentDays: 2)
        XCTAssertEqual(summary.focusStartedCount, 3)
        XCTAssertEqual(summary.completedFocusCount, 1)
        XCTAssertEqual(summary.completedFocusMinutes, 25)
        XCTAssertEqual(summary.averageFocusMinutesPerDay, 12.5, accuracy: 0.01)
        XCTAssertEqual(summary.completionRate, 1.0 / 3.0, accuracy: 0.01)
        XCTAssertEqual(summary.interruptionRate, 1.0 / 3.0, accuracy: 0.01)
        XCTAssertEqual(summary.bestDay?.dayKey, "2026-05-11")
    }

    func testPrunesStatsOlderThanRetentionWindow() {
        let clock = PomodoroTestClock(makeDate(year: 2026, month: 5, day: 12))
        let suiteName = "PomodoroStatsStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let oldStats = PomodoroDailyStats(
            dayKey: "2025-01-01",
            focusStartedCount: 1,
            focusCompletedCount: 1,
            focusSkippedCount: 0,
            focusInterruptedCount: 0,
            completedFocusMinutes: 25
        )
        let recentStats = PomodoroDailyStats(
            dayKey: "2026-05-12",
            focusStartedCount: 1,
            focusCompletedCount: 1,
            focusSkippedCount: 0,
            focusInterruptedCount: 0,
            completedFocusMinutes: 25
        )
        let data = try! JSONEncoder().encode([oldStats, recentStats])
        defaults.set(data, forKey: PomodoroStatsStore.defaultKey)

        let store = PomodoroStatsStore(userDefaults: defaults, now: { clock.value })

        XCTAssertEqual(store.dailyStats.map(\.dayKey), ["2026-05-12"])
    }

    private func makeStore(now: @escaping () -> Date = { makeDate(year: 2026, month: 5, day: 12) }) -> PomodoroStatsStore {
        let suiteName = "PomodoroStatsStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return PomodoroStatsStore(userDefaults: defaults, calendar: .gregorianUTC, now: now)
    }
}

private final class PomodoroTestClock {
    var value: Date

    init(_ value: Date) {
        self.value = value
    }
}

private func makeDate(year: Int, month: Int, day: Int) -> Date {
    Calendar.gregorianUTC.date(from: DateComponents(year: year, month: month, day: day))!
}

private extension Calendar {
    static var gregorianUTC: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
