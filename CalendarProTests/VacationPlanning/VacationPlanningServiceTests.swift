import XCTest
@testable import CalendarPro

final class VacationPlanningServiceTests: XCTestCase {
    func testVacationOpportunitiesGenerateExpected2026Summaries() throws {
        let service = VacationPlanningService(
            registry: HolidayProviderRegistry(providers: [MainlandCNProvider()]),
            calendar: .gregorianMondayFirst
        )

        let opportunities = try service.opportunities(
            forYear: 2026,
            activeRegionIDs: ["mainland-cn"],
            enabledHolidaySetIDs: []
        )

        XCTAssertTrue(opportunities.contains { $0.holidayName == "元旦" && $0.summary == "请3休8" })
        XCTAssertTrue(opportunities.contains { $0.holidayName == "春节" && $0.summary == "请5休15" })
        XCTAssertTrue(opportunities.contains { $0.holidayName == "清明节" && $0.summary == "请4休9" })
        XCTAssertTrue(opportunities.contains { $0.holidayName == "劳动节" && $0.summary == "请4休11" })
        XCTAssertTrue(opportunities.contains { $0.holidayName == "端午节" && $0.summary == "请4休9" })
        XCTAssertTrue(opportunities.contains { $0.holidayName == "中秋节、国庆节" && $0.summary == "请3休13" })
    }

    func testSpringFestivalOpportunityMarksAdjustmentWorkdayInSegments() throws {
        let service = VacationPlanningService(
            registry: HolidayProviderRegistry(providers: [MainlandCNProvider()]),
            calendar: .gregorianMondayFirst
        )

        let opportunities = try service.opportunities(
            forYear: 2026,
            activeRegionIDs: ["mainland-cn"],
            enabledHolidaySetIDs: []
        )

        let springFestival = try XCTUnwrap(opportunities.first { $0.holidayName == "春节" })
        let adjustmentSegment = try XCTUnwrap(
            springFestival.segments.first {
                Calendar.gregorianMondayFirst.isDate($0.date, inSameDayAs: makeDate(year: 2026, month: 2, day: 28))
            }
        )

        XCTAssertEqual(adjustmentSegment.kind, .adjustmentWorkday)
        XCTAssertEqual(springFestival.leaveDaysRequired, 5)
    }

    func testVacationOpportunitiesAreSortedChronologically() throws {
        let service = VacationPlanningService(
            registry: HolidayProviderRegistry(providers: [MainlandCNProvider()]),
            calendar: .gregorianMondayFirst
        )

        let opportunities = try service.opportunities(
            forYear: 2026,
            activeRegionIDs: ["mainland-cn"],
            enabledHolidaySetIDs: []
        )

        let orderedFocusDates = opportunities.map(\.focusDate)
        XCTAssertEqual(orderedFocusDates, orderedFocusDates.sorted())
        XCTAssertEqual(
            opportunities.map(\.holidayName),
            ["元旦", "春节", "清明节", "劳动节", "端午节", "中秋节、国庆节"]
        )
    }

    func testScrollTargetResolverPrefersOpportunityIntersectingCurrentMonth() throws {
        let service = VacationPlanningService(
            registry: HolidayProviderRegistry(providers: [MainlandCNProvider()]),
            calendar: .gregorianMondayFirst
        )

        let opportunities = try service.opportunities(
            forYear: 2026,
            activeRegionIDs: ["mainland-cn"],
            enabledHolidaySetIDs: []
        )
        let resolver = VacationGuideScrollTargetResolver(
            calendar: .gregorianMondayFirst,
            preferredMonth: 9
        )

        let target = resolver.targetOpportunity(in: opportunities, displayedYear: 2026)

        XCTAssertEqual(target?.holidayName, "中秋节、国庆节")
    }

    func testScrollTargetResolverFallsForwardToNearestFutureOpportunity() throws {
        let service = VacationPlanningService(
            registry: HolidayProviderRegistry(providers: [MainlandCNProvider()]),
            calendar: .gregorianMondayFirst
        )

        let opportunities = try service.opportunities(
            forYear: 2026,
            activeRegionIDs: ["mainland-cn"],
            enabledHolidaySetIDs: []
        )
        let resolver = VacationGuideScrollTargetResolver(
            calendar: .gregorianMondayFirst,
            preferredMonth: 8
        )

        let target = resolver.targetOpportunity(in: opportunities, displayedYear: 2026)

        XCTAssertEqual(target?.holidayName, "中秋节、国庆节")
    }

    func testServiceReturnsEmptyWhenMainlandChinaIsNotActive() throws {
        let service = VacationPlanningService(
            registry: HolidayProviderRegistry(providers: [MainlandCNProvider()]),
            calendar: .gregorianMondayFirst
        )

        let opportunities = try service.opportunities(
            forYear: 2026,
            activeRegionIDs: ["us"],
            enabledHolidaySetIDs: []
        )

        XCTAssertTrue(opportunities.isEmpty)
    }

    func testServiceReturnsEmptyWhenStatutoryHolidaysAreDisabled() throws {
        let service = VacationPlanningService(
            registry: HolidayProviderRegistry(providers: [MainlandCNProvider()]),
            calendar: .gregorianMondayFirst
        )

        let opportunities = try service.opportunities(
            forYear: 2026,
            activeRegionIDs: ["mainland-cn"],
            enabledHolidaySetIDs: ["adjustment-workdays"]
        )

        XCTAssertTrue(opportunities.isEmpty)
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        DateComponents(
            calendar: Calendar.gregorianMondayFirst,
            timeZone: TimeZone(secondsFromGMT: 0),
            year: year,
            month: month,
            day: day
        ).date!
    }
}
