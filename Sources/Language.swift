import Foundation

enum AppLanguage: String, CaseIterable {
    case english = "en"
    case chinese = "zh-Hans"

    static func load(from defaults: UserDefaults = .standard) -> AppLanguage {
        defaults.string(forKey: "InterfaceLanguage").flatMap(AppLanguage.init(rawValue:)) ?? .english
    }
    func save(to defaults: UserDefaults = .standard) {
        defaults.set(rawValue, forKey: "InterfaceLanguage")
    }
    func text(_ english: String, _ chinese: String) -> String {
        self == .english ? english : chinese
    }
}

enum AppVersion {
    static var current: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.1"
    }
}
