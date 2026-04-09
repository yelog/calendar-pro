import Foundation

enum LocaleFeatureAvailability {
    static var isChineseLocale: Bool {
        Locale.current.language.languageCode?.identifier == "zh"
    }

    static var showLunarFeatures: Bool { isChineseLocale }
    static var showAlmanacFeatures: Bool { isChineseLocale }
    static var showChineseDateStyles: Bool { isChineseLocale }
    static var showWorkingAdjustmentDay: Bool { isChineseLocale }
}
