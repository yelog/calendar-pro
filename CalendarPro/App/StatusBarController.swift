import AppKit
import Combine

@MainActor
final class StatusBarController {
    private let statusItem: NSStatusItem
    private let popoverController: PopoverController
    private let menuBarViewModel: MenuBarViewModel

    private var cancellables = Set<AnyCancellable>()

    init(settingsStore: SettingsStore) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popoverController = PopoverController(settingsStore: settingsStore)
        menuBarViewModel = MenuBarViewModel(settingsStore: settingsStore)

        configureStatusButton()
        bindViewModel()
        menuBarViewModel.start()
    }

    private func configureStatusButton() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(togglePopover(_:))
        button.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        button.title = menuBarViewModel.displayText
    }

    private func bindViewModel() {
        menuBarViewModel.$displayText
            .receive(on: RunLoop.main)
            .sink { [weak self] text in
                self?.statusItem.button?.title = text
            }
            .store(in: &cancellables)
    }

    @objc
    private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }
        popoverController.toggle(relativeTo: button)
    }
}
