import Foundation

struct LunarDateDescriptor: Equatable {
    let month: Int
    let day: Int
    let isLeapMonth: Bool
    let monthText: String
    let dayText: String
    let festivalName: String?

    var displayText: String {
        festivalName ?? (day == 1 ? monthText : dayText)
    }
}
