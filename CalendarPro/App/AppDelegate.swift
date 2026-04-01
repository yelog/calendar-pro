import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settingsStore = SettingsStore()
    let eventService = EventService()

    private var statusBarController: StatusBarController?
    private var uiTestWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private let uiTestEventDetailWindowController = EventDetailWindowController()

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(isUITestPopoverMode ? .regular : .accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if isUITestPopoverMode {
            presentUITestWindow()
        } else {
            statusBarController = StatusBarController(settingsStore: settingsStore, eventService: eventService)
        }

        // 初始化 Sparkle 自动更新
        UpdateChecker.shared.initialize()

        Task {
            await refreshHolidayFeedIfNeeded()
        }
    }
    
    @objc func openSettings() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let hostingController = NSHostingController(
            rootView: SettingsRootView(store: settingsStore, eventService: eventService)
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 840, height: 560),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hostingController
        window.title = "设置"
        
        if let popoverWindow = statusBarController?.popoverContentWindow() {
            positionWindowNearPopover(window, popoverWindow: popoverWindow)
        } else {
            window.center()
        }
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.settingsWindow = nil
            }
        }
    }

    private func positionWindowNearPopover(_ settingsWindow: NSWindow, popoverWindow: NSWindow) {
        let popoverFrame = popoverWindow.frame
        let settingsSize = settingsWindow.frame.size
        
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        
        var x = popoverFrame.origin.x + popoverFrame.size.width + 20
        var y = popoverFrame.origin.y - settingsSize.height / 2 + popoverFrame.size.height / 2
        
        if x + settingsSize.width > screenFrame.origin.x + screenFrame.size.width {
            x = popoverFrame.origin.x - settingsSize.width - 20
        }
        
        y = max(screenFrame.origin.y, min(y, screenFrame.origin.y + screenFrame.size.height - settingsSize.height))
        
        settingsWindow.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private var isUITestPopoverMode: Bool {
        ProcessInfo.processInfo.environment["CALENDAR_PRO_UI_TEST_MODE"] == "popover-window"
    }

    private func refreshHolidayFeedIfNeeded() async {
        guard let client = HolidayFeedClient.configuredClient() else { return }

        do {
            let result = try await client.refreshIfNeeded()
            if result.source == .remote {
                settingsStore.noteHolidayDataUpdated()
            }
        } catch {
            // 启动时静默失败，不影响用户体验
        }
    }

    private func presentUITestWindow() {
        let hostingController = NSHostingController(
            rootView: RootPopoverView(
                settingsStore: settingsStore,
                eventService: eventService,
                onPresentEventDetailWindow: { [weak self] event, onClose in
                    self?.uiTestEventDetailWindowController.show(
                        event: event,
                        anchoredTo: self?.uiTestWindow,
                        onClose: onClose
                    )
                },
                onPresentReminderDetailWindow: { [weak self] reminder, onToggle, onClose in
                    self?.uiTestEventDetailWindowController.show(
                        reminder: reminder,
                        anchoredTo: self?.uiTestWindow,
                        onToggle: onToggle,
                        onClose: onClose
                    )
                },
                onDismissEventDetailWindow: { [weak self] in
                    self?.uiTestEventDetailWindowController.close()
                },
                onQuit: { NSApp.terminate(nil) }
            )
        )
        if #available(macOS 13.0, *) {
            hostingController.sizingOptions = .preferredContentSize
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 400),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hostingController
        window.title = "Calendar Pro"
        window.setContentSize(hostingController.view.fittingSize)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        uiTestWindow = window
    }
}
