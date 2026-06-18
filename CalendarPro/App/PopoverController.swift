import AppKit
import EventKit
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
    private let eventDetailPresenter: EventDetailWindowPresenting
    private let vacationGuidePresenter: VacationGuideWindowPresenting
    private let weatherDetailPresenter: WeatherDetailWindowPresenting
    private let timeRefreshCoordinator: TimeRefreshCoordinator
    private let pomodoroTimer: PomodoroTimerController
    private let viewModel: CalendarPopoverViewModel
    private var isComposerPresented = false

    init(
        settingsStore: SettingsStore,
        eventService: EventService,
        popover: PopoverPresenting = NSPopover(),
        interactionMonitor: PopoverInteractionMonitoring = PopoverInteractionMonitor(),
        eventDetailPresenter: EventDetailWindowPresenting = EventDetailWindowController(),
        vacationGuidePresenter: VacationGuideWindowPresenting = VacationGuideWindowController(),
        weatherDetailPresenter: WeatherDetailWindowPresenting = WeatherDetailWindowController(),
        timeRefreshCoordinator: TimeRefreshCoordinator = TimeRefreshCoordinator(),
        pomodoroTimer: PomodoroTimerController = PomodoroTimerController(),
        viewModel: CalendarPopoverViewModel? = nil
    ) {
        self.popover = popover
        self.settingsStore = settingsStore
        self.eventService = eventService
        self.interactionMonitor = interactionMonitor
        self.eventDetailPresenter = eventDetailPresenter
        self.vacationGuidePresenter = vacationGuidePresenter
        self.weatherDetailPresenter = weatherDetailPresenter
        self.timeRefreshCoordinator = timeRefreshCoordinator
        self.pomodoroTimer = pomodoroTimer
        self.viewModel = viewModel ?? CalendarPopoverViewModel(now: { timeRefreshCoordinator.currentDate })
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

    func popoverContentWindow() -> NSWindow? {
        popover.contentViewController?.view.window
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
                viewModel: viewModel,
                timeRefreshCoordinator: timeRefreshCoordinator,
                pomodoroTimer: pomodoroTimer,
                onPresentEventDetailWindow: { [weak self] event, onEdit, onDelete, onClose in
                    self?.showEventDetailWindow(for: event, onEdit: onEdit, onDelete: onDelete, onClose: onClose)
                },
                onPresentReminderDetailWindow: { [weak self] reminder, onToggle, onEdit, onDelete, onClose in
                    self?.showReminderDetailWindow(
                        for: reminder,
                        onToggle: onToggle,
                        onEdit: onEdit,
                        onDelete: onDelete,
                        onClose: onClose
                    )
                },
                onPresentItemComposer: { [weak self] kind, selectedDate, eventCalendars, reminderCalendars, onSaveEvent, onSaveReminder, onClose in
                    self?.showItemComposer(
                        kind: kind,
                        selectedDate: selectedDate,
                        eventCalendars: eventCalendars,
                        reminderCalendars: reminderCalendars,
                        onSaveEvent: onSaveEvent,
                        onSaveReminder: onSaveReminder,
                        onClose: onClose
                    )
                },
                onPresentItemEditor: { [weak self] mode, eventCalendars, reminderCalendars, onSaveEvent, onSaveReminder, onClose in
                    self?.showItemEditor(
                        mode: mode,
                        eventCalendars: eventCalendars,
                        reminderCalendars: reminderCalendars,
                        onSaveEvent: onSaveEvent,
                        onSaveReminder: onSaveReminder,
                        onClose: onClose
                    )
                },
                onPresentVacationGuide: { [weak self] month, onLocate in
                    self?.showVacationGuide(forMonth: month, onLocateDate: onLocate)
                },
                onPresentWeatherDetailWindow: { [weak self] overview, onClose in
                    self?.showWeatherDetailWindow(overview: overview, onClose: onClose)
                },
                onDismissEventDetailWindow: { [weak self] in
                    self?.closeEventDetailWindow()
                },
                onDismissWeatherDetailWindow: { [weak self] in
                    self?.closeWeatherDetailWindow()
                },
                onQuit: { [weak self] in
                    self?.quitApp()
                }
            )
        )
        if #available(macOS 13.0, *) {
            hostingController.sizingOptions = .preferredContentSize
        }
        popover.contentViewController = hostingController
        popover.contentSize = hostingController.view.fittingSize
    }

    private func showPopover(relativeTo button: NSView) {
        timeRefreshCoordinator.refreshNow()
        viewModel.checkAndResetIfNeeded()
        viewModel.syncCurrentDaySelectionIfNeeded(calendar: .autoupdatingCurrent)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        interactionMonitor.start { [weak self] in
            self?.closePopover()
        }
    }

    private func closePopover() {
        interactionMonitor.stop()
        closeVacationGuideWindow()
        closeWeatherDetailWindow()
        popover.performClose(nil)
    }

    func popoverShouldClose(_ popover: NSPopover) -> Bool {
        closeEventDetailWindow()
        closeVacationGuideWindow()
        closeWeatherDetailWindow()
        return true
    }

    func popoverDidClose(_ notification: Notification) {
        interactionMonitor.stop()
        restoreTransientPopoverBehaviorIfNeeded()
        viewModel.popoverDidClose()
    }

    func showEventDetailWindow(
        for event: EKEvent,
        onEdit: @escaping (EKEvent) -> Void,
        onDelete: @escaping (EKEvent) -> Void,
        onClose: @escaping () -> Void
    ) {
        closeVacationGuideWindow()
        closeWeatherDetailWindow()
        eventDetailPresenter.show(
            event: event,
            anchoredTo: popover.contentViewController?.view.window,
            onEdit: onEdit,
            onDelete: onDelete,
            onJoinMeeting: { [weak self] in
                self?.closePopover()
            },
            onClose: onClose
        )
    }

    func showReminderDetailWindow(
        for reminder: EKReminder,
        onToggle: @escaping (EKReminder) -> Void,
        onEdit: @escaping (EKReminder) -> Void,
        onDelete: @escaping (EKReminder) -> Void,
        onClose: @escaping () -> Void
    ) {
        closeVacationGuideWindow()
        closeWeatherDetailWindow()
        eventDetailPresenter.show(
            reminder: reminder,
            anchoredTo: popover.contentViewController?.view.window,
            onToggle: onToggle,
            onEdit: onEdit,
            onDelete: onDelete,
            onClose: onClose
        )
    }

    func showItemComposer(
        kind: CalendarItemCreationKind,
        selectedDate: Date,
        eventCalendars: [EKCalendar],
        reminderCalendars: [EKCalendar],
        onSaveEvent: @escaping (CalendarEventCreationRequest) throws -> Void,
        onSaveReminder: @escaping (ReminderCreationRequest) throws -> Void,
        onClose: @escaping () -> Void
    ) {
        closeVacationGuideWindow()
        closeWeatherDetailWindow()
        suspendTransientPopoverBehaviorForComposer()
        eventDetailPresenter.showComposer(
            kind: kind,
            selectedDate: selectedDate,
            eventCalendars: eventCalendars,
            reminderCalendars: reminderCalendars,
            anchoredTo: popover.contentViewController?.view.window,
            onSaveEvent: onSaveEvent,
            onSaveReminder: onSaveReminder,
            onClose: { [weak self] in
                onClose()
                self?.restoreTransientPopoverBehaviorIfNeeded()
            }
        )
    }

    func showItemEditor(
        mode: CalendarItemComposerMode,
        eventCalendars: [EKCalendar],
        reminderCalendars: [EKCalendar],
        onSaveEvent: @escaping (CalendarEventCreationRequest) throws -> Void,
        onSaveReminder: @escaping (ReminderCreationRequest) throws -> Void,
        onClose: @escaping () -> Void
    ) {
        closeVacationGuideWindow()
        closeWeatherDetailWindow()
        suspendTransientPopoverBehaviorForComposer()
        eventDetailPresenter.showEditor(
            mode: mode,
            eventCalendars: eventCalendars,
            reminderCalendars: reminderCalendars,
            anchoredTo: popover.contentViewController?.view.window,
            onSaveEvent: onSaveEvent,
            onSaveReminder: onSaveReminder,
            onClose: { [weak self] in
                onClose()
                self?.restoreTransientPopoverBehaviorIfNeeded()
            }
        )
    }

    func closeEventDetailWindow() {
        eventDetailPresenter.close()
    }

    func closeVacationGuideWindow() {
        vacationGuidePresenter.close()
    }

    func closeWeatherDetailWindow() {
        weatherDetailPresenter.close()
    }

    private func showVacationGuide(forMonth month: Date, onLocateDate: @escaping (Date) -> Void) {
        closeEventDetailWindow()
        closeWeatherDetailWindow()
        vacationGuidePresenter.show(
            referenceMonth: month,
            settingsStore: settingsStore,
            anchoredTo: popover.contentViewController?.view.window,
            onLocateDate: onLocateDate
        )
    }

    private func showWeatherDetailWindow(overview: WeatherForecastOverview, onClose: @escaping () -> Void) {
        closeEventDetailWindow()
        closeVacationGuideWindow()
        weatherDetailPresenter.show(
            overview: overview,
            anchoredTo: popover.contentViewController?.view.window,
            onClose: onClose
        )
    }

    private func quitApp() {
        closePopover()
        closeEventDetailWindow()
        closeWeatherDetailWindow()
        NSApp.terminate(nil)
    }

    private func suspendTransientPopoverBehaviorForComposer() {
        isComposerPresented = true
        popover.behavior = .applicationDefined
    }

    private func restoreTransientPopoverBehaviorIfNeeded() {
        guard isComposerPresented else { return }
        isComposerPresented = false
        popover.behavior = .transient
    }
}
