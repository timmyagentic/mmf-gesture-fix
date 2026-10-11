import Foundation

func runLanguageTests() -> Bool {
    let suite = "MMFGestureFix.Tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let defaultEnglish = AppLanguage.load(from: defaults) == .english
    defaults.set("unsupported", forKey: "InterfaceLanguage")
    let fallbackEnglish = AppLanguage.load(from: defaults) == .english
    defaults.set(false, forKey: "RepairEnabled")
    AppLanguage.chinese.save(to: defaults)
    let chinesePersists = AppLanguage.load(from: UserDefaults(suiteName: suite)!) == .chinese
    let chineseText = AppLanguage.load(from: defaults).text("Pause Repair", "暂停修复") == "暂停修复"
    AppLanguage.english.save(to: defaults)
    let englishPersists = AppLanguage.load(from: defaults) == .english
    let englishText = AppLanguage.load(from: defaults).text("Pause Repair", "暂停修复") == "Pause Repair"
    let repairUnchanged = defaults.bool(forKey: "RepairEnabled") == false
    let ok = defaultEnglish && fallbackEnglish && chinesePersists && chineseText && englishPersists && englishText && repairUnchanged
    print("Language defaults, fallback, persistence, translation and repair isolation: \(ok ? "PASS" : "FAIL")")
    return ok
}
