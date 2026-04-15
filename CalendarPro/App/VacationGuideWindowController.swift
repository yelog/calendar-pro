import AppKit
import SwiftUI

@MainActor
protocol VacationGuideWindowPresenting: AnyObject {
    func show(
        referenceMonth: Date,
        settingsStore: SettingsStore,
        anchoredTo anchorWindow: NSWindow?,
        onLocateDate: @escaping (Date) -> Void
    )

    func close()
}

@MainActor
final class VacationGuideWindowController: NSObject, NSWindowDelegate, VacationGuideWindowPresenting {
    private enum Configuration {
        static let width: CGFloat = 460
        static let minHeight: CGFloat = 360
        static let idealHeight: CGFloat = 560
    }

    private var panel: NSPanel?

    func show(
        referenceMonth: Date,
        settingsStore: SettingsStore,
        anchoredTo anchorWindow: NSWindow?,
        onLocateDate: @escaping (Date) -> Void
    ) {
        let panel = makePanelIfNeeded()
        let hostingController = NSHostingController(
            rootView: VacationGuideWindowView(
                settingsStore: settingsStore,
                referenceMonth: referenceMonth,
                onLocateDate: { [weak self] date in
                    onLocateDate(date)
                    self?.close()
                },
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
        panel?.contentViewController = nil
    }

    private func presentPanel(
        _ panel: NSPanel,
        hosting hostingController: NSHostingController<some View>,
        anchoredTo anchorWindow: NSWindow?
    ) {
        panel.contentViewController = hostingController
        hostingController.view.layoutSubtreeIfNeeded()

        let fittingSize = hostingController.view.fittingSize
        let targetSize = panelSize(for: fittingSize, anchoredTo: anchorWindow)
        let panelFrame = frame(for: targetSize, anchoredTo: anchorWindow)
        panel.setContentSize(panelFrame.size)
        panel.setFrame(panelFrame, display: false)
        panel.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makePanelIfNeeded() -> NSPanel {
        if let panel {
            return panel
        }

        let panel = NSPanel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: Configuration.width,
                height: Configuration.idealHeight
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

        let targetSize = panelSize(
            for: CGSize(width: Configuration.width, height: preferredHeight),
            anchoredTo: anchorWindow
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

    private func panelSize(for fittingSize: CGSize, anchoredTo anchorWindow: NSWindow?) -> CGSize {
        let preferredHeight = max(fittingSize.height, Configuration.idealHeight)
        let maximumHeight = max(availableHeight(anchoredTo: anchorWindow), Configuration.minHeight)
        let height = min(preferredHeight, maximumHeight)
        return CGSize(width: Configuration.width, height: height)
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
