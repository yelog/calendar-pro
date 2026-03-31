import Foundation

enum LunarDisplayStyle: String, Codable, CaseIterable {
    case day
    case monthDay
    case yearMonthDay
}

struct LunarDateDescriptor: Equatable {
    let year: Int
    let month: Int
    let day: Int
    let isLeapMonth: Bool
    let yearText: String
    let monthText: String
    let dayText: String
    let festivalName: String?

    func displayText(style: LunarDisplayStyle = .day) -> String {
        if let festivalName {
            return festivalName
        }

        switch style {
        case .day:
            return day == 1 ? monthText : dayText
        case .monthDay:
            return monthText + dayText
        case .yearMonthDay:
            return yearText + monthText + dayText
        }
    }
}