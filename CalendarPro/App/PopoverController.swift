import AppKit
import SwiftUI

@MainActor
protocol PopoverPresenting: AnyObject {
    var isShown: Bool { get }
    var behavior: NSPopover.Behavior { get set }
    var animates: Bool { get set }
    var contentSize: NSSize { get set }
    var contentViewController: NSViewController? { get set }
    var delegate: NSPopoverDelegate? { get set }

    func show(relativeTo positioningRect: NSRect, of positioningView: NSView, preferredEdge: NSRectEdge)
    func performClose(_ sender: Any?)
}

extension NSPopover: PopoverPresenting {}

protocol EventMonitorInstalling {
    func addGlobalMouseDownMonitor(handler: @escaping () -> Void) -> Any?
    func removeMonitor(_ monitor: Any)
}

struct AppKitEventMonitorInstaller: EventMonitorInstalling {
    func addGlobalMouseDownMonitor(handler: @escaping () -> Void) -> Any? {
        NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { _ in
            handler()
        }
    }

    func removeMonitor(_ monitor: Any) {
        NSEvent.removeMonitor(monitor)
    }
}

@MainActor
protocol PopoverInteractionMonitoring: AnyObject {
    func start(onInteraction: @escaping @MainActor () -> Void)
    func stop()
}

@MainActor
final class PopoverInteractionMonitor: PopoverInteractionMonitoring {
    private let notificationCenter: NotificationCenter
    private let eventMonitorInstaller: EventMonitorInstalling

    private var globalMouseMonitor: Any?
    private var resignActiveObserver: NSObjectProtocol?

    init(
        notificationCenter: NotificationCenter = NotificationCenter.default,
        eventMonitorInstaller: EventMonitorInstalling = AppKitEventMonitorInstaller()
    ) {
        self.notificationCenter = notificationCenter
        self.eventMonitorInstaller = eventMonitorInstaller
    }

    func start(onInteraction: @escaping @MainActor () -> Void) {
        stop()

        globalMouseMonitor = eventMonitorInstaller.addGlobalMouseDownMonitor {
            Task { @MainActor in
                onInteraction()
            }
        }

        resignActiveObserver = notificationCenter.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: nil
        ) { _ in
            Task { @MainActor in
                onInteraction()
            }
        }
    }

    func stop() {
        if let globalMouseMonitor {
            eventMonitorInstaller.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }

        if let resignActiveObserver {
            notificationCenter.removeObserver(resignActiveObserver)
            self.resignActiveObserver = nil
        }
    }
}

@MainActor
final class PopoverController: NSObject, NSPopoverDelegate {
    private let popover: PopoverPresenting
    private let settingsStore: SettingsStore
    private let eventService: EventService
    private let interactionMonitor: PopoverInteractionMonitoring

    init(
        settingsStore: SettingsStore,
        eventService: EventService,
        popover: PopoverPresenting = NSPopover(),
        interactionMonitor: PopoverInteractionMonitoring = PopoverInteractionMonitor()
    ) {
        self.popover = popover
        self.settingsStore = settingsStore
        self.eventService = eventService
        self.interactionMonitor = interactionMonitor
        super.init()

        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 340, height: 400)
        popover.delegate = self
        updateContentView()
    }

    var isShown: Bool {
        popover.isShown
    }

    func toggle(relativeTo button: NSView) {
        if popover.isShown {
            closePopover()
        } else {
            showPopover(relativeTo: button)
        }
    }

    private func updateContentView() {
        let hostingController = NSHostingController(
            rootView: RootPopoverView(
                settingsStore: settingsStore,
                eventService: eventService,
                onQuit: { [weak self] in
                    self?.quitApp()
                }
            )
        )
        if #available(macOS 13.0, *) {
            hostingController.sizingOptions = [.preferredContentSize]
        }
        popover.contentViewController = hostingController
        popover.contentSize = hostingController.view.fittingSize
    }

    private func showPopover(relativeTo button: NSView) {
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        interactionMonitor.start { [weak self] in
            self?.closePopover()
        }
    }

    private func closePopover() {
        interactionMonitor.stop()
        popover.performClose(nil)
    }

    func popoverDidClose(_ notification: Notification) {
        interactionMonitor.stop()
    }

    private func quitApp() {
        closePopover()
        NSApp.terminate(nil)
    }
}
