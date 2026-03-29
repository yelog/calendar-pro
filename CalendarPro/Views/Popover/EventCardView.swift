import SwiftUI
import EventKit

struct EventCardView: View {
    let event: EKEvent
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color(nsColor: event.calendar.color))
                .frame(width: 6, height: 6)
                .padding(.top, 4)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(timeRangeText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                
                Text(event.title ?? "无标题")
                    .font(.system(size: 13, weight: .regular))
                    .lineLimit(2)
                
                if let location = event.location, !location.isEmpty {
                    Text(location)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary.opacity(0.8))
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var timeRangeText: String {
        if event.isAllDay {
            return "全天"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        let start = formatter.string(from: event.startDate)
        let end = formatter.string(from: event.endDate)
        
        return "\(start)-\(end)"
    }
}