import AppKit
import EventKit
import SwiftUI

struct RemindersSettingsView: View {
    @ObservedObject var store: SettingsStore
    @ObservedObject var eventService: EventService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox(L("提醒看板")) {
                    VStack(alignment: .leading, spacing: 14) {
                        Toggle(L("显示提醒事项看板"), isOn: showRemindersBoardBinding)
                            .toggleStyle(.checkbox)

                        if store.menuBarPreferences.showRemindersBoard {
                            Divider()

                            if !eventService.remindersAuthorized {
                                permissionRow(
                                    title: L("Reminders Access Required"),
                                    buttonTitle: L("Request Access")
                                ) {
                                    Task {
                                        await eventService.requestReminderAccess()
                                    }
                                }
                            } else {
                                boardListsSection

                                Divider()

                                boardDisplaySection

                                Divider()

                                boardColorSection
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 24)
        }
    }

    private var showRemindersBoardBinding: Binding<Bool> {
        Binding(
            get: { store.menuBarPreferences.showRemindersBoard },
            set: { store.setShowRemindersBoard($0) }
        )
    }

    private var boardShowCompletedBinding: Binding<Bool> {
        Binding(
            get: { store.menuBarPreferences.boardShowCompleted },
            set: { store.setBoardShowCompleted($0) }
        )
    }

    private var boardCompletedRetentionSecondsBinding: Binding<Int> {
        Binding(
            get: { store.menuBarPreferences.boardCompletedRetentionSeconds },
            set: { store.setBoardCompletedRetentionSeconds($0) }
        )
    }

    private var boardGroupingModeBinding: Binding<RemindersBoardGroupingMode> {
        Binding(
            get: { store.menuBarPreferences.boardGroupingMode },
            set: { store.setBoardGroupingMode($0) }
        )
    }

    private var boardColorModeBinding: Binding<RemindersBoardColorMode> {
        Binding(
            get: { store.menuBarPreferences.boardColorMode },
            set: { store.setBoardColorMode($0) }
        )
    }

    private var boardColorPresetBinding: Binding<BoardColorPreset> {
        Binding(
            get: { store.menuBarPreferences.boardColorPreset },
            set: { store.setBoardColorPreset($0) }
        )
    }

    private func boardReminderCalendarEnabledBinding(for calendarID: String) -> Binding<Bool> {
        Binding(
            get: {
                let enabledIDs = store.menuBarPreferences.boardEnabledReminderCalendarIDs
                return enabledIDs.isEmpty || enabledIDs.contains(calendarID)
            },
            set: {
                store.setBoardReminderCalendarEnabled(
                    $0,
                    calendarID: calendarID,
                    allCalendarIDs: eventService.reminderCalendars.map(\.calendarIdentifier)
                )
            }
        )
    }

    private func boardColorBinding(for key: BoardColorKey) -> Binding<Color> {
        Binding(
            get: {
                let preferences = store.menuBarPreferences.boardColorPreferences
                return Color(boardColorHex: preferences.colorHex(for: key))
            },
            set: { color in
                store.setBoardColorHex(Self.hexString(from: color), for: key)
            }
        )
    }

    private static func hexString(from color: Color) -> String {
        guard let srgb = NSColor(color).usingColorSpace(.sRGB) else {
            return "#8E8E93"
        }

        let red = Int(round(srgb.redComponent * 255))
        let green = Int(round(srgb.greenComponent * 255))
        let blue = Int(round(srgb.blueComponent * 255))
        return String(format: "#%02X%02X%02X", red, green, blue)
    }

    private var boardListsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("看板提醒列表"))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            if eventService.reminderCalendars.isEmpty {
                Text(L("No Reminder Lists Available"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 4) {
                    ForEach(
                        eventService.reminderCalendars,
                        id: \.calendarIdentifier
                    ) { calendar in
                        HStack {
                            Circle()
                                .fill(Color(nsColor: calendar.color))
                                .frame(width: 10, height: 10)
                            Text(calendar.title)
                                .font(.system(size: 12))
                            Spacer()
                            Toggle(
                                "",
                                isOn: boardReminderCalendarEnabledBinding(
                                    for: calendar.calendarIdentifier
                                )
                            )
                            .toggleStyle(.checkbox)
                        }
                    }
                }
            }
        }
    }

    private var boardDisplaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(L("显示已完成"), isOn: boardShowCompletedBinding)
                .toggleStyle(.checkbox)

            HStack {
                Text(L("完成后保留显示"))
                    .font(.system(size: 12))
                Spacer()
                Picker(L("完成后保留显示"), selection: boardCompletedRetentionSecondsBinding) {
                    Text(L("立即隐藏")).tag(0)
                    Text(L("1 秒")).tag(1)
                    Text(L("3 秒")).tag(3)
                    Text(L("5 秒")).tag(5)
                    Text(L("10 秒")).tag(10)
                }
                .frame(width: 160)
                .labelsHidden()
            }

            HStack {
                Text(L("分组模式"))
                    .font(.system(size: 12))
                Spacer()
                Picker(L("分组模式"), selection: boardGroupingModeBinding) {
                    ForEach(RemindersBoardGroupingMode.allCases) { mode in
                        Text(mode.displayTitle).tag(mode)
                    }
                }
                .frame(width: 160)
                .labelsHidden()
            }

            HStack {
                Text(L("颜色模式"))
                    .font(.system(size: 12))
                Spacer()
                Picker(L("颜色模式"), selection: boardColorModeBinding) {
                    ForEach(RemindersBoardColorMode.allCases) { mode in
                        Text(mode.displayTitle).tag(mode)
                    }
                }
                .frame(width: 160)
                .labelsHidden()
            }
        }
    }

    private var boardColorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L("配色方案"))
                    .font(.system(size: 12))
                Spacer()
                Picker(L("配色方案"), selection: boardColorPresetBinding) {
                    ForEach(BoardColorPreset.allCases) { preset in
                        Text(preset.displayTitle).tag(preset)
                    }
                }
                .frame(width: 160)
                .labelsHidden()
            }

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                ForEach(boardColorKeyRows.indices, id: \.self) { rowIndex in
                    GridRow {
                        ForEach(boardColorKeyRows[rowIndex]) { key in
                            boardColorPickerCell(key: key)
                        }
                    }
                }
            }
        }
    }

    private let boardColorKeys = BoardColorKey.allCases

    private var boardColorKeyRows: [[BoardColorKey]] {
        stride(from: 0, to: boardColorKeys.count, by: 2).map { start in
            Array(boardColorKeys[start..<min(start + 2, boardColorKeys.count)])
        }
    }

    private func boardColorPickerCell(key: BoardColorKey) -> some View {
        HStack(spacing: 6) {
            ColorPicker(
                key.displayTitle,
                selection: boardColorBinding(for: key),
                supportsOpacity: false
            )
            .labelsHidden()
            .fixedSize()

            Text(key.displayTitle)
                .font(.system(size: 12))
        }
    }

    private func permissionRow(
        title: String,
        buttonTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Button(buttonTitle, action: action)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
    }
}
