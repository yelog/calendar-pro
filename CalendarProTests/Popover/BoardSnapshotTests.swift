import XCTest
import EventKit
@testable import CalendarPro

final class BoardSnapshotTests: XCTestCase {
    private let calendar = BoardSnapshotTests.makeCalendar()

    private static func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 16, hour: 12))!
    }

    private func makeDate(_ month: Int, _ day: Int, hour: Int = 12, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    private func makeReminder(
        title: String,
        listName: String = "Inbox",
        priority: Int = 0,
        due: Date? = nil,
        includesTime: Bool = true,
        isCompleted: Bool = false,
        completedAt: Date? = nil
    ) -> EKReminder {
        let store = EKEventStore()
        let reminder = EKReminder(eventStore: store)
        let list = EKCalendar(for: .reminder, eventStore: store)
        list.title = listName
        reminder.calendar = list
        reminder.title = title
        reminder.priority = priority
        reminder.isCompleted = isCompleted
        // Only assign completionDate when explicitly given: in EventKit it is
        // coupled with isCompleted (assigning nil flips isCompleted back to false).
        if let completedAt {
            reminder.completionDate = completedAt
        }

        if let due {
            var components = calendar.dateComponents([.year, .month, .day], from: due)
            if includesTime {
                components.hour = calendar.component(.hour, from: due)
                components.minute = calendar.component(.minute, from: due)
            }
            reminder.dueDateComponents = components
        }

        return reminder
    }

    private func makeSnapshot(
        _ reminders: [EKReminder],
        groupingMode: RemindersBoardGroupingMode = .list,
        colorMode: RemindersBoardColorMode = .overdue,
        colorPreferences: BoardColorPreferences = .classic,
        showCompleted: Bool = false,
        retentionSeconds: Int = 0
    ) -> BoardSnapshot {
        BoardSnapshot.make(
            reminders: reminders,
            now: now,
            calendar: calendar,
            groupingMode: groupingMode,
            colorMode: colorMode,
            colorPreferences: colorPreferences,
            showCompleted: showCompleted,
            retentionSeconds: retentionSeconds
        )
    }

    // MARK: - Priority mapping

    func testPriorityMappingCoversEKPriorityRanges() {
        XCTAssertEqual(ReminderBoardPriority(ekPriority: 0), .none)
        XCTAssertEqual(ReminderBoardPriority(ekPriority: 1), .high)
        XCTAssertEqual(ReminderBoardPriority(ekPriority: 3), .high)
        XCTAssertEqual(ReminderBoardPriority(ekPriority: 4), .medium)
        XCTAssertEqual(ReminderBoardPriority(ekPriority: 6), .medium)
        XCTAssertEqual(ReminderBoardPriority(ekPriority: 7), .low)
        XCTAssertEqual(ReminderBoardPriority(ekPriority: 9), .low)
        XCTAssertEqual(ReminderBoardPriority(ekPriority: 10), .none)
        XCTAssertEqual(ReminderBoardPriority(ekPriority: -1), .none)
    }

    // MARK: - Grouping

    func testGroupingByListUsesListNameAndSortsGroupsByName() {
        let snapshot = makeSnapshot([
            makeReminder(title: "beta", listName: "Work"),
            makeReminder(title: "alpha", listName: "Home")
        ])

        XCTAssertEqual(snapshot.groups.map(\.title), ["Home", "Work"])
        XCTAssertEqual(snapshot.groups[0].rows.map(\.title), ["alpha"])
        XCTAssertEqual(snapshot.groups[1].rows.map(\.title), ["beta"])
    }

    func testGroupingByPriorityOrdersHighMediumLowNoneAndSkipsEmptyGroups() {
        let snapshot = makeSnapshot(
            [
                makeReminder(title: "none-task", priority: 0),
                makeReminder(title: "low-task", priority: 7),
                makeReminder(title: "high-task", priority: 2),
                makeReminder(title: "medium-task", priority: 5)
            ],
            groupingMode: .priority
        )

        XCTAssertEqual(snapshot.groups.map(\.title), ["高", "中", "低", "无"])
        XCTAssertEqual(snapshot.groups[0].rows.map(\.title), ["high-task"])
        XCTAssertEqual(snapshot.groups[3].rows.map(\.title), ["none-task"])

        let single = makeSnapshot(
            [makeReminder(title: "high-task", priority: 1)],
            groupingMode: .priority
        )
        XCTAssertEqual(single.groups.count, 1)
    }

    // MARK: - Row sorting

    func testRowsSortByDueDateWithNoDateLastThenTitle() {
        let snapshot = makeSnapshot([
            makeReminder(title: "zebra", due: makeDate(10, 16, hour: 9)),
            makeReminder(title: "no-date-b", due: nil),
            makeReminder(title: "early", due: makeDate(10, 15, hour: 8)),
            makeReminder(title: "no-date-a", due: nil),
            makeReminder(title: "same-time-b", due: makeDate(10, 16, hour: 9)),
            makeReminder(title: "same-time-a", due: makeDate(10, 16, hour: 9))
        ])

        XCTAssertEqual(
            snapshot.groups[0].rows.map(\.title),
            ["early", "same-time-a", "same-time-b", "zebra", "no-date-a", "no-date-b"]
        )
    }

    // MARK: - Time buckets

    func testTimeBucketBoundaries() {
        let cases: [(due: Date?, expected: ReminderBoardTimeBucket)] = [
            (makeDate(10, 15, hour: 23, minute: 59), .past),
            (makeDate(10, 16, hour: 0, minute: 0), .today),
            (makeDate(10, 17, hour: 0, minute: 0), .thisWeek),
            (makeDate(10, 22, hour: 23, minute: 59), .thisWeek),
            (makeDate(10, 23, hour: 0, minute: 0), .later),
            (nil, .none)
        ]

        for (due, expected) in cases {
            XCTAssertEqual(
                ReminderBoardTimeBucket.resolve(dueDate: due, now: now, calendar: calendar),
                expected,
                "due \(String(describing: due)) should resolve to \(expected)"
            )
        }
    }

    // MARK: - Color resolution

    func testOverdueColorModeResolvesTwoColors() {
        let rows = makeSnapshot(
            [
                makeReminder(title: "overdue", due: makeDate(10, 10)),
                makeReminder(title: "today", due: makeDate(10, 16)),
                makeReminder(title: "later", due: makeDate(10, 30))
            ]
        ).groups[0].rows

        let colorByTitle = Dictionary(uniqueKeysWithValues: rows.map { ($0.title, $0.colorHex) })
        XCTAssertEqual(colorByTitle["overdue"], BoardColorPreferences.classic.overdue)
        XCTAssertEqual(colorByTitle["today"], BoardColorPreferences.classic.notOverdue)
        XCTAssertEqual(colorByTitle["later"], BoardColorPreferences.classic.notOverdue)
    }

    func testTimeBucketColorModeMapsBuckets() {
        let rows = makeSnapshot(
            [
                makeReminder(title: "past", due: makeDate(10, 10)),
                makeReminder(title: "today", due: makeDate(10, 16)),
                makeReminder(title: "this-week", due: makeDate(10, 20)),
                makeReminder(title: "later", due: makeDate(11, 1))
            ],
            colorMode: .timeBucket
        ).groups[0].rows

        let colorByTitle = Dictionary(uniqueKeysWithValues: rows.map { ($0.title, $0.colorHex) })
        XCTAssertEqual(colorByTitle["past"], BoardColorPreferences.classic.past)
        XCTAssertEqual(colorByTitle["today"], BoardColorPreferences.classic.today)
        XCTAssertEqual(colorByTitle["this-week"], BoardColorPreferences.classic.thisWeek)
        XCTAssertEqual(colorByTitle["later"], BoardColorPreferences.classic.later)
    }

    func testNoDateRowAlwaysUsesNoDateColor() {
        for colorMode in RemindersBoardColorMode.allCases {
            let rows = makeSnapshot(
                [makeReminder(title: "someday", due: nil)],
                colorMode: colorMode
            ).groups[0].rows

            XCTAssertEqual(rows.first?.colorHex, BoardColorPreferences.classic.noDate)
            XCTAssertNil(rows.first?.dueText)
        }
    }

    func testCompletedRowsUseCompletedColorAndFilterByShowCompleted() {
        let reminders = [
            makeReminder(title: "done", due: makeDate(10, 10), isCompleted: true),
            makeReminder(title: "done-no-date", due: nil, isCompleted: true),
            makeReminder(title: "todo", due: makeDate(10, 17))
        ]

        for colorMode in RemindersBoardColorMode.allCases {
            let visible = makeSnapshot(reminders, colorMode: colorMode, showCompleted: true)
                .groups[0].rows
            XCTAssertEqual(visible.count, 3)

            let done = visible.first { $0.title == "done" }
            XCTAssertEqual(done?.colorHex, BoardColorPreferences.classic.completed)
            XCTAssertTrue(done?.isCompleted ?? false)

            let doneNoDate = visible.first { $0.title == "done-no-date" }
            XCTAssertEqual(doneNoDate?.colorHex, BoardColorPreferences.classic.completed)
        }

        // Distinct noDate palette proves a completed no-date row gets the
        // completed color rather than the no-date one.
        var distinctPalette = BoardColorPreferences.classic
        distinctPalette.noDate = "#00FF00"

        let withDistinctNoDate = makeSnapshot(
            [makeReminder(title: "done-no-date", due: nil, isCompleted: true)],
            colorPreferences: distinctPalette,
            showCompleted: true
        ).groups[0].rows

        XCTAssertEqual(withDistinctNoDate.first?.colorHex, distinctPalette.completed)

        let hidden = makeSnapshot(reminders, showCompleted: false)
        XCTAssertEqual(hidden.groups[0].rows.map(\.title), ["todo"])
        XCTAssertEqual(hidden.incompleteCount, 1)
    }

    func testIncompleteCountCountsOnlyIncompleteRows() {
        let snapshot = makeSnapshot(
            [
                makeReminder(title: "a", isCompleted: true),
                makeReminder(title: "b"),
                makeReminder(title: "c")
            ],
            showCompleted: true
        )

        XCTAssertEqual(snapshot.groups[0].rows.count, 3)
        XCTAssertEqual(snapshot.incompleteCount, 2)
    }

    // MARK: - Completed retention window

    func testCompletedRowsFilterByRetentionWindowAndFlagPendingHide() {
        let snapshot = makeSnapshot(
            [
                makeReminder(
                    title: "fresh",
                    isCompleted: true,
                    completedAt: now.addingTimeInterval(-1)
                ),
                makeReminder(
                    title: "boundary",
                    isCompleted: true,
                    completedAt: now.addingTimeInterval(-3)
                ),
                makeReminder(
                    title: "stale",
                    isCompleted: true,
                    completedAt: now.addingTimeInterval(-10)
                )
            ],
            retentionSeconds: 3
        )

        // Strict boundary: a row completed exactly at now - retentionSeconds
        // is dropped. The completed-without-completionDate branch cannot be
        // built in memory (EventKit couples the two), so it has no test here.
        XCTAssertEqual(snapshot.groups[0].rows.map(\.title), ["fresh"])
        XCTAssertTrue(snapshot.groups[0].rows[0].isPendingHide)
        XCTAssertEqual(snapshot.incompleteCount, 0)
    }

    func testZeroRetentionHidesCompletedRowsImmediately() {
        let snapshot = makeSnapshot(
            [
                makeReminder(
                    title: "done",
                    isCompleted: true,
                    completedAt: now.addingTimeInterval(-0.5)
                ),
            ],
            retentionSeconds: 0
        )

        XCTAssertTrue(snapshot.groups.isEmpty)
    }

    func testShowCompletedModeKeepsAllRowsPersistentWithoutPendingHideFlag() {
        let snapshot = makeSnapshot(
            [
                makeReminder(
                    title: "fresh",
                    isCompleted: true,
                    completedAt: now.addingTimeInterval(-1)
                ),
                makeReminder(
                    title: "old",
                    isCompleted: true,
                    completedAt: now.addingTimeInterval(-3600)
                )
            ],
            showCompleted: true,
            retentionSeconds: 3
        )

        XCTAssertEqual(snapshot.groups[0].rows.map(\.title), ["fresh", "old"])
        XCTAssertFalse(snapshot.groups[0].rows.contains { $0.isPendingHide })
    }

    func testIncompleteRowsUnaffectedByRetentionWindow() {
        let snapshot = makeSnapshot(
            [
                makeReminder(title: "todo", due: makeDate(10, 17)),
                makeReminder(
                    title: "done",
                    isCompleted: true,
                    completedAt: now.addingTimeInterval(-1)
                )
            ],
            retentionSeconds: 3
        )

        XCTAssertEqual(snapshot.groups[0].rows.map(\.title), ["todo", "done"])
        XCTAssertFalse(snapshot.groups[0].rows[0].isPendingHide)
        XCTAssertTrue(snapshot.groups[0].rows[1].isPendingHide)
    }

    // MARK: - Preset palettes

    func testPresetPalettesAreCompleteAndCustomHasNoPalette() {
        for preset in [BoardColorPreset.classic, .warm, .cool, .highContrast] {
            guard let palette = preset.colorPreferences else {
                XCTFail("\(preset) should provide a full palette")
                continue
            }

            for key in BoardColorKey.allCases {
                XCTAssertTrue(
                    palette.colorHex(for: key).hasPrefix("#"),
                    "\(preset).\(key) should be hex"
                )
            }
        }

        XCTAssertNil(BoardColorPreset.custom.colorPreferences)
    }

    func testPresetPalettesAreDistinct() {
        let palettes = [BoardColorPreset.classic, .warm, .cool, .highContrast]
            .compactMap(\.colorPreferences)
        XCTAssertEqual(Set(palettes).count, 4, "preset palettes should be distinct")
    }
}
