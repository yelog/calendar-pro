import AppKit
import Combine
import Foundation

enum RefreshGranularity: Equatable {
    case second
    case minute
}

@MainActor
final class TimeRefreshCoordinator: ObservableObject {
    @Published private(set) var currentDate: Date
    @Published private(set) var granularity: RefreshGranularity

    private let now: () -> Date
    private let calendarProvider: () -> Calendar
    private let notificationCenter: NotificationCenter
    private let workspaceNotificationCenter: NotificationCenter

    private var timerCancellable: AnyCancellable?
    private var eventCancellables = Set<AnyCancellable>()
    private var alignedRefreshWorkItem: DispatchWorkItem?
    private var isRunning = false

    init(
        granularity: RefreshGranularity = .minute,
        now: @escaping () -> Date = Date.init,
        calendarProvider: @escaping () -> Calendar = { .autoupdatingCurrent },
        notificationCenter: NotificationCenter = .default,
        workspaceNotificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter
    ) {
        self.granularity = granularity
        self.now = now
        self.calendarProvider = calendarProvider
        self.notificationCenter = notificationCenter
        self.workspaceNotificationCenter = workspaceNotificationCenter
        currentDate = now()

        bindSignificantTimeEvents()
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        refreshNow()
        scheduleTimer()
    }

    func stop() {
        isRunning = false
        cancelScheduledRefresh()
    }

    func setGranularity(_ granularity: RefreshGranularity) {
        guard self.granularity != granularity else { return }
        self.granularity = granularity
        refreshNow()
        if isRunning {
            scheduleTimer()
        }
    }

    func refreshNow() {
        currentDate = now()
    }

    static func delayUntilNextMinuteBoundary(from date: Date, calendar: Calendar) -> TimeInterval {
        guard let nextMinute = calendar.nextDate(
            after: date,
            matching: DateComponents(second: 0),
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        ) else {
            return 60
        }

        return max(nextMinute.timeIntervalSince(date), 0)
    }

    private func bindSignificantTimeEvents() {
        [
            notificationCenter.publisher(for: .NSSystemTimeZoneDidChange),
            notificationCenter.publisher(for: .NSCalendarDayChanged),
            notificationCenter.publisher(for: .NSSystemClockDidChange),
            notificationCenter.publisher(for: NSApplication.didBecomeActiveNotification)
        ].forEach { publisher in
            publisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.handleSignificantTimeEvent()
                }
                .store(in: &eventCancellables)
        }

        [
            workspaceNotificationCenter.publisher(for: NSWorkspace.didWakeNotification),
            workspaceNotificationCenter.publisher(for: NSWorkspace.sessionDidBecomeActiveNotification)
        ].forEach { publisher in
            publisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.handleSignificantTimeEvent()
                }
                .store(in: &eventCancellables)
        }
    }

    private func handleSignificantTimeEvent() {
        refreshNow()
        if isRunning {
            scheduleTimer()
        }
    }

    private func scheduleTimer() {
        cancelScheduledRefresh()

        switch granularity {
        case .second:
            scheduleRepeatingSecondTimer()
        case .minute:
            scheduleAlignedMinuteTimer()
        }
    }

    private func cancelScheduledRefresh() {
        timerCancellable?.cancel()
        timerCancellable = nil
        alignedRefreshWorkItem?.cancel()
        alignedRefreshWorkItem = nil
    }

    private func scheduleRepeatingSecondTimer() {
        timerCancellable = Timer.publish(every: 1.0, tolerance: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshNow()
            }
    }

    private func scheduleAlignedMinuteTimer() {
        let delay = Self.delayUntilNextMinuteBoundary(from: now(), calendar: calendarProvider())
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.isRunning else { return }
            self.refreshNow()
            self.alignedRefreshWorkItem = nil
            self.scheduleAlignedMinuteTimer()
        }

        alignedRefreshWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }
}
