import Foundation

struct TraditionalFestivalResolver {
    func festivalName(month: Int, day: Int, isLeapMonth: Bool) -> String? {
        guard !isLeapMonth else { return nil }

        return switch (month, day) {
        case (1, 1):
            "春节"
        case (1, 15):
            "元宵节"
        case (5, 5):
            "端午节"
        case (7, 7):
            "七夕"
        case (8, 15):
            "中秋节"
        case (9, 9):
            "重阳节"
        case (12, 8):
            "腊八节"
        default:
            nil
        }
    }
}
