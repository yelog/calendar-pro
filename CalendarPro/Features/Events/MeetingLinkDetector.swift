import EventKit
import Foundation

enum MeetingSupportTier {
    case firstClass
    case fallback
}

enum MeetingPlatform: Equatable {
    case microsoftTeams
    case tencentMeeting
    case feishu
    case zoom
    case googleMeet
    case webex
    case voovMeeting
    case whereby
    case goToMeeting
    case dingTalk

    var displayName: String {
        switch self {
        case .microsoftTeams: return "Microsoft Teams"
        case .tencentMeeting: return "Tencent Meeting"
        case .feishu: return "Feishu"
        case .zoom: return "Zoom"
        case .googleMeet: return "Google Meet"
        case .webex: return "Webex"
        case .voovMeeting: return "VooV Meeting"
        case .whereby: return "Whereby"
        case .goToMeeting: return "GoTo Meeting"
        case .dingTalk: return "DingTalk"
        }
    }

    var joinButtonTitle: String {
        switch self {
        case .googleMeet:
            return AppLocalization.localizedString("Join Google Meet")
        case .tencentMeeting:
            return AppLocalization.localizedString("Join Tencent Meeting")
        case .voovMeeting:
            return AppLocalization.localizedString("Join VooV Meeting")
        case .goToMeeting:
            return AppLocalization.localizedString("Join GoTo Meeting")
        default:
            return String(format: AppLocalization.localizedString("Join %@ Meeting"), displayName)
        }
    }

    var symbolName: String {
        "video.fill"
    }

    var supportTier: MeetingSupportTier {
        switch self {
        case .microsoftTeams, .tencentMeeting, .feishu, .zoom, .googleMeet, .webex:
            return .firstClass
        case .voovMeeting, .whereby, .goToMeeting, .dingTalk:
            return .fallback
        }
    }
}

struct MeetingLink {
    let url: URL
    let platform: MeetingPlatform
}

enum MeetingLinkDetector {
    private struct PlatformPattern {
        let platform: MeetingPlatform
        let regex: String
    }

    private static let patterns: [PlatformPattern] = [
        PlatformPattern(platform: .microsoftTeams, regex: #"https?://teams\.microsoft\.com/l/meetup-join/[^\s<>\"\)>]+"#),
        PlatformPattern(platform: .zoom, regex: #"https?://[\w.-]*zoom\.us/(?:j|my|w|wc/join)/[^\s<>\"\)>]+"#),
        PlatformPattern(platform: .googleMeet, regex: #"https?://meet\.google\.com/[a-z\-]+"#),
        PlatformPattern(platform: .webex, regex: #"https?://[\w.-]*webex\.com/(?:meet|join|wbxmjs/joinservice)/[^\s<>\"\)>]+"#),
        PlatformPattern(platform: .feishu, regex: #"https?://(?:meetings|vc)\.feishu\.cn/[^\s<>\"\)>]+"#),
        PlatformPattern(platform: .tencentMeeting, regex: #"https?://meeting\.tencent\.com/[^\s<>\"\)>]+"#),
        PlatformPattern(platform: .voovMeeting, regex: #"https?://(?:www\.)?voovmeeting\.com/[^\s<>\"\)>]+"#),
        PlatformPattern(platform: .whereby, regex: #"https?://(?:www\.)?whereby\.com/[^\s<>\"\)>]+"#),
        PlatformPattern(platform: .goToMeeting, regex: #"https?://meet\.goto\.com/[^\s<>\"\)>]+"#),
        PlatformPattern(platform: .goToMeeting, regex: #"https?://global\.gotomeeting\.com/join/[^\s<>\"\)>]+"#),
        PlatformPattern(platform: .dingTalk, regex: #"https?://meeting\.dingtalk\.com/[^\s<>\"\)>]+"#),
    ]

    static func detect(in event: EKEvent) -> MeetingLink? {
        // 1. Check event.url first
        if let url = event.url, let link = matchURL(url) {
            return link
        }
        // 2. Search in notes
        if let notes = event.notes, let link = findInText(notes) {
            return link
        }
        // 3. Search in location
        if let location = event.location, let link = findInText(location) {
            return link
        }
        return nil
    }

    static func findInText(_ text: String) -> MeetingLink? {
        for entry in patterns {
            let pattern = entry.regex
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            let range = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, range: range),
               let matchRange = Range(match.range, in: text) {
                let urlString = String(text[matchRange])
                // Clean trailing punctuation that might have been captured
                let cleaned = urlString.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))
                if let url = URL(string: cleaned) {
                    return MeetingLink(url: url, platform: entry.platform)
                }
            }
        }
        return nil
    }

    private static func matchURL(_ url: URL) -> MeetingLink? {
        let urlString = url.absoluteString
        for entry in patterns {
            let pattern = entry.regex
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            let range = NSRange(urlString.startIndex..., in: urlString)
            if regex.firstMatch(in: urlString, range: range) != nil {
                return MeetingLink(url: url, platform: entry.platform)
            }
        }
        return nil
    }
}
