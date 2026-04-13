import EventKit
import Foundation

enum MeetingActionKind: Equatable {
    case join
    case chat
}

enum MeetingActionConfidence: Equatable {
    case high
    case medium
}

enum MeetingActionSource: Equatable {
    case explicitLink
    case inferredFromJoinLink
    case inferredFromAttendees
    case graphResolved
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
    private struct PatternMatch {
        let url: URL
        let source: MeetingActionSource
    }

    private static let explicitTeamsChatPatterns = [
        #"msteams://teams\.microsoft\.com/l/chat/[^\s<>\"\)>]+"#,
        #"msteams://teams\.microsoft\.com/l/channel/[^\s<>\"\)>]+"#,
        #"msteams://teams\.microsoft\.com/l/message/[^\s<>\"\)>]+"#,
        #"https?://teams\.microsoft\.com/l/chat/[^\s<>\"\)>]+"#,
        #"https?://teams\.microsoft\.com/l/channel/[^\s<>\"\)>]+"#,
        #"https?://teams\.microsoft\.com/l/message/[^\s<>\"\)>]+"#
    ]

    static func resolve(
        for event: EKEvent,
        attendeeIdentityProvider: (EKEvent) -> [String] = attendeeChatIdentities
    ) -> [MeetingAction] {
        guard let meetingLink = MeetingLinkDetector.detect(in: event) else {
            return []
        }

        if meetingLink.platform == .microsoftTeams {
            return resolveTeamsActions(for: event, meetingLink: meetingLink, attendeeIdentityProvider: attendeeIdentityProvider)
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

    private static func resolveTeamsActions(
        for event: EKEvent,
        meetingLink: MeetingLink,
        attendeeIdentityProvider: (EKEvent) -> [String]
    ) -> [MeetingAction] {
        var actions: [MeetingAction] = [teamsJoinAction(for: meetingLink)]

        if let chatAction = explicitTeamsChatAction(in: event)
            ?? inferredTeamsChatAction(for: event, attendeeIdentityProvider: attendeeIdentityProvider) {
            actions.append(chatAction)
        }

        return actions
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

    private static func explicitTeamsChatAction(in event: EKEvent) -> MeetingAction? {
        let texts = [
            event.url?.absoluteString,
            event.notes,
            event.location
        ].compactMap { $0 }

        for text in texts {
            if let match = firstPatternMatch(in: text, patterns: explicitTeamsChatPatterns) {
                return MeetingAction(
                    kind: .chat,
                    platform: .microsoftTeams,
                    title: L("Chat"),
                    confidence: .high,
                    source: match.source,
                    openPlan: teamsNativePreferredOpenPlan(for: match.url)
                )
            }
        }

        return nil
    }

    private static func inferredTeamsChatAction(
        for event: EKEvent,
        attendeeIdentityProvider: (EKEvent) -> [String]
    ) -> MeetingAction? {
        let identities = Array(Set(attendeeIdentityProvider(event).map { $0.lowercased() })).sorted()
        guard identities.count >= 2 else {
            return nil
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "teams.microsoft.com"
        components.path = "/l/chat/0/0"
        components.queryItems = [
            URLQueryItem(name: "users", value: identities.joined(separator: ","))
        ]

        guard let webURL = components.url else {
            return nil
        }

        return MeetingAction(
            kind: .chat,
            platform: .microsoftTeams,
            title: L("Chat"),
            confidence: .medium,
            source: .inferredFromAttendees,
            openPlan: teamsNativePreferredOpenPlan(for: webURL)
        )
    }

    private static func attendeeChatIdentities(from event: EKEvent) -> [String] {
        guard let attendees = event.attendees else {
            return []
        }

        return attendees.compactMap { participant in
            let raw = (participant.url as NSURL?)?.resourceSpecifier?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            guard let raw, isValidChatIdentity(raw) else {
                return nil
            }

            return raw
        }
    }

    private static func isValidChatIdentity(_ value: String) -> Bool {
        guard value.contains("@"), !value.contains(" ") else {
            return false
        }

        let parts = value.split(separator: "@")
        guard parts.count == 2 else {
            return false
        }

        return parts[0].isEmpty == false && parts[1].contains(".")
    }

    private static func firstPatternMatch(in text: String, patterns: [String]) -> PatternMatch? {
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
                continue
            }

            let range = NSRange(text.startIndex..., in: text)
            guard let match = regex.firstMatch(in: text, range: range),
                  let matchRange = Range(match.range, in: text) else {
                continue
            }

            let rawURL = String(text[matchRange]).trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))
            guard let url = URL(string: rawURL) else {
                continue
            }

            return PatternMatch(url: url, source: .explicitLink)
        }

        return nil
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
