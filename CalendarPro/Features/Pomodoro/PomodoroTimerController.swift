import Combine
import Foundation

@MainActor
final class PomodoroTimerController: ObservableObject {
    enum Phase: Equatable {
        case idle
        case focus
        case shortBreak
        case longBreak
    }

    struct State: Equatable {
        var phase: Phase
        var remainingSeconds: Int
        var totalSeconds: Int
        var completedFocusCount: Int
        var isPaused: Bool

        var isActive: Bool {
            phase != .idle
        }

        var progress: Double {
            guard totalSeconds > 0 else { return 0 }
            let elapsed = max(0, totalSeconds - remainingSeconds)
            return min(1, Double(elapsed) / Double(totalSeconds))
        }

        static let idle = State(
            phase: .idle,
            remainingSeconds: 0,
            totalSeconds: 0,
            completedFocusCount: 0,
            isPaused: false
        )
    }

    nonisolated static let focusDuration = 25 * 60
    nonisolated static let shortBreakDuration = 5 * 60
    nonisolated static let longBreakDuration = 15 * 60
    nonisolated static let focusesBeforeLongBreak = 4

    @Published private(set) var state: State = .idle

    private enum TransitionReason {
        case naturalCompletion
        case skip
    }

    private let now: () -> Date
    private let startsTimer: Bool
    private let statsStore: PomodoroStatsStore?
    private let reminderService: PomodoroReminderServicing?
    private let reminderPreferences: () -> PomodoroReminderPreferences
    private var endDate: Date?
    private var timerCancellable: AnyCancellable?

    init(
        now: @escaping () -> Date = Date.init,
        startsTimer: Bool = true,
        statsStore: PomodoroStatsStore? = nil,
        reminderService: PomodoroReminderServicing? = nil,
        reminderPreferences: @escaping () -> PomodoroReminderPreferences = { .default }
    ) {
        self.now = now
        self.startsTimer = startsTimer
        self.statsStore = statsStore
        self.reminderService = reminderService
        self.reminderPreferences = reminderPreferences
    }

    func startFocus() {
        begin(.focus, duration: Self.focusDuration, completedFocusCount: state.completedFocusCount)
    }

    func pause() {
        guard state.isActive, !state.isPaused else { return }
        refresh(advancesStage: false)
        state.isPaused = true
        endDate = nil
        stopTimerIfNeeded()
    }

    func resume() {
        guard state.isActive, state.isPaused else { return }
        endDate = now().addingTimeInterval(TimeInterval(state.remainingSeconds))
        state.isPaused = false
        startTimerIfNeeded()
    }

    func skip() {
        guard state.isActive else { return }
        advanceFromCurrentPhase(reason: .skip)
    }

    func end() {
        if state.phase == .focus {
            statsStore?.recordFocusInterrupted()
        }
        state = .idle
        endDate = nil
        stopTimerIfNeeded()
    }

    func refresh() {
        refresh(advancesStage: true)
    }

    private func refresh(advancesStage: Bool) {
        guard state.isActive, !state.isPaused, let endDate else { return }
        let remaining = Int(ceil(endDate.timeIntervalSince(now())))

        if remaining > 0 {
            state.remainingSeconds = min(remaining, state.totalSeconds)
            return
        }

        state.remainingSeconds = 0
        if advancesStage {
            advanceFromCurrentPhase(reason: .naturalCompletion)
        }
    }

    private func advanceFromCurrentPhase(reason: TransitionReason) {
        switch state.phase {
        case .idle:
            end()
        case .focus:
            switch reason {
            case .naturalCompletion:
                statsStore?.recordFocusCompleted()
            case .skip:
                statsStore?.recordFocusSkipped()
            }

            let completed = state.completedFocusCount + 1
            if completed >= Self.focusesBeforeLongBreak {
                begin(.longBreak, duration: Self.longBreakDuration, completedFocusCount: 0)
                sendReminderIfNeeded(.focusCompleted(nextPhase: .longBreak), reason: reason)
            } else {
                begin(.shortBreak, duration: Self.shortBreakDuration, completedFocusCount: completed)
                sendReminderIfNeeded(.focusCompleted(nextPhase: .shortBreak), reason: reason)
            }
        case .shortBreak, .longBreak:
            begin(.focus, duration: Self.focusDuration, completedFocusCount: state.completedFocusCount)
            sendReminderIfNeeded(.breakCompleted, reason: reason)
        }
    }

    private func sendReminderIfNeeded(_ kind: PomodoroReminderKind, reason: TransitionReason) {
        guard reason == .naturalCompletion, let reminderService else { return }
        let preferences = reminderPreferences()
        Task { @MainActor in
            await reminderService.sendReminder(kind, preferences: preferences)
        }
    }

    private func begin(_ phase: Phase, duration: Int, completedFocusCount: Int) {
        state = State(
            phase: phase,
            remainingSeconds: duration,
            totalSeconds: duration,
            completedFocusCount: completedFocusCount,
            isPaused: false
        )
        if phase == .focus {
            statsStore?.recordFocusStarted()
        }
        endDate = now().addingTimeInterval(TimeInterval(duration))
        startTimerIfNeeded()
    }

    private func startTimerIfNeeded() {
        guard startsTimer else { return }
        guard timerCancellable == nil else { return }

        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.refresh()
                }
            }
    }

    private func stopTimerIfNeeded() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }
}
