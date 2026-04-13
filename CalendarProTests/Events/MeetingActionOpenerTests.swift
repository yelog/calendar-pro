import XCTest
@testable import CalendarPro

final class MeetingActionOpenerTests: XCTestCase {

    func testOpen_directPlanOpensSingleURL() {
        let url = URL(string: "https://teams.microsoft.com/l/chat/19:abc123@thread.v2/conversations")!
        let handler = RecordingURLHandler(results: [url: true])
        let opener = MeetingActionOpener(urlHandler: handler)

        XCTAssertTrue(opener.open(.direct(url)))
        XCTAssertEqual(handler.openedURLs, [url])
    }

    func testOpen_orderedPlanFallsBackAfterPrimaryFails() {
        let primary = URL(string: "msteams://teams.microsoft.com/l/meetup-join/19%3ameeting_xxx/0?context=%7b%7d")!
        let fallback = URL(string: "https://teams.microsoft.com/l/meetup-join/19%3ameeting_xxx/0?context=%7b%7d")!
        let handler = RecordingURLHandler(results: [primary: false, fallback: true])
        let opener = MeetingActionOpener(urlHandler: handler)

        XCTAssertTrue(opener.open(.ordered(primary: [primary], fallback: fallback)))
        XCTAssertEqual(handler.openedURLs, [primary, fallback])
    }

    private final class RecordingURLHandler: URLHandling {
        let results: [URL: Bool]
        private(set) var openedURLs: [URL] = []

        init(results: [URL: Bool]) {
            self.results = results
        }

        func open(_ url: URL) -> Bool {
            openedURLs.append(url)
            return results[url] ?? false
        }
    }
}
