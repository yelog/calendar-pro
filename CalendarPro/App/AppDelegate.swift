import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    enum SettingsWindowConfiguration {
        static let defaultSize = NSSize(width: 840, height: 560)
        static let minimumSize = NSSize(width: 760, height: 520)
        static let autosaveName = "CalendarProSettingsWindowFrame"
    }

    let settingsStore = SettingsStore()
    let eventService = EventService()

    private var statusBarController: StatusBarController?
    private var uiTestWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private let uiTestEventDetailWindowController = EventDetailWindowController()
    private let uiTestVacationGuideWindowController = VacationGuideWindowController()
    private let uiTestPopoverViewModel = CalendarPopoverViewModel()
    private let uiTestTimeRefreshCoordinator = TimeRefreshCoordinator()

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

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
            centerSettingsWindowOnCurrentScreen(window)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(
            rootView: SettingsRootView(store: settingsStore, eventService: eventService)
        )
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: SettingsWindowConfiguration.defaultSize),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hostingController
        window.title = L("Settings")
        window.minSize = SettingsWindowConfiguration.minimumSize
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName(SettingsWindowConfiguration.autosaveName)
        window.setFrameUsingName(SettingsWindowConfiguration.autosaveName, force: false)
        window.delegate = self
        centerSettingsWindowOnCurrentScreen(window)

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }

        if window === settingsWindow {
            DispatchQueue.main.async { [weak self] in
                self?.settingsWindow = nil
            }
        }
    }

    private func centerSettingsWindowOnCurrentScreen(_ settingsWindow: NSWindow) {
        let targetScreen = settingsTargetScreen()
            ?? NSScreen.main
            ?? NSScreen.screens.first

        guard let targetScreen else { return }

        let visibleFrame = targetScreen.visibleFrame
        let windowSize = settingsWindow.frame.size
        let centeredOrigin = NSPoint(
            x: visibleFrame.midX - windowSize.width / 2,
            y: visibleFrame.midY - windowSize.height / 2
        )

        let clampedOrigin = NSPoint(
            x: max(visibleFrame.minX, min(centeredOrigin.x, visibleFrame.maxX - windowSize.width)),
            y: max(visibleFrame.minY, min(centeredOrigin.y, visibleFrame.maxY - windowSize.height))
        )

        settingsWindow.setFrameOrigin(clampedOrigin)
    }

    private func settingsTargetScreen() -> NSScreen? {
        if let popoverScreen = statusBarController?.popoverContentWindow()?.screen {
            return popoverScreen
        }

        if let keyWindowScreen = NSApp.keyWindow?.screen {
            return keyWindowScreen
        }

        let mouseLocation = NSEvent.mouseLocation
        if let mouseScreen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) {
            return mouseScreen
        }

        return nil
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
        uiTestTimeRefreshCoordinator.start()
        let hostingController = NSHostingController(
            rootView: RootPopoverView(
                settingsStore: settingsStore,
                eventService: eventService,
                viewModel: uiTestPopoverViewModel,
                timeRefreshCoordinator: uiTestTimeRefreshCoordinator,
                onPresentEventDetailWindow: { [weak self] event, onEdit, onDelete, onClose in
                    self?.uiTestVacationGuideWindowController.close()
                    self?.uiTestEventDetailWindowController.show(
                        event: event,
                        anchoredTo: self?.uiTestWindow,
                        onEdit: onEdit,
                        onDelete: onDelete,
                        onClose: onClose
                    )
                },
                onPresentReminderDetailWindow: { [weak self] reminder, onToggle, onEdit, onDelete, onClose in
                    self?.uiTestVacationGuideWindowController.close()
                    self?.uiTestEventDetailWindowController.show(
                        reminder: reminder,
                        anchoredTo: self?.uiTestWindow,
                        onToggle: onToggle,
                        onEdit: onEdit,
                        onDelete: onDelete,
                        onClose: onClose
                    )
                },
                onPresentItemComposer: { [weak self] kind, selectedDate, eventCalendars, reminderCalendars, onSaveEvent, onSaveReminder, onClose in
                    self?.uiTestVacationGuideWindowController.close()
                    self?.uiTestEventDetailWindowController.showComposer(
                        kind: kind,
                        selectedDate: selectedDate,
                        eventCalendars: eventCalendars,
                        reminderCalendars: reminderCalendars,
                        anchoredTo: self?.uiTestWindow,
                        onSaveEvent: onSaveEvent,
                        onSaveReminder: onSaveReminder,
                        onClose: onClose
                    )
                },
                onPresentItemEditor: { [weak self] mode, eventCalendars, reminderCalendars, onSaveEvent, onSaveReminder, onClose in
                    self?.uiTestVacationGuideWindowController.close()
                    self?.uiTestEventDetailWindowController.showEditor(
                        mode: mode,
                        eventCalendars: eventCalendars,
                        reminderCalendars: reminderCalendars,
                        anchoredTo: self?.uiTestWindow,
                        onSaveEvent: onSaveEvent,
                        onSaveReminder: onSaveReminder,
                        onClose: onClose
                    )
                },
                onPresentVacationGuide: { [weak self] month, onLocate in
                    guard let self else { return }
                    self.uiTestEventDetailWindowController.close()
                    self.uiTestVacationGuideWindowController.show(
                        referenceMonth: month,
                        settingsStore: self.settingsStore,
                        anchoredTo: self.uiTestWindow
                    ) { date in
                        onLocate(date)
                    }
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
