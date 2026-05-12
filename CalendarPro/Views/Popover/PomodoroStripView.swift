import SwiftUI

struct PomodoroStripView: View {
    @Environment(\.colorScheme) private var colorScheme

    let state: PomodoroTimerController.State
    let onStartFocus: () -> Void
    let onPause: () -> Void
    let onResume: () -> Void
    let onSkip: () -> Void
    let onEnd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                phaseBadge

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
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pomodoro-strip")
    }

    private var phaseBadge: some View {
        ZStack {
            Circle()
                .fill(accentColor.opacity(colorScheme == .dark ? 0.22 : 0.14))
            Image(systemName: phaseIconName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accentColor)
        }
        .frame(width: 30, height: 30)
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
