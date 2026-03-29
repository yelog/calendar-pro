import AppKit
import XCTest

private final class LaunchState: @unchecked Sendable {
    var error: Error?
}

final class CalendarPopoverUITests: XCTestCase {
    private let bundleIdentifier = "com.yelog.CalendarPro"

    override func setUpWithError() throws {
        continueAfterFailure = false
        terminateExistingInstances()
    }

    override func tearDownWithError() throws {
        terminateExistingInstances()
    }

    @MainActor
    func testPopoverRendersMonthNavigation() throws {
        let app = XCUIApplication(bundleIdentifier: bundleIdentifier)
        try launchApplication(app)

        XCTAssertTrue(app.buttons["previous-month-button"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["next-month-button"].exists)
    }

    @MainActor
    private func launchApplication(_ app: XCUIApplication) throws {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance = true
        configuration.environment = ["CALENDAR_PRO_UI_TEST_MODE": "popover-window"]

        let appURL = try applicationURL()
        let launchExpectation = expectation(description: "launch CalendarPro")
        let launchState = LaunchState()

        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { _, error in
            launchState.error = error
            launchExpectation.fulfill()
        }

        wait(for: [launchExpectation], timeout: 10)
        if let error = launchState.error {
            throw error
        }

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }
}
    
private extension CalendarPopoverUITests {
    func applicationURL() throws -> URL {
        let productsDirectory = Bundle.main.bundleURL.deletingLastPathComponent()
        let appURL = productsDirectory.appendingPathComponent("CalendarPro.app")
        guard FileManager.default.fileExists(atPath: appURL.path) else {
            throw NSError(
                domain: "CalendarPopoverUITests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Missing app at \(appURL.path)"]
            )
        }
        return appURL
    }

    func terminateExistingInstances() {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).forEach { runningApplication in
            _ = runningApplication.terminate()
        }
    }
}
