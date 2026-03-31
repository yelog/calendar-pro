import XCTest
import ServiceManagement
@testable import CalendarPro

final class LaunchAtLoginControllerTests: XCTestCase {
    func testMapStatusEnabled() {
        XCTAssertEqual(SystemLaunchAtLoginController.mapStatus(.enabled), .enabled)
    }

    func testMapStatusNotRegistered() {
        XCTAssertEqual(SystemLaunchAtLoginController.mapStatus(.notRegistered), .disabled)
    }

    func testMapStatusRequiresApproval() {
        XCTAssertEqual(SystemLaunchAtLoginController.mapStatus(.requiresApproval), .requiresApproval)
    }

    func testMapStatusNotFound() {
        XCTAssertEqual(SystemLaunchAtLoginController.mapStatus(.notFound), .unavailable)
    }
}
