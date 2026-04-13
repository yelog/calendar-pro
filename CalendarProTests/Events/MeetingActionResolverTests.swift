import XCTest
import EventKit
@testable import CalendarPro

final class MeetingActionResolverTests: XCTestCase {

    func testResolve_returnsJoinForTeamsMeetupJoinLink() {
        let event = makeEvent(
            title: "MES meeting",
            start: makeDate(year: 2026, month: 4, day: 13, hour: 15, minute: 0),
            end: makeDate(year: 2026, month: 4, day: 13, hour: 16, minute: 0)
        )
        event.notes = """
        Join Microsoft Teams Meeting
        https://teams.microsoft.com/l/meetup-join/19%3ameeting_xxx/0?context=%7b%7d
        """

        let actions = MeetingActionResolver.resolve(for: event)

        XCTAssertEqual(actions.map(\.kind), [.join])
        XCTAssertEqual(actions.first?.platform, .microsoftTeams)
        XCTAssertEqual(actions.first?.source, .inferredFromJoinLink)
        XCTAssertEqual(actions.first?.confidence, .high)

        guard case .ordered(let primary, let fallback)? = actions.first?.openPlan else {
            return XCTFail("Expected ordered open plan")
        }
        XCTAssertEqual(primary.first?.scheme, "msteams")
        XCTAssertEqual(fallback?.scheme, "https")
    }

    func testResolve_returnsJoinAndHighConfidenceChatWhenExplicitChatLinkExists() {
        let event = makeEvent(
            title: "Design sync",
            start: makeDate(year: 2026, month: 4, day: 13, hour: 10, minute: 0),
            end: makeDate(year: 2026, month: 4, day: 13, hour: 11, minute: 0)
        )
        event.notes = """
        Join Microsoft Teams Meeting
        https://teams.microsoft.com/l/meetup-join/19%3ameeting_xxx/0?context=%7b%7d
        Chat:
        https://teams.microsoft.com/l/chat/19:abc123@thread.v2/conversations
        """

        let actions = MeetingActionResolver.resolve(for: event)

        XCTAssertEqual(actions.map(\.kind), [.join, .chat])
        XCTAssertEqual(actions.last?.confidence, .high)
        XCTAssertEqual(actions.last?.source, .explicitLink)
        XCTAssertEqual(actions.last?.title, L("Chat"))
    }

    func testResolve_returnsJoinAndMediumConfidenceChatFromAttendeeIdentities() {
        let event = makeEvent(
            title: "Team sync",
            start: makeDate(year: 2026, month: 4, day: 13, hour: 14, minute: 0),
            end: makeDate(year: 2026, month: 4, day: 13, hour: 15, minute: 0)
        )
        event.notes = "https://teams.microsoft.com/l/meetup-join/19%3ameeting_xxx/0?context=%7b%7d"

        let actions = MeetingActionResolver.resolve(for: event) { _ in
            ["alice@example.com", "bob@example.com"]
        }

        XCTAssertEqual(actions.map(\.kind), [.join, .chat])
        XCTAssertEqual(actions.last?.confidence, .medium)
        XCTAssertEqual(actions.last?.source, .inferredFromAttendees)

        guard case .ordered(let primary, let fallback)? = actions.last?.openPlan else {
            return XCTFail("Expected ordered chat open plan")
        }
        XCTAssertEqual(primary.first?.scheme, "msteams")
        XCTAssertTrue(fallback?.absoluteString.contains("users=") == true)
    }

    func testResolve_hidesChatWhenAttendeeIdentitiesAreInsufficient() {
        let event = makeEvent(
            title: "1:1",
            start: makeDate(year: 2026, month: 4, day: 13, hour: 16, minute: 0),
            end: makeDate(year: 2026, month: 4, day: 13, hour: 16, minute: 30)
        )
        event.notes = "https://teams.microsoft.com/l/meetup-join/19%3ameeting_xxx/0?context=%7b%7d"

        let actions = MeetingActionResolver.resolve(for: event) { _ in
            ["invalid-address"]
        }

        XCTAssertEqual(actions.map(\.kind), [.join])
    }

    func testResolve_returnsSingleJoinForNonTeamsPlatform() {
        let event = makeEvent(
            title: "Zoom sync",
            start: makeDate(year: 2026, month: 4, day: 13, hour: 18, minute: 0),
            end: makeDate(year: 2026, month: 4, day: 13, hour: 19, minute: 0)
        )
        event.notes = "https://zoom.us/j/123456789"

        let actions = MeetingActionResolver.resolve(for: event)

        XCTAssertEqual(actions.map(\.kind), [.join])
        XCTAssertEqual(actions.first?.platform, .zoom)
        XCTAssertEqual(actions.first?.source, .explicitLink)

        guard case .direct(let url)? = actions.first?.openPlan else {
            return XCTFail("Expected direct open plan for non-Teams")
        }
        XCTAssertEqual(url.host, "zoom.us")
    }

    private func makeEvent(title: String, start: Date, end: Date) -> EKEvent {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = start
        event.endDate = end
        if let calendar = store.defaultCalendarForNewEvents {
            event.calendar = calendar
        }
        return event
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        DateComponents(
            calendar: Calendar.gregorianMondayFirst,
            timeZone: TimeZone(secondsFromGMT: 0),
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ).date!
    }
}
