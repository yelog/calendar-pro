import AppKit
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
    func testToggleShowsPopoverAndStartsInteractionMonitor() {
        let popover = FakePopover()
        let interactionMonitor = FakePopoverInteractionMonitor()
        let controller = makeController(
            name: #function,
            popover: popover,
            interactionMonitor: interactionMonitor
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
        let controller = makeController(
            name: #function,
            popover: popover,
            interactionMonitor: interactionMonitor
        )

        controller.toggle(relativeTo: NSButton())
        interactionMonitor.triggerInteraction()

        XCTAssertFalse(popover.isShown)
        XCTAssertEqual(popover.closeCallCount, 1)
        XCTAssertNil(interactionMonitor.handler)
    }

    private func makeController(
        name: String,
        popover: PopoverPresenting,
        interactionMonitor: PopoverInteractionMonitoring
    ) -> PopoverController {
        let userDefaults = UserDefaults(suiteName: name)!
        userDefaults.removePersistentDomain(forName: name)
        let settingsStore = SettingsStore(userDefaults: userDefaults)

        return PopoverController(
            settingsStore: settingsStore,
            eventService: EventService(),
            popover: popover,
            interactionMonitor: interactionMonitor
        )
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
        isShown = false
        closeCallCount += 1
        delegate?.popoverDidClose?(Notification(name: NSPopover.didCloseNotification, object: self))
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
