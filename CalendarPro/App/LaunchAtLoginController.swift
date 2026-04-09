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
            L("Launch Enabled")
        case .disabled:
            L("Launch Disabled")
        case .requiresApproval:
            L("Launch Pending Approval")
        case .unavailable:
            L("Unavailable")
        }
    }

    var detailText: String? {
        switch self {
        case .enabled:
            L("Launch enabled detail")
        case .disabled:
            L("Launch disabled detail")
        case .requiresApproval:
            L("Launch approval detail")
        case .unavailable:
            L("Launch unavailable detail")
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
