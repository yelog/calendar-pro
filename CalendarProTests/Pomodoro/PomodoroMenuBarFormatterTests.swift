import XCTest
@testable import CalendarPro

final class PomodoroMenuBarFormatterTests: XCTestCase {
    func testIdleStateHasNoSuffixOrTooltip() {
        XCTAssertNil(PomodoroMenuBarFormatter.suffix(for: .idle))
        XCTAssertNil(PomodoroMenuBarFormatter.tooltip(for: .idle))
    }

    func testDisabledPreferencesReturnNoSuffix() {
        let state = makeState(phase: .focus, remainingSeconds: 90)
        let preferences = PomodoroPreferences(isEnabled: false, menuBarStyle: .countdown, reminders: .default)

        XCTAssertNil(PomodoroMenuBarFormatter.suffix(for: state, preferences: preferences))
    }

    func testFocusStateReturnsTomatoCountdownSuffix() {
        let state = makeState(phase: .focus, remainingSeconds: 18 * 60 + 42)

        XCTAssertEqual(PomodoroMenuBarFormatter.suffix(for: state), "🍅18:42")
    }

    func testBreakStateReturnsLocalizedChineseSuffix() {
        let state = makeState(phase: .shortBreak, remainingSeconds: 4 * 60 + 31)

        XCTAssertEqual(PomodoroMenuBarFormatter.suffix(for: state, languageCode: "zh"), "休04:31")
    }

    func testBreakStateReturnsEnglishSuffix() {
        let state = makeState(phase: .longBreak, remainingSeconds: 14 * 60 + 3)

        XCTAssertEqual(PomodoroMenuBarFormatter.suffix(for: state, languageCode: "en"), "Br 14:03")
    }

    func testProgressStyleReturnsProgressBarSuffix() {
        let state = makeState(
            phase: .focus,
            remainingSeconds: PomodoroTimerController.focusDuration / 2,
            totalSeconds: PomodoroTimerController.focusDuration
        )
        let preferences = PomodoroPreferences(isEnabled: true, menuBarStyle: .progress, reminders: .default)

        XCTAssertEqual(PomodoroMenuBarFormatter.suffix(for: state, preferences: preferences), "🍅▰▰▱▱ 13m")
    }

    func testPieStyleReturnsPieSuffix() {
        let state = makeState(
            phase: .shortBreak,
            remainingSeconds: PomodoroTimerController.shortBreakDuration / 2,
            totalSeconds: PomodoroTimerController.shortBreakDuration
        )
        let preferences = PomodoroPreferences(isEnabled: true, menuBarStyle: .pie, reminders: .default)

        XCTAssertEqual(PomodoroMenuBarFormatter.suffix(for: state, preferences: preferences), "◕ 3m")
    }

    func testTooltipIncludesPhaseAndRemainingTime() {
        let state = makeState(phase: .focus, remainingSeconds: 90)

        XCTAssertEqual(PomodoroMenuBarFormatter.tooltip(for: state), "专注中 · 01:30")
    }

    private func makeState(
        phase: PomodoroTimerController.Phase,
        remainingSeconds: Int,
        totalSeconds: Int = PomodoroTimerController.focusDuration
    ) -> PomodoroTimerController.State {
        PomodoroTimerController.State(
            phase: phase,
            remainingSeconds: remainingSeconds,
            totalSeconds: totalSeconds,
            completedFocusCount: 0,
            isPaused: false
        )
    }
}
