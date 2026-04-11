import XCTest
@testable import CalendarPro

final class MeetingLinkDetectorTests: XCTestCase {

    // MARK: - Join button titles

    func testGoogleMeetJoinButtonTitle_isNatural() {
        XCTAssertEqual(MeetingPlatform.googleMeet.joinButtonTitle, L("Join Google Meet"))
    }

    func testTencentMeetingJoinButtonTitle_isNatural() {
        XCTAssertEqual(MeetingPlatform.tencentMeeting.joinButtonTitle, L("Join Tencent Meeting"))
    }

    // MARK: - Teams

    func testDetectsTeamsLinkInText() {
        let link = MeetingLinkDetector.findInText(
            "Join: https://teams.microsoft.com/l/meetup-join/abc123-def456"
        )
        XCTAssertNotNil(link)
        XCTAssertEqual(link?.platform, .microsoftTeams)
        XCTAssertEqual(link?.platform.displayName, "Microsoft Teams")
        XCTAssertTrue(link?.url.absoluteString.contains("teams.microsoft.com") == true)
    }

    // MARK: - Zoom

    func testDetectsZoomLink() {
        let link = MeetingLinkDetector.findInText(
            "https://us02web.zoom.us/j/1234567890?pwd=abc"
        )
        XCTAssertNotNil(link)
        XCTAssertEqual(link?.platform, .zoom)
    }

    func testDetectsZoomPersonalLink() {
        let link = MeetingLinkDetector.findInText(
            "https://acme.zoom.us/my/team-standup"
        )
        XCTAssertNotNil(link)
        XCTAssertEqual(link?.platform, .zoom)
    }

    // MARK: - Google Meet

    func testDetectsGoogleMeetLink() {
        let link = MeetingLinkDetector.findInText(
            "Meet at https://meet.google.com/abc-defg-hij"
        )
        XCTAssertNotNil(link)
        XCTAssertEqual(link?.platform, .googleMeet)
    }

    // MARK: - Webex

    func testDetectsWebexLink() {
        let link = MeetingLinkDetector.findInText(
            "https://company.webex.com/meet/john.doe"
        )
        XCTAssertNotNil(link)
        XCTAssertEqual(link?.platform, .webex)
    }

    func testDetectsWebexJoinServiceLink() {
        let link = MeetingLinkDetector.findInText(
            "https://company.webex.com/wbxmjs/joinservice/sites/company/meeting/download/abc123"
        )
        XCTAssertNotNil(link)
        XCTAssertEqual(link?.platform, .webex)
    }

    // MARK: - 飞书

    func testDetectsFeishuLink() {
        let link = MeetingLinkDetector.findInText(
            "https://meetings.feishu.cn/s/abc123"
        )
        XCTAssertNotNil(link)
        XCTAssertEqual(link?.platform, .feishu)
    }

    // MARK: - 腾讯会议

    func testDetectsTencentMeetingLink() {
        let link = MeetingLinkDetector.findInText(
            "https://meeting.tencent.com/dm/abc123"
        )
        XCTAssertNotNil(link)
        XCTAssertEqual(link?.platform, .tencentMeeting)
    }

    func testDetectsVooVMeetingLink() {
        let link = MeetingLinkDetector.findInText(
            "https://voovmeeting.com/dm/987654321"
        )
        XCTAssertNotNil(link)
        XCTAssertEqual(link?.platform, .voovMeeting)
    }

    // MARK: - 钉钉

    func testDetectsDingTalkLink() {
        let link = MeetingLinkDetector.findInText(
            "https://meeting.dingtalk.com/j/abc123"
        )
        XCTAssertNotNil(link)
        XCTAssertEqual(link?.platform, .dingTalk)
    }

    // MARK: - Other common platforms

    func testDetectsWherebyLink() {
        let link = MeetingLinkDetector.findInText(
            "https://whereby.com/calendarpro-demo"
        )
        XCTAssertNotNil(link)
        XCTAssertEqual(link?.platform, .whereby)
    }

    func testDetectsGoToMeetingLink() {
        let link = MeetingLinkDetector.findInText(
            "https://meet.goto.com/123456789"
        )
        XCTAssertNotNil(link)
        XCTAssertEqual(link?.platform, .goToMeeting)
    }

    func testDetectsLegacyGoToMeetingLink() {
        let link = MeetingLinkDetector.findInText(
            "https://global.gotomeeting.com/join/123456789"
        )
        XCTAssertNotNil(link)
        XCTAssertEqual(link?.platform, .goToMeeting)
    }

    // MARK: - No match

    func testReturnsNilForPlainText() {
        let link = MeetingLinkDetector.findInText("Just a regular meeting note")
        XCTAssertNil(link)
    }

    func testReturnsNilForNonMeetingURL() {
        let link = MeetingLinkDetector.findInText("https://www.google.com/search?q=hello")
        XCTAssertNil(link)
    }

    // MARK: - Complex notes (like Teams template)

    func testDetectsTeamsLinkInComplexNotes() {
        let notes = """
        ________________________________________________________________________________

        Microsoft Teams 会议
        使用电脑、移动应用或会议室设备加入
        单击此处以加入会议<https://teams.microsoft.com/l/meetup-join/19%3ameeting_MjM0ZWZjOGUtMDM3My00YmFkLWJhMTQtMjRhNGFjMjhkMjU2%40thread.v2/0?context=%7b%22Tid%22%3a%225c7d0b28-bdf8-410c-aa93-4df372b16203%22%2c%22Oid%22%3a%2288945701-2c07-403a-8adf-0c916644d7b3%22%7d>
        会议 ID: 423 559 682 579
        密码: uuSc7p
        """
        let link = MeetingLinkDetector.findInText(notes)
        XCTAssertNotNil(link)
        XCTAssertEqual(link?.platform, .microsoftTeams)
    }
}
