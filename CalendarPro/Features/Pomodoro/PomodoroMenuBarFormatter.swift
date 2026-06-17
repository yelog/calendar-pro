import Foundation

enum PomodoroMenuBarFormatter {
    static func suffix(
        for state: PomodoroTimerController.State,
        preferences: PomodoroPreferences = .default,
        languageCode: String = AppLocalization.languageCode
    ) -> String? {
        guard preferences.isEnabled, state.isActive else { return nil }

        switch preferences.menuBarStyle {
        case .countdown:
            return countdownSuffix(for: state, languageCode: languageCode)
        case .progress:
            return progressSuffix(for: state)
        case .pie:
            return pieSuffix(for: state)
        }
    }

    private static func countdownSuffix(for state: PomodoroTimerController.State, languageCode: String) -> String? {
        let time = timeText(seconds: state.remainingSeconds)
        switch state.phase {
        case .idle:
            return nil
        case .focus:
            return "🍅\(time)"
        case .shortBreak, .longBreak:
            return languageCode == "zh" ? "休\(time)" : "Br \(time)"
        }
    }

    private static func progressSuffix(for state: PomodoroTimerController.State) -> String? {
        guard state.phase != .idle else { return nil }
        let filledCount = min(4, max(0, Int(ceil(state.progress * 4))))
        let emptyCount = max(0, 4 - filledCount)
        let bar = String(repeating: "▰", count: filledCount) + String(repeating: "▱", count: emptyCount)
        let minutes = max(1, Int(ceil(Double(max(0, state.remainingSeconds)) / 60)))
        return "\(phaseSymbol(for: state.phase))\(bar) \(minutes)m"
    }

    private static func pieSuffix(for state: PomodoroTimerController.State) -> String? {
        guard state.phase != .idle else { return nil }
        let minutes = max(1, Int(ceil(Double(max(0, state.remainingSeconds)) / 60)))
        return "● \(minutes)m"
    }

    static func tooltip(for state: PomodoroTimerController.State) -> String? {
        guard state.isActive else { return nil }

        return "\(phaseText(for: state.phase)) · \(timeText(seconds: state.remainingSeconds))"
    }

    static func timeText(seconds: Int) -> String {
        let clamped = max(0, seconds)
        return String(format: "%02d:%02d", clamped / 60, clamped % 60)
    }

    static func phaseText(for phase: PomodoroTimerController.Phase) -> String {
        switch phase {
        case .idle:
            return L("Pomodoro")
        case .focus:
            return L("Focusing")
        case .shortBreak:
            return L("Short Break")
        case .longBreak:
            return L("Long Break")
        }
    }

    private static func phaseSymbol(for phase: PomodoroTimerController.Phase) -> String {
        switch phase {
        case .idle:
            return ""
        case .focus:
            return "🍅"
        case .shortBreak, .longBreak:
            return "休"
        }
    }

}
