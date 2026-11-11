import AppKit
import Combine
import Foundation

@MainActor
final class HolidayFeedRefreshScheduler {
    enum Outcome: Equatable, Sendable {
        case success(HolidayFeedClient.RefreshResult)
        case failure(String)
    }

    @Published private(set) var latestOutcome: Outcome?

    private let client: HolidayFeedClient
    private let notificationCenter: NotificationCenter
    private let workspaceNotificationCenter: NotificationCenter
    private let onDataUpdated: @MainActor (HolidayFeedClient.RefreshResult) -> Void

    private var notificationCancellables = Set<AnyCancellable>()
    private var timerCancellable: AnyCancellable?
    private var refreshTask: Task<HolidayFeedClient.RefreshResult, Error>?
    private var refreshTaskID: UUID?
    private var refreshTaskIsForced = false
    private var isStarted = false

    init(
        client: HolidayFeedClient,
        notificationCenter: NotificationCenter = .default,
        workspaceNotificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
        onDataUpdated: @escaping @MainActor (HolidayFeedClient.RefreshResult) -> Void = { _ in }
    ) {
        self.client = client
        self.notificationCenter = notificationCenter
        self.workspaceNotificationCenter = workspaceNotificationCenter
        self.onDataUpdated = onDataUpdated
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        bindSignificantEvents()
        refreshInBackground()
    }

    func stop() {
        isStarted = false
        notificationCancellables.removeAll()
        timerCancellable?.cancel()
        timerCancellable = nil
        refreshTask?.cancel()
        refreshTask = nil
        refreshTaskID = nil
        refreshTaskIsForced = false
    }

    func refresh(force: Bool = false) async throws -> HolidayFeedClient.RefreshResult {
        if let refreshTask {
            let taskWasForced = refreshTaskIsForced
            let result = try await refreshTask.value

            if
                force,
                !taskWasForced,
                result.source == .cache,
                result.fallbackReason == nil
            {
                return try await refresh(force: true)
            }
            return result
        }

        return try await startRefresh(force: force).value
    }

    private func startRefresh(
        force: Bool
    ) -> Task<HolidayFeedClient.RefreshResult, Error> {
        let taskID = UUID()
        let task = Task { @MainActor [weak self] in
            guard let self else {
                throw CancellationError()
            }

            defer {
                if self.refreshTaskID == taskID {
                    self.refreshTask = nil
                    self.refreshTaskID = nil
                    self.refreshTaskIsForced = false
                }
            }

            do {
                let result = try await self.client.refreshIfNeeded(force: force)
                self.latestOutcome = .success(result)
                if result.didUpdatePayloads {
                    self.onDataUpdated(result)
                }
                if self.isStarted {
                    self.scheduleNextRefresh(retryAfterFailure: result.fallbackReason != nil)
                }
                return result
            } catch {
                self.latestOutcome = .failure(error.localizedDescription)
                if self.isStarted {
                    self.scheduleNextRefresh(retryAfterFailure: true)
                }
                throw error
            }
        }

        refreshTaskID = taskID
        refreshTaskIsForced = force
        refreshTask = task
        return task
    }

    private func refreshInBackground(force: Bool = false) {
        Task { [weak self] in
            _ = try? await self?.refresh(force: force)
        }
    }

    private func bindSignificantEvents() {
        notificationCenter.publisher(for: NSApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshInBackground()
            }
            .store(in: &notificationCancellables)

        [
            workspaceNotificationCenter.publisher(for: NSWorkspace.didWakeNotification),
            workspaceNotificationCenter.publisher(for: NSWorkspace.sessionDidBecomeActiveNotification)
        ].forEach { publisher in
            publisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.refreshInBackground()
                }
                .store(in: &notificationCancellables)
        }
    }

    private func scheduleNextRefresh(retryAfterFailure: Bool) {
        timerCancellable?.cancel()

        let delay: TimeInterval
        if
            !retryAfterFailure,
            let modifiedAt = client.cache.manifestModifiedAt()
        {
            let remaining = modifiedAt
                .addingTimeInterval(client.refreshInterval)
                .timeIntervalSince(client.now())
            delay = remaining > 1 ? remaining : client.refreshInterval
        } else {
            delay = client.refreshInterval
        }

        timerCancellable = Timer.publish(every: delay, on: .main, in: .common)
            .autoconnect()
            .first()
            .sink { [weak self] _ in
                self?.refreshInBackground()
            }
    }
}
