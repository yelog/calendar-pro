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
            rootView: EventDetailWindowView(event: event) { [weak self] in
                self?.close()
            }
        )

        panel.contentViewController = hostingController
        hostingController.view.layoutSubtreeIfNeeded()

        let fittingSize = hostingController.view.fittingSize
        let visibleFrame = anchorWindow?.screen?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? NSScreen.screens.first?.visibleFrame
            ?? CGRect(x: 100, y: 100, width: 1200, height: 800)

        let availableHeight: CGFloat
        if let anchorFrame = anchorWindow?.frame {
            availableHeight = anchorFrame.maxY - visibleFrame.minY
        } else {
            availableHeight = visibleFrame.height
        }

        let panelSize = EventDetailWindowSizing.panelSize(for: fittingSize, availableHeight: availableHeight)
        let panelFrame = frame(for: panelSize, anchoredTo: anchorWindow)
        panel.setContentSize(panelFrame.size)
        panel.setFrame(panelFrame, display: false)
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
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: EventDetailWindowSizing.width,
                height: EventDetailWindowSizing.idealHeight
            ),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.delegate = self
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = false

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
