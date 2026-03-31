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
            "已开启"
        case .disabled:
            "未开启"
        case .requiresApproval:
            "等待批准"
        case .unavailable:
            "不可用"
        }
    }

    var detailText: String? {
        switch self {
        case .enabled:
            "开机后 Calendar Pro 会自动启动。"
        case .disabled:
            "当前未加入系统登录项，需要时可以随时开启。"
        case .requiresApproval:
            "系统需要你在“系统设置 > 通用 > 登录项”中批准 Calendar Pro。"
        case .unavailable:
            "系统当前未找到可注册的应用实例，请从已安装的应用包启动后重试。"
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
