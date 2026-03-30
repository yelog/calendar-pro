import AppKit
import Combine

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
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func screenParametersDidChange() {
        configureStatusItems()
    }

    private func configureStatusItems() {
        statusItems.forEach { NSStatusBar.system.removeStatusItem($0) }
        statusItems.removeAll()
        
        let screens = NSScreen.screens
        for screen in screens {
            let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            configureStatusButton(statusItem.button)
            statusItems.append(statusItem)
        }
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
}