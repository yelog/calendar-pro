import SwiftUI

struct PomodoroStripView: View {
    @Environment(\.colorScheme) private var colorScheme

    let state: PomodoroTimerController.State
    let onOpenStatistics: () -> Void
    let onStartFocus: () -> Void
    let onPause: () -> Void
    let onResume: () -> Void
    let onSkip: () -> Void
    let onEnd: () -> Void

    var body: some View {
        ZStack {
            Button(action: onOpenStatistics) {
                Color.clear
                    .contentShape(
                        RoundedRectangle(cornerRadius: PopoverSurfaceMetrics.cornerRadius, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .help(L("Statistics"))
            .accessibilityLabel(L("Statistics"))
            .accessibilityIdentifier("pomodoro-statistics-toggle")

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 10) {
                    statisticsIndicator

                    VStack(alignment: .leading, spacing: 2) {
                        Text(titleText)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                        Text(detailText)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    if state.isActive {
                        Text(PomodoroMenuBarFormatter.timeText(seconds: state.remainingSeconds))
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(accentColor)
                    }
                }

                if state.isActive {
                    progressBar
                }

                actionRow
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pomodoro-strip")
    }

    private var statisticsIndicator: some View {
        ZStack {
            Circle()
                .fill(accentColor.opacity(colorScheme == .dark ? 0.22 : 0.14))
            Image(systemName: phaseIconName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accentColor)
        }
        .frame(width: 30, height: 30)
        .accessibilityHidden(true)
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(accentColor.opacity(colorScheme == .dark ? 0.18 : 0.12))
                Capsule()
                    .fill(accentColor.opacity(0.72))
                    .frame(width: proxy.size.width * state.progress)
            }
        }
        .frame(height: 5)
        .accessibilityHidden(true)
    }

    private var actionRow: some View {
        HStack(spacing: 8) {
            switch state.phase {
            case .idle:
                Button(action: onStartFocus) {
                    Label(L("Start Focus"), systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            case .focus, .shortBreak, .longBreak:
                if state.isPaused {
                    Button(action: onResume) {
                        Label(L("Resume"), systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                } else {
                    Button(action: onPause) {
                        Label(L("Pause"), systemImage: "pause.fill")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Button(action: onSkip) {
                    Label(L("Skip"), systemImage: "forward.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: onEnd) {
                    Label(L("End"), systemImage: "xmark")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .labelStyle(.titleAndIcon)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: PopoverSurfaceMetrics.cornerRadius, style: .continuous)
            .fill(PopoverSurfaceMetrics.floatingPanelBaseFill(for: colorScheme))
            .overlay {
                RoundedRectangle(cornerRadius: PopoverSurfaceMetrics.cornerRadius, style: .continuous)
                    .fill(PopoverSurfaceMetrics.floatingPanelTintOverlay(accent: accentColor, for: colorScheme))
            }
            .overlay {
                RoundedRectangle(cornerRadius: PopoverSurfaceMetrics.cornerRadius, style: .continuous)
                    .stroke(PopoverSurfaceMetrics.floatingPanelBorderColor(for: colorScheme), lineWidth: 1)
            }
    }

    private var titleText: String {
        if state.isPaused {
            return L("Paused")
        }

        switch state.phase {
        case .idle:
            return L("Pomodoro")
        case .focus:
            return L("Focusing")
        case .shortBreak:
            return L("Short Break")
        case .longBreak:
            return L("Long Break")
        }
    }

    private var detailText: String {
        switch state.phase {
        case .idle:
            return L("25 min focus · 5 min break")
        case .focus:
            let next = state.completedFocusCount + 1 >= PomodoroTimerController.focusesBeforeLongBreak
                ? L("Long break next")
                : L("Short break next")
            return "\(LF("Round %d of 4", state.completedFocusCount + 1)) · \(next)"
        case .shortBreak, .longBreak:
            return L("Focus starts next")
        }
    }

    private var phaseIconName: String {
        switch state.phase {
        case .idle:
            return "timer"
        case .focus:
            return state.isPaused ? "pause.fill" : "flame.fill"
        case .shortBreak, .longBreak:
            return "leaf.fill"
        }
    }

    private var accentColor: Color {
        switch state.phase {
        case .idle:
            return Color(red: 0.86, green: 0.31, blue: 0.22)
        case .focus:
            return Color(red: 0.88, green: 0.28, blue: 0.18)
        case .shortBreak, .longBreak:
            return Color(red: 0.10, green: 0.58, blue: 0.45)
        }
    }
}

struct PomodoroStatisticsPanelView: View {
    @Environment(\.colorScheme) private var colorScheme

    let todaySummary: PomodoroStatsSummary
    let sevenDaySummary: PomodoroStatsSummary
    let onClose: () -> Void

    private let accentColor = Color(red: 0.86, green: 0.31, blue: 0.22)

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
                .padding(.top, 12)
            todaySection
            rhythmSection
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .padding(.bottom, 16)
        .background(panelBackground)
        .accessibilityIdentifier("pomodoro-statistics-panel")
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accentColor)
                .frame(width: 28, height: 28)
                .background(accentColor.opacity(colorScheme == .dark ? 0.2 : 0.12), in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(L("Statistics"))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Text(L("Pomodoro"))
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(L("Statistics"))
            .accessibilityLabel(L("Statistics"))
        }
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(L("Today"))

            HStack(spacing: 8) {
                metricCard(
                    title: L("Completed Pomodoros"),
                    value: "\(todaySummary.completedFocusCount)",
                    icon: "checkmark.circle.fill"
                )
                metricCard(
                    title: L("Focus Minutes"),
                    value: "\(todaySummary.completedFocusMinutes)",
                    icon: "clock.fill"
                )
            }
        }
    }

    private var rhythmSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(L("7-Day Rhythm"))

            VStack(alignment: .leading, spacing: 14) {
                sevenDayChart

                Divider()

                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(sevenDaySummary.completedFocusCount)")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        Text(L("Completed Pomodoros"))
                            .font(.system(size: 9.5))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int(round(sevenDaySummary.completionRate * 100)))%")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        Text(L("Completion Rate"))
                            .font(.system(size: 9.5))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(cardBackground)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
    }

    private func metricCard(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(accentColor)
            Text(value)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(title)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(11)
        .frame(maxWidth: .infinity, minHeight: 94, alignment: .leading)
        .background(cardBackground)
    }

    private var sevenDayChart: some View {
        let maxCount = max(1, sevenDaySummary.days.map(\.focusCompletedCount).max() ?? 1)

        return HStack(alignment: .bottom, spacing: 8) {
            ForEach(sevenDaySummary.days) { day in
                VStack(spacing: 5) {
                    Capsule()
                        .fill(
                            day.focusCompletedCount == 0
                                ? Color.secondary.opacity(0.14)
                                : accentColor.opacity(0.76)
                        )
                        .frame(
                            width: 8,
                            height: day.focusCompletedCount == 0
                                ? 5
                                : max(8, CGFloat(day.focusCompletedCount) / CGFloat(maxCount) * 48)
                        )
                    Text(String(day.dayKey.suffix(2)))
                        .font(.system(size: 8.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .bottom)
            }
        }
        .frame(height: 66, alignment: .bottom)
        .accessibilityHidden(true)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.primary.opacity(colorScheme == .dark ? 0.07 : 0.04))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(PopoverSurfaceMetrics.floatingPanelBorderColor(for: colorScheme), lineWidth: 1)
            }
    }

    private var panelBackground: some View {
        Rectangle()
            .fill(PopoverSurfaceMetrics.floatingPanelBaseFill(for: colorScheme))
            .overlay {
                LinearGradient(
                    colors: [accentColor.opacity(colorScheme == .dark ? 0.08 : 0.04), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
    }
}
