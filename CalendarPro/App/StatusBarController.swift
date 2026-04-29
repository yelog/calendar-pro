import AppKit
import Combine

private let statusItemAutosaveName = "CalendarProStatusBarItem"

@MainActor
final class StatusBarController {
    private var statusItems: [NSStatusItem] = []
    private var popoverController: PopoverController
    private let menuBarViewModel: MenuBarViewModel
    private let upcomingEventMonitor: UpcomingEventMonitor
    private let textImageRenderer = MenuBarTextImageRenderer()
    private let settingsStore: SettingsStore
    private let eventService: EventService
    private let timeRefreshCoordinator = TimeRefreshCoordinator()

    private var cancellables = Set<AnyCancellable>()

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
        upcomingEventMonitor = UpcomingEventMonitor(
            eventService: eventService,
            settingsStore: settingsStore,
            timeRefreshCoordinator: timeRefreshCoordinator
        )

        configureStatusItems()
        bindViewModel()
        menuBarViewModel.start()
        upcomingEventMonitor.start()
        
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
        // 默认使用模板图片；自定义颜色或填充背景时切换为彩色图片。
        button.imagePosition = .imageOnly
        applyStatusImage(
            menuBarViewModel.displayText,
            style: settingsStore.menuBarPreferences.textStyle,
            indicator: nil,
            to: button
        )
    }

    private func bindViewModel() {
        Publishers.CombineLatest3(
            menuBarViewModel.$displayText,
            settingsStore.$menuBarPreferences
                .map { $0.textStyle }
                .removeDuplicates(),
            upcomingEventMonitor.$activeIndicator
        )
            .receive(on: RunLoop.main)
            .sink { [weak self] text, style, indicator in
                guard let self else { return }
                self.statusItems.forEach {
                    if let button = $0.button {
                        self.applyStatusImage(text, style: style, indicator: indicator, to: button)
                    }
                }
            }
            .store(in: &cancellables)
    }

    private func applyStatusImage(_ text: String, style: MenuBarTextStyle, indicator: MenuBarEventIndicator?, to button: NSStatusBarButton) {
        let renderResult = textImageRenderer.render(text: text, style: style, indicator: indicator)
        button.image = renderResult.image
        let tooltip = indicator.map { "\($0.tooltipText)\n\(text)" } ?? text
        button.toolTip = tooltip
        button.setAccessibilityLabel(tooltip)
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
