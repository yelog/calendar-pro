import AppKit
import EventKit
import Foundation
import SwiftUI

/// Board grouping mode: by reminder list or by priority tier.
enum RemindersBoardGroupingMode: String, Codable, CaseIterable, Identifiable {
    case list
    case priority

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .list: return L("按列表")
        case .priority: return L("按优先级")
        }
    }
}

/// Board color mode: overdue/not-overdue duo, or per-time-bucket colors.
enum RemindersBoardColorMode: String, Codable, CaseIterable, Identifiable {
    case overdue
    case timeBucket

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .overdue: return L("逾期着色")
        case .timeBucket: return L("时间分段着色")
        }
    }
}

/// Priority tier mapped from EKReminder.priority (0 none; 1-3 high; 4-6 medium;
/// 7-9 low). rawValue doubles as the group display order: high first, none last.
enum ReminderBoardPriority: Int, Codable, CaseIterable, Identifiable {
    case high = 0
    case medium = 1
    case low = 2
    case none = 3

    var id: Int { rawValue }

    init(ekPriority: Int) {
        switch ekPriority {
        case 1...3: self = .high
        case 4...6: self = .medium
        case 7...9: self = .low
        default: self = .none
        }
    }

    var displayTitle: String {
        switch self {
        case .high: return L("高")
        case .medium: return L("中")
        case .low: return L("低")
        case .none: return L("无")
        }
    }
}

extension EKReminder {
    var boardPriority: ReminderBoardPriority {
        ReminderBoardPriority(ekPriority: priority)
    }
}

/// Due-time bucket: past (before today), today, this week (within 7 days of
/// today's start), later, or no date.
enum ReminderBoardTimeBucket: Equatable {
    case past
    case today
    case thisWeek
    case later
    case none

    static func resolve(
        dueDate: Date?,
        now: Date,
        calendar: Calendar
    ) -> ReminderBoardTimeBucket {
        guard let dueDate else { return .none }

        let dayStart = calendar.startOfDay(for: now)
        let dueStart = calendar.startOfDay(for: dueDate)

        if dueStart < dayStart {
            return .past
        }
        if dueStart == dayStart {
            return .today
        }

        // Week window: 7 days starting at today's midnight, exclusive of day 8.
        guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: dayStart) else {
            return .later
        }
        return dueStart < weekEnd ? .thisWeek : .later
    }
}

/// Display-ready board row derived from an EKReminder, colors resolved to hex.
struct RemindersBoardRow: Identifiable, Equatable {
    let id: String
    let title: String
    let listName: String
    let listColorHex: String
    let isCompleted: Bool
    let dueDate: Date?
    let dueText: String?
    let priority: ReminderBoardPriority
    let bucket: ReminderBoardTimeBucket
    let colorHex: String
    /// True while a just-completed row is inside the retention window: the
    /// checkbox blinks until a delayed refresh removes the row.
    let isPendingHide: Bool
}

/// Board group; title and header color follow the grouping mode
/// (list name with list color, or priority tier with priority color).
struct BoardSnapshotGroup: Identifiable, Equatable {
    let id: String
    let title: String
    let colorHex: String
    let rows: [RemindersBoardRow]
}

/// Board layout snapshot: grouped rows plus the incomplete count.
struct BoardSnapshot: Equatable {
    let groups: [BoardSnapshotGroup]
    let incompleteCount: Int

    /// Builds the grouped, sorted and colored snapshot for the given reminders.
    static func make(
        reminders: [EKReminder],
        now: Date,
        calendar: Calendar = .autoupdatingCurrent,
        groupingMode: RemindersBoardGroupingMode,
        colorMode: RemindersBoardColorMode,
        colorPreferences: BoardColorPreferences,
        showCompleted: Bool,
        retentionSeconds: Int = 0
    ) -> BoardSnapshot {
        let visibleReminders = reminders.filter { reminder in
            if showCompleted || !reminder.isCompleted {
                return true
            }
            return isWithinRetentionWindow(
                reminder,
                now: now,
                retentionSeconds: retentionSeconds
            )
        }

        let rows = visibleReminders
            .map {
                makeRow(
                    for: $0,
                    now: now,
                    calendar: calendar,
                    colorMode: colorMode,
                    colorPreferences: colorPreferences,
                    showCompleted: showCompleted,
                    retentionSeconds: retentionSeconds
                )
            }
            .sorted(by: makeRowComparator(calendar: calendar))

        let groups: [BoardSnapshotGroup]
        switch groupingMode {
        case .list:
            groups = listGroups(from: rows)
        case .priority:
            groups = priorityGroups(from: rows, colorPreferences: colorPreferences)
        }

        let incompleteCount = rows.filter { !$0.isCompleted }.count
        return BoardSnapshot(groups: groups, incompleteCount: incompleteCount)
    }

    // MARK: - Row building

    private static func isWithinRetentionWindow(
        _ reminder: EKReminder,
        now: Date,
        retentionSeconds: Int
    ) -> Bool {
        guard retentionSeconds > 0, let completionDate = reminder.completionDate else {
            return false
        }
        return completionDate > now.addingTimeInterval(-Double(retentionSeconds))
    }

    private static func makeRow(
        for reminder: EKReminder,
        now: Date,
        calendar: Calendar,
        colorMode: RemindersBoardColorMode,
        colorPreferences: BoardColorPreferences,
        showCompleted: Bool,
        retentionSeconds: Int
    ) -> RemindersBoardRow {
        let dueDate = reminder.dueDateComponents.flatMap { calendar.date(from: $0) }
        let hasExplicitTime = reminder.dueDateComponents.map { components in
            components.hour != nil || components.minute != nil || components.second != nil
        } ?? false
        let bucket = ReminderBoardTimeBucket.resolve(dueDate: dueDate, now: now, calendar: calendar)
        let identifier = reminder.calendarItemIdentifier
        let fallbackIdentifier = "unsaved-\(reminder.title ?? "")-\(dueDate?.timeIntervalSinceReferenceDate ?? 0)"
        let isPendingHide = !showCompleted
            && reminder.isCompleted
            && isWithinRetentionWindow(reminder, now: now, retentionSeconds: retentionSeconds)

        return RemindersBoardRow(
            id: identifier.isEmpty ? fallbackIdentifier : identifier,
            title: reminder.title?.isEmpty == false ? reminder.title! : L("无标题"),
            listName: reminder.calendar?.title.isEmpty == false ? reminder.calendar!.title : L("未知列表"),
            listColorHex: hexString(from: reminder.calendar?.color),
            isCompleted: reminder.isCompleted,
            dueDate: dueDate,
            dueText: dueDate.map { dueText(for: $0, includesTime: hasExplicitTime) },
            priority: reminder.boardPriority,
            bucket: bucket,
            colorHex: resolveColorHex(
                isCompleted: reminder.isCompleted,
                bucket: bucket,
                colorMode: colorMode,
                colorPreferences: colorPreferences
            ),
            isPendingHide: isPendingHide
        )
    }

    private static func resolveColorHex(
        isCompleted: Bool,
        bucket: ReminderBoardTimeBucket,
        colorMode: RemindersBoardColorMode,
        colorPreferences: BoardColorPreferences
    ) -> String {
        if isCompleted {
            return colorPreferences.completed
        }
        guard bucket != .none else {
            return colorPreferences.noDate
        }

        switch colorMode {
        case .overdue:
            return bucket == .past ? colorPreferences.overdue : colorPreferences.notOverdue
        case .timeBucket:
            switch bucket {
            case .past: return colorPreferences.past
            case .today: return colorPreferences.today
            case .thisWeek: return colorPreferences.thisWeek
            case .later: return colorPreferences.later
            case .none: return colorPreferences.noDate
            }
        }
    }

    // MARK: - Sorting and grouping

    private static func makeRowComparator(calendar: Calendar)
    -> (RemindersBoardRow, RemindersBoardRow) -> Bool {
        { lhs, rhs in
            switch (lhs.dueDate, rhs.dueDate) {
            case let (lhsDate?, rhsDate?):
                if lhsDate != rhsDate {
                    return lhsDate < rhsDate
                }
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                break
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    private static func listGroups(from rows: [RemindersBoardRow]) -> [BoardSnapshotGroup] {
        let grouped = Dictionary(grouping: rows, by: \.listName)
        return grouped
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
            .map { listName, groupRows in
                BoardSnapshotGroup(
                    id: "list-\(listName)",
                    title: listName,
                    colorHex: groupRows.first?.listColorHex ?? "#8E8E93",
                    rows: groupRows
                )
            }
    }

    private static func priorityGroups(
        from rows: [RemindersBoardRow],
        colorPreferences: BoardColorPreferences
    ) -> [BoardSnapshotGroup] {
        ReminderBoardPriority.allCases.compactMap { priority in
            let groupRows = rows.filter { $0.priority == priority }
            guard !groupRows.isEmpty else { return nil }

            let headerColorHex: String
            switch priority {
            case .high: headerColorHex = colorPreferences.priorityHigh
            case .medium: headerColorHex = colorPreferences.priorityMedium
            case .low: headerColorHex = colorPreferences.priorityLow
            case .none: headerColorHex = colorPreferences.priorityNone
            }

            return BoardSnapshotGroup(
                id: "priority-\(priority.rawValue)",
                title: priority.displayTitle,
                colorHex: headerColorHex,
                rows: groupRows
            )
        }
    }

    // MARK: - Display helpers

    // Formatters are cached by (includesTime, locale): DateFormatter creation
    // is expensive, and the lock guards the cache from tests off the main thread.
    private nonisolated(unsafe) static var dueTextFormatters: [String: DateFormatter] = [:]
    private static let dueTextFormattersLock = NSLock()

    private static func dueText(for date: Date, includesTime: Bool) -> String {
        let locale = AppLocalization.locale
        let key = "\(includesTime)-\(locale.identifier)"

        dueTextFormattersLock.lock()
        defer { dueTextFormattersLock.unlock() }

        if let cached = dueTextFormatters[key] {
            return cached.string(from: date)
        }

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate(includesTime ? "MdHm" : "Md")
        dueTextFormatters[key] = formatter
        return formatter.string(from: date)
    }

    /// Converts to "#RRGGBB" in sRGB; falls back to neutral gray otherwise.
    static func hexString(from color: NSColor?) -> String {
        guard let srgb = color?.usingColorSpace(.sRGB) else {
            return "#8E8E93"
        }

        let red = Int(round(srgb.redComponent * 255))
        let green = Int(round(srgb.greenComponent * 255))
        let blue = Int(round(srgb.blueComponent * 255))
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}

extension Color {
    /// Creates a color from a "#RRGGBB" string; falls back to the secondary
    /// label color when parsing fails.
    init(boardColorHex hex: String) {
        let value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard value.count == 6, let integer = UInt64(value, radix: 16) else {
            self.init(nsColor: .secondaryLabelColor)
            return
        }

        self.init(
            red: Double((integer >> 16) & 0xFF) / 255,
            green: Double((integer >> 8) & 0xFF) / 255,
            blue: Double(integer & 0xFF) / 255
        )
    }
}
