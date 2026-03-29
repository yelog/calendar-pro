import EventKit
import Combine

@MainActor
final class EventService: ObservableObject {
    @Published private(set) var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published private(set) var calendars: [EKCalendar] = []
    @Published private(set) var isAuthorized: Bool = false
    
    private let eventStore = EKEventStore()
    
    func checkAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        isAuthorized = authorizationStatus == .fullAccess || authorizationStatus == .writeOnly
    }
    
    func requestAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            // 直接使用返回的授权结果更新状态
            isAuthorized = granted
            authorizationStatus = granted ? .fullAccess : .denied
            if granted {
                fetchCalendars()
            }
            return granted
        } catch {
            isAuthorized = false
            authorizationStatus = .denied
            return false
        }
    }
    
    func fetchCalendars() {
        guard isAuthorized else { return }
        calendars = eventStore.calendars(for: .event)
    }
    
    func fetchEvents(for date: Date) -> [EKEvent] {
        guard isAuthorized else { return [] }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        
        let predicate = eventStore.predicateForEvents(
            withStart: startOfDay,
            end: endOfDay,
            calendars: nil
        )
        
        return eventStore.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
    }
    
    func calendar(withIdentifier identifier: String) -> EKCalendar? {
        return calendars.first { $0.calendarIdentifier == identifier }
    }
}