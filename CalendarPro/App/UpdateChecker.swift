import AppKit
import Foundation
import Sparkle

/// Sparkle 自动更新管理器
@MainActor
final class UpdateChecker: NSObject, SPUUpdaterDelegate {
    static let shared = UpdateChecker()

    private var updaterController: SPUStandardUpdaterController?
    private let checkInterval: TimeInterval = 24 * 60 * 60

    private override init() {
        super.init()
    }

    /// 初始化 Sparkle 更新器
    func initialize() {
        guard updaterController == nil else { return }

        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )

        if let updater = updaterController?.updater {
            updater.automaticallyChecksForUpdates = UserDefaults.standard.bool(forKey: "autoCheckUpdates")
            updater.updateCheckInterval = checkInterval
        }

        updateFeedURL()
    }

    /// 刷新 Feed URL（清除缓存，强制使用 delegate 方法）
    func updateFeedURL() {
        updaterController?.updater.clearFeedURLFromUserDefaults()
    }

    /// 手动检查更新
    func checkForUpdates(silent: Bool = false) {
        guard let controller = updaterController else {
            if !silent {
                showManualUpdateAlert()
            }
            return
        }

        if silent {
            controller.updater.checkForUpdatesInBackground()
        } else {
            controller.checkForUpdates(nil)
        }
    }

    /// 自动检查更新开关
    var automaticallyChecksForUpdates: Bool {
        get { updaterController?.updater.automaticallyChecksForUpdates ?? false }
        set {
            updaterController?.updater.automaticallyChecksForUpdates = newValue
            UserDefaults.standard.set(newValue, forKey: "autoCheckUpdates")
        }
    }

    // MARK: - SPUUpdaterDelegate

    func feedURLString(for updater: SPUUpdater) -> String? {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let useBetaChannel = version.contains("beta") || version.contains("alpha") || version.contains("rc")

        if useBetaChannel {
            return "https://yelog.github.io/calendar-pro/appcast-beta.xml"
        } else {
            return "https://yelog.github.io/calendar-pro/appcast.xml"
        }
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        let nsError = error as NSError
        if nsError.domain == SUSparkleErrorDomain {
            switch nsError.code {
            case 1001: // SUNoUpdateError
                return
            case 4007: // SUInstallationCanceledError
                return
            default:
                break
            }
        }
    }

    // MARK: - 手动更新回退

    private func showManualUpdateAlert() {
        let alert = NSAlert()
        alert.messageText = "检查更新失败"
        alert.informativeText = "自动更新不可用，请前往 GitHub 下载最新版本。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "前往 GitHub")
        alert.addButton(withTitle: "取消")

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "https://github.com/yelog/calendar-pro/releases/latest") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
