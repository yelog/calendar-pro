import SwiftUI
import EventKit

extension EKEvent {
    var selectionIdentifier: String {
        if let eventIdentifier {
            return eventIdentifier
        }

        return [
            calendar.calendarIdentifier,
            title ?? "untitled",
            String(startDate.timeIntervalSinceReferenceDate),
            String(endDate.timeIntervalSinceReferenceDate)
        ].joined(separator: "|")
    }
}

struct EventCardView: View {
    let item: CalendarItem
    let isSelected: Bool
    let showsDisclosure: Bool

    init(item: CalendarItem, isSelected: Bool = false, showsDisclosure: Bool = true) {
        self.item = item
        self.isSelected = isSelected
        self.showsDisclosure = showsDisclosure
    }

    init(event: EKEvent, isSelected: Bool) {
        self.init(item: .event(event), isSelected: isSelected)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color(nsColor: item.color))
                .frame(width: 6, height: 6)
                .padding(.top, 4)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(timeRangeText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                
                Text(item.title)
                    .font(.system(size: 13, weight: .regular))
                    .lineLimit(2)
                    .strikethrough(item.isCompleted)
                    .foregroundStyle(item.isCompleted ? .secondary : .primary)
                
                if let location = item.location, !location.isEmpty {
                    Text(location)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary.opacity(0.8))
                        .lineLimit(1)
                }
            }
            
            Spacer()

            if showsDisclosure {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : Color(nsColor: .tertiaryLabelColor))
                    .padding(.top, 2)
            }
        }
        .padding(10)
        .background(backgroundColor)
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(borderColor, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .contentShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private var timeRangeText: String {
        if item.isAllDay {
            return "全天"
        }
        
        guard let startDate = item.startDate else {
            return ""
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        let start = formatter.string(from: startDate)
        
        if let endDate = item.endDate {
            let end = formatter.string(from: endDate)
            return "\(start)-\(end)"
        }
        
        return start
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.12)
        }
        return Color(nsColor: .controlBackgroundColor)
    }

    private var borderColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.35)
        }
        return Color.primary.opacity(0.05)
    }
}
