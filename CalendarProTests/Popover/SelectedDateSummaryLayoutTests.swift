import XCTest
@testable import CalendarPro

final class SelectedDateSummaryLayoutTests: XCTestCase {
    func testFlowPlannerKeepsItemsOnLineWhenTheyExactlyFit() {
        let plan = SummaryChipFlowPlanner.plan(
            sizes: [CGSize(width: 40, height: 19), CGSize(width: 20, height: 17)],
            availableWidth: 64,
            horizontalSpacing: 4,
            verticalSpacing: 5
        )

        XCTAssertEqual(plan.origins, [CGPoint(x: 0, y: 0), CGPoint(x: 44, y: 0)])
        XCTAssertEqual(plan.size, CGSize(width: 64, height: 19))
    }

    func testFlowPlannerWrapsWhenNextItemExceedsWidthByOnePoint() {
        let plan = SummaryChipFlowPlanner.plan(
            sizes: [CGSize(width: 40, height: 19), CGSize(width: 20, height: 17)],
            availableWidth: 63,
            horizontalSpacing: 4,
            verticalSpacing: 5
        )

        XCTAssertEqual(plan.origins, [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 24)])
        XCTAssertEqual(plan.size, CGSize(width: 40, height: 41))
    }

    func testFlowPlannerUsesTallestItemForNextRowOrigin() {
        let plan = SummaryChipFlowPlanner.plan(
            sizes: [
                CGSize(width: 38, height: 32),
                CGSize(width: 20, height: 17),
                CGSize(width: 20, height: 19)
            ],
            availableWidth: 62,
            horizontalSpacing: 4,
            verticalSpacing: 5
        )

        XCTAssertEqual(plan.origins, [CGPoint(x: 0, y: 0), CGPoint(x: 42, y: 0), CGPoint(x: 0, y: 37)])
        XCTAssertEqual(plan.size.height, 56)
    }

    func testFlowPlannerReturnsZeroSizeForNoItems() {
        let plan = SummaryChipFlowPlanner.plan(
            sizes: [],
            availableWidth: 308,
            horizontalSpacing: 4,
            verticalSpacing: 5
        )

        XCTAssertEqual(plan.size, .zero)
        XCTAssertTrue(plan.origins.isEmpty)
    }

    func testFlowPlannerClampsLongItemAndHandlesZeroWidth() {
        let plan = SummaryChipFlowPlanner.plan(
            sizes: [CGSize(width: 120, height: 40)],
            availableWidth: 80,
            horizontalSpacing: 4,
            verticalSpacing: 5
        )
        let zeroWidthPlan = SummaryChipFlowPlanner.plan(
            sizes: [CGSize(width: 120, height: 40)],
            availableWidth: 0,
            horizontalSpacing: 4,
            verticalSpacing: 5
        )

        XCTAssertEqual(plan.size, CGSize(width: 80, height: 40))
        XCTAssertEqual(plan.itemSizes, [CGSize(width: 80, height: 40)])
        XCTAssertEqual(zeroWidthPlan.size, CGSize(width: 0, height: 40))
    }

    func testFlowPlannerAddsNonzeroBoundsOriginToItemOrigins() {
        let plan = SummaryChipFlowPlanner.plan(
            sizes: [CGSize(width: 20, height: 19), CGSize(width: 10, height: 17)],
            availableWidth: 34,
            horizontalSpacing: 4,
            verticalSpacing: 5
        )
        let placedOrigins = SummaryChipFlowLayout.placementOrigins(
            for: plan,
            in: CGRect(origin: CGPoint(x: 12, y: 9), size: plan.size)
        )

        XCTAssertEqual(placedOrigins, [CGPoint(x: 12, y: 9), CGPoint(x: 36, y: 9)])
    }
}
