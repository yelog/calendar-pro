import Foundation

enum AppLocalization {
    static let appLanguageDefaultsKey = "appLanguage"

    static var appLanguage: AppLanguage {
        guard let rawValue = UserDefaults.standard.string(forKey: appLanguageDefaultsKey),
              let appLanguage = AppLanguage(rawValue: rawValue) else {
            return .simplifiedChinese
        }
        return appLanguage
    }

    static var locale: Locale {
        switch appLanguage {
        case .followSystem:
            return .autoupdatingCurrent
        case .simplifiedChinese:
            return Locale(identifier: "zh-Hans")
        case .english:
            return Locale(identifier: "en")
        }
    }

    static var languageCode: String {
        switch appLanguage {
        case .followSystem:
            return Locale.autoupdatingCurrent.language.languageCode?.identifier ?? "en"
        case .simplifiedChinese:
            return "zh"
        case .english:
            return "en"
        }
    }

    static func localizedString(_ key: String) -> String {
        let bundle = localizedBundle()
        let value = bundle.localizedString(forKey: key, value: nil, table: nil)
        return value == key ? Bundle.main.localizedString(forKey: key, value: nil, table: nil) : value
    }

    private static func localizedBundle() -> Bundle {
        guard let identifier = appLanguage.localeIdentifier else { return .main }
        guard let path = Bundle.main.path(forResource: identifier, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }
}

func L(_ key: String) -> String {
    AppLocalization.localizedString(key)
}

func LF(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: AppLocalization.localizedString(key), arguments: arguments)
}
