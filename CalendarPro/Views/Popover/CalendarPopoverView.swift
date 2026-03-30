import SwiftUI
import EventKit

struct CalendarPopoverView: View {
    let displayedMonth: Date
    let weekdaySymbols: [String]
    let monthDays: [CalendarDay]
    let showEvents: Bool
    let selectedDate: Date?
    let items: [CalendarItem]
    let selectedEvent: EKEvent?
    let isLoadingEvents: Bool
    let onPreviousMonth: () -> Void
    let onNextMonth: () -> Void
    let onSelectDate: (Date) -> Void
    let onSelectEvent: (EKEvent) -> Void
    let onDismissEventDetail: () -> Void
    let onResetToToday: () -> Void
    let onQuit: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            if detailPanelVisible, let selectedEvent {
                EventDetailPanelView(event: selectedEvent, onClose: onDismissEventDetail)
                    .frame(width: CalendarPopoverLayout.detailPanelWidth)
                    .transition(.move(edge: .leading).combined(with: .opacity))

                Divider()
            }

            mainPanel
                .frame(width: CalendarPopoverLayout.mainPanelWidth)
        }
        .frame(width: detailPanelVisible ? CalendarPopoverLayout.expandedWidth : CalendarPopoverLayout.mainPanelWidth)
        .fixedSize(horizontal: false, vertical: true)
        .background(popoverBackground)
        .animation(.spring(response: 0.28, dampingFraction: 0.9), value: detailPanelVisible)
        .animation(.spring(response: 0.28, dampingFraction: 0.9), value: selectedEvent?.selectionIdentifier)
    }

    private var mainPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            MonthHeaderView(
                displayedMonth: displayedMonth,
                onPreviousMonth: onPreviousMonth,
                onNextMonth: onNextMonth
            )
            
            CalendarGridView(
                weekdaySymbols: weekdaySymbols,
                monthDays: monthDays,
                onSelectDate: onSelectDate
            )
            
            eventsSection
            
            Divider()
                .padding(.horizontal, -16)
            
            HStack {
                Button {
                    NSApp.sendAction(#selector(AppDelegate.openSettings), to: nil, from: nil)
                } label: {
                    Label("设置", systemImage: "gearshape")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(",", modifiers: .command)
                
                Spacer()
                
                Button(action: onResetToToday) {
                    Label("今日", systemImage: "calendar")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .keyboardShortcut("t", modifiers: .command)
                
                Spacer()
                
                Button(action: onQuit) {
                    Label("退出", systemImage: "power")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(.secondary)
            .padding(.bottom, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var eventsSection: some View {
        if showEvents, let date = selectedDate {
            Divider()
                .padding(.horizontal, -16)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formattedSelectedDate(date))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))

                        Text(eventSummaryText)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if selectedEvent != nil {
                        Text("详情已打开")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.accentColor.opacity(0.12))
                            )
                    }
                }

                EventListView(
                    items: items,
                    isLoading: isLoadingEvents
                )
                .frame(maxHeight: 200)
            }
        }
    }

    private var detailPanelVisible: Bool {
        showEvents && selectedEvent != nil
    }

    private var eventSummaryText: String {
        if isLoadingEvents {
            return "正在加载日程..."
        }

        if items.isEmpty {
            return "当天无日程"
        }

        return "\(items.count) 条日程，点击查看详情"
    }

    private func formattedSelectedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("M月d日 EEEE")
        return formatter.string(from: date)
    }

    private var popoverBackground: some View {
        LinearGradient(
            colors: [
                Color(nsColor: .windowBackgroundColor),
                Color.accentColor.opacity(0.04)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private enum CalendarPopoverLayout {
    static let mainPanelWidth: CGFloat = 340
    static let detailPanelWidth: CGFloat = 288
    static let expandedWidth: CGFloat = mainPanelWidth + detailPanelWidth + 1
}

private struct EventDetailPanelView: View {
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
