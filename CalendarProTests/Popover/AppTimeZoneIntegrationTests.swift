import Combine
import EventKit
import XCTest
@testable import CalendarPro

@MainActor
final class AppTimeZoneIntegrationTests: XCTestCase {
    func testTimeZoneCatalogIncludesSearchableUTC() {
        XCTAssertTrue(AppTimeZoneCatalog.matchingIdentifiers(query: "UTC", locale: Locale(identifier: "en")).contains("UTC"))
    }

    func testCivilHolidayDatesStayOnNewYearsDayAcrossTimeZones() throws {
        for identifier in ["America/Los_Angeles", "Pacific/Honolulu", "Pacific/Kiritimati", "Asia/Shanghai"] {
            let calendar = calendar(identifier)
            let newYear = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)))
            let holidays = try HolidayResolver(registry: .default, calendar: calendar).holidays(
                on: newYear, activeRegionIDs: ["mainland-cn"], enabledHolidaySetIDs: ["statutory-holidays"]
            )

            XCTAssertTrue(holidays.contains { $0.name == "元旦" }, identifier)
        }
    }
    func testMenuBarImmediatelyRendersChangedAppTimeZone() async throws {
        let suite = "AppTimeZoneIntegrationTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SettingsStore(userDefaults: defaults, launchAtLoginController: EnabledLoginController())
        store.setTimeZoneIdentifier("America/Los_Angeles")
        var preferences = store.menuBarPreferences
        preferences.tokens = [
            DisplayTokenPreference(token: .date, isEnabled: true, order: 0, style: .numeric),
            DisplayTokenPreference(token: .time, isEnabled: true, order: 1, style: .short)
        ]
        preferences.separator = " "
        store.menuBarPreferences = preferences
        let now = try instant("2026-11-02T16:30:00Z")
        let model = MenuBarViewModel(
            settingsStore: store,
            registry: .default,
            now: { now },
            localeProvider: { Locale(identifier: "en_US_POSIX") }
        )
        XCTAssertEqual(model.displayText, "02/11 08:30")

        let updated = expectation(description: "new timezone is rendered without a timer tick")
        let observation = model.$displayText.filter { $0 == "03/11 00:30" }.first().sink { _ in updated.fulfill() }
        store.setTimeZoneIdentifier("Asia/Shanghai")
        await fulfillment(of: [updated], timeout: 2)
        withExtendedLifetime(observation) {}
        XCTAssertEqual(model.displayText, "03/11 00:30")
    }

    func testTimeZoneChangePreservesBrowsedCivilDate() throws {
        let shanghai = calendar("Asia/Shanghai")
        let losAngeles = calendar("America/Los_Angeles")
        let selected = try XCTUnwrap(shanghai.date(from: DateComponents(year: 2026, month: 11, day: 3)))
        let model = CalendarPopoverViewModel(displayedMonth: selected, calendarProvider: { losAngeles })
        model.selectDate(selected)

        model.changeTimeZone(from: shanghai, to: losAngeles)

        let result = try XCTUnwrap(model.selectedDate)
        XCTAssertEqual(losAngeles.dateComponents([.year, .month, .day], from: result), DateComponents(year: 2026, month: 11, day: 3))
        XCTAssertEqual(model.displayedMonthNumber, 11)
        XCTAssertNotEqual(result, selected)
    }

    func testTimeZoneChangeFollowsTodayAcrossYearBoundary() throws {
        let now = try instant("2026-12-31T16:30:00Z")
        let shanghai = calendar("Asia/Shanghai")
        let losAngeles = calendar("America/Los_Angeles")
        let model = CalendarPopoverViewModel(now: { now }, calendarProvider: { losAngeles })
        model.selectCurrentDate()

        model.changeTimeZone(from: shanghai, to: losAngeles)

        XCTAssertEqual(model.selectedDate, now)
        XCTAssertEqual(model.displayedYear, 2026)
        XCTAssertEqual(model.displayedMonthNumber, 12)
        XCTAssertEqual(model.currentYear, 2026)
    }

    func testAppMidnightRefreshesWhileOtherZoneIsSameDay() throws {
        let shanghai = calendar("Asia/Shanghai")
        let losAngeles = calendar("America/Los_Angeles")
        var now = try instant("2026-11-02T15:59:00Z")
        let before = now
        let coordinator = TimeRefreshCoordinator(now: { now }, calendarProvider: { shanghai })

        now = try instant("2026-11-02T16:01:00Z")
        coordinator.refreshNow()

        XCTAssertTrue(losAngeles.isDate(before, inSameDayAs: now))
        XCTAssertEqual(coordinator.dayChangeRevision, 1)
    }

    func testTimelineCreationUsesWallTimeAfterSpringForwardAndRejectsGap() throws {
        let newYork = calendar("America/New_York")
        let selected = try XCTUnwrap(newYork.date(from: DateComponents(year: 2026, month: 3, day: 8)))
        XCTAssertNil(EventTimelineCreationSlot.make(yPosition: 150, selectedDate: selected, pointsPerMinute: 1, calendar: newYork))

        let slot = try XCTUnwrap(EventTimelineCreationSlot.make(yPosition: 210, selectedDate: selected, pointsPerMinute: 1, calendar: newYork))
        XCTAssertEqual(newYork.component(.hour, from: slot.startDate), 3)
        XCTAssertEqual(newYork.component(.minute, from: slot.startDate), 30)
        XCTAssertEqual(slot.endDate.timeIntervalSince(slot.startDate), 1800)
    }

    func testTimelineCreationUsesWallTimeAfterFallBack() throws {
        let newYork = calendar("America/New_York")
        let selected = try XCTUnwrap(newYork.date(from: DateComponents(year: 2026, month: 11, day: 1)))
        let slot = try XCTUnwrap(EventTimelineCreationSlot.make(yPosition: 540, selectedDate: selected, pointsPerMinute: 1, calendar: newYork))

        XCTAssertEqual(newYork.component(.hour, from: slot.startDate), 9)
        XCTAssertEqual(newYork.component(.minute, from: slot.startDate), 0)
    }

    func testRecentGroupingAndPaginationUseAppDateForFloatingReminder() throws {
        let shanghai = calendar("Asia/Shanghai")
        let reminder = EKReminder(eventStore: EKEventStore())
        reminder.title = "Floating reminder"
        reminder.dueDateComponents = DateComponents(year: 2026, month: 11, day: 3, hour: 0, minute: 30)
        let now = try instant("2026-11-02T16:00:00Z")
        let end = try instant("2026-11-03T16:00:00Z")
        let items = [CalendarItem.reminder(reminder)]

        let snapshot = UpcomingSnapshot.make(items: items, now: now, calendar: shanghai)
        let step = RootPopoverView.advanceUpcomingPage(
            direction: .future, windowItems: items, windowStart: now, windowEnd: end,
            collectedCount: 0, loadedIdentifiers: [], pageSize: 10,
            futureLimitEnd: end, isResumingWindow: false, calendar: shanghai
        )

        XCTAssertEqual(snapshot.dayGroups.count, 1)
        XCTAssertEqual(snapshot.dayGroups.first?.dayStart, now)
        XCTAssertEqual(step.slice.takenItems.count, 1)
    }

    func testSpringForwardEventProgressUsesElapsedTime() throws {
        let newYork = calendar("America/New_York")
        let event = EKEvent(eventStore: EKEventStore())
        event.timeZone = newYork.timeZone
        event.startDate = try instant("2026-03-08T06:30:00Z")
        event.endDate = try instant("2026-03-08T07:30:00Z")
        let now = try instant("2026-03-08T07:00:00Z")
        let layout = EventDayTimelineLayout.make(items: [.event(event)], selectedDate: now, now: now, calendar: newYork)

        let item = try XCTUnwrap(layout.timedItems.first)
        XCTAssertEqual(try XCTUnwrap(item.currentProgress), 0.5, accuracy: 0.001)
    }

    func testFallBackEventRemainsDurationCardWhenWallTimesRepeat() throws {
        let newYork = calendar("America/New_York")
        let event = EKEvent(eventStore: EKEventStore())
        event.timeZone = newYork.timeZone
        event.startDate = try instant("2026-11-01T05:30:00Z")
        event.endDate = try instant("2026-11-01T06:30:00Z")
        let now = try instant("2026-11-01T06:00:00Z")
        let layout = EventDayTimelineLayout.make(items: [.event(event)], selectedDate: now, now: now, calendar: newYork)

        let item = try XCTUnwrap(layout.timedItems.first)
        XCTAssertFalse(item.isPoint)
        XCTAssertGreaterThan(item.height(pointsPerMinute: 1), 0)
        XCTAssertEqual(try XCTUnwrap(item.currentProgress), 0.5, accuracy: 0.001)
    }

    func testPomodoroNewRecordsFollowTimeZoneWithoutMovingHistory() throws {
        let suite = "AppTimeZonePomodoroTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var currentCalendar = calendar("Asia/Shanghai")
        let now = try instant("2026-11-02T16:30:00Z")
        let stats = PomodoroStatsStore(userDefaults: defaults, now: { now }, calendarProvider: { currentCalendar })
        stats.recordFocusCompleted()

        currentCalendar = calendar("America/Los_Angeles")
        stats.recordFocusStarted()

        XCTAssertEqual(stats.dailyStats.first(where: { $0.dayKey == "2026-11-03" })?.focusCompletedCount, 1)
        XCTAssertEqual(stats.dailyStats.first(where: { $0.dayKey == "2026-11-02" })?.focusStartedCount, 1)
        XCTAssertEqual(stats.summary(forRecentDays: 1).completedFocusCount, 0)
    }

    private func calendar(_ identifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier)!
        return calendar
    }

    private func instant(_ string: String) throws -> Date {
        try XCTUnwrap(ISO8601DateFormatter().date(from: string))
    }
}

private struct EnabledLoginController: LaunchAtLoginControlling {
    func status() -> LaunchAtLoginStatus { .enabled }
    func setEnabled(_ enabled: Bool) throws {}
}
