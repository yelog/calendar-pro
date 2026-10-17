import XCTest
import EventKit
@testable import CalendarPro

final class UpcomingSnapshotTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    // MARK: - UpcomingSnapshot grouping

    func testGroupsItemsByDayInAscendingOrder() {
        let now = makeDate(2026, 10, 16, 10, 0)
        let day3Event = makeEvent(
            start: makeDate(2026, 10, 19, 9, 0),
            end: makeDate(2026, 10, 19, 10, 0)
        )
        let todayEvent = makeEvent(
            start: makeDate(2026, 10, 16, 11, 0),
            end: makeDate(2026, 10, 16, 12, 0)
        )
        let tomorrowEvent = makeEvent(
            start: makeDate(2026, 10, 17, 15, 0),
            end: makeDate(2026, 10, 17, 16, 0)
        )

        let snapshot = UpcomingSnapshot.make(
            items: [day3Event, tomorrowEvent, todayEvent],
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.dayGroups.count, 3)
        XCTAssertEqual(snapshot.totalItemCount, 3)
        XCTAssertEqual(
            snapshot.dayGroups.map(\.dayStart),
            [
                calendar.startOfDay(for: makeDate(2026, 10, 16, 0, 0)),
                calendar.startOfDay(for: makeDate(2026, 10, 17, 0, 0)),
                calendar.startOfDay(for: makeDate(2026, 10, 19, 0, 0))
            ]
        )
        XCTAssertEqual(snapshot.dayGroups[0].items.count, 1)
        XCTAssertEqual(snapshot.dayGroups[1].items.count, 1)
        XCTAssertEqual(snapshot.dayGroups[2].items.count, 1)
    }

    func testGroupsSameDayItemsTogetherAndKeepsTimedOrderWithinDay() throws {
        let now = makeDate(2026, 10, 16, 10, 0)
        let afternoonEvent = makeEvent(
            start: makeDate(2026, 10, 17, 15, 0),
            end: makeDate(2026, 10, 17, 16, 0)
        )
        let morningReminder = CalendarItem.reminder(makeReminder(2026, 10, 17, 8, 30))
        let allDayEvent = makeAllDayEvent(
            start: makeDate(2026, 10, 17, 0, 0),
            end: makeDate(2026, 10, 17, 23, 59)
        )
        let morningEvent = makeEvent(
            start: makeDate(2026, 10, 17, 8, 0),
            end: makeDate(2026, 10, 17, 9, 0)
        )

        let snapshot = UpcomingSnapshot.make(
            items: [afternoonEvent, morningReminder, allDayEvent, morningEvent],
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.dayGroups.count, 1)
        let group = try XCTUnwrap(snapshot.dayGroups.first)
        // Within a day: all-day items first, then by start time
        XCTAssertEqual(group.items.count, 4)
        XCTAssertTrue(group.items[0].isAllDay)
        XCTAssertLessThanOrEqual(
            group.items[1].startDate!.timeIntervalSince1970,
            group.items[2].startDate!.timeIntervalSince1970
        )
        XCTAssertLessThanOrEqual(
            group.items[2].startDate!.timeIntervalSince1970,
            group.items[3].startDate!.timeIntervalSince1970
        )
    }

    func testEmptyInputYieldsNoGroups() {
        let snapshot = UpcomingSnapshot.make(
            items: [],
            now: makeDate(2026, 10, 16, 10, 0),
            calendar: calendar
        )

        XCTAssertTrue(snapshot.dayGroups.isEmpty)
        XCTAssertEqual(snapshot.totalItemCount, 0)
    }

    func testIgnoresItemsWithoutStartDate() {
        // No dueDateComponents means no start date; the snapshot ignores it
        let reminderWithoutDueDate = EKReminder(eventStore: EKEventStore())
        reminderWithoutDueDate.title = "reminder without due date"
        let snapshot = UpcomingSnapshot.make(
            items: [CalendarItem.reminder(reminderWithoutDueDate)],
            now: makeDate(2026, 10, 16, 10, 0),
            calendar: calendar
        )

        XCTAssertTrue(snapshot.dayGroups.isEmpty)
        XCTAssertEqual(snapshot.totalItemCount, 0)
    }

    // MARK: - Bidirectional window grouping (past day groups)

    func testPastEventsFormAscendingDayGroupsWithFutureGroups() {
        // Past and future day groups coexist in one ascending order
        let now = makeDate(2026, 10, 16, 10, 0)
        let threeDaysAgo = makeEvent(
            start: makeDate(2026, 10, 13, 9, 0),
            end: makeDate(2026, 10, 13, 10, 0)
        )
        let yesterday = makeEvent(
            start: makeDate(2026, 10, 15, 9, 0),
            end: makeDate(2026, 10, 15, 10, 0)
        )
        let tomorrow = makeEvent(
            start: makeDate(2026, 10, 17, 9, 0),
            end: makeDate(2026, 10, 17, 10, 0)
        )

        let snapshot = UpcomingSnapshot.make(
            items: [tomorrow, threeDaysAgo, yesterday],
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.dayGroups.count, 3)
        XCTAssertEqual(snapshot.totalItemCount, 3)
        XCTAssertEqual(
            snapshot.dayGroups.map(\.dayStart),
            [
                calendar.startOfDay(for: makeDate(2026, 10, 13, 0, 0)),
                calendar.startOfDay(for: makeDate(2026, 10, 15, 0, 0)),
                calendar.startOfDay(for: makeDate(2026, 10, 17, 0, 0))
            ]
        )
    }

    func testYesterdayGroupUsesYesterdayHeaderText() throws {
        let now = makeDate(2026, 10, 16, 10, 0)
        let yesterday = makeEvent(
            start: makeDate(2026, 10, 15, 9, 0),
            end: makeDate(2026, 10, 15, 10, 0)
        )

        let snapshot = UpcomingSnapshot.make(
            items: [yesterday],
            now: now,
            calendar: calendar
        )

        let group = try XCTUnwrap(snapshot.dayGroups.first)
        XCTAssertEqual(group.headerText, L("All Yesterday"))
    }

    func testMultiDayEventAppearsOnceInItsStartDayGroup() {
        // Multi-day events group once on their start day only
        let now = makeDate(2026, 10, 16, 10, 0)
        let multiDayEvent = makeEvent(
            start: makeDate(2026, 10, 12, 20, 0),
            end: makeDate(2026, 10, 14, 22, 0)
        )

        let snapshot = UpcomingSnapshot.make(
            items: [multiDayEvent],
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.dayGroups.count, 1)
        XCTAssertEqual(
            snapshot.dayGroups.first?.dayStart,
            calendar.startOfDay(for: makeDate(2026, 10, 12, 0, 0))
        )
        XCTAssertEqual(snapshot.dayGroups.first?.items.count, 1)
        XCTAssertEqual(snapshot.totalItemCount, 1)
    }

    // MARK: - EventService.reminder(isDueWithin:) window filtering

    @MainActor
    func testReminderWindowFilterAcceptsDueWithinWindow() {
        let reminder = makeReminder(2026, 10, 17, 9, 0)

        let isDue = EventService.reminder(
            reminder,
            isDueWithin: calendar.startOfDay(for: makeDate(2026, 10, 16, 0, 0)),
            windowEnd: makeDate(2026, 10, 19, 0, 0),
            calendar: calendar
        )

        XCTAssertTrue(isDue)
    }

    @MainActor
    func testReminderWindowFilterRejectsDueBeforeWindowStart() {
        let reminder = makeReminder(2026, 10, 15, 9, 0)

        let isDue = EventService.reminder(
            reminder,
            isDueWithin: calendar.startOfDay(for: makeDate(2026, 10, 16, 0, 0)),
            windowEnd: makeDate(2026, 10, 19, 0, 0),
            calendar: calendar
        )

        XCTAssertFalse(isDue)
    }

    @MainActor
    func testReminderWindowFilterExpandsDailyRecurrenceIntoWindow() {
        // Daily recurrence based before the window still hits via the
        // per-day approximation
        let reminder = makeReminder(2026, 10, 1, 8, 0)
        reminder.recurrenceRules = [
            EKRecurrenceRule(recurrenceWith: .daily, interval: 1, end: nil)
        ]

        let isDue = EventService.reminder(
            reminder,
            isDueWithin: calendar.startOfDay(for: makeDate(2026, 10, 16, 0, 0)),
            windowEnd: makeDate(2026, 10, 19, 0, 0),
            calendar: calendar
        )

        XCTAssertTrue(isDue)
    }

    @MainActor
    func testReminderWindowFilterRejectsWeeklyRecurrenceOutsideWindow() {
        // Weekly (Friday) reminder stays out when the window has no Friday
        let reminder = makeReminder(2026, 10, 9, 8, 0)
        reminder.recurrenceRules = [
            EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, end: nil)
        ]

        // The default window contains a Friday; use a Friday-free window
        let windowStart = calendar.startOfDay(for: makeDate(2026, 10, 17, 0, 0))
        let windowEnd = makeDate(2026, 10, 22, 0, 0)

        let isDue = EventService.reminder(
            reminder,
            isDueWithin: windowStart,
            windowEnd: windowEnd,
            calendar: calendar
        )

        XCTAssertFalse(isDue)
    }

    // MARK: - EventService.event(isWithinUpcomingWindow:) window filtering

    @MainActor
    func testEventWindowFilterExcludesMultiDayEventStartedBeforeWindowStart() {
        // The overlap predicate still returns it, but a start before the
        // window is excluded so multi-day events show once, in their
        // start-day window
        let event = makeEKEvent(
            start: makeDate(2026, 10, 15, 20, 0),
            end: makeDate(2026, 10, 16, 12, 0)
        )

        let isIncluded = EventService.event(
            event,
            isWithinUpcomingWindow: calendar.startOfDay(for: makeDate(2026, 10, 16, 0, 0)),
            enabledCalendarIDs: []
        )

        XCTAssertFalse(isIncluded)
    }

    @MainActor
    func testEventWindowFilterExcludesMultiDayEventSpanningWindowStart() {
        let event = makeEKEvent(
            start: makeDate(2026, 10, 15, 20, 0),
            end: makeDate(2026, 10, 17, 12, 0)
        )

        let isIncluded = EventService.event(
            event,
            isWithinUpcomingWindow: calendar.startOfDay(for: makeDate(2026, 10, 16, 0, 0)),
            enabledCalendarIDs: []
        )

        XCTAssertFalse(isIncluded)
    }

    @MainActor
    func testEventWindowFilterIncludesEventStartedTodayAfterWindowStart() {
        // Started-after-midnight events stay; ended same-day events stay
        // too under the bidirectional window
        let event = makeEKEvent(
            start: makeDate(2026, 10, 16, 8, 0),
            end: makeDate(2026, 10, 16, 12, 0)
        )

        let isIncluded = EventService.event(
            event,
            isWithinUpcomingWindow: calendar.startOfDay(for: makeDate(2026, 10, 16, 0, 0)),
            enabledCalendarIDs: []
        )

        XCTAssertTrue(isIncluded)
    }

    @MainActor
    func testEventWindowFilterIncludesPastEventWithinExtendedWindow() {
        // Ended events inside an extended past window are included for
        // history browsing
        let event = makeEKEvent(
            start: makeDate(2026, 10, 12, 9, 0),
            end: makeDate(2026, 10, 12, 10, 0)
        )

        let isIncluded = EventService.event(
            event,
            isWithinUpcomingWindow: calendar.startOfDay(for: makeDate(2026, 10, 10, 0, 0)),
            enabledCalendarIDs: []
        )

        XCTAssertTrue(isIncluded)
    }

    // MARK: - RootPopoverView.advanceUpcomingPage slice and cursor advance

    /// Convenience wrapper applying paging defaults to cut case boilerplate.
    private func advance(
        direction: RootPopoverView.UpcomingPageDirection,
        windowItems: [CalendarItem],
        windowStart: Date,
        windowEnd: Date,
        collectedCount: Int = 0,
        loadedIdentifiers: Set<String> = [],
        pageSize: Int = 10,
        futureLimitEnd: Date? = nil,
        isResumingWindow: Bool = false
    ) -> (
        slice: RootPopoverView.UpcomingPageWindowSlice,
        nextWindowStart: Date?,
        isExhausted: Bool
    ) {
        RootPopoverView.advanceUpcomingPage(
            direction: direction,
            windowItems: windowItems,
            windowStart: windowStart,
            windowEnd: windowEnd,
            collectedCount: collectedCount,
            loadedIdentifiers: loadedIdentifiers,
            pageSize: pageSize,
            futureLimitEnd: futureLimitEnd,
            isResumingWindow: isResumingWindow
        )
    }

    /// Builds n events spaced evenly from firstStart with distinct titles
    /// so fallback identities stay unique.
    private func makeSequentialEvents(
        count: Int,
        firstStart: Date,
        interval: TimeInterval = 3600,
        titlePrefix: String = "event"
    ) -> [CalendarItem] {
        (0..<count).map { index in
            .event(makeEKEvent(
                start: firstStart.addingTimeInterval(Double(index) * interval),
                end: firstStart.addingTimeInterval(Double(index) * interval + 1800),
                title: "\(titlePrefix)\(index)"
            ))
        }
    }

    /// Test double mirroring the production loadUpcomingPage loop: window
    /// construction (future [cursor, cursor+30d), past [cursor-30d, cursor)
    /// with the cursor as the past upper bound), slice advance, 12-window
    /// cap and resume-flag hand-off all match production; the EventKit
    /// query is a half-open range filter over universe. Cursor and resume
    /// flag are passed across calls to verify the page-full resume
    /// sequence contract.
    private func mirrorLoadPage(
        direction: RootPopoverView.UpcomingPageDirection,
        cursor: Date,
        isResumingWindow: Bool,
        loadedIdentifiers: Set<String>,
        universe: [CalendarItem],
        futureLimitEnd: Date? = nil
    ) -> (
        collected: [CalendarItem],
        nextCursor: Date?,
        isResumingWindow: Bool,
        isExhausted: Bool
    ) {
        var collected: [CalendarItem] = []
        var workingCursor = cursor
        var resumingWindow = isResumingWindow
        var loaded = loadedIdentifiers
        var isExhausted = false
        var queriedWindowCount = 0

        while !isExhausted,
              collected.count < RootPopoverView.upcomingPageSize,
              queriedWindowCount < RootPopoverView.upcomingPageMaxWindows {
            let windowStart: Date
            let windowEnd: Date
            switch direction {
            case .future:
                windowStart = workingCursor
                var end = calendar.date(
                    byAdding: .day,
                    value: RootPopoverView.upcomingPageWindowDays,
                    to: workingCursor
                ) ?? workingCursor
                if let futureLimitEnd, end > futureLimitEnd {
                    end = futureLimitEnd
                }
                windowEnd = end
            case .past:
                windowEnd = workingCursor
                windowStart = calendar.date(
                    byAdding: .day,
                    value: -RootPopoverView.upcomingPageWindowDays,
                    to: workingCursor
                ) ?? workingCursor
            }
            guard windowEnd > windowStart else {
                isExhausted = true
                break
            }

            queriedWindowCount += 1
            // EventKit query double: returns everything in the window
            let windowItems = universe.filter { item in
                guard let startDate = item.startDate else { return false }
                return startDate >= windowStart && startDate < windowEnd
            }
            let step = RootPopoverView.advanceUpcomingPage(
                direction: direction,
                windowItems: windowItems,
                windowStart: windowStart,
                windowEnd: windowEnd,
                collectedCount: collected.count,
                loadedIdentifiers: loaded,
                pageSize: RootPopoverView.upcomingPageSize,
                futureLimitEnd: nil,
                isResumingWindow: resumingWindow
            )
            collected.append(contentsOf: step.slice.takenItems)
            for item in step.slice.takenItems {
                loaded.insert(item.selectionIdentifier)
            }
            resumingWindow = step.slice.isPageFull
            if let steppedCursor = step.nextWindowStart {
                workingCursor = steppedCursor
            }
            isExhausted = step.isExhausted
        }

        // Same finish rules as production: exhaustion or window cap means a
        // nil cursor; page-full finish resumes the same window next load
        let hitWindowCap = !isExhausted
            && collected.count < RootPopoverView.upcomingPageSize
        let finalCursor: Date? = (isExhausted || hitWindowCap) ? nil : workingCursor
        let endedWithPageFull = finalCursor != nil
            && collected.count >= RootPopoverView.upcomingPageSize
        return (
            collected,
            finalCursor,
            endedWithPageFull,
            isExhausted
        )
    }

    func testFuturePageTakesUpToPageSizeAndResumesSameWindow() {
        // 12 in window: take 10, cursor stays at window start so the
        // resume re-covers the page boundary
        let windowStart = makeDate(2026, 10, 16, 0, 0)
        let windowEnd = makeDate(2026, 11, 15, 0, 0)
        let items = makeSequentialEvents(count: 12, firstStart: windowStart)

        let step = advance(
            direction: .future,
            windowItems: items,
            windowStart: windowStart,
            windowEnd: windowEnd
        )

        XCTAssertEqual(step.slice.takenItems.count, 10)
        XCTAssertTrue(step.slice.isPageFull)
        XCTAssertEqual(step.slice.inRangeItemCount, 12)
        XCTAssertFalse(step.isExhausted)
        XCTAssertEqual(step.nextWindowStart, windowStart)
    }

    func testFuturePageAdvancesToWindowEndWhenWindowSparse() {
        // Under-full window advances the cursor to the window end
        let windowStart = makeDate(2026, 10, 16, 0, 0)
        let windowEnd = makeDate(2026, 11, 15, 0, 0)
        let items = makeSequentialEvents(count: 3, firstStart: windowStart)

        let step = advance(
            direction: .future,
            windowItems: items,
            windowStart: windowStart,
            windowEnd: windowEnd
        )

        XCTAssertEqual(step.slice.takenItems.count, 3)
        XCTAssertFalse(step.slice.isPageFull)
        XCTAssertFalse(step.isExhausted)
        XCTAssertEqual(step.nextWindowStart, windowEnd)
    }

    func testFuturePageCrossesEmptyWindowWithoutExhausting() {
        // Empty future window is not the end; the per-page window cap
        // bounds the loop
        let windowStart = makeDate(2026, 10, 16, 0, 0)
        let windowEnd = makeDate(2026, 11, 15, 0, 0)

        let step = advance(
            direction: .future,
            windowItems: [],
            windowStart: windowStart,
            windowEnd: windowEnd
        )

        XCTAssertTrue(step.slice.takenItems.isEmpty)
        XCTAssertEqual(step.slice.inRangeItemCount, 0)
        XCTAssertFalse(step.isExhausted)
        XCTAssertEqual(step.nextWindowStart, windowEnd)
    }

    func testFuturePageExhaustsAtLimitBound() {
        // Window end clipped to the user limit and still under-full: the
        // limit means exhausted, nil cursor
        let windowStart = makeDate(2026, 10, 16, 0, 0)
        let windowEnd = makeDate(2027, 1, 14, 10, 0)
        let items = makeSequentialEvents(count: 3, firstStart: windowStart)

        let step = advance(
            direction: .future,
            windowItems: items,
            windowStart: windowStart,
            windowEnd: windowEnd,
            futureLimitEnd: windowEnd
        )

        XCTAssertEqual(step.slice.takenItems.count, 3)
        XCTAssertFalse(step.slice.isPageFull)
        XCTAssertTrue(step.isExhausted)
        XCTAssertNil(step.nextWindowStart)
    }

    func testFuturePageContinuationSkipsLoadedItemsAndTakesRemainder() {
        // The continuation page re-queries the same window and takes only
        // the remaining 2, never repeating loaded identities
        let windowStart = makeDate(2026, 10, 16, 0, 0)
        let windowEnd = makeDate(2026, 11, 15, 0, 0)
        let items = makeSequentialEvents(count: 12, firstStart: windowStart)

        let firstStep = advance(
            direction: .future,
            windowItems: items,
            windowStart: windowStart,
            windowEnd: windowEnd
        )
        let loadedIdentifiers = Set(firstStep.slice.takenItems.map(\.selectionIdentifier))

        let secondStep = advance(
            direction: .future,
            windowItems: items,
            windowStart: windowStart,
            windowEnd: windowEnd,
            loadedIdentifiers: loadedIdentifiers
        )

        XCTAssertEqual(secondStep.slice.takenItems.count, 2)
        XCTAssertFalse(secondStep.slice.isPageFull)
        XCTAssertFalse(secondStep.isExhausted)
        XCTAssertEqual(secondStep.nextWindowStart, windowEnd)
        // Exactly the two items the first page skipped
        XCTAssertEqual(
            Set(secondStep.slice.takenItems.map(\.selectionIdentifier)),
            Set(items.suffix(2).map(\.selectionIdentifier))
        )
    }

    func testSameInstantGroupSplitAcrossPagesNotDuplicatedNorLost() {
        // Same-instant items split across the page boundary: pages of 2
        // then 1, no duplicates, none lost
        let windowStart = makeDate(2026, 10, 16, 0, 0)
        let windowEnd = makeDate(2026, 10, 20, 0, 0)
        let sameInstant = makeDate(2026, 10, 17, 9, 0)
        let items = makeSequentialEvents(
            count: 3,
            firstStart: sameInstant,
            interval: 0,
            titlePrefix: "same-instant"
        )

        let firstStep = advance(
            direction: .future,
            windowItems: items,
            windowStart: windowStart,
            windowEnd: windowEnd,
            pageSize: 2
        )
        XCTAssertEqual(firstStep.slice.takenItems.count, 2)
        XCTAssertTrue(firstStep.slice.isPageFull)

        let loadedIdentifiers = Set(firstStep.slice.takenItems.map(\.selectionIdentifier))
        let secondStep = advance(
            direction: .future,
            windowItems: items,
            windowStart: windowStart,
            windowEnd: windowEnd,
            loadedIdentifiers: loadedIdentifiers,
            pageSize: 2
        )

        XCTAssertEqual(secondStep.slice.takenItems.count, 1)
        XCTAssertEqual(
            Set(firstStep.slice.takenItems.map(\.selectionIdentifier))
                .union(secondStep.slice.takenItems.map(\.selectionIdentifier)),
            Set(items.map(\.selectionIdentifier))
        )
        XCTAssertTrue(
            Set(firstStep.slice.takenItems.map(\.selectionIdentifier))
                .isDisjoint(with: Set(secondStep.slice.takenItems.map(\.selectionIdentifier)))
        )
    }

    func testPastPageTakesMostRecentItemsFirst() {
        // Past direction takes the most recent batch, stored ascending;
        // the resume cursor is the window upper bound because rewinding to
        // the start would skip the leftovers
        let windowStart = makeDate(2026, 10, 1, 0, 0)
        let windowEnd = makeDate(2026, 10, 16, 0, 0)
        let items = makeSequentialEvents(count: 12, firstStart: windowStart)

        let step = advance(
            direction: .past,
            windowItems: items,
            windowStart: windowStart,
            windowEnd: windowEnd
        )

        XCTAssertEqual(step.slice.takenItems.count, 10)
        XCTAssertTrue(step.slice.isPageFull)
        XCTAssertEqual(
            step.slice.takenItems.map(\.startDate),
            Array(items.suffix(10)).map(\.startDate)
        )
        XCTAssertEqual(step.nextWindowStart, windowEnd)
        XCTAssertFalse(step.isExhausted)
    }

    func testPastPageFullResumesWindowAtWindowEnd() {
        // Page-full past resume cursor must be the window upper bound so
        // the next query re-covers the same window and leftovers stay
        // reachable
        let windowStart = makeDate(2026, 10, 1, 0, 0)
        let windowEnd = makeDate(2026, 10, 16, 0, 0)
        let items = makeSequentialEvents(count: 12, firstStart: windowStart)

        let step = advance(
            direction: .past,
            windowItems: items,
            windowStart: windowStart,
            windowEnd: windowEnd
        )

        XCTAssertEqual(step.slice.takenItems.count, 10)
        XCTAssertTrue(step.slice.isPageFull)
        XCTAssertEqual(step.nextWindowStart, windowEnd)
        XCTAssertFalse(step.isExhausted)
    }

    func testPastCrossPullRetrievesAllItemsFromSingleWindow() throws {
        // Two past pulls over one 12-item window: the first takes the
        // latest 10, the second must resume the same window for the
        // remaining 2 before the earlier empty window legitimately ends
        // history
        let windowStart = makeDate(2026, 10, 1, 0, 0)
        let windowEnd = makeDate(2026, 10, 16, 0, 0)
        let items = makeSequentialEvents(count: 12, firstStart: windowStart)

        // First pull: cursor at the window upper bound, not resuming
        let firstPull = mirrorLoadPage(
            direction: .past,
            cursor: windowEnd,
            isResumingWindow: false,
            loadedIdentifiers: [],
            universe: items
        )
        XCTAssertEqual(firstPull.collected.count, 10)
        XCTAssertEqual(firstPull.nextCursor, windowEnd)
        XCTAssertTrue(firstPull.isResumingWindow)
        XCTAssertFalse(firstPull.isExhausted)

        // Second pull: cursor and resume flag handed over by the first
        let firstIdentifiers = Set(firstPull.collected.map(\.selectionIdentifier))
        let secondPull = mirrorLoadPage(
            direction: .past,
            cursor: try XCTUnwrap(firstPull.nextCursor),
            isResumingWindow: firstPull.isResumingWindow,
            loadedIdentifiers: firstIdentifiers,
            universe: items
        )
        // The resume window hands back the 2 leftover items
        XCTAssertEqual(secondPull.collected.count, 2)
        XCTAssertTrue(
            Set(secondPull.collected.map(\.selectionIdentifier))
                .isDisjoint(with: firstIdentifiers)
        )
        // Both pulls together cover all 12 items exactly once
        let allIdentifiers = firstIdentifiers
            .union(secondPull.collected.map(\.selectionIdentifier))
        XCTAssertEqual(allIdentifiers, Set(items.map(\.selectionIdentifier)))
        XCTAssertTrue(secondPull.isExhausted)
        XCTAssertNil(secondPull.nextCursor)
        XCTAssertFalse(secondPull.isResumingWindow)
    }

    func testFutureCrossPullRetrievesAllItemsFromSingleWindow() throws {
        // Future-direction mirror of the same scenario: the window tail is
        // the user limit; the first pull takes the earliest 10, the second
        // resumes for the last 2 then hits the limit
        let windowStart = makeDate(2026, 10, 16, 0, 0)
        let windowEnd = makeDate(2026, 11, 15, 0, 0)
        let items = makeSequentialEvents(count: 12, firstStart: windowStart)

        let firstPull = mirrorLoadPage(
            direction: .future,
            cursor: windowStart,
            isResumingWindow: false,
            loadedIdentifiers: [],
            universe: items,
            futureLimitEnd: windowEnd
        )
        XCTAssertEqual(firstPull.collected.count, 10)
        XCTAssertEqual(firstPull.nextCursor, windowStart)
        XCTAssertTrue(firstPull.isResumingWindow)
        XCTAssertFalse(firstPull.isExhausted)

        let firstIdentifiers = Set(firstPull.collected.map(\.selectionIdentifier))
        let secondPull = mirrorLoadPage(
            direction: .future,
            cursor: try XCTUnwrap(firstPull.nextCursor),
            isResumingWindow: firstPull.isResumingWindow,
            loadedIdentifiers: firstIdentifiers,
            universe: items,
            futureLimitEnd: windowEnd
        )
        XCTAssertEqual(secondPull.collected.count, 2)
        XCTAssertTrue(
            Set(secondPull.collected.map(\.selectionIdentifier))
                .isDisjoint(with: firstIdentifiers)
        )
        // Both pulls cover all 12 exactly once; exhaustion lands on the
        // user limit after the resume completes
        XCTAssertEqual(
            firstIdentifiers.union(secondPull.collected.map(\.selectionIdentifier)),
            Set(items.map(\.selectionIdentifier))
        )
        XCTAssertTrue(secondPull.isExhausted)
        XCTAssertNil(secondPull.nextCursor)
        XCTAssertFalse(secondPull.isResumingWindow)
    }

    func testPastEmptyWindowExhausts() {
        // Empty past window means the historical start
        let windowStart = makeDate(2026, 10, 1, 0, 0)
        let windowEnd = makeDate(2026, 10, 16, 0, 0)

        let step = advance(
            direction: .past,
            windowItems: [],
            windowStart: windowStart,
            windowEnd: windowEnd
        )

        XCTAssertTrue(step.slice.takenItems.isEmpty)
        XCTAssertEqual(step.slice.inRangeItemCount, 0)
        XCTAssertTrue(step.isExhausted)
        XCTAssertNil(step.nextWindowStart)
    }

    @MainActor
    func testPastWindowWithOnlyLoadedReminderAdvances() {
        // A window of already-loaded items (recurring reminders repeat per
        // window) is not empty; keep advancing instead of misreading
        // history's end
        let windowStart = makeDate(2026, 10, 1, 0, 0)
        let windowEnd = makeDate(2026, 10, 16, 0, 0)
        let reminder = makeReminder(2026, 10, 8, 9, 0)
        let loadedItem = CalendarItem.reminder(reminder)

        let step = advance(
            direction: .past,
            windowItems: [loadedItem],
            windowStart: windowStart,
            windowEnd: windowEnd,
            loadedIdentifiers: [loadedItem.selectionIdentifier]
        )

        XCTAssertTrue(step.slice.takenItems.isEmpty)
        XCTAssertEqual(step.slice.inRangeItemCount, 1)
        XCTAssertFalse(step.isExhausted)
        XCTAssertEqual(step.nextWindowStart, windowStart)
    }

    func testPastResumeWindowWithNoNewItemsAdvances() {
        // A resume window bringing nothing new only means the window is
        // used up; advance to the next one
        let windowStart = makeDate(2026, 10, 1, 0, 0)
        let windowEnd = makeDate(2026, 10, 16, 0, 0)

        let step = advance(
            direction: .past,
            windowItems: [],
            windowStart: windowStart,
            windowEnd: windowEnd,
            isResumingWindow: true
        )

        XCTAssertFalse(step.isExhausted)
        XCTAssertEqual(step.nextWindowStart, windowStart)
    }

    func testPastPageAdvancesAfterConsumingWindowItems() {
        // Under-full after consuming the window: cursor moves to the
        // window head (next window's upper bound)
        let windowStart = makeDate(2026, 10, 1, 0, 0)
        let windowEnd = makeDate(2026, 10, 16, 0, 0)
        let items = makeSequentialEvents(count: 3, firstStart: windowStart)

        let step = advance(
            direction: .past,
            windowItems: items,
            windowStart: windowStart,
            windowEnd: windowEnd
        )

        XCTAssertEqual(step.slice.takenItems.count, 3)
        XCTAssertFalse(step.slice.isPageFull)
        XCTAssertFalse(step.isExhausted)
        XCTAssertEqual(step.nextWindowStart, windowStart)
    }

    func testPageSizeBoundaryAlreadyFullTakesNothing() {
        // An already-full page takes nothing more and stays full
        let windowStart = makeDate(2026, 10, 16, 0, 0)
        let windowEnd = makeDate(2026, 11, 15, 0, 0)
        let items = makeSequentialEvents(count: 5, firstStart: windowStart)

        let step = advance(
            direction: .future,
            windowItems: items,
            windowStart: windowStart,
            windowEnd: windowEnd,
            collectedCount: 10
        )

        XCTAssertTrue(step.slice.takenItems.isEmpty)
        XCTAssertTrue(step.slice.isPageFull)
        XCTAssertFalse(step.isExhausted)
        XCTAssertEqual(step.nextWindowStart, windowStart)
    }

    // MARK: - Fixtures

    private func makeDate(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        _ minute: Int
    ) -> Date {
        DateComponents(
            calendar: calendar,
            timeZone: TimeZone(secondsFromGMT: 0),
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ).date!
    }

    private func makeEKEvent(
        start: Date,
        end: Date,
        allDay: Bool = false,
        title: String? = nil
    ) -> EKEvent {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.title = title ?? (allDay ? "all-day event" : "event")
        event.startDate = start
        event.endDate = end
        // Pin the time zone so all-day date normalization does not drift
        // with the machine time zone
        event.timeZone = TimeZone(secondsFromGMT: 0)
        event.isAllDay = allDay
        if let ekCalendar = store.defaultCalendarForNewEvents {
            event.calendar = ekCalendar
        }
        return event
    }

    private func makeEvent(start: Date, end: Date) -> CalendarItem {
        .event(makeEKEvent(start: start, end: end))
    }

    private func makeAllDayEvent(start: Date, end: Date) -> CalendarItem {
        .event(makeEKEvent(start: start, end: end, allDay: true))
    }

    private func makeReminder(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        _ minute: Int
    ) -> EKReminder {
        let reminder = EKReminder(eventStore: EKEventStore())
        reminder.title = "reminder"
        reminder.dueDateComponents = DateComponents(
            calendar: calendar,
            timeZone: TimeZone(secondsFromGMT: 0),
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )
        return reminder
    }
}
