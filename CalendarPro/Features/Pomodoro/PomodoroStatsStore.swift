import Combine
import Foundation

struct PomodoroDailyStats: Codable, Equatable, Identifiable {
    var dayKey: String
    var focusStartedCount: Int
    var focusCompletedCount: Int
    var focusSkippedCount: Int
    var focusInterruptedCount: Int
    var completedFocusMinutes: Int

    var id: String { dayKey }

    static func empty(dayKey: String) -> PomodoroDailyStats {
        PomodoroDailyStats(
            dayKey: dayKey,
            focusStartedCount: 0,
            focusCompletedCount: 0,
            focusSkippedCount: 0,
            focusInterruptedCount: 0,
            completedFocusMinutes: 0
        )
    }
}

struct PomodoroStatsSummary: Equatable {
    let days: [PomodoroDailyStats]

    var completedFocusCount: Int { days.reduce(0) { $0 + $1.focusCompletedCount } }
    var completedFocusMinutes: Int { days.reduce(0) { $0 + $1.completedFocusMinutes } }
    var focusStartedCount: Int { days.reduce(0) { $0 + $1.focusStartedCount } }
    var focusSkippedCount: Int { days.reduce(0) { $0 + $1.focusSkippedCount } }
    var focusInterruptedCount: Int { days.reduce(0) { $0 + $1.focusInterruptedCount } }

    var averageFocusMinutesPerDay: Double {
        guard !days.isEmpty else { return 0 }
        return Double(completedFocusMinutes) / Double(days.count)
    }

    var completionRate: Double {
        guard focusStartedCount > 0 else { return 0 }
        return Double(completedFocusCount) / Double(focusStartedCount)
    }

    var interruptionRate: Double {
        guard focusStartedCount > 0 else { return 0 }
        return Double(focusSkippedCount + focusInterruptedCount) / Double(focusStartedCount)
    }

    var bestDay: PomodoroDailyStats? {
        days.max { lhs, rhs in
            if lhs.focusCompletedCount == rhs.focusCompletedCount {
                return lhs.completedFocusMinutes < rhs.completedFocusMinutes
            }
            return lhs.focusCompletedCount < rhs.focusCompletedCount
        }
    }
}

@MainActor
final class PomodoroStatsStore: ObservableObject {
    @Published private(set) var dailyStats: [PomodoroDailyStats]

    private let userDefaults: UserDefaults
    private let key: String
    private let calendar: Calendar
    private let now: () -> Date
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    nonisolated static let defaultKey = "pomodoroDailyStats"
    nonisolated static let retentionDays = 180

    init(
        userDefaults: UserDefaults = .standard,
        key: String = PomodoroStatsStore.defaultKey,
        calendar: Calendar = .autoupdatingCurrent,
        now: @escaping () -> Date = Date.init
    ) {
        self.userDefaults = userDefaults
        self.key = key
        self.calendar = calendar
        self.now = now

        if let data = userDefaults.data(forKey: key),
           let decoded = try? decoder.decode([PomodoroDailyStats].self, from: data) {
            dailyStats = decoded.sorted { $0.dayKey < $1.dayKey }
        } else {
            dailyStats = []
        }

        pruneAndPersistIfNeeded()
    }

    func recordFocusStarted() {
        updateToday { $0.focusStartedCount += 1 }
    }

    func recordFocusCompleted(minutes: Int = PomodoroTimerController.focusDuration / 60) {
        updateToday {
            $0.focusCompletedCount += 1
            $0.completedFocusMinutes += minutes
        }
    }

    func recordFocusSkipped() {
        updateToday { $0.focusSkippedCount += 1 }
    }

    func recordFocusInterrupted() {
        updateToday { $0.focusInterruptedCount += 1 }
    }

    func stats(forRecentDays dayCount: Int) -> [PomodoroDailyStats] {
        guard dayCount > 0 else { return [] }
        let start = calendar.startOfDay(for: now())
        return stride(from: dayCount - 1, through: 0, by: -1).map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: start) ?? start
            let key = dayKey(for: date)
            return dailyStats.first { $0.dayKey == key } ?? .empty(dayKey: key)
        }
    }

    func summary(forRecentDays dayCount: Int) -> PomodoroStatsSummary {
        PomodoroStatsSummary(days: stats(forRecentDays: dayCount))
    }

    private func updateToday(_ mutate: (inout PomodoroDailyStats) -> Void) {
        let key = dayKey(for: now())
        var stats = dailyStats
        let index = stats.firstIndex { $0.dayKey == key }

        if let index {
            mutate(&stats[index])
        } else {
            var newStats = PomodoroDailyStats.empty(dayKey: key)
            mutate(&newStats)
            stats.append(newStats)
        }

        dailyStats = stats.sorted { $0.dayKey < $1.dayKey }
        pruneAndPersistIfNeeded()
    }

    private func pruneAndPersistIfNeeded() {
        let cutoffDate = calendar.date(
            byAdding: .day,
            value: -(Self.retentionDays - 1),
            to: calendar.startOfDay(for: now())
        ) ?? now()
        let cutoffKey = dayKey(for: cutoffDate)
        let pruned = dailyStats.filter { $0.dayKey >= cutoffKey }

        if pruned != dailyStats {
            dailyStats = pruned
        }

        persist()
    }

    private func persist() {
        guard let data = try? encoder.encode(dailyStats) else { return }
        userDefaults.set(data, forKey: key)
    }

    private func dayKey(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}
