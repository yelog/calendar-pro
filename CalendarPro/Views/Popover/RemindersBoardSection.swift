import SwiftUI
import EventKit

/// Collapsible reminders board section; expanded content scrolls above 240pt.
struct RemindersBoardSection: View {
    private enum Metrics {
        static let expandedMaxHeight: CGFloat = 240
        static let chevronWidth: CGFloat = 12
        static let priorityDotSize: CGFloat = 6
        static let rowLeadingIndent: CGFloat = 18
    }

    let reminders: [EKReminder]
    let groupingMode: RemindersBoardGroupingMode
    let colorMode: RemindersBoardColorMode
    let colorPreferences: BoardColorPreferences
    let showCompleted: Bool
    /// Seconds a completed row stays visible (0 hides immediately);
    /// only used when show-completed is off.
    let completedRetentionSeconds: Int
    @ObservedObject var timeRefreshCoordinator: TimeRefreshCoordinator
    let onToggleReminder: (EKReminder) -> Void

    @State private var isExpanded = false

    private func makeSnapshot() -> BoardSnapshot {
        BoardSnapshot.make(
            reminders: reminders,
            now: timeRefreshCoordinator.currentDate,
            calendar: .autoupdatingCurrent,
            groupingMode: groupingMode,
            colorMode: colorMode,
            colorPreferences: colorPreferences,
            showCompleted: showCompleted,
            retentionSeconds: completedRetentionSeconds
        )
    }

    // Rows are pure values; map row ids back to EKReminder for the toggle callback.
    private var remindersByID: [String: EKReminder] {
        Dictionary(
            reminders.map { ($0.calendarItemIdentifier, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    var body: some View {
        let snapshot = makeSnapshot()

        return VStack(alignment: .leading, spacing: 8) {
            header(snapshot)

            if isExpanded {
                boardContent(snapshot)
            }
        }
    }

    // MARK: - Header

    private func header(_ snapshot: BoardSnapshot) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: Metrics.chevronWidth)

                Text(L("提醒事项看板"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .lineLimit(1)

                Spacer(minLength: 12)

                if snapshot.incompleteCount > 0 {
                    Text("\(snapshot.incompleteCount)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .fixedSize()
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("calendar-popover-reminders-board-header")
    }

    // MARK: - Expanded content

    @ViewBuilder
    private func boardContent(_ snapshot: BoardSnapshot) -> some View {
        if snapshot.groups.isEmpty {
            Text(L("暂无提醒事项"))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
        } else {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(snapshot.groups) { group in
                        boardGroup(group)
                    }
                }
                .padding(.vertical, 1)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: Metrics.expandedMaxHeight)
        }
    }

    private func boardGroup(_ group: BoardSnapshotGroup) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(boardColorHex: group.colorHex))
                    .frame(width: 7, height: 7)

                Text(group.title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }

            let remindersByID = remindersByID
            ForEach(group.rows) { row in
                boardRow(row, reminder: remindersByID[row.id])
            }
        }
    }

    // MARK: - Task row

    private func boardRow(_ row: RemindersBoardRow, reminder: EKReminder?) -> some View {
        HStack(spacing: 6) {
            Button {
                if let reminder {
                    onToggleReminder(reminder)
                }
            } label: {
                if row.isPendingHide {
                    BlinkingCheckboxIcon(colorHex: row.colorHex)
                } else {
                    Image(systemName: row.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(
                            row.isCompleted ? Color(boardColorHex: row.colorHex) : .secondary
                        )
                }
            }
            .buttonStyle(.plain)
            .disabled(reminder == nil)
            .help(L("已完成"))

            Circle()
                .fill(Color(boardColorHex: priorityDotColorHex(for: row)))
                .frame(width: Metrics.priorityDotSize, height: Metrics.priorityDotSize)
                .help(row.priority.displayTitle)

            Text(row.title)
                .font(.system(size: 12))
                .lineLimit(1)
                .truncationMode(.tail)
                .strikethrough(row.isCompleted)
                .foregroundStyle(row.isCompleted ? Color(boardColorHex: row.colorHex) : Color.primary)

            Spacer(minLength: 8)

            if let dueText = row.dueText {
                Text(dueText)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color(boardColorHex: row.colorHex))
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .padding(.leading, Metrics.rowLeadingIndent)
        .contentShape(Rectangle())
    }

    private func priorityDotColorHex(for row: RemindersBoardRow) -> String {
        if row.isCompleted {
            return colorPreferences.completed
        }

        switch row.priority {
        case .high: return colorPreferences.priorityHigh
        case .medium: return colorPreferences.priorityMedium
        case .low: return colorPreferences.priorityLow
        case .none: return colorPreferences.priorityNone
        }
    }
}

/// Checkbox icon that blinks (0.5s fade out, 0.5s fade in) to signal a row
/// recorded as completed and about to leave the board.
private struct BlinkingCheckboxIcon: View {
    let colorHex: String

    @State private var isDimmed = false

    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color(boardColorHex: colorHex))
            .opacity(isDimmed ? 0.15 : 1)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    isDimmed = true
                }
            }
    }
}
