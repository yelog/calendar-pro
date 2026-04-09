import Foundation
import ServiceManagement

enum LaunchAtLoginStatus: Equatable {
    case enabled
    case disabled
    case requiresApproval
    case unavailable

    var isEnabled: Bool {
        self == .enabled
    }

    var summaryText: String {
        switch self {
        case .enabled:
            String(localized: "Launch Enabled")
        case .disabled:
            String(localized: "Launch Disabled")
        case .requiresApproval:
            String(localized: "Launch Pending Approval")
        case .unavailable:
            String(localized: "Unavailable")
        }
    }

    var detailText: String? {
        switch self {
        case .enabled:
            String(localized: "Launch enabled detail")
        case .disabled:
            String(localized: "Launch disabled detail")
        case .requiresApproval:
            String(localized: "Launch approval detail")
        case .unavailable:
            String(localized: "Launch unavailable detail")
        }
    }
}

protocol LaunchAtLoginControlling {
    func status() -> LaunchAtLoginStatus
    func setEnabled(_ enabled: Bool) throws
}

struct SystemLaunchAtLoginController: LaunchAtLoginControlling {
    func status() -> LaunchAtLoginStatus {
        Self.mapStatus(SMAppService.mainApp.status)
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    static func mapStatus(_ status: SMAppService.Status) -> LaunchAtLoginStatus {
        switch status {
        case .enabled:
            .enabled
        case .notRegistered:
            .disabled
        case .requiresApproval:
            .requiresApproval
        case .notFound:
            .unavailable
        @unknown default:
            .unavailable
        }
    }
}
