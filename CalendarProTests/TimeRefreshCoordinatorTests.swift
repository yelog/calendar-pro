import AppKit
import Combine
import XCTest
@testable import CalendarPro

@MainActor
final class TimeRefreshCoordinatorTests: XCTestCase {
    func testDayChangeObserversReadTheNewDateBeforeUpdatingSelection() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))
        let clock = MutableBox(try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 3, hour: 23, minute: 59))))
        let coordinator = TimeRefreshCoordinator(now: { clock.value }, calendarProvider: { calendar })
        let model = CalendarPopoverViewModel(now: { coordinator.currentDate }, calendarProvider: { calendar })
        model.selectCurrentDate()
        var observedDate: Date?
        let observation = coordinator.$dayChangeRevision.dropFirst().sink { _ in
            observedDate = coordinator.currentDate
            model.syncCurrentDaySelectionIfNeeded(calendar: calendar)
        }

        clock.value = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 4, hour: 0, minute: 1)))
        coordinator.refreshNow()

        XCTAssertEqual(observedDate, clock.value)
        XCTAssertEqual(model.selectedDate, clock.value)
        withExtendedLifetime(observation) {}
    }
    func testDelayUntilNextMinuteBoundaryUsesRemainingSecondsInCurrentMinute() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: DateComponents(year: 2026, month: 4, day: 5, hour: 11, minute: 28, second: 31))!

        let delay = TimeRefreshCoordinator.delayUntilNextMinuteBoundary(from: date, calendar: calendar)

        XCTAssertEqual(delay, 29, accuracy: 0.001)
    }

    func testDelayUntilNextMinuteBoundaryAdvancesFullMinuteWhenAlreadyAligned() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: DateComponents(year: 2026, month: 4, day: 5, hour: 11, minute: 28, second: 0))!

        let delay = TimeRefreshCoordinator.delayUntilNextMinuteBoundary(from: date, calendar: calendar)

        XCTAssertEqual(delay, 60, accuracy: 0.001)
    }

    func testSystemClockChangeNotificationRefreshesCurrentDate() async {
        let notificationCenter = NotificationCenter()
        let workspaceNotificationCenter = NotificationCenter()
        let currentTime = MutableBox(Date(timeIntervalSince1970: 0))
        let coordinator = TimeRefreshCoordinator(
            now: { currentTime.value },
            notificationCenter: notificationCenter,
            workspaceNotificationCenter: workspaceNotificationCenter
        )

        currentTime.value = Date(timeIntervalSince1970: 120)
        notificationCenter.post(name: .NSSystemClockDidChange, object: nil)
        await Task.yield()

        XCTAssertEqual(coordinator.currentDate, currentTime.value)
    }

    func testWorkspaceWakeNotificationRefreshesCurrentDate() async {
        let notificationCenter = NotificationCenter()
        let workspaceNotificationCenter = NotificationCenter()
        let currentTime = MutableBox(Date(timeIntervalSince1970: 0))
        let coordinator = TimeRefreshCoordinator(
            now: { currentTime.value },
            notificationCenter: notificationCenter,
            workspaceNotificationCenter: workspaceNotificationCenter
        )

        currentTime.value = Date(timeIntervalSince1970: 180)
        workspaceNotificationCenter.post(name: NSWorkspace.didWakeNotification, object: nil)
        await Task.yield()

        XCTAssertEqual(coordinator.currentDate, currentTime.value)
    }

    func testWorkspaceWakeNotificationAcrossDayIncrementsDayChangeRevision() async {
        let notificationCenter = NotificationCenter()
        let workspaceNotificationCenter = NotificationCenter()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let currentTime = MutableBox(calendar.date(from: DateComponents(year: 2026, month: 4, day: 28, hour: 23, minute: 50))!)
        let coordinator = TimeRefreshCoordinator(
            now: { currentTime.value },
            calendarProvider: { calendar },
            notificationCenter: notificationCenter,
            workspaceNotificationCenter: workspaceNotificationCenter
        )

        XCTAssertEqual(coordinator.dayChangeRevision, 0)

        currentTime.value = calendar.date(from: DateComponents(year: 2026, month: 4, day: 29, hour: 8, minute: 10))!
        workspaceNotificationCenter.post(name: NSWorkspace.didWakeNotification, object: nil)
        await Task.yield()

        XCTAssertEqual(coordinator.currentDate, currentTime.value)
        XCTAssertEqual(coordinator.dayChangeRevision, 1)
    }

    func testRefreshWithinSameDayDoesNotIncrementDayChangeRevision() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let currentTime = MutableBox(calendar.date(from: DateComponents(year: 2026, month: 4, day: 28, hour: 8, minute: 10))!)
        let coordinator = TimeRefreshCoordinator(
            now: { currentTime.value },
            calendarProvider: { calendar },
            notificationCenter: NotificationCenter(),
            workspaceNotificationCenter: NotificationCenter()
        )

        currentTime.value = calendar.date(from: DateComponents(year: 2026, month: 4, day: 28, hour: 23, minute: 50))!
        coordinator.refreshNow()

        XCTAssertEqual(coordinator.currentDate, currentTime.value)
        XCTAssertEqual(coordinator.dayChangeRevision, 0)
    }
}

private final class MutableBox<Value> {
    var value: Value

    init(_ value: Value) {
        self.value = value
    }
}
