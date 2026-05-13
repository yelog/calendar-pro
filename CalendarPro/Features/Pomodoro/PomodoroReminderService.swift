import AppKit
import Foundation
import UserNotifications

enum PomodoroReminderKind: Equatable {
    case focusCompleted(nextPhase: PomodoroTimerController.Phase)
    case breakCompleted
}

enum PomodoroNotificationAuthorizationStatus: Equatable {
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral
    case unknown
}

@MainActor
protocol PomodoroReminderServicing: AnyObject {
    func authorizationStatus() async -> PomodoroNotificationAuthorizationStatus
    func requestAuthorization() async -> Bool
    func sendReminder(_ kind: PomodoroReminderKind, preferences: PomodoroReminderPreferences) async
}

@MainActor
final class PomodoroReminderService: PomodoroReminderServicing {
    private let notificationCenter: UNUserNotificationCenter
    private let soundName: NSSound.Name

    init(
        notificationCenter: UNUserNotificationCenter = .current(),
        soundName: NSSound.Name = .init("Glass")
    ) {
        self.notificationCenter = notificationCenter
        self.soundName = soundName
    }

    func authorizationStatus() async -> PomodoroNotificationAuthorizationStatus {
        let settings = await notificationCenter.notificationSettings()
        return PomodoroNotificationAuthorizationStatus(settings.authorizationStatus)
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await notificationCenter.requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    func sendReminder(_ kind: PomodoroReminderKind, preferences: PomodoroReminderPreferences) async {
        if preferences.soundEnabled {
            NSSound(named: soundName)?.play()
        }

        guard preferences.notificationsEnabled else { return }
        guard await authorizationStatus().canSendNotifications else { return }

        let content = UNMutableNotificationContent()
        content.title = title(for: kind)
        content.body = body(for: kind)
        content.sound = nil

        let request = UNNotificationRequest(
            identifier: "pomodoro-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        try? await notificationCenter.add(request)
    }

    private func title(for kind: PomodoroReminderKind) -> String {
        switch kind {
        case .focusCompleted:
            return L("Pomodoro Focus Completed Notification Title")
        case .breakCompleted:
            return L("Pomodoro Break Completed Notification Title")
        }
    }

    private func body(for kind: PomodoroReminderKind) -> String {
        switch kind {
        case .focusCompleted(let nextPhase):
            if nextPhase == .longBreak {
                return L("Pomodoro Long Break Notification Body")
            }
            return L("Pomodoro Short Break Notification Body")
        case .breakCompleted:
            return L("Pomodoro Break Completed Notification Body")
        }
    }
}

private extension PomodoroNotificationAuthorizationStatus {
    init(_ status: UNAuthorizationStatus) {
        switch status {
        case .notDetermined:
            self = .notDetermined
        case .denied:
            self = .denied
        case .authorized:
            self = .authorized
        case .provisional:
            self = .provisional
        case .ephemeral:
            self = .ephemeral
        @unknown default:
            self = .unknown
        }
    }

    var canSendNotifications: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined, .denied, .unknown:
            return false
        }
    }
}
