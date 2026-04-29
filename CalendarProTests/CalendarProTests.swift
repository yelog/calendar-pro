import AppKit
import EventKit
import XCTest
@testable import CalendarPro

final class CalendarProTests: XCTestCase {
    func testAppModuleLoads() {
        let renderer = ClockRenderService()
        let text = renderer.render(
            now: Date(timeIntervalSince1970: 0),
            preferences: .default,
            locale: Locale(identifier: "en_US_POSIX"),
            calendar: Calendar(identifier: .gregorian),
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        XCTAssertFalse(text.isEmpty)
    }
}

@MainActor
final class PopoverControllerTests: XCTestCase {
    func testShowEventDetailWindowDelegatesToPresenter() {
        let presenter = FakeEventDetailWindowPresenter()
        let controller = makeController(
            name: #function,
            popover: FakePopover(),
            interactionMonitor: FakePopoverInteractionMonitor(),
            eventDetailPresenter: presenter
        )
        let event = makeEvent()
        var didInvokeClose = false

        controller.showEventDetailWindow(for: event) {
            didInvokeClose = true
        }

        XCTAssertEqual(presenter.showCallCount, 1)
        XCTAssertTrue(presenter.lastEvent === event)
        XCTAssertNil(presenter.lastAnchorWindow)

        presenter.lastOnClose?()
        XCTAssertTrue(didInvokeClose)
    }

    func testToggleShowsPopoverAndStartsInteractionMonitor() {
        let popover = FakePopover()
        let interactionMonitor = FakePopoverInteractionMonitor()
        let eventDetailPresenter = FakeEventDetailWindowPresenter()
        let controller = makeController(
            name: #function,
            popover: popover,
            interactionMonitor: interactionMonitor,
            eventDetailPresenter: eventDetailPresenter
        )

        controller.toggle(relativeTo: NSButton())

        XCTAssertTrue(popover.isShown)
        XCTAssertEqual(popover.showCallCount, 1)
        XCTAssertEqual(interactionMonitor.startCallCount, 1)
        XCTAssertNotNil(popover.contentViewController)
    }

    func testInteractionMonitorClosesShownPopover() {
        let popover = FakePopover()
        let interactionMonitor = FakePopoverInteractionMonitor()
        let eventDetailPresenter = FakeEventDetailWindowPresenter()
        let controller = makeController(
            name: #function,
            popover: popover,
            interactionMonitor: interactionMonitor,
            eventDetailPresenter: eventDetailPresenter
        )

        controller.toggle(relativeTo: NSButton())
        interactionMonitor.triggerInteraction()

        XCTAssertFalse(popover.isShown)
        XCTAssertEqual(popover.closeCallCount, 1)
        XCTAssertNil(interactionMonitor.handler)
    }

    func testCloseEventDetailWindowIsSafeWhenNothingIsShown() {
        let presenter = FakeEventDetailWindowPresenter()
        let controller = makeController(
            name: #function,
            popover: FakePopover(),
            interactionMonitor: FakePopoverInteractionMonitor(),
            eventDetailPresenter: presenter
        )

        controller.closeEventDetailWindow()

        XCTAssertEqual(presenter.closeCallCount, 1)
    }

    func testClosingPopoverAlsoClosesEventDetailWindow() {
        let popover = FakePopover()
        let interactionMonitor = FakePopoverInteractionMonitor()
        let presenter = FakeEventDetailWindowPresenter()
        let controller = makeController(
            name: #function,
            popover: popover,
            interactionMonitor: interactionMonitor,
            eventDetailPresenter: presenter
        )

        controller.toggle(relativeTo: NSButton())
        interactionMonitor.triggerInteraction()

        XCTAssertEqual(presenter.closeCallCount, 1)
    }

    func testShowingComposerSuspendsTransientPopoverUntilComposerCloses() {
        let popover = FakePopover()
        let presenter = FakeEventDetailWindowPresenter()
        let controller = makeController(
            name: #function,
            popover: popover,
            interactionMonitor: FakePopoverInteractionMonitor(),
            eventDetailPresenter: presenter
        )

        controller.showItemComposer(
            kind: .event,
            selectedDate: Date(),
            eventCalendars: [],
            reminderCalendars: [],
            onSaveEvent: { _ in },
            onSaveReminder: { _ in },
            onClose: {}
        )

        XCTAssertEqual(popover.behavior, .applicationDefined)

        presenter.lastOnClose?()

        XCTAssertEqual(popover.behavior, .transient)
    }

    func testReopenAfterThirtySecondsResetsToToday() {
        let popover = FakePopover()
        let interactionMonitor = FakePopoverInteractionMonitor()
        let viewModel = CalendarPopoverViewModel(
            displayedMonth: Calendar.current.date(byAdding: .month, value: -2, to: Date()) ?? Date()
        )
        let selectedDate = Calendar.current.date(byAdding: .day, value: -10, to: Date()) ?? Date()
        viewModel.selectDate(selectedDate)
        let controller = makeController(
            name: #function,
            popover: popover,
            interactionMonitor: interactionMonitor,
            viewModel: viewModel
        )

        controller.toggle(relativeTo: NSButton())
        interactionMonitor.triggerInteraction()
        viewModel.lastClosedTime = Date().addingTimeInterval(-31)

        controller.toggle(relativeTo: NSButton())

        XCTAssertTrue(popover.isShown)
        XCTAssertTrue(Calendar.current.isDate(viewModel.displayedMonth, equalTo: Date(), toGranularity: .month))
        XCTAssertNotNil(viewModel.selectedDate)
        XCTAssertTrue(Calendar.current.isDate(viewModel.selectedDate!, inSameDayAs: Date()))
        XCTAssertNil(viewModel.lastClosedTime)
    }

    func testShowingPopoverAfterDayChangeSyncsCurrentDaySelection() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let currentTime = PopoverMutableBox(calendar.date(from: DateComponents(year: 2030, month: 6, day: 15, hour: 8, minute: 10))!)
        let timeRefreshCoordinator = TimeRefreshCoordinator(
            now: { currentTime.value },
            calendarProvider: { calendar },
            notificationCenter: NotificationCenter(),
            workspaceNotificationCenter: NotificationCenter()
        )
        let viewModel = CalendarPopoverViewModel(
            displayedMonth: currentTime.value,
            now: { timeRefreshCoordinator.currentDate }
        )
        viewModel.selectCurrentDate()
        currentTime.value = calendar.date(from: DateComponents(year: 2030, month: 6, day: 16, hour: 8, minute: 10))!
        let popover = FakePopover()
        let controller = makeController(
            name: #function,
            popover: popover,
            interactionMonitor: FakePopoverInteractionMonitor(),
            timeRefreshCoordinator: timeRefreshCoordinator,
            viewModel: viewModel
        )

        controller.toggle(relativeTo: NSButton())

        XCTAssertTrue(popover.isShown)
        XCTAssertNotNil(viewModel.selectedDate)
        XCTAssertTrue(calendar.isDate(viewModel.selectedDate!, inSameDayAs: currentTime.value))
    }

    private func makeController(
        name: String,
        popover: PopoverPresenting,
        interactionMonitor: PopoverInteractionMonitoring,
        eventDetailPresenter: EventDetailWindowPresenting = FakeEventDetailWindowPresenter(),
        timeRefreshCoordinator: TimeRefreshCoordinator = TimeRefreshCoordinator(),
        viewModel: CalendarPopoverViewModel? = nil
    ) -> PopoverController {
        let userDefaults = UserDefaults(suiteName: name)!
        userDefaults.removePersistentDomain(forName: name)
        let settingsStore = SettingsStore(userDefaults: userDefaults)

        return PopoverController(
            settingsStore: settingsStore,
            eventService: EventService(),
            popover: popover,
            interactionMonitor: interactionMonitor,
            eventDetailPresenter: eventDetailPresenter,
            timeRefreshCoordinator: timeRefreshCoordinator,
            viewModel: viewModel ?? CalendarPopoverViewModel()
        )
    }

    private func makeEvent() -> EKEvent {
        let event = EKEvent(eventStore: EKEventStore())
        event.title = "评审会议"
        event.startDate = Date(timeIntervalSince1970: 1_711_676_800)
        event.endDate = Date(timeIntervalSince1970: 1_711_680_400)
        return event
    }
}

@MainActor
final class PopoverInteractionMonitorTests: XCTestCase {
    func testGlobalMouseMonitorInvokesHandler() {
        let notificationCenter = NotificationCenter()
        let installer = FakeEventMonitorInstaller()
        let monitor = PopoverInteractionMonitor(
            notificationCenter: notificationCenter,
            eventMonitorInstaller: installer
        )
        let expectation = expectation(description: "global mouse interaction")

        monitor.start {
            expectation.fulfill()
        }
        installer.fireGlobalMouseDown()

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(installer.addGlobalMouseDownMonitorCallCount, 1)
    }

    func testDidResignActiveNotificationInvokesHandler() {
        let notificationCenter = NotificationCenter()
        let installer = FakeEventMonitorInstaller()
        let monitor = PopoverInteractionMonitor(
            notificationCenter: notificationCenter,
            eventMonitorInstaller: installer
        )
        let expectation = expectation(description: "resign active interaction")

        monitor.start {
            expectation.fulfill()
        }
        notificationCenter.post(name: NSApplication.didResignActiveNotification, object: nil)

        wait(for: [expectation], timeout: 1)
    }

    func testStopRemovesInstalledGlobalMonitor() {
        let notificationCenter = NotificationCenter()
        let installer = FakeEventMonitorInstaller()
        let monitor = PopoverInteractionMonitor(
            notificationCenter: notificationCenter,
            eventMonitorInstaller: installer
        )

        monitor.start {}
        monitor.stop()

        XCTAssertEqual(installer.removeMonitorCallCount, 1)
    }
}

@MainActor
private final class FakePopover: NSObject, PopoverPresenting {
    weak var delegate: NSPopoverDelegate?
    var isShown = false
    var behavior: NSPopover.Behavior = .transient
    var animates = false
    var contentSize = NSSize.zero
    var contentViewController: NSViewController?

    private(set) var showCallCount = 0
    private(set) var closeCallCount = 0

    func show(relativeTo positioningRect: NSRect, of positioningView: NSView, preferredEdge: NSRectEdge) {
        isShown = true
        showCallCount += 1
    }

    func performClose(_ sender: Any?) {
        guard isShown else { return }
        let shouldClose = delegate?.popoverShouldClose?(NSPopover()) ?? true
        guard shouldClose else { return }
        isShown = false
        closeCallCount += 1
        delegate?.popoverDidClose?(Notification(name: NSPopover.didCloseNotification, object: self))
    }
}

private final class PopoverMutableBox<Value> {
    var value: Value

    init(_ value: Value) {
        self.value = value
    }
}

@MainActor
private final class FakePopoverInteractionMonitor: PopoverInteractionMonitoring {
    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0
    private(set) var handler: (@MainActor () -> Void)?

    func start(onInteraction: @escaping @MainActor () -> Void) {
        startCallCount += 1
        handler = onInteraction
    }

    func stop() {
        stopCallCount += 1
        handler = nil
    }

    func triggerInteraction() {
        handler?()
    }
}

private final class FakeEventMonitorInstaller: EventMonitorInstalling {
    private(set) var addGlobalMouseDownMonitorCallCount = 0
    private(set) var removeMonitorCallCount = 0

    private var handler: (() -> Void)?

    func addGlobalMouseDownMonitor(handler: @escaping () -> Void) -> Any? {
        addGlobalMouseDownMonitorCallCount += 1
        self.handler = handler
        return UUID()
    }

    func removeMonitor(_ monitor: Any) {
        removeMonitorCallCount += 1
        handler = nil
    }

    func fireGlobalMouseDown() {
        handler?()
    }
}

@MainActor
private final class FakeEventDetailWindowPresenter: EventDetailWindowPresenting {
    private(set) var closeCallCount = 0
    private(set) var showCallCount = 0
    private(set) var lastEvent: EKEvent?
    private(set) var lastAnchorWindow: NSWindow?
    private(set) var lastOnClose: (() -> Void)?

    func show(event: EKEvent, anchoredTo anchorWindow: NSWindow?, onJoinMeeting: (() -> Void)? = nil, onClose: @escaping () -> Void) {
        showCallCount += 1
        lastEvent = event
        lastAnchorWindow = anchorWindow
        lastOnClose = onClose
    }

    func show(reminder: EKReminder, anchoredTo anchorWindow: NSWindow?, onToggle: @escaping (EKReminder) -> Void, onClose: @escaping () -> Void) {
        showCallCount += 1
        lastOnClose = onClose
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
        showCallCount += 1
        lastAnchorWindow = anchorWindow
        lastOnClose = onClose
    }

    func close() {
        closeCallCount += 1
    }
}
