import Foundation

enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case followSystem
    case simplifiedChinese
    case english

    var id: String { rawValue }

    var localeIdentifier: String? {
        switch self {
        case .followSystem:
            return nil
        case .simplifiedChinese:
            return "zh-Hans"
        case .english:
            return "en"
        }
    }
}
