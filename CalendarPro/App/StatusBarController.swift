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

    private var cancellables = Set<AnyCancellable>()
    
    init(settingsStore: SettingsStore, eventService: EventService) {
        self.settingsStore = settingsStore
        self.eventService = eventService
        popoverController = PopoverController(settingsStore: settingsStore, eventService: eventService)
        menuBarViewModel = MenuBarViewModel(settingsStore: settingsStore)

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
        button.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        button.title = menuBarViewModel.displayText
    }

    private func bindViewModel() {
        menuBarViewModel.$displayText
            .receive(on: RunLoop.main)
            .sink { [weak self] text in
                self?.statusItems.forEach { $0.button?.title = text }
            }
            .store(in: &cancellables)
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