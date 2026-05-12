import SwiftUI

struct PomodoroSettingsView: View {
    @ObservedObject var store: SettingsStore
    @ObservedObject var statsStore: PomodoroStatsStore

    private var todaySummary: PomodoroStatsSummary { statsStore.summary(forRecentDays: 1) }
    private var sevenDaySummary: PomodoroStatsSummary { statsStore.summary(forRecentDays: 7) }
    private var thirtyDaySummary: PomodoroStatsSummary { statsStore.summary(forRecentDays: 30) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                GeneralSettingsSection(L("Pomodoro")) {
                    GeneralSettingsRow(
                        title: L("Enable Pomodoro Timer"),
                        description: L("Enable Pomodoro Timer Description")
                    ) {
                        Toggle("", isOn: enabledBinding)
                            .labelsHidden()
                    }
                }

                GeneralSettingsSection(L("Menu Bar Style")) {
                    VStack(alignment: .leading, spacing: 14) {
                        Picker("", selection: styleBinding) {
                            ForEach(PomodoroMenuBarStyle.allCases) { style in
                                Text(styleTitle(style)).tag(style)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 360)
                        .disabled(!store.pomodoroPreferences.isEnabled)

                        menuBarPreview

                        Text(L("Pomodoro Menu Bar Style Description"))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GeneralSettingsSection(L("Statistics")) {
                    VStack(alignment: .leading, spacing: 16) {
                        todayCards
                        sevenDayRhythm
                        thirtyDayTrend
                        completionQuality
                        legend
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 30)
            .padding(.vertical, 24)
        }
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { store.pomodoroPreferences.isEnabled },
            set: { store.setPomodoroEnabled($0) }
        )
    }

    private var styleBinding: Binding<PomodoroMenuBarStyle> {
        Binding(
            get: { store.pomodoroPreferences.menuBarStyle },
            set: { store.setPomodoroMenuBarStyle($0) }
        )
    }

    private var menuBarPreview: some View {
        let sampleState = PomodoroTimerController.State(
            phase: .focus,
            remainingSeconds: 18 * 60 + 42,
            totalSeconds: PomodoroTimerController.focusDuration,
            completedFocusCount: 1,
            isPaused: false
        )
        let suffix = PomodoroMenuBarFormatter.suffix(
            for: sampleState,
            preferences: store.pomodoroPreferences
        ) ?? L("Pomodoro Hidden")

        return HStack(spacing: 10) {
            Text(L("Preview"))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            Text("05月12日 周二 10:30  \(suffix)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.055))
                )
        }
    }

    private var todayCards: some View {
        HStack(spacing: 12) {
            PomodoroStatCard(
                title: L("Completed Pomodoros"),
                value: "\(todaySummary.completedFocusCount)",
                detail: L("Today")
            )
            PomodoroStatCard(
                title: L("Focus Minutes"),
                value: "\(todaySummary.completedFocusMinutes)",
                detail: L("Today")
            )
        }
    }

    private var sevenDayRhythm: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("7-Day Rhythm"))
                .font(.system(size: 13, weight: .semibold))

            PomodoroBarChart(days: sevenDaySummary.days)
        }
    }

    private var thirtyDayTrend: some View {
        HStack(spacing: 12) {
            PomodoroStatCard(
                title: L("30-Day Focus"),
                value: "\(thirtyDaySummary.completedFocusMinutes)",
                detail: L("minutes")
            )
            PomodoroStatCard(
                title: L("Daily Average"),
                value: String(format: "%.0f", thirtyDaySummary.averageFocusMinutesPerDay),
                detail: L("minutes")
            )
            PomodoroStatCard(
                title: L("Best Day"),
                value: "\(thirtyDaySummary.bestDay?.focusCompletedCount ?? 0)",
                detail: L("pomodoros")
            )
        }
    }

    private var completionQuality: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("Completion Quality"))
                .font(.system(size: 13, weight: .semibold))

            HStack(spacing: 12) {
                PomodoroQualityMeter(
                    title: L("Completion Rate"),
                    value: thirtyDaySummary.completionRate,
                    color: .green
                )
                PomodoroQualityMeter(
                    title: L("Interruption Rate"),
                    value: thirtyDaySummary.interruptionRate,
                    color: .red
                )
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 14) {
            PomodoroLegendItem(color: .red.opacity(0.72), text: L("Completed focus"))
            PomodoroLegendItem(color: .green.opacity(0.72), text: L("Break phase"))
            PomodoroLegendItem(color: .gray.opacity(0.35), text: L("No record"))
            PomodoroLegendItem(color: .red.opacity(0.25), text: L("Skipped or interrupted"))
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
    }

    private func styleTitle(_ style: PomodoroMenuBarStyle) -> String {
        switch style {
        case .countdown:
            return L("Countdown")
        case .progress:
            return L("Progress")
        case .pie:
            return L("Pie")
        }
    }
}

private struct PomodoroStatCard: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(detail)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.045))
        )
    }
}

private struct PomodoroBarChart: View {
    let days: [PomodoroDailyStats]

    private var maxCount: Int {
        max(1, days.map(\.focusCompletedCount).max() ?? 1)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(days) { day in
                VStack(spacing: 6) {
                    ZStack(alignment: .bottom) {
                        Capsule()
                            .fill(Color.gray.opacity(0.16))
                        Capsule()
                            .fill(Color.red.opacity(day.focusCompletedCount > 0 ? 0.68 : 0))
                            .frame(height: CGFloat(day.focusCompletedCount) / CGFloat(maxCount) * 72)
                    }
                    .frame(width: 18, height: 72)

                    Text(shortDayLabel(day.dayKey))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.035))
        )
    }

    private func shortDayLabel(_ dayKey: String) -> String {
        String(dayKey.suffix(5)).replacingOccurrences(of: "-", with: "/")
    }
}

private struct PomodoroQualityMeter: View {
    let title: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(round(value * 100)))%")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.16))
                    Capsule()
                        .fill(color.opacity(0.68))
                        .frame(width: proxy.size.width * min(1, max(0, value)))
                }
            }
            .frame(height: 7)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.035))
        )
    }
}

private struct PomodoroLegendItem: View {
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
        }
    }
}
