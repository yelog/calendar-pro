import Foundation

enum LocaleFeatureAvailability {
    static var isChineseLocale: Bool {
        AppLocalization.languageCode == "zh"
    }

    static var showLunarFeatures: Bool { isChineseLocale }
    static var showAlmanacFeatures: Bool { isChineseLocale }
    static var showChineseDateStyles: Bool { isChineseLocale }
    static var showWorkingAdjustmentDay: Bool { isChineseLocale }
    static var showVacationGuideFeatures: Bool { isChineseLocale }
}
