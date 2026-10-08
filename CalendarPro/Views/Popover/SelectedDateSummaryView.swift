import SwiftUI

struct SelectedDateSummaryView: View {
    let summary: SelectedDateSummary

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 8) {
                dateLine
                if !summary.chips.isEmpty {
                    HStack(spacing: 4) {
                        chipViews
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
            }
            .fixedSize(horizontal: true, vertical: false)

            VStack(alignment: .leading, spacing: 5) {
                adaptiveDateGroup
                if !summary.chips.isEmpty {
                    SummaryChipFlowLayout(horizontalSpacing: 4, verticalSpacing: 5) {
                        chipViews
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText))
        .accessibilityIdentifier("calendar-popover-selected-date-summary")
    }

    private var dateLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(summary.solarDateText)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: true, vertical: false)

            Text(summary.weekdayText)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: true, vertical: false)

            if let lunarDateText = summary.lunarDateText {
                Text(L("Lunar"))
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.leading, 4)

                Text(lunarDateText)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    private var adaptiveDateGroup: some View {
        ViewThatFits(in: .horizontal) {
            dateLine
                .fixedSize(horizontal: true, vertical: false)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(summary.solarDateText)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(summary.weekdayText)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                if let lunarDateText = summary.lunarDateText {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(L("Lunar"))
                            .foregroundStyle(.secondary)
                        Text(lunarDateText)
                            .foregroundStyle(.primary)
                    }
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var chipViews: some View {
        ForEach(summary.chips) { chip in
            chipView(chip)
        }
    }

    private func chipView(_ chip: CalendarDayDisplayMetadata.Chip) -> some View {
        Text(chip.text)
            .font(.system(size: chipFontSize(for: chip.style), weight: .medium, design: .rounded))
            .foregroundStyle(chipForegroundColor(for: chip.style))
            .multilineTextAlignment(.leading)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, chipHorizontalPadding(for: chip.style))
            .padding(.vertical, 3)
            .frame(minHeight: chipMinimumHeight(for: chip.style), alignment: .center)
            .background {
                Capsule(style: .continuous)
                    .fill(chipFillColor(for: chip.style))
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(chipBorderColor(for: chip.style), lineWidth: 0.5)
            }
            .accessibilityHidden(true)
    }

    private var accessibilityText: String {
        var components = [summary.fullSolarDateText]
        if let lunarDateText = summary.lunarDateText {
            components.append("\(L("Lunar")) \(lunarDateText)")
        }
        components.append(contentsOf: summary.chips.map { chip in
            switch chip.style {
            case .dayOff:
                L("Day off")
            case .workday:
                "\(chip.text), \(L("Adjusted working day"))"
            case .primary, .supplemental:
                chip.text
            }
        })
        return components.joined(separator: ", ")
    }

    private func chipFontSize(for style: CalendarDayDisplayMetadata.Chip.Style) -> CGFloat {
        style == .dayOff || style == .workday ? 9.5 : 10
    }

    private func chipHorizontalPadding(for style: CalendarDayDisplayMetadata.Chip.Style) -> CGFloat {
        style == .dayOff || style == .workday ? 5 : 6
    }

    private func chipMinimumHeight(for style: CalendarDayDisplayMetadata.Chip.Style) -> CGFloat {
        style == .dayOff || style == .workday ? 17 : 19
    }

    private func chipForegroundColor(for style: CalendarDayDisplayMetadata.Chip.Style) -> Color {
        switch style {
        case .primary:
            colorScheme == .dark
                ? Color(red: 1.0, green: 0.64, blue: 0.64)
                : Color(red: 0.70, green: 0.20, blue: 0.23)
        case .supplemental:
            colorScheme == .dark
                ? Color(red: 1.0, green: 0.70, blue: 0.46)
                : Color(red: 0.58, green: 0.32, blue: 0.08)
        case .dayOff:
            colorScheme == .dark
                ? Color(red: 1.0, green: 0.68, blue: 0.70)
                : Color(red: 0.74, green: 0.19, blue: 0.25)
        case .workday:
            colorScheme == .dark
                ? Color(red: 0.58, green: 0.74, blue: 0.96)
                : Color(red: 0.12, green: 0.36, blue: 0.68)
        }
    }

    private func chipFillColor(for style: CalendarDayDisplayMetadata.Chip.Style) -> Color {
        switch style {
        case .primary:
            Color(red: 1.0, green: 0.24, blue: 0.30).opacity(colorScheme == .dark ? 0.13 : 0.07)
        case .supplemental:
            Color(red: 1.0, green: 0.58, blue: 0.18).opacity(colorScheme == .dark ? 0.12 : 0.07)
        case .dayOff:
            Color(red: 1.0, green: 0.22, blue: 0.30).opacity(colorScheme == .dark ? 0.16 : 0.08)
        case .workday:
            Color(red: 0.18, green: 0.48, blue: 0.88).opacity(colorScheme == .dark ? 0.18 : 0.09)
        }
    }

    private func chipBorderColor(for style: CalendarDayDisplayMetadata.Chip.Style) -> Color {
        switch style {
        case .primary:
            Color(red: 0.88, green: 0.20, blue: 0.26).opacity(colorScheme == .dark ? 0.24 : 0.15)
        case .supplemental:
            Color(red: 0.86, green: 0.42, blue: 0.04).opacity(colorScheme == .dark ? 0.22 : 0.14)
        case .dayOff:
            Color(red: 0.88, green: 0.18, blue: 0.26).opacity(colorScheme == .dark ? 0.26 : 0.16)
        case .workday:
            Color(red: 0.24, green: 0.54, blue: 0.90).opacity(colorScheme == .dark ? 0.30 : 0.18)
        }
    }
}

struct SummaryChipFlowPlan: Equatable {
    let size: CGSize
    let origins: [CGPoint]
    let itemSizes: [CGSize]
}

enum SummaryChipFlowPlanner {
    static func plan(
        sizes: [CGSize],
        availableWidth: CGFloat,
        horizontalSpacing: CGFloat,
        verticalSpacing: CGFloat
    ) -> SummaryChipFlowPlan {
        guard !sizes.isEmpty else {
            return SummaryChipFlowPlan(size: .zero, origins: [], itemSizes: [])
        }

        let widthLimit = availableWidth.isFinite ? max(0, availableWidth) : .greatestFiniteMagnitude
        var origins: [CGPoint] = []
        var itemSizes: [CGSize] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var contentWidth: CGFloat = 0
        var isRowEmpty = true

        for size in sizes {
            let itemWidth = min(max(0, size.width), widthLimit)
            let itemHeight = max(0, size.height)
            if !isRowEmpty, x + horizontalSpacing + itemWidth > widthLimit {
                y += rowHeight + verticalSpacing
                x = 0
                rowHeight = 0
                isRowEmpty = true
            }

            if !isRowEmpty {
                x += horizontalSpacing
            }
            origins.append(CGPoint(x: x, y: y))
            itemSizes.append(CGSize(width: itemWidth, height: itemHeight))
            x += itemWidth
            contentWidth = max(contentWidth, x)
            rowHeight = max(rowHeight, itemHeight)
            isRowEmpty = false
        }

        return SummaryChipFlowPlan(
            size: CGSize(width: contentWidth, height: y + rowHeight),
            origins: origins,
            itemSizes: itemSizes
        )
    }
}

struct SummaryChipFlowLayout: Layout {
    var horizontalSpacing: CGFloat = 4
    var verticalSpacing: CGFloat = 5

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        makePlan(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let plan = makePlan(
            proposal: ProposedViewSize(width: bounds.width, height: proposal.height),
            subviews: subviews
        )
        let placedOrigins = Self.placementOrigins(for: plan, in: bounds)
        for (index, subview) in subviews.enumerated() {
            let origin = placedOrigins[index]
            let itemSize = plan.itemSizes[index]
            subview.place(
                at: origin,
                anchor: .topLeading,
                proposal: ProposedViewSize(width: itemSize.width, height: itemSize.height)
            )
        }
    }

    static func placementOrigins(for plan: SummaryChipFlowPlan, in bounds: CGRect) -> [CGPoint] {
        plan.origins.map { CGPoint(x: bounds.minX + $0.x, y: bounds.minY + $0.y) }
    }

    private func makePlan(proposal: ProposedViewSize, subviews: Subviews) -> SummaryChipFlowPlan {
        let availableWidth = proposal.width ?? .greatestFiniteMagnitude
        let widths = subviews.map { subview -> CGSize in
            let idealSize = subview.sizeThatFits(.unspecified)
            guard availableWidth.isFinite, idealSize.width > availableWidth else {
                return idealSize
            }
            return subview.sizeThatFits(ProposedViewSize(width: availableWidth, height: nil))
        }

        return SummaryChipFlowPlanner.plan(
            sizes: widths,
            availableWidth: availableWidth,
            horizontalSpacing: horizontalSpacing,
            verticalSpacing: verticalSpacing
        )
    }
}

#Preview("Selected date summary") {
    SelectedDateSummaryView(
        summary: SelectedDateSummary(
            date: Date(),
            solarDateText: "10月1日",
            weekdayText: "周四",
            fullSolarDateText: "2026年10月1日，星期四",
            lunarDateText: "丙午年八月廿一",
            chips: [
                .init(text: "国庆节", style: .primary),
                .init(text: "休", style: .dayOff)
            ]
        )
    )
    .padding(16)
    .frame(width: 308, alignment: .leading)
}
