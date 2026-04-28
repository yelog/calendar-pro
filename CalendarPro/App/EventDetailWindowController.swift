import AppKit
import SwiftUI
import EventKit

@MainActor
protocol EventDetailWindowPresenting: AnyObject {
    func show(event: EKEvent, anchoredTo anchorWindow: NSWindow?, onJoinMeeting: (() -> Void)?, onClose: @escaping () -> Void)
    func show(reminder: EKReminder, anchoredTo anchorWindow: NSWindow?, onToggle: @escaping (EKReminder) -> Void, onClose: @escaping () -> Void)
    func showComposer(
        kind: CalendarItemCreationKind,
        selectedDate: Date,
        eventCalendars: [EKCalendar],
        reminderCalendars: [EKCalendar],
        anchoredTo anchorWindow: NSWindow?,
        onSaveEvent: @escaping (CalendarEventCreationRequest) throws -> Void,
        onSaveReminder: @escaping (ReminderCreationRequest) throws -> Void,
        onClose: @escaping () -> Void
    )
    func close()
}

@MainActor
final class EventDetailWindowController: NSObject, EventDetailWindowPresenting, NSWindowDelegate {
    private enum PanelMode {
        case detail
        case composer
    }

    private final class FloatingPanel: NSPanel {
        var allowsTextInput = false

        override var canBecomeKey: Bool {
            allowsTextInput || super.canBecomeKey
        }

        override var canBecomeMain: Bool {
            allowsTextInput || super.canBecomeMain
        }
    }

    private var panel: NSPanel?
    private var panelMode: PanelMode?
    private var onClose: (() -> Void)?

    func show(event: EKEvent, anchoredTo anchorWindow: NSWindow?, onJoinMeeting: (() -> Void)? = nil, onClose: @escaping () -> Void) {
        self.onClose = onClose

        let panel = makePanelIfNeeded(mode: .detail)
        let hostingController = NSHostingController(
            rootView: EventDetailWindowView(
                event: event,
                onClose: { [weak self] in
                    self?.close()
                },
                onPreferredHeightChange: { [weak self] preferredHeight in
                    self?.resizePanelIfNeeded(preferredHeight: preferredHeight, anchoredTo: anchorWindow)
                },
                onJoinMeeting: onJoinMeeting
            )
        )

        presentPanel(panel, hosting: hostingController, anchoredTo: anchorWindow)
    }

    func show(reminder: EKReminder, anchoredTo anchorWindow: NSWindow?, onToggle: @escaping (EKReminder) -> Void, onClose: @escaping () -> Void) {
        self.onClose = onClose

        let panel = makePanelIfNeeded(mode: .detail)
        let hostingController = NSHostingController(
            rootView: ReminderDetailWindowView(reminder: reminder, onToggle: onToggle) { [weak self] in
                self?.close()
            }
        )

        presentPanel(panel, hosting: hostingController, anchoredTo: anchorWindow)
    }

    func showComposer(
        kind: CalendarItemCreationKind,
        selectedDate: Date,
        eventCalendars: [EKCalendar],
        reminderCalendars: [EKCalendar],
        anchoredTo anchorWindow: NSWindow?,
        onSaveEvent: @escaping (CalendarEventCreationRequest) throws -> Void,
        onSaveReminder: @escaping (ReminderCreationRequest) throws -> Void,
        onClose: @escaping () -> Void
    ) {
        self.onClose = onClose

        let panel = makePanelIfNeeded(mode: .composer)
        let hostingController = NSHostingController(
            rootView: CalendarItemComposerView(
                kind: kind,
                selectedDate: selectedDate,
                eventCalendars: eventCalendars,
                reminderCalendars: reminderCalendars,
                onSaveEvent: onSaveEvent,
                onSaveReminder: onSaveReminder
            ) { [weak self] in
                self?.close()
            }
        )

        presentPanel(panel, hosting: hostingController, anchoredTo: anchorWindow, activatesForTextInput: true)
    }

    func close() {
        panel?.close()
    }

    func windowWillClose(_ notification: Notification) {
        let onClose = self.onClose
        self.onClose = nil
        if let closedPanel = notification.object as? NSPanel, closedPanel === panel {
            panel = nil
            panelMode = nil
        }
        onClose?()
    }

    // MARK: - Private

    private func presentPanel(
        _ panel: NSPanel,
        hosting hostingController: NSHostingController<some View>,
        anchoredTo anchorWindow: NSWindow?,
        activatesForTextInput: Bool = false
    ) {
        panel.contentViewController = hostingController
        hostingController.view.layoutSubtreeIfNeeded()

        let fittingSize = hostingController.view.fittingSize
        let availableHeight = availableHeight(anchoredTo: anchorWindow)
        let panelSize = EventDetailWindowSizing.panelSize(for: fittingSize, availableHeight: availableHeight)
        let panelFrame = frame(for: panelSize, anchoredTo: anchorWindow)
        panel.setContentSize(panelFrame.size)
        panel.setFrame(panelFrame, display: false)
        if activatesForTextInput {
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
        } else {
            panel.orderFrontRegardless()
        }
    }

    private func resizePanelIfNeeded(preferredHeight: CGFloat, anchoredTo anchorWindow: NSWindow?) {
        guard let panel, preferredHeight > 0 else { return }

        let availableHeight = availableHeight(anchoredTo: anchorWindow)
        let targetSize = EventDetailWindowSizing.panelSize(
            for: CGSize(width: EventDetailWindowSizing.width, height: preferredHeight),
            availableHeight: availableHeight
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

    private func makePanelIfNeeded(mode: PanelMode) -> NSPanel {
        if let panel, panelMode == mode {
            return panel
        }

        panel?.close()
        panel = nil
        panelMode = nil

        let styleMask: NSWindow.StyleMask = mode == .composer
            ? [.borderless, .fullSizeContentView]
            : [.borderless, .nonactivatingPanel, .fullSizeContentView]

        let panel = FloatingPanel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: EventDetailWindowSizing.width,
                height: EventDetailWindowSizing.idealHeight
            ),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        panel.allowsTextInput = mode == .composer
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
        self.panelMode = mode
        return panel
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
