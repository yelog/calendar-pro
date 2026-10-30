import XCTest
import AppKit
import EventKit
import SwiftUI
@testable import CalendarPro

final class EventDetailWindowSizingTests: XCTestCase {
    func testUsesFixedPopoverWidth() {
        let size = EventDetailWindowSizing.panelSize(for: CGSize(width: 780, height: 300), availableHeight: 360)

        XCTAssertEqual(size.width, 340)
    }

    func testPrefersIdealHeightForShortContentEvenWhenThereIsMoreSpace() {
        let size = EventDetailWindowSizing.panelSize(for: CGSize(width: 240, height: 260), availableHeight: 720)

        XCTAssertEqual(size.height, 360)
    }

    func testUsesMeasuredHeightWhenContentIsTallerThanIdealHeight() {
        let size = EventDetailWindowSizing.panelSize(for: CGSize(width: 240, height: 420), availableHeight: 720)

        XCTAssertEqual(size.height, 420)
    }

    func testClampsHeightToAvailableHeightForVeryTallContent() {
        let size = EventDetailWindowSizing.panelSize(for: CGSize(width: 240, height: 1_200), availableHeight: 400)

        XCTAssertEqual(size.height, 400)
    }
}

@MainActor
final class EventPanelLayoutTests: XCTestCase {
    func testComposerWindowHeightSettlesWithoutInteraction() {
        let host = EventPanelLayoutHost(availableHeight: 700)
        let view = CalendarItemComposerView(
            mode: .create(kind: .event, selectedDate: Date(), initialTimeRange: nil),
            eventCalendars: [],
            reminderCalendars: [],
            maximumHeight: 700,
            onPreferredHeightChange: { [weak host] in host?.resize(to: $0) },
            onSaveEvent: { _ in },
            onSaveReminder: { _ in },
            onClose: {}
        )

        host.install(view)
        host.pumpMainRunLoop(for: 0.5)

        XCTAssertGreaterThan(host.resizeCount, 0, "The composer did not report a natural height")
        XCTAssertLessThanOrEqual(host.resizeCount, 8, "Composer height kept feeding back into its window size")
    }

    func testComposerWindowHeightSettlesWithinSmallAvailableHeight() {
        let host = EventPanelLayoutHost(availableHeight: 360)
        let view = CalendarItemComposerView(
            mode: .create(kind: .event, selectedDate: Date(), initialTimeRange: nil),
            eventCalendars: [],
            reminderCalendars: [],
            maximumHeight: 360,
            onPreferredHeightChange: { [weak host] in host?.resize(to: $0) },
            onSaveEvent: { _ in },
            onSaveReminder: { _ in },
            onClose: {}
        )

        host.install(view)
        host.pumpMainRunLoop(for: 0.5)

        XCTAssertLessThanOrEqual(host.panelHeight, 360)
        XCTAssertGreaterThan(host.resizeCount, 0, "The small composer did not report a natural height")
        XCTAssertLessThanOrEqual(host.resizeCount, 8, "Composer height kept feeding back into its small window size")
    }

    func testEventDetailWithNotesWindowHeightSettlesWithoutInteraction() {
        let event = makeEvent(notes: (1...6).map { "Synthetic note line \($0)" }.joined(separator: "\n"))
        let host = EventPanelLayoutHost(availableHeight: 700)
        let view = EventDetailWindowView(
            event: event,
            onEdit: { _ in },
            onDelete: { _ in },
            onClose: {},
            onPreferredHeightChange: { [weak host] in host?.resize(to: $0) }
        )

        host.install(view)
        host.pumpMainRunLoop(for: 0.5)

        XCTAssertGreaterThan(host.resizeCount, 0, "The detail did not report a natural height")
        XCTAssertLessThanOrEqual(host.resizeCount, 8, "Event detail height kept feeding back into its window size")
    }

    func testLongEventNotesWindowHeightSettlesAtAvailableHeight() {
        let notes = (1...200).map { "Synthetic note line \($0)" }.joined(separator: "\n")
        let event = makeEvent(notes: notes)
        let host = EventPanelLayoutHost(availableHeight: 700)
        let view = EventDetailWindowView(
            event: event,
            maximumHeight: 700,
            onEdit: { _ in },
            onDelete: { _ in },
            onClose: {},
            onPreferredHeightChange: { [weak host] in host?.resize(to: $0) }
        )

        host.install(view)
        host.pumpMainRunLoop(for: 0.5)

        XCTAssertLessThan(host.panelHeight, 700)
        XCTAssertGreaterThan(host.resizeCount, 0, "Long notes did not report a natural height")
        XCTAssertLessThanOrEqual(host.resizeCount, 8, "Long event notes kept feeding back into the window size")
    }

    private func makeEvent(notes: String) -> EKEvent {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = "Test Calendar"
        calendar.source = store.sources.first { $0.sourceType == .local }
        calendar.cgColor = NSColor.systemBlue.cgColor
        event.calendar = calendar
        event.title = "Synthetic all-day event"
        event.startDate = Date(timeIntervalSince1970: 1_793_952_000)
        event.endDate = Date(timeIntervalSince1970: 1_794_124_800)
        event.isAllDay = true
        event.notes = notes
        return event
    }
}

@MainActor
final class EventDetailWindowControllerTests: XCTestCase {
    func testPreviousDetailsMeasurementCannotResizeReplacementDetail() throws {
        var createdPanels: [NSPanel] = []
        var oldPageReportHeight: ((CGFloat) -> Void)?
        var callbackCount = 0
        var requestedFrames: [NSRect] = []
        let controller = EventDetailWindowController(
            panelFactory: { contentRect, styleMask in
                let panel = NSPanel(contentRect: contentRect, styleMask: styleMask, backing: .buffered, defer: false)
                panel.isReleasedWhenClosed = false
                createdPanels.append(panel)
                return panel
            },
            preferredHeightCallbackObserver: { callback in
                callbackCount += 1
                if callbackCount == 1 { oldPageReportHeight = callback }
            },
            availableHeightProvider: { _ in 1000 },
            setPanelFrame: { panel, frame, _ in
                requestedFrames.append(frame)
                panel.setFrame(frame, display: false)
            }
        )

        controller.show(
            event: makeEvent(notes: (1...200).map { "Old detail note line \($0)" }.joined(separator: "\n")),
            anchoredTo: nil,
            onEdit: { _ in },
            onDelete: { _ in },
            onClose: {}
        )
        let reportOldPageHeight = try XCTUnwrap(oldPageReportHeight)
        controller.show(
            event: makeEvent(notes: nil),
            anchoredTo: nil,
            onEdit: { _ in },
            onDelete: { _ in },
            onClose: {}
        )
        reportOldPageHeight(650)

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.5))

        XCTAssertEqual(createdPanels.count, 1)
        let replacementHeight = try XCTUnwrap(requestedFrames.last?.height)
        XCTAssertGreaterThan(replacementHeight, 0)
        XCTAssertLessThan(replacementHeight, 650)
        controller.close()
    }

    func testClosingControllerDiscardsPendingPreferredHeightUpdates() throws {
        var createdPanels: [NSPanel] = []
        var preferredHeightCallback: ((CGFloat) -> Void)?
        var requestedFrames: [NSRect] = []
        let controller = EventDetailWindowController(
            panelFactory: { contentRect, styleMask in
                let panel = NSPanel(contentRect: contentRect, styleMask: styleMask, backing: .buffered, defer: false)
                panel.isReleasedWhenClosed = false
                createdPanels.append(panel)
                return panel
            },
            preferredHeightCallbackObserver: { callback in preferredHeightCallback = callback },
            availableHeightProvider: { _ in 1000 },
            setPanelFrame: { panel, frame, _ in
                requestedFrames.append(frame)
                panel.setFrame(frame, display: false)
            }
        )

        controller.show(
            event: makeEvent(notes: (1...200).map { "Pending note line \($0)" }.joined(separator: "\n")),
            anchoredTo: nil,
            onEdit: { _ in },
            onDelete: { _ in },
            onClose: {}
        )
        let reportHeight = try XCTUnwrap(preferredHeightCallback)
        let heightBeforeClose = requestedFrames.last?.height
        reportHeight(640)
        controller.close()
        reportHeight(680)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))

        XCTAssertEqual(createdPanels.count, 1)
        XCTAssertFalse(createdPanels[0].isVisible)
        XCTAssertEqual(requestedFrames.last?.height, heightBeforeClose)
    }

    func testSameTurnPreferredHeightUpdatesUseOnlyLatestValue() throws {
        var createdPanels: [NSPanel] = []
        var preferredHeightCallback: ((CGFloat) -> Void)?
        var requestedFrames: [NSRect] = []
        let controller = EventDetailWindowController(
            panelFactory: { contentRect, styleMask in
                let panel = NSPanel(contentRect: contentRect, styleMask: styleMask, backing: .buffered, defer: false)
                panel.isReleasedWhenClosed = false
                createdPanels.append(panel)
                return panel
            },
            activateApplication: {},
            preferredHeightCallbackObserver: { callback in preferredHeightCallback = callback },
            availableHeightProvider: { _ in 1000 },
            preferredHeightScheduler: { apply in DispatchQueue.main.async { apply() } },
            setPanelFrame: { panel, frame, _ in
                requestedFrames.append(frame)
                panel.setFrame(frame, display: false)
            }
        )

        controller.showComposer(
            kind: .event,
            selectedDate: Date(),
            initialTimeRange: nil,
            eventCalendars: [],
            reminderCalendars: [],
            anchoredTo: nil,
            onSaveEvent: { _ in },
            onSaveReminder: { _ in },
            onClose: {}
        )
        let initialFrame = try XCTUnwrap(requestedFrames.first)
        let reportHeight = try XCTUnwrap(preferredHeightCallback)
        reportHeight(400)
        reportHeight(500)
        reportHeight(.nan)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

        XCTAssertEqual(requestedFrames.last?.height, 500)
        controller.close()

        XCTAssertEqual(createdPanels.count, 1)
        XCTAssertNotEqual(initialFrame.height, requestedFrames.last?.height)
    }

    func testLateCloseNotificationFromReplacedPanelDoesNotClearCurrentPanel() {
        var createdPanels: [NSPanel] = []
        let controller = EventDetailWindowController(
            panelFactory: { contentRect, styleMask in
                let panel = NSPanel(contentRect: contentRect, styleMask: styleMask, backing: .buffered, defer: false)
                panel.isReleasedWhenClosed = false
                createdPanels.append(panel)
                return panel
            },
            activateApplication: {}
        )

        controller.show(
            event: makeEvent(notes: nil),
            anchoredTo: nil,
            onEdit: { _ in },
            onDelete: { _ in },
            onClose: {}
        )
        let oldPanel = createdPanels[0]
        controller.showComposer(
            kind: .event,
            selectedDate: Date(),
            initialTimeRange: nil,
            eventCalendars: [],
            reminderCalendars: [],
            anchoredTo: nil,
            onSaveEvent: { _ in },
            onSaveReminder: { _ in },
            onClose: {}
        )
        let currentPanel = createdPanels[1]

        controller.windowWillClose(Notification(name: NSWindow.willCloseNotification, object: oldPanel))

        XCTAssertTrue(currentPanel.isVisible)
        controller.close()
    }

    private func makeEvent(notes: String?) -> EKEvent {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = "Test Calendar"
        calendar.source = store.sources.first { $0.sourceType == .local }
        calendar.cgColor = NSColor.systemBlue.cgColor
        event.calendar = calendar
        event.title = "Synthetic event"
        event.startDate = Date(timeIntervalSince1970: 1_793_952_000)
        event.endDate = Date(timeIntervalSince1970: 1_794_124_800)
        event.isAllDay = true
        event.notes = notes
        return event
    }
}

@MainActor
private final class EventPanelLayoutHost {
    private let panel: NSPanel
    private let availableHeight: CGFloat
    private(set) var resizeCount = 0

    var panelHeight: CGFloat { panel.frame.height }

    init(availableHeight: CGFloat) {
        self.availableHeight = availableHeight
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: EventDetailWindowSizing.width, height: EventDetailWindowSizing.idealHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
    }

    func install<Content: View>(_ content: Content) {
        let hostingController = NSHostingController(rootView: AnyView(content))
        panel.contentViewController = hostingController

        let size = EventDetailWindowSizing.panelSize(
            for: hostingController.view.fittingSize,
            availableHeight: availableHeight
        )
        panel.setContentSize(size)
        panel.setFrame(NSRect(origin: panel.frame.origin, size: size), display: false)
    }

    func resize(to preferredHeight: CGFloat) {
        guard preferredHeight.isFinite, preferredHeight > 0, resizeCount < 64 else { return }
        let size = EventDetailWindowSizing.panelSize(
            for: CGSize(width: EventDetailWindowSizing.width, height: preferredHeight),
            availableHeight: availableHeight
        )
        guard abs(panel.frame.height - size.height) > 1 else { return }

        resizeCount += 1
        panel.setContentSize(size)
        panel.setFrame(NSRect(origin: panel.frame.origin, size: size), display: false)
    }

    func pumpMainRunLoop(for duration: TimeInterval) {
        RunLoop.main.run(until: Date(timeIntervalSinceNow: duration))
    }
}
