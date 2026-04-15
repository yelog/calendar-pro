import SwiftUI

struct MonthHeaderView: View {
    let displayedMonth: Date
    let showVacationGuideButton: Bool
    let isVacationGuideEnabled: Bool
    let vacationGuideDisabledReason: String?
    let onPreviousMonth: () -> Void
    let onNextMonth: () -> Void
    let onSelectYear: () -> Void
    let onSelectMonth: () -> Void
    let onOpenVacationGuide: () -> Void

    private var yearText: String {
        let formatter = DateFormatter()
        formatter.locale = AppLocalization.locale
        formatter.setLocalizedDateFormatFromTemplate("y")
        return formatter.string(from: displayedMonth)
    }

    private var monthText: String {
        let formatter = DateFormatter()
        formatter.locale = AppLocalization.locale
        formatter.setLocalizedDateFormatFromTemplate("MMMM")
        return formatter.string(from: displayedMonth)
    }

    var body: some View {
        HStack(spacing: 12) {
            navigationButton(
                systemImage: "chevron.left",
                label: L("Previous Month"),
                identifier: "previous-month-button",
                action: onPreviousMonth
            )

            Spacer()

            HStack(spacing: 4) {
                Button(action: onSelectYear) {
                    Text(yearText)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)

                Button(action: onSelectMonth) {
                    Text(monthText)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            HStack(spacing: 8) {
                if showVacationGuideButton {
                    Button(action: onOpenVacationGuide) {
                        Text("休假")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(isVacationGuideEnabled ? Color.accentColor : .secondary)
                            .padding(.horizontal, 8)
                            .frame(height: 28)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(
                                        isVacationGuideEnabled
                                            ? Color.accentColor.opacity(0.12)
                                            : Color.primary.opacity(0.06)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!isVacationGuideEnabled)
                    .accessibilityIdentifier("vacation-guide-button")
                    .help(vacationGuideDisabledReason ?? "查看年度休假建议")
                }

                navigationButton(
                    systemImage: "chevron.right",
                    label: L("Next Month"),
                    identifier: "next-month-button",
                    action: onNextMonth
                )
            }
        }
    }

    private func navigationButton(
        systemImage: String,
        label: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.07))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }
}
