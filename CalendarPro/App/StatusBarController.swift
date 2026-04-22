import AppKit
import Combine

private let statusItemAutosaveName = "CalendarProStatusBarItem"

@MainActor
final class StatusBarController {
    private var statusItems: [NSStatusItem] = []
    private var popoverController: PopoverController
    private let menuBarViewModel: MenuBarViewModel
    private let settingsStore: SettingsStore
    private let eventService: EventService
    private let timeRefreshCoordinator = TimeRefreshCoordinator()

    private var cancellables = Set<AnyCancellable>()

    /// 渲染菜单栏文字时使用的字体（与之前保持一致）
    private let statusBarFont: NSFont = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
    
    init(settingsStore: SettingsStore, eventService: EventService) {
        self.settingsStore = settingsStore
        self.eventService = eventService
        popoverController = PopoverController(
            settingsStore: settingsStore,
            eventService: eventService,
            timeRefreshCoordinator: timeRefreshCoordinator
        )
        menuBarViewModel = MenuBarViewModel(
            settingsStore: settingsStore,
            timeRefreshCoordinator: timeRefreshCoordinator
        )

        configureStatusItems()
        bindViewModel()
        menuBarViewModel.start()
        
        Task {
            await eventService.requestAccess()
            await eventService.requestReminderAccess()
        }
        
        // NOTE: 不监听屏幕变化通知。macOS 会自动处理菜单栏布局，
        // autosaveName 会确保位置持久化。重建 StatusItem 会丢失 window ID
        // 导致 Ice 等菜单栏管理器无法识别同一个 item。
    }
    
    nonisolated deinit {
        // StatusBarController 生命周期与应用相同，由 AppDelegate 持有
        // 应用退出时所有 status items 会自动移除
    }

    private func configureStatusItems() {
        guard statusItems.isEmpty else { return }
        
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = statusItemAutosaveName
        configureStatusButton(statusItem.button)
        statusItems.append(statusItem)
    }
    
    private func configureStatusButton(_ button: NSStatusBarButton?) {
        guard let button else { return }
        button.target = self
        button.action = #selector(togglePopover(_:))
        // 使用模板图片渲染文字，确保在 active/inactive 菜单栏和深色/浅色模式下均正确着色
        button.imagePosition = .imageOnly
        applyTemplateImage(menuBarViewModel.displayText, to: button)
    }

    private func bindViewModel() {
        menuBarViewModel.$displayText
            .receive(on: RunLoop.main)
            .sink { [weak self] text in
                guard let self else { return }
                self.statusItems.forEach {
                    if let button = $0.button {
                        self.applyTemplateImage(text, to: button)
                    }
                }
            }
            .store(in: &cancellables)
    }

    /// 将文本渲染成黑色实体图，然后设置 isTemplate = true，
    /// 让 AppKit 根据当前 appearance（active / inactive / highlighted）自动着色。
    private func applyTemplateImage(_ text: String, to button: NSStatusBarButton) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: statusBarFont
        ]
        let attributedText = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedText.size()

        // 使用 1 pt 左右内边距，避免文字贴边
        let padding: CGFloat = 2
        let imageSize = NSSize(width: ceil(textSize.width) + padding * 2,
                               height: ceil(textSize.height))

        let image = NSImage(size: imageSize, flipped: false) { rect in
            // 用纯黑色绘制——isTemplate 之后系统只读取 alpha 通道
            let drawRect = NSRect(
                x: padding,
                y: (rect.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            attributedText.draw(in: drawRect)
            return true
        }
        image.isTemplate = true

        button.image = image
        // 确保 accessibilityLabel 仍然可用（辅助功能）
        button.toolTip = text
    }

    @objc
    private func togglePopover(_ sender: AnyObject?) {
        guard let button = sender as? NSStatusBarButton else { return }
        popoverController.toggle(relativeTo: button)
    }

    func popoverContentWindow() -> NSWindow? {
        popoverController.popoverContentWindow()
    }
}
