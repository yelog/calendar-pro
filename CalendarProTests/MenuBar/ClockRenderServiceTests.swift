import XCTest
@testable import CalendarPro

final class ClockRenderServiceTests: XCTestCase {
    func testRendererRespectsTokenOrderAndShortStyles() {
        let renderer = ClockRenderService()
        let text = renderer.render(
            now: Date(timeIntervalSince1970: 0),
            preferences: .previewShort,
            locale: Locale(identifier: "en_US_POSIX"),
            calendar: Calendar(identifier: .gregorian),
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        XCTAssertEqual(text, "00:00 Thu 01/01")
    }

    func testRendererSkipsEmptySupplementalTokens() {
        let renderer = ClockRenderService()
        let preferences = MenuBarPreferences(
            tokens: [
                DisplayTokenPreference(token: .time, isEnabled: true, order: 0, style: .short),
                DisplayTokenPreference(token: .lunar, isEnabled: true, order: 1, style: .short)
            ],
            separator: " ",
            showLunarInMenuBar: true,
            activeRegionIDs: ["mainland-cn"],
            enabledHolidayIDs: [],
            weekStart: .monday
        )

        let text = renderer.render(
            now: Date(timeIntervalSince1970: 0),
            preferences: preferences,
            locale: Locale(identifier: "en_US_POSIX"),
            calendar: Calendar(identifier: .gregorian),
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        XCTAssertEqual(text, "00:00")
    }
}
