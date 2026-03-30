import AppKit
import SwiftUI
import EventKit

@MainActor
protocol EventDetailWindowPresenting: AnyObject {
    func show(event: EKEvent, anchoredTo anchorWindow: NSWindow?, onClose: @escaping () -> Void)
    func close()
}

@MainActor
final class EventDetailWindowController: NSObject, EventDetailWindowPresenting, NSWindowDelegate {
    private var panel: NSPanel?
    private var onClose: (() -> Void)?

    func show(event: EKEvent, anchoredTo anchorWindow: NSWindow?, onClose: @escaping () -> Void) {
        self.onClose = onClose

        let panel = makePanelIfNeeded()
        let hostingController = NSHostingController(
            rootView: EventDetailWindowView(event: event) { [weak panel] in
                panel?.close()
            }
        )
        if #available(macOS 13.0, *) {
            hostingController.sizingOptions = .preferredContentSize
        }

        panel.contentViewController = hostingController

        let fittingSize = hostingController.view.fittingSize
        let panelSize = NSSize(
            width: max(320, fittingSize.width),
            height: max(360, fittingSize.height)
        )
        panel.setContentSize(panelSize)
        panel.setFrame(frame(for: panelSize, anchoredTo: anchorWindow), display: false)
        panel.orderFrontRegardless()
    }

    func close() {
        panel?.close()
    }

    func windowWillClose(_ notification: Notification) {
        let onClose = self.onClose
        self.onClose = nil
        onClose?()
    }

    private func makePanelIfNeeded() -> NSPanel {
        if let panel {
            return panel
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 360),
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.delegate = self
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.moveToActiveSpace]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = false
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        self.panel = panel
        return panel
    }

    private func frame(for panelSize: NSSize, anchoredTo anchorWindow: NSWindow?) -> NSRect {
        let visibleFrame = anchorWindow?.screen?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? NSScreen.screens.first?.visibleFrame
            ?? CGRect(x: 100, y: 100, width: 1200, height: 800)

        guard let anchorFrame = anchorWindow?.frame else {
            return NSRect(
                x: visibleFrame.midX - panelSize.width / 2,
                y: visibleFrame.midY - panelSize.height / 2,
                width: panelSize.width,
                height: panelSize.height
            )
        }

        return EventDetailWindowLayout.defaultFrame(
            panelSize: panelSize,
            anchorFrame: anchorFrame,
            visibleFrame: visibleFrame
        )
    }
}
