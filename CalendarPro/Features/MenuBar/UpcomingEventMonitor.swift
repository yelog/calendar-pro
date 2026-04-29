import AppKit
import Combine
import Foundation

enum MenuBarIndicatorStatus: Equatable {
    case ongoing
    case upcoming
}

struct MenuBarEventIndicatorDot: Equatable {
    let colorHex: String
    let status: MenuBarIndicatorStatus
}

struct MenuBarEventIndicator: Equatable {
    let dots: [MenuBarEventIndicatorDot]
    let tooltipText: String
    let count: Int

    var primaryDot: MenuBarEventIndicatorDot? {
        dots.first
    }
}

@MainActor
final class UpcomingEventMonitor: ObservableObject {
    @Published private(set) var activeIndicator: MenuBarEventIndicator?

    private let eventService: EventService
    private let settingsStore: SettingsStore
    private let timeRefreshCoordinator: TimeRefreshCoordinator
    private let calendar: () -> Calendar
    private var cancellables = Set<AnyCancellable>()
    private var fetchTask: Task<Void, Never>?

    init(
        eventService: EventService,
        settingsStore: SettingsStore,
        timeRefreshCoordinator: TimeRefreshCoordinator,
        calendar: @escaping () -> Calendar = { .autoupdatingCurrent }
    ) {
        self.eventService = eventService
        self.settingsStore = settingsStore
        self.timeRefreshCoordinator = timeRefreshCoordinator
        self.calendar = calendar

        bindRefresh()
    }

    func start() {
        refreshIfNeeded(at: timeRefreshCoordinator.currentDate)
    }

    private func bindRefresh() {
        timeRefreshCoordinator.$currentDate
            .sink { [weak self] currentDate in
                self?.refreshIfNeeded(at: currentDate)
            }
            .store(in: &cancellables)

        settingsStore.$menuBarPreferences
            .sink { [weak self] _ in
                guard let self else { return }
                self.refreshIfNeeded(at: self.timeRefreshCoordinator.currentDate)
            }
            .store(in: &cancellables)

        eventService.$storeChangeRevision
            .sink { [weak self] _ in
                guard let self else { return }
                self.refreshIfNeeded(at: self.timeRefreshCoordinator.currentDate)
            }
            .store(in: &cancellables)
    }

    private func refreshIfNeeded(at now: Date) {
        fetchTask?.cancel()
        fetchTask = Task {
            let prefs = self.settingsStore.menuBarPreferences

            guard prefs.showUpcomingIndicator,
                  prefs.showEvents,
                  prefs.hasEnabledEventSources,
                  self.eventService.isAuthorized || self.eventService.remindersAuthorized else {
                if self.activeIndicator != nil {
                    self.activeIndicator = nil
                }
                return
            }

            let cal = self.calendar()
            let today = cal.startOfDay(for: now)

            let items = await self.eventService.fetchCalendarItems(
                for: today,
                enabledCalendarIDs: prefs.enabledCalendarIDs,
                enabledReminderCalendarIDs: prefs.enabledReminderCalendarIDs,
                showCalendarEvents: prefs.showCalendarEvents,
                showReminders: prefs.showReminders
            )

            guard !Task.isCancelled else { return }

            let upcomingMinutes = Double(prefs.upcomingReminderMinutes)
            let activeItems = items.filter { item in
                guard item.hasExplicitTime, !item.isAllDay, !item.isCanceled else { return false }

                if let status = item.timelineStatus(at: now, calendar: cal), status == .ongoing {
                    return true
                }

                guard let startDate = item.startDate else { return false }
                let interval = startDate.timeIntervalSince(now)
                return interval > 0 && interval <= upcomingMinutes * 60
            }

            guard !Task.isCancelled else { return }

            if activeItems.isEmpty {
                self.activeIndicator = nil
                return
            }

            var dots: [MenuBarEventIndicatorDot] = []
            for item in activeItems.prefix(3) {
                let color = item.color.menuBarHexString() ?? Self.accentColorHex
                let status: MenuBarIndicatorStatus
                if let s = item.timelineStatus(at: now, calendar: cal), s == .ongoing {
                    status = .ongoing
                } else {
                    status = .upcoming
                }
                dots.append(MenuBarEventIndicatorDot(colorHex: color, status: status))
            }

            let tooltip = Self.buildTooltip(for: activeItems, now: now, calendar: cal)

            let indicator = MenuBarEventIndicator(
                dots: dots,
                tooltipText: tooltip,
                count: activeItems.count
            )

            if self.activeIndicator != indicator {
                self.activeIndicator = indicator
            }
        }
    }

    private static let accentColorHex = "#007AFF"

    private static func buildTooltip(for items: [CalendarItem], now: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        let summaries = items.prefix(3).map { item -> String in
            let title = item.title ?? ""
            let timePart: String
            if let status = item.timelineStatus(at: now, calendar: calendar), status == .ongoing {
                timePart = L("Ongoing")
            } else if let start = item.startDate {
                timePart = formatter.string(from: start)
            } else {
                timePart = ""
            }
            return "\(title) (\(timePart))"
        }

        let joined = summaries.joined(separator: ", ")
        if items.count > 3 {
            let remaining = items.count - 3
            return "\(L("Upcoming")): \(joined) +\(remaining)"
        } else if items.count > 1 {
            return "\(L("Upcoming")): \(joined)"
        } else {
            return "\(L("Upcoming")): \(joined)"
        }
    }
}
