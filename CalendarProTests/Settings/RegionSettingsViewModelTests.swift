import XCTest
@testable import CalendarPro

@MainActor
final class RegionSettingsViewModelTests: XCTestCase {
    func testRegionSettingsReflectsEnabledProviders() {
        let viewModel = RegionSettingsViewModel.preview

        XCTAssertTrue(viewModel.availableRegions.contains { $0.id == "mainland-cn" && $0.isEnabled })
        XCTAssertTrue(viewModel.availableRegions.contains { $0.id == "hong-kong" && !$0.isEnabled })
    }

    func testTogglingHolidaySetUpdatesViewModelState() {
        let suiteName = #function
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)

        let store = SettingsStore(userDefaults: userDefaults)
        let viewModel = RegionSettingsViewModel(store: store)

        viewModel.setHolidaySetEnabled(false, holidaySetID: "adjustment-workdays")

        let mainland = viewModel.availableRegions.first { $0.id == "mainland-cn" }
        XCTAssertEqual(
            mainland?.holidaySets.first(where: { $0.id == "adjustment-workdays" })?.isEnabled,
            false
        )
    }
}
