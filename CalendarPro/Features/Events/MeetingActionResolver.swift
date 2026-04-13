import EventKit
import Foundation

enum MeetingActionKind: Equatable {
    case join
}

enum MeetingActionConfidence: Equatable {
    case high
}

enum MeetingActionSource: Equatable {
    case explicitLink
    case inferredFromJoinLink
}

enum MeetingActionOpenPlan: Equatable {
    case direct(URL)
    case ordered(primary: [URL], fallback: URL?)
}

struct MeetingAction: Equatable {
    let kind: MeetingActionKind
    let platform: MeetingPlatform
    let title: String
    let confidence: MeetingActionConfidence
    let source: MeetingActionSource
    let openPlan: MeetingActionOpenPlan
}

enum MeetingActionResolver {
    static func resolve(for event: EKEvent) -> [MeetingAction] {
        guard let meetingLink = MeetingLinkDetector.detect(in: event) else {
            return []
        }

        if meetingLink.platform == .microsoftTeams {
            return [teamsJoinAction(for: meetingLink)]
        }

        return [
            MeetingAction(
                kind: .join,
                platform: meetingLink.platform,
                title: meetingLink.platform.joinButtonTitle,
                confidence: .high,
                source: .explicitLink,
                openPlan: .direct(meetingLink.url)
            )
        ]
    }

    private static func teamsJoinAction(for meetingLink: MeetingLink) -> MeetingAction {
        let source: MeetingActionSource = meetingLink.url.scheme?.lowercased() == "msteams"
            ? .explicitLink
            : .inferredFromJoinLink

        return MeetingAction(
            kind: .join,
            platform: .microsoftTeams,
            title: meetingLink.platform.joinButtonTitle,
            confidence: .high,
            source: source,
            openPlan: teamsNativePreferredOpenPlan(for: meetingLink.url)
        )
    }

    private static func teamsNativePreferredOpenPlan(for url: URL) -> MeetingActionOpenPlan {
        if url.scheme?.lowercased() == "msteams" {
            return .direct(url)
        }

        guard let nativeURL = teamsNativeURL(from: url) else {
            return .direct(url)
        }

        return .ordered(primary: [nativeURL], fallback: url)
    }

    private static func teamsNativeURL(from url: URL) -> URL? {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return nil
        }

        guard let host = url.host?.lowercased(), host == "teams.microsoft.com" else {
            return nil
        }

        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        components.scheme = "msteams"
        return components.url
    }
}
