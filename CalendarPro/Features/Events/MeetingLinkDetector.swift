import EventKit
import Foundation

struct MeetingLink {
    let url: URL
    let platform: String
    let iconName: String
}

enum MeetingLinkDetector {
    private static let patterns: [(platform: String, iconName: String, regex: String)] = [
        ("Microsoft Teams", "video.fill", #"https?://teams\.microsoft\.com/l/meetup-join/[^\s<>\"\)>]+"#),
        ("Zoom", "video.fill", #"https?://[\w.-]*zoom\.us/[jmy]/[^\s<>\"\)>]+"#),
        ("Google Meet", "video.fill", #"https?://meet\.google\.com/[a-z\-]+"#),
        ("Webex", "video.fill", #"https?://[\w.-]*webex\.com/(meet|join)/[^\s<>\"\)>]+"#),
        ("Feishu", "video.fill", #"https?://(meetings|vc)\.feishu\.cn/[^\s<>\"\)>]+"#),
        ("Tencent Meeting", "video.fill", #"https?://meeting\.tencent\.com/[^\s<>\"\)>]+"#),
        ("DingTalk", "video.fill", #"https?://meeting\.dingtalk\.com/[^\s<>\"\)>]+"#),
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
        for (platform, iconName, pattern) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            let range = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, range: range),
               let matchRange = Range(match.range, in: text) {
                let urlString = String(text[matchRange])
                // Clean trailing punctuation that might have been captured
                let cleaned = urlString.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))
                if let url = URL(string: cleaned) {
                    return MeetingLink(url: url, platform: platform, iconName: iconName)
                }
            }
        }
        return nil
    }

    private static func matchURL(_ url: URL) -> MeetingLink? {
        let urlString = url.absoluteString
        for (platform, iconName, pattern) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            let range = NSRange(urlString.startIndex..., in: urlString)
            if regex.firstMatch(in: urlString, range: range) != nil {
                return MeetingLink(url: url, platform: platform, iconName: iconName)
            }
        }
        return nil
    }
}
