import SwiftUI
import EventKit

struct EventListView: View {
    let items: [CalendarItem]
    let isLoading: Bool
    let selectedEventIdentifier: String?
    let onSelectEvent: (EKEvent) -> Void
    
    var body: some View {
        if isLoading {
            HStack {
                Spacer()
                ProgressView()
                    .scaleEffect(0.7)
                Spacer()
            }
            .frame(height: 60)
        } else if items.isEmpty {
            Text("当天无日程")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        } else {
            VStack(spacing: 6) {
                ForEach(items) { item in
                    switch item {
                    case .event(let event):
                        Button {
                            onSelectEvent(event)
                        } label: {
                            EventCardView(
                                item: item,
                                isSelected: selectedEventIdentifier == event.selectionIdentifier,
                                showsDisclosure: true
                            )
                        }
                        .buttonStyle(.plain)
                    case .reminder:
                        EventCardView(
                            item: item,
                            isSelected: false,
                            showsDisclosure: false
                        )
                    }
                }
            }
        }
    }
}
