import AppKit
import SwiftUI

@MainActor
protocol WeatherDetailWindowPresenting: AnyObject {
    func show(
        overview: WeatherForecastOverview,
        anchoredTo anchorWindow: NSWindow?,
        onClose: @escaping () -> Void
    )

    func close()
}

@MainActor
final class WeatherDetailWindowController: NSObject, NSWindowDelegate, WeatherDetailWindowPresenting {
    private var panel: NSPanel?
    private var onClose: (() -> Void)?

    func show(
        overview: WeatherForecastOverview,
        anchoredTo anchorWindow: NSWindow?,
        onClose: @escaping () -> Void
    ) {
        let panel = makePanelIfNeeded()
        self.onClose = onClose
        let hostingController = NSHostingController(
            rootView: WeatherDetailWindowView(
                overview: overview,
                onClose: { [weak self] in
                    self?.close()
                },
                onPreferredHeightChange: { [weak self] preferredHeight in
                    self?.resizePanelIfNeeded(preferredHeight: preferredHeight, anchoredTo: anchorWindow)
                }
            )
        )

        presentPanel(panel, hosting: hostingController, anchoredTo: anchorWindow)
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

    private func presentPanel(
        _ panel: NSPanel,
        hosting hostingController: NSHostingController<some View>,
        anchoredTo anchorWindow: NSWindow?
    ) {
        panel.contentViewController = hostingController

        let fittingSize = hostingController.view.fittingSize
        let targetSize = WeatherDetailWindowSizing.panelSize(
            for: fittingSize,
            availableHeight: availableHeight(anchoredTo: anchorWindow)
        )
        let panelFrame = frame(for: targetSize, anchoredTo: anchorWindow)
        panel.setContentSize(panelFrame.size)
        panel.setFrame(panelFrame, display: false)
        panel.orderFrontRegardless()
    }

    private func makePanelIfNeeded() -> NSPanel {
        if let panel {
            return panel
        }

        let panel = NSPanel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: WeatherDetailWindowSizing.width,
                height: WeatherDetailWindowSizing.idealHeight
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

    private func resizePanelIfNeeded(preferredHeight: CGFloat, anchoredTo anchorWindow: NSWindow?) {
        guard let panel, preferredHeight > 0 else { return }

        let targetSize = WeatherDetailWindowSizing.panelSize(
            for: CGSize(width: WeatherDetailWindowSizing.width, height: preferredHeight),
            availableHeight: availableHeight(anchoredTo: anchorWindow)
        )
        let targetFrame = frame(for: targetSize, anchoredTo: anchorWindow)
        let currentFrame = panel.frame

        guard
            abs(currentFrame.height - targetFrame.height) > 1
                || abs(currentFrame.origin.y - targetFrame.origin.y) > 1
        else {
            return
        }

        panel.setContentSize(targetFrame.size)
        panel.setFrame(targetFrame, display: true)
    }

    private func frame(for panelSize: NSSize, anchoredTo anchorWindow: NSWindow?) -> NSRect {
        let visibleFrame = visibleFrame(anchoredTo: anchorWindow)
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

    private func visibleFrame(anchoredTo anchorWindow: NSWindow?) -> CGRect {
        anchorWindow?.screen?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? NSScreen.screens.first?.visibleFrame
            ?? CGRect(x: 100, y: 100, width: 1200, height: 800)
    }

    private func availableHeight(anchoredTo anchorWindow: NSWindow?) -> CGFloat {
        let visibleFrame = visibleFrame(anchoredTo: anchorWindow)

        if let anchorFrame = anchorWindow?.frame {
            let anchorContentTop = anchorFrame.maxY - EventDetailWindowLayout.popoverArrowHeight
            return anchorContentTop - visibleFrame.minY
        }

        return visibleFrame.height
    }
}
