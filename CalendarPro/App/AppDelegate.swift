import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settingsStore = SettingsStore()

    private var statusBarController: StatusBarController?
    private var uiTestWindow: NSWindow?
    private var settingsWindow: NSWindow?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(isUITestPopoverMode ? .regular : .accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if isUITestPopoverMode {
            presentUITestWindow()
        } else {
            statusBarController = StatusBarController(settingsStore: settingsStore)
        }
    }
    
    @objc func openSettings() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let hostingController = NSHostingController(
            rootView: SettingsRootView(store: settingsStore)
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hostingController
        window.title = "设置"
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    private var isUITestPopoverMode: Bool {
        ProcessInfo.processInfo.environment["CALENDAR_PRO_UI_TEST_MODE"] == "popover-window"
    }

    private func presentUITestWindow() {
        let hostingController = NSHostingController(
            rootView: RootPopoverView(
                settingsStore: settingsStore,
                onQuit: { NSApp.terminate(nil) }
            )
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 400),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hostingController
        window.title = "Calendar Pro"
        window.setContentSize(NSSize(width: 340, height: 400))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        uiTestWindow = window
    }
}