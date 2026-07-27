import AppKit
import SwiftUI

@MainActor
protocol PomodoroStatisticsWindowPresenting: AnyObject {
    func show(
        statsStore: PomodoroStatsStore,
        anchoredTo anchorWindow: NSWindow?,
        onClose: @escaping () -> Void
    )

    func close()
}

@MainActor
final class PomodoroStatisticsWindowController: NSObject, NSWindowDelegate, PomodoroStatisticsWindowPresenting {
    static let panelSize = CGSize(width: 300, height: 380)

    private var panel: NSPanel?
    private var onClose: (() -> Void)?

    func show(
        statsStore: PomodoroStatsStore,
        anchoredTo anchorWindow: NSWindow?,
        onClose: @escaping () -> Void
    ) {
        let panel = makePanelIfNeeded()
        self.onClose = onClose
        panel.contentViewController = NSHostingController(
            rootView: PomodoroStatisticsWindowView(
                statsStore: statsStore,
                onClose: { [weak self] in self?.close() }
            )
        )

        let frame = EventDetailWindowLayout.defaultFrame(
            panelSize: Self.panelSize,
            anchorFrame: anchorWindow?.frame ?? fallbackAnchorFrame(),
            visibleFrame: visibleFrame(anchoredTo: anchorWindow)
        )
        panel.setContentSize(frame.size)
        panel.setFrame(frame, display: false)
        panel.orderFrontRegardless()
    }

    func close() {
        panel?.close()
    }

    func windowWillClose(_ notification: Notification) {
        guard let closedPanel = notification.object as? NSPanel, closedPanel === panel else { return }
        closedPanel.contentViewController = nil
        panel = nil

        let onClose = self.onClose
        self.onClose = nil
        onClose?()
    }

    private func makePanelIfNeeded() -> NSPanel {
        if let panel { return panel }

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.panelSize),
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

    private func visibleFrame(anchoredTo anchorWindow: NSWindow?) -> CGRect {
        anchorWindow?.screen?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? NSScreen.screens.first?.visibleFrame
            ?? CGRect(x: 100, y: 100, width: 1200, height: 800)
    }

    private func fallbackAnchorFrame() -> CGRect {
        let visibleFrame = visibleFrame(anchoredTo: nil)
        return CGRect(x: visibleFrame.midX, y: visibleFrame.midY, width: 1, height: 1)
    }
}
