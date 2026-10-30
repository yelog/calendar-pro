import AppKit
import SwiftUI
import EventKit

@MainActor
protocol EventDetailWindowPresenting: AnyObject {
    func show(
        event: EKEvent,
        anchoredTo anchorWindow: NSWindow?,
        onEdit: @escaping (EKEvent) -> Void,
        onDelete: @escaping (EKEvent) -> Void,
        onJoinMeeting: (() -> Void)?,
        onClose: @escaping () -> Void
    )
    func show(
        reminder: EKReminder,
        anchoredTo anchorWindow: NSWindow?,
        onToggle: @escaping (EKReminder) -> Void,
        onEdit: @escaping (EKReminder) -> Void,
        onDelete: @escaping (EKReminder) -> Void,
        onClose: @escaping () -> Void
    )
    func showComposer(
        kind: CalendarItemCreationKind,
        selectedDate: Date,
        initialTimeRange: CalendarItemCreationTimeRange?,
        eventCalendars: [EKCalendar],
        reminderCalendars: [EKCalendar],
        anchoredTo anchorWindow: NSWindow?,
        onSaveEvent: @escaping (CalendarEventCreationRequest) throws -> Void,
        onSaveReminder: @escaping (ReminderCreationRequest) throws -> Void,
        onClose: @escaping () -> Void
    )
    func showEditor(
        mode: CalendarItemComposerMode,
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
    typealias PanelFactory = (NSRect, NSWindow.StyleMask) -> NSPanel
    typealias ApplicationActivator = () -> Void

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
    private weak var hostingController: NSHostingController<AnyView>?
    private var presentationID = UUID()
    private var pendingPreferredHeight: CGFloat?
    private var resizeTaskID: UUID?
    private var resizeTask: Task<Void, Never>?
    private let panelFactory: PanelFactory?
    private let activateApplication: ApplicationActivator
    private let preferredHeightCallbackObserver: ((@escaping (CGFloat) -> Void) -> Void)?
    private let availableHeightProvider: ((NSWindow?) -> CGFloat)?
    private let preferredHeightScheduler: ((@escaping @MainActor () -> Void) -> Void)?
    private let setPanelFrame: ((NSPanel, NSRect, Bool) -> Void)?

    init(
        panelFactory: PanelFactory? = nil,
        activateApplication: @escaping ApplicationActivator = { NSApp.activate(ignoringOtherApps: true) },
        preferredHeightCallbackObserver: ((@escaping (CGFloat) -> Void) -> Void)? = nil,
        availableHeightProvider: ((NSWindow?) -> CGFloat)? = nil,
        preferredHeightScheduler: ((@escaping @MainActor () -> Void) -> Void)? = nil,
        setPanelFrame: ((NSPanel, NSRect, Bool) -> Void)? = nil
    ) {
        self.panelFactory = panelFactory
        self.activateApplication = activateApplication
        self.preferredHeightCallbackObserver = preferredHeightCallbackObserver
        self.availableHeightProvider = availableHeightProvider
        self.preferredHeightScheduler = preferredHeightScheduler
        self.setPanelFrame = setPanelFrame
        super.init()
    }

    func show(
        event: EKEvent,
        anchoredTo anchorWindow: NSWindow?,
        onEdit: @escaping (EKEvent) -> Void,
        onDelete: @escaping (EKEvent) -> Void,
        onJoinMeeting: (() -> Void)? = nil,
        onClose: @escaping () -> Void
    ) {
        let panel = makePanelIfNeeded(mode: .detail)
        let presentationID = beginPresentation(onClose: onClose)
        let maximumHeight = effectiveAvailableHeight(anchoredTo: anchorWindow)
        let preferredHeightCallback: (CGFloat) -> Void = { [weak self] preferredHeight in
            self?.scheduleResize(
                preferredHeight: preferredHeight,
                presentationID: presentationID,
                panel: panel,
                anchoredTo: anchorWindow
            )
        }
        preferredHeightCallbackObserver?(preferredHeightCallback)
        let hostingController = NSHostingController<AnyView>(
            rootView: AnyView(EventDetailWindowView(
                event: event,
                maximumHeight: maximumHeight,
                onEdit: onEdit,
                onDelete: onDelete,
                onClose: { [weak self] in
                    self?.close()
                },
                onPreferredHeightChange: preferredHeightCallback,
                onJoinMeeting: onJoinMeeting
            ))
        )

        presentPanel(panel, hosting: hostingController, anchoredTo: anchorWindow, managesPreferredHeight: true)
    }

    func show(
        reminder: EKReminder,
        anchoredTo anchorWindow: NSWindow?,
        onToggle: @escaping (EKReminder) -> Void,
        onEdit: @escaping (EKReminder) -> Void,
        onDelete: @escaping (EKReminder) -> Void,
        onClose: @escaping () -> Void
    ) {
        let panel = makePanelIfNeeded(mode: .detail)
        _ = beginPresentation(onClose: onClose)
        let hostingController = NSHostingController<AnyView>(
            rootView: AnyView(ReminderDetailWindowView(
                reminder: reminder,
                onToggle: onToggle,
                onEdit: onEdit,
                onDelete: onDelete
            ) { [weak self] in
                self?.close()
            })
        )

        presentPanel(panel, hosting: hostingController, anchoredTo: anchorWindow)
    }

    func showComposer(
        kind: CalendarItemCreationKind,
        selectedDate: Date,
        initialTimeRange: CalendarItemCreationTimeRange?,
        eventCalendars: [EKCalendar],
        reminderCalendars: [EKCalendar],
        anchoredTo anchorWindow: NSWindow?,
        onSaveEvent: @escaping (CalendarEventCreationRequest) throws -> Void,
        onSaveReminder: @escaping (ReminderCreationRequest) throws -> Void,
        onClose: @escaping () -> Void
    ) {
        let panel = makePanelIfNeeded(mode: .composer)
        let presentationID = beginPresentation(onClose: onClose)
        let maximumHeight = effectiveAvailableHeight(anchoredTo: anchorWindow)
        let preferredHeightCallback: (CGFloat) -> Void = { [weak self] preferredHeight in
            self?.scheduleResize(
                preferredHeight: preferredHeight,
                presentationID: presentationID,
                panel: panel,
                anchoredTo: anchorWindow
            )
        }
        preferredHeightCallbackObserver?(preferredHeightCallback)
        let hostingController = NSHostingController<AnyView>(
            rootView: AnyView(CalendarItemComposerView(
                mode: .create(
                    kind: kind,
                    selectedDate: selectedDate,
                    initialTimeRange: initialTimeRange
                ),
                eventCalendars: eventCalendars,
                reminderCalendars: reminderCalendars,
                maximumHeight: maximumHeight,
                onPreferredHeightChange: preferredHeightCallback,
                onSaveEvent: onSaveEvent,
                onSaveReminder: onSaveReminder
            ) { [weak self] in
                self?.close()
            })
        )

        presentPanel(panel, hosting: hostingController, anchoredTo: anchorWindow, activatesForTextInput: true, managesPreferredHeight: true)
    }

    func showEditor(
        mode: CalendarItemComposerMode,
        eventCalendars: [EKCalendar],
        reminderCalendars: [EKCalendar],
        anchoredTo anchorWindow: NSWindow?,
        onSaveEvent: @escaping (CalendarEventCreationRequest) throws -> Void,
        onSaveReminder: @escaping (ReminderCreationRequest) throws -> Void,
        onClose: @escaping () -> Void
    ) {
        let panel = makePanelIfNeeded(mode: .composer)
        let presentationID = beginPresentation(onClose: onClose)
        let maximumHeight = effectiveAvailableHeight(anchoredTo: anchorWindow)
        let preferredHeightCallback: (CGFloat) -> Void = { [weak self] preferredHeight in
            self?.scheduleResize(
                preferredHeight: preferredHeight,
                presentationID: presentationID,
                panel: panel,
                anchoredTo: anchorWindow
            )
        }
        preferredHeightCallbackObserver?(preferredHeightCallback)
        let hostingController = NSHostingController<AnyView>(
            rootView: AnyView(CalendarItemComposerView(
                mode: mode,
                eventCalendars: eventCalendars,
                reminderCalendars: reminderCalendars,
                maximumHeight: maximumHeight,
                onPreferredHeightChange: preferredHeightCallback,
                onSaveEvent: onSaveEvent,
                onSaveReminder: onSaveReminder
            ) { [weak self] in
                self?.close()
            })
        )

        presentPanel(panel, hosting: hostingController, anchoredTo: anchorWindow, activatesForTextInput: true, managesPreferredHeight: true)
    }

    func close() {
        invalidatePendingResize()
        panel?.close()
    }

    func windowWillClose(_ notification: Notification) {
        guard let closedPanel = notification.object as? NSPanel, closedPanel === panel else { return }
        invalidatePendingResize()
        let onClose = self.onClose
        self.onClose = nil
        panel = nil
        panelMode = nil
        onClose?()
    }

    // MARK: - Private

    private func presentPanel(
        _ panel: NSPanel,
        hosting hostingController: NSHostingController<AnyView>,
        anchoredTo anchorWindow: NSWindow?,
        activatesForTextInput: Bool = false,
        managesPreferredHeight: Bool = false
    ) {
        panel.contentViewController = hostingController
        self.hostingController = hostingController
        hostingController.sizingOptions = managesPreferredHeight ? [] : .standardBounds

        let availableHeight = effectiveAvailableHeight(anchoredTo: anchorWindow)
        let panelSize: CGSize
        if managesPreferredHeight {
            let measuredSize = hostingController.sizeThatFits(in: CGSize(
                width: EventDetailWindowSizing.width,
                height: availableHeight
            ))
            let initialHeight = measuredSize.width.isFinite
                && measuredSize.width > 0
                && measuredSize.height.isFinite
                && measuredSize.height > 0
                ? measuredSize.height
                : EventDetailWindowSizing.idealHeight
            panelSize = EventDetailWindowSizing.panelSize(
                for: CGSize(width: EventDetailWindowSizing.width, height: initialHeight),
                availableHeight: availableHeight
            )
        } else {
            panelSize = EventDetailWindowSizing.panelSize(
                for: hostingController.view.fittingSize,
                availableHeight: availableHeight
            )
        }
        let panelFrame = frame(for: panelSize, anchoredTo: anchorWindow)
        if let setPanelFrame {
            setPanelFrame(panel, panelFrame, false)
        } else {
            panel.setFrame(panelFrame, display: false)
        }
        if activatesForTextInput {
            activateApplication()
            panel.makeKeyAndOrderFront(nil)
        } else {
            panel.orderFrontRegardless()
        }
    }

    private func beginPresentation(onClose: @escaping () -> Void) -> UUID {
        invalidatePendingResize()
        let presentationID = UUID()
        self.presentationID = presentationID
        self.onClose = onClose
        return presentationID
    }

    private func invalidatePendingResize() {
        resizeTask?.cancel()
        resizeTask = nil
        resizeTaskID = nil
        pendingPreferredHeight = nil
        presentationID = UUID()
        hostingController?.sizingOptions = .standardBounds
        hostingController = nil
    }

    private func scheduleResize(
        preferredHeight: CGFloat,
        presentationID: UUID,
        panel scheduledPanel: NSPanel,
        anchoredTo anchorWindow: NSWindow?
    ) {
        guard preferredHeight.isFinite,
              preferredHeight > 0,
              presentationID == self.presentationID,
              scheduledPanel === panel else {
            return
        }

        pendingPreferredHeight = preferredHeight
        guard resizeTaskID == nil else { return }

        let taskID = UUID()
        resizeTaskID = taskID
        let applyLatestHeight: @MainActor () -> Void = { [weak self, weak scheduledPanel] in
            guard let self,
                  let scheduledPanel,
                  self.resizeTaskID == taskID else {
                return
            }

            let latestHeight = self.pendingPreferredHeight
            self.resizeTask = nil
            self.resizeTaskID = nil
            self.pendingPreferredHeight = nil

            guard self.presentationID == presentationID,
                  scheduledPanel === self.panel,
                  let latestHeight else {
                return
            }
            self.resizePanelIfNeeded(preferredHeight: latestHeight, panel: scheduledPanel, anchoredTo: anchorWindow)
        }
        if let preferredHeightScheduler {
            preferredHeightScheduler(applyLatestHeight)
        } else {
            resizeTask = Task { @MainActor in
                await Task.yield()
                applyLatestHeight()
            }
        }
    }

    private func resizePanelIfNeeded(preferredHeight: CGFloat, panel: NSPanel, anchoredTo anchorWindow: NSWindow?) {
        guard preferredHeight.isFinite,
              preferredHeight > 0,
              panel === self.panel else {
            return
        }

        let availableHeight = effectiveAvailableHeight(anchoredTo: anchorWindow)
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

        if let setPanelFrame {
            setPanelFrame(panel, targetFrame, true)
        } else {
            panel.setFrame(targetFrame, display: true)
        }
    }

    private func makePanelIfNeeded(mode: PanelMode) -> NSPanel {
        if let panel, panelMode == mode {
            return panel
        }

        invalidatePendingResize()
        onClose = nil
        panel?.close()
        panel = nil
        panelMode = nil

        let styleMask: NSWindow.StyleMask = mode == .composer
            ? [.borderless, .fullSizeContentView]
            : [.borderless, .nonactivatingPanel, .fullSizeContentView]

        let contentRect = NSRect(
            x: 0,
            y: 0,
            width: EventDetailWindowSizing.width,
            height: EventDetailWindowSizing.idealHeight
        )
        let panel: NSPanel
        if let panelFactory {
            panel = panelFactory(contentRect, styleMask)
        } else {
            panel = FloatingPanel(contentRect: contentRect, styleMask: styleMask, backing: .buffered, defer: false)
        }
        (panel as? FloatingPanel)?.allowsTextInput = mode == .composer
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

    private func effectiveAvailableHeight(anchoredTo anchorWindow: NSWindow?) -> CGFloat {
        max(
            availableHeightProvider?(anchorWindow) ?? availableHeight(anchoredTo: anchorWindow),
            EventDetailWindowSizing.minHeight
        )
    }
}
