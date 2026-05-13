import XCTest
@testable import CalendarPro

@MainActor
final class PomodoroTimerControllerTests: XCTestCase {
    func testInitialStateIsIdle() {
        let controller = makeController()

        XCTAssertEqual(controller.state, .idle)
    }

    func testStartFocusCreatesTwentyFiveMinuteSession() {
        let controller = makeController()

        controller.startFocus()

        XCTAssertEqual(controller.state.phase, .focus)
        XCTAssertEqual(controller.state.remainingSeconds, 25 * 60)
        XCTAssertEqual(controller.state.totalSeconds, 25 * 60)
        XCTAssertEqual(controller.state.completedFocusCount, 0)
        XCTAssertFalse(controller.state.isPaused)
    }

    func testStartFocusRecordsStatsStarted() {
        let statsStore = makeStatsStore()
        let controller = makeController(statsStore: statsStore)

        controller.startFocus()

        XCTAssertEqual(statsStore.summary(forRecentDays: 1).focusStartedCount, 1)
    }

    func testCompletingEarlyFocusRoundStartsShortBreak() {
        let clock = PomodoroTimerTestClock(Date(timeIntervalSince1970: 0))
        let controller = makeController(now: { clock.value })

        controller.startFocus()
        clock.value = clock.value.addingTimeInterval(TimeInterval(PomodoroTimerController.focusDuration))
        controller.refresh()

        XCTAssertEqual(controller.state.phase, .shortBreak)
        XCTAssertEqual(controller.state.remainingSeconds, PomodoroTimerController.shortBreakDuration)
        XCTAssertEqual(controller.state.completedFocusCount, 1)
    }

    func testNaturalFocusCompletionRecordsCompletedStats() {
        let clock = PomodoroTimerTestClock(Date(timeIntervalSince1970: 0))
        let statsStore = makeStatsStore(now: { clock.value })
        let controller = makeController(now: { clock.value }, statsStore: statsStore)

        controller.startFocus()
        clock.value = clock.value.addingTimeInterval(TimeInterval(PomodoroTimerController.focusDuration))
        controller.refresh()

        XCTAssertEqual(statsStore.summary(forRecentDays: 1).completedFocusCount, 1)
        XCTAssertEqual(statsStore.summary(forRecentDays: 1).completedFocusMinutes, 25)
    }

    func testNaturalFocusCompletionSendsReminder() async {
        let clock = PomodoroTimerTestClock(Date(timeIntervalSince1970: 0))
        let reminderService = SpyPomodoroReminderService()
        let controller = makeController(now: { clock.value }, reminderService: reminderService)

        controller.startFocus()
        clock.value = clock.value.addingTimeInterval(TimeInterval(PomodoroTimerController.focusDuration))
        controller.refresh()
        await Task.yield()

        XCTAssertEqual(reminderService.sentReminders.map(\.kind), [.focusCompleted(nextPhase: .shortBreak)])
        XCTAssertEqual(reminderService.sentReminders.first?.preferences, .default)
    }

    func testFourthFocusRoundStartsLongBreakAndResetsRoundCycle() {
        let clock = PomodoroTimerTestClock(Date(timeIntervalSince1970: 0))
        let controller = makeController(now: { clock.value })

        for _ in 0..<3 {
            controller.startFocus()
            clock.value = clock.value.addingTimeInterval(TimeInterval(PomodoroTimerController.focusDuration))
            controller.refresh()
        }

        controller.startFocus()
        clock.value = clock.value.addingTimeInterval(TimeInterval(PomodoroTimerController.focusDuration))
        controller.refresh()

        XCTAssertEqual(controller.state.phase, .longBreak)
        XCTAssertEqual(controller.state.remainingSeconds, PomodoroTimerController.longBreakDuration)
        XCTAssertEqual(controller.state.completedFocusCount, 0)
    }

    func testCompletingBreakStartsNextFocus() {
        let clock = PomodoroTimerTestClock(Date(timeIntervalSince1970: 0))
        let controller = makeController(now: { clock.value })

        controller.startFocus()
        clock.value = clock.value.addingTimeInterval(TimeInterval(PomodoroTimerController.focusDuration))
        controller.refresh()
        clock.value = clock.value.addingTimeInterval(TimeInterval(PomodoroTimerController.shortBreakDuration))
        controller.refresh()

        XCTAssertEqual(controller.state.phase, .focus)
        XCTAssertEqual(controller.state.remainingSeconds, PomodoroTimerController.focusDuration)
        XCTAssertEqual(controller.state.completedFocusCount, 1)
    }

    func testNaturalBreakCompletionSendsReminder() async {
        let clock = PomodoroTimerTestClock(Date(timeIntervalSince1970: 0))
        let reminderService = SpyPomodoroReminderService()
        let controller = makeController(now: { clock.value }, reminderService: reminderService)

        controller.startFocus()
        clock.value = clock.value.addingTimeInterval(TimeInterval(PomodoroTimerController.focusDuration))
        controller.refresh()
        clock.value = clock.value.addingTimeInterval(TimeInterval(PomodoroTimerController.shortBreakDuration))
        controller.refresh()
        await Task.yield()

        XCTAssertEqual(
            reminderService.sentReminders.map(\.kind),
            [.focusCompleted(nextPhase: .shortBreak), .breakCompleted]
        )
    }

    func testPauseAndResumePreserveRemainingSeconds() {
        let clock = PomodoroTimerTestClock(Date(timeIntervalSince1970: 0))
        let controller = makeController(now: { clock.value })

        controller.startFocus()
        clock.value = clock.value.addingTimeInterval(60)
        controller.pause()
        let pausedRemaining = controller.state.remainingSeconds
        clock.value = clock.value.addingTimeInterval(300)
        controller.resume()
        controller.refresh()

        XCTAssertEqual(pausedRemaining, PomodoroTimerController.focusDuration - 60)
        XCTAssertEqual(controller.state.remainingSeconds, pausedRemaining)
        XCTAssertFalse(controller.state.isPaused)
    }

    func testSkipFocusAdvancesToBreak() {
        let controller = makeController()

        controller.startFocus()
        controller.skip()

        XCTAssertEqual(controller.state.phase, .shortBreak)
        XCTAssertEqual(controller.state.completedFocusCount, 1)
    }

    func testSkipFocusRecordsSkippedStats() {
        let statsStore = makeStatsStore()
        let controller = makeController(statsStore: statsStore)

        controller.startFocus()
        controller.skip()

        XCTAssertEqual(statsStore.summary(forRecentDays: 1).focusSkippedCount, 1)
        XCTAssertEqual(statsStore.summary(forRecentDays: 1).completedFocusCount, 0)
    }

    func testSkipDoesNotSendReminder() async {
        let reminderService = SpyPomodoroReminderService()
        let controller = makeController(reminderService: reminderService)

        controller.startFocus()
        controller.skip()
        await Task.yield()

        XCTAssertTrue(reminderService.sentReminders.isEmpty)
    }

    func testSkipBreakAdvancesToFocus() {
        let controller = makeController()

        controller.startFocus()
        controller.skip()
        controller.skip()

        XCTAssertEqual(controller.state.phase, .focus)
        XCTAssertEqual(controller.state.completedFocusCount, 1)
    }

    func testSkipBreakDoesNotRecordSkippedFocus() {
        let statsStore = makeStatsStore()
        let controller = makeController(statsStore: statsStore)

        controller.startFocus()
        controller.skip()
        controller.skip()

        XCTAssertEqual(statsStore.summary(forRecentDays: 1).focusSkippedCount, 1)
    }

    func testEndResetsToIdle() {
        let controller = makeController()

        controller.startFocus()
        controller.end()

        XCTAssertEqual(controller.state, .idle)
    }

    func testEndFocusRecordsInterruptedStats() {
        let statsStore = makeStatsStore()
        let controller = makeController(statsStore: statsStore)

        controller.startFocus()
        controller.end()

        XCTAssertEqual(statsStore.summary(forRecentDays: 1).focusInterruptedCount, 1)
        XCTAssertEqual(statsStore.summary(forRecentDays: 1).completedFocusCount, 0)
    }

    func testEndDoesNotSendReminder() async {
        let reminderService = SpyPomodoroReminderService()
        let controller = makeController(reminderService: reminderService)

        controller.startFocus()
        controller.end()
        await Task.yield()

        XCTAssertTrue(reminderService.sentReminders.isEmpty)
    }

    private func makeController(
        now: @escaping () -> Date = Date.init,
        statsStore: PomodoroStatsStore? = nil,
        reminderService: PomodoroReminderServicing? = nil,
        reminderPreferences: @escaping () -> PomodoroReminderPreferences = { .default }
    ) -> PomodoroTimerController {
        PomodoroTimerController(
            now: now,
            startsTimer: false,
            statsStore: statsStore,
            reminderService: reminderService,
            reminderPreferences: reminderPreferences
        )
    }

    private func makeStatsStore(now: @escaping () -> Date = Date.init) -> PomodoroStatsStore {
        let suiteName = "PomodoroTimerControllerTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return PomodoroStatsStore(userDefaults: defaults, now: now)
    }
}

private final class SpyPomodoroReminderService: PomodoroReminderServicing {
    private(set) var sentReminders: [(kind: PomodoroReminderKind, preferences: PomodoroReminderPreferences)] = []

    func authorizationStatus() async -> PomodoroNotificationAuthorizationStatus {
        .authorized
    }

    func requestAuthorization() async -> Bool {
        true
    }

    func sendReminder(_ kind: PomodoroReminderKind, preferences: PomodoroReminderPreferences) async {
        sentReminders.append((kind, preferences))
    }
}

private final class PomodoroTimerTestClock {
    var value: Date

    init(_ value: Date) {
        self.value = value
    }
}
