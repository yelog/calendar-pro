import Foundation

/// Board color preferences stored as "#RRGGBB" hex strings for Codable
/// persistence; the UI falls back to gray when a value fails to parse.
struct BoardColorPreferences: Codable, Equatable, Hashable {
    var overdue: String
    var notOverdue: String
    var past: String
    var today: String
    var thisWeek: String
    var later: String
    var noDate: String
    var priorityHigh: String
    var priorityMedium: String
    var priorityLow: String
    var priorityNone: String
    var completed: String

    /// Classic palette (the default).
    static let classic = BoardColorPreferences(
        overdue: "#DC2626",
        notOverdue: "#2563EB",
        past: "#DC2626",
        today: "#EA580C",
        thisWeek: "#2563EB",
        later: "#64748B",
        noDate: "#9CA3AF",
        priorityHigh: "#DC2626",
        priorityMedium: "#EA580C",
        priorityLow: "#2563EB",
        priorityNone: "#9CA3AF",
        completed: "#9CA3AF"
    )

    func colorHex(for key: BoardColorKey) -> String {
        switch key {
        case .overdue: return overdue
        case .notOverdue: return notOverdue
        case .past: return past
        case .today: return today
        case .thisWeek: return thisWeek
        case .later: return later
        case .noDate: return noDate
        case .priorityHigh: return priorityHigh
        case .priorityMedium: return priorityMedium
        case .priorityLow: return priorityLow
        case .priorityNone: return priorityNone
        case .completed: return completed
        }
    }

    mutating func setColorHex(_ hex: String, for key: BoardColorKey) {
        switch key {
        case .overdue: overdue = hex
        case .notOverdue: notOverdue = hex
        case .past: past = hex
        case .today: today = hex
        case .thisWeek: thisWeek = hex
        case .later: later = hex
        case .noDate: noDate = hex
        case .priorityHigh: priorityHigh = hex
        case .priorityMedium: priorityMedium = hex
        case .priorityLow: priorityLow = hex
        case .priorityNone: priorityNone = hex
        case .completed: completed = hex
        }
    }
}

/// Key identifying one board color in the settings color grid.
enum BoardColorKey: String, CaseIterable, Identifiable {
    case overdue
    case notOverdue
    case past
    case today
    case thisWeek
    case later
    case noDate
    case priorityHigh
    case priorityMedium
    case priorityLow
    case priorityNone
    case completed

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .overdue: return L("逾期")
        case .notOverdue: return L("未逾期")
        case .past: return L("过去")
        case .today: return L("今天")
        case .thisWeek: return L("本周")
        case .later: return L("更晚")
        case .noDate: return L("无日期")
        case .priorityHigh: return L("高优先级")
        case .priorityMedium: return L("中优先级")
        case .priorityLow: return L("低优先级")
        case .priorityNone: return L("无优先级")
        case .completed: return L("已完成")
        }
    }
}

/// Board color preset: picking one applies the whole palette; editing any
/// single color switches the preset to custom.
enum BoardColorPreset: String, Codable, CaseIterable, Identifiable {
    case classic
    case warm
    case cool
    case highContrast
    case custom

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .classic: return L("经典")
        case .warm: return L("暖色")
        case .cool: return L("冷色")
        case .highContrast: return L("高对比度")
        case .custom: return L("自定义")
        }
    }

    /// Full palette for the preset; nil for custom, which keeps current colors.
    var colorPreferences: BoardColorPreferences? {
        switch self {
        case .classic:
            return .classic
        case .warm:
            return BoardColorPreferences(
                overdue: "#B91C1C",
                notOverdue: "#D97706",
                past: "#B91C1C",
                today: "#EA580C",
                thisWeek: "#CA8A04",
                later: "#78716C",
                noDate: "#A8A29E",
                priorityHigh: "#B91C1C",
                priorityMedium: "#EA580C",
                priorityLow: "#CA8A04",
                priorityNone: "#A8A29E",
                completed: "#A8A29E"
            )
        case .cool:
            return BoardColorPreferences(
                overdue: "#DB2777",
                notOverdue: "#0284C7",
                past: "#DB2777",
                today: "#0891B2",
                thisWeek: "#2563EB",
                later: "#7C3AED",
                noDate: "#94A3B8",
                priorityHigh: "#DB2777",
                priorityMedium: "#0891B2",
                priorityLow: "#2563EB",
                priorityNone: "#94A3B8",
                completed: "#94A3B8"
            )
        case .highContrast:
            return BoardColorPreferences(
                overdue: "#D70015",
                notOverdue: "#0040DD",
                past: "#D70015",
                today: "#C93400",
                thisWeek: "#0040DD",
                later: "#5E5CE6",
                noDate: "#8E8E93",
                priorityHigh: "#D70015",
                priorityMedium: "#C93400",
                priorityLow: "#0040DD",
                priorityNone: "#8E8E93",
                completed: "#8E8E93"
            )
        case .custom:
            return nil
        }
    }
}
