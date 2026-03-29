import AppKit
import SwiftUI

@MainActor
final class PopoverController {
    private let popover: NSPopover

    init(settingsStore: SettingsStore) {
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 340, height: 320)
        popover.contentViewController = NSHostingController(
            rootView: RootPopoverView(settingsStore: settingsStore)
        )
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
}
