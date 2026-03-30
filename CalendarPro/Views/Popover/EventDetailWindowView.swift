import SwiftUI
import EventKit

struct EventDetailWindowView: View {
    let event: EKEvent
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("日程详情")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)

                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(calendarColor)
                            .frame(width: 10, height: 10)
                            .padding(.top, 5)

                        Text(event.title ?? "无标题")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .lineLimit(3)
                    }
                }

                Spacer(minLength: 0)

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("event-detail-close-button")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(dateRangeText)
                    .font(.system(size: 14, weight: .semibold))

                Text(timeSummaryText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(summaryBackground)

            EventDetailRow(icon: "calendar", title: "所属日历", value: event.calendar.title)

            if let locationText {
                EventDetailRow(icon: "mappin.and.ellipse", title: "地点", value: locationText)
            }

            if let linkText {
                EventDetailRow(icon: "link", title: "链接", value: linkText)
            }

            if let notesText {
                EventDetailRow(icon: "note.text", title: "备注", value: notesText, isMultiline: true)
            }

            if locationText == nil, linkText == nil, notesText == nil {
                Text("暂无更多详情")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(panelBackground)
    }

    private var calendarColor: Color {
        Color(nsColor: event.calendar.color)
    }

    private var summaryBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(nsColor: .controlBackgroundColor),
                        calendarColor.opacity(0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private var panelBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(nsColor: .underPageBackgroundColor))

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(calendarColor.opacity(0.04))
        }
        .padding(10)
    }

    private var locationText: String? {
        event.location?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }

    private var notesText: String? {
        event.notes?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }

    private var linkText: String? {
        event.url?.absoluteString
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }

    private var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("M月d日 EEEE")

        let endDate = visibleEndDate
        let calendar = Calendar.autoupdatingCurrent

        if calendar.isDate(event.startDate, inSameDayAs: endDate) {
            return formatter.string(from: event.startDate)
        }

        return "\(formatter.string(from: event.startDate)) - \(formatter.string(from: endDate))"
    }

    private var timeSummaryText: String {
        if event.isAllDay {
            return "全天"
        }

        let intervalFormatter = DateIntervalFormatter()
        intervalFormatter.locale = .autoupdatingCurrent
        intervalFormatter.dateStyle = .none
        intervalFormatter.timeStyle = .short
        return intervalFormatter.string(from: event.startDate, to: event.endDate)
    }

    private var visibleEndDate: Date {
        if event.isAllDay {
            return event.endDate.addingTimeInterval(-1)
        }
        return event.endDate
    }
}

private struct EventDetailRow: View {
    let icon: String
    let title: String
    let value: String
    var isMultiline: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 16, alignment: .center)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.system(size: 12))
                    .lineLimit(isMultiline ? nil : 2)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
