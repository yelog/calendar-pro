import SwiftUI

struct MonthHeaderView: View {
    let displayedMonth: Date
    let onPreviousMonth: () -> Void
    let onNextMonth: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            navigationButton(
                systemImage: "chevron.left",
                label: "上一月",
                identifier: "previous-month-button",
                action: onPreviousMonth
            )

            Spacer()

            Text(displayedMonth, format: .dateTime.year().month(.wide))
                .font(.system(.title3, design: .rounded).weight(.semibold))

            Spacer()

            navigationButton(
                systemImage: "chevron.right",
                label: "下一月",
                identifier: "next-month-button",
                action: onNextMonth
            )
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
