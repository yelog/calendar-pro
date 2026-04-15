import SwiftUI

struct VacationOpportunityCardView: View {
    let opportunity: VacationOpportunity
    let onLocate: (Date) -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(opportunity.holidayName)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))

                Spacer(minLength: 8)

                Text(starText)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.orange)
            }

            Text(opportunity.summary)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text(dateRangeText)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(opportunity.segments) { segment in
                        segmentView(segment)
                    }
                }
            }

            Text(opportunity.note)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)

            HStack {
                Text("性价比 \(opportunity.starRating)/5")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    onLocate(opportunity.focusDate)
                } label: {
                    Text("定位到月历")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.accentColor.opacity(colorScheme == .dark ? 0.22 : 0.12))
                )
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(cardFillColor)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(cardBorderColor, lineWidth: 0.8)
        }
    }

    private var starText: String {
        String(repeating: "★", count: opportunity.starRating) + String(repeating: "☆", count: max(0, 5 - opportunity.starRating))
    }

    private var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.locale = AppLocalization.locale
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return "\(formatter.string(from: opportunity.startDate)) - \(formatter.string(from: opportunity.endDate))"
    }

    private func segmentView(_ segment: VacationSegment) -> some View {
        VStack(spacing: 2) {
            Text(dayText(for: segment.date))
                .font(.system(size: 9, weight: .semibold, design: .rounded))

            Text(segment.label)
                .font(.system(size: 9, weight: .bold, design: .rounded))
        }
        .foregroundStyle(segmentForegroundColor(for: segment.kind))
        .frame(width: 24, height: 36)
        .background {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(segmentFillColor(for: segment.kind))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(segmentBorderColor(for: segment.kind), lineWidth: 0.6)
        }
    }

    private func dayText(for date: Date) -> String {
        String(Calendar.current.component(.day, from: date))
    }

    private func segmentFillColor(for kind: VacationSegmentKind) -> Color {
        switch kind {
        case .weekend:
            return colorScheme == .dark
                ? Color.white.opacity(0.1)
                : Color(nsColor: .controlBackgroundColor).opacity(0.92)
        case .statutoryHoliday:
            return Color(red: 0.95, green: 0.61, blue: 0.18)
        case .leaveRequired:
            return colorScheme == .dark
                ? Color(red: 0.48, green: 0.14, blue: 0.18)
                : Color(red: 0.67, green: 0.19, blue: 0.24)
        case .adjustmentWorkday:
            return colorScheme == .dark
                ? Color(red: 0.15, green: 0.36, blue: 0.70)
                : Color(red: 0.20, green: 0.48, blue: 0.88)
        case .bridgeRestDay:
            return Color.accentColor.opacity(0.2)
        }
    }

    private func segmentBorderColor(for kind: VacationSegmentKind) -> Color {
        segmentFillColor(for: kind).opacity(colorScheme == .dark ? 0.7 : 0.4)
    }

    private func segmentForegroundColor(for kind: VacationSegmentKind) -> Color {
        switch kind {
        case .weekend:
            return .secondary
        case .statutoryHoliday, .leaveRequired, .adjustmentWorkday:
            return Color.white.opacity(0.96)
        case .bridgeRestDay:
            return .primary
        }
    }

    private var cardFillColor: Color {
        PopoverSurfaceMetrics.elevatedCardFillColor(for: colorScheme)
    }

    private var cardBorderColor: Color {
        PopoverSurfaceMetrics.elevatedCardBorderColor(for: colorScheme)
    }
}
