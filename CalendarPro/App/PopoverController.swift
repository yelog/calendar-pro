import AppKit
import SwiftUI

@MainActor
final class PopoverController {
    private let popover: NSPopover
    private let settingsStore: SettingsStore

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 340, height: 400)
        updateContentView()
    }

    var isShown: Bool {
        popover.isShown
    }

    func toggle(relativeTo button: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func updateContentView() {
        popover.contentViewController = NSHostingController(
            rootView: RootPopoverView(
                settingsStore: settingsStore,
                onOpenSettings: { [weak self] in
                    self?.openSettings()
                },
                onQuit: { [weak self] in
                    self?.quitApp()
                }
            )
        )
    }

    private func openSettings() {
        popover.performClose(nil)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    private func quitApp() {
        popover.performClose(nil)
        NSApp.terminate(nil)
    }
}
