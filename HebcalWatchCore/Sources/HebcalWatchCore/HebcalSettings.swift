//
//  HebcalSettings.swift
//  HebcalWatchCore
//
//  The three user settings, and how they persist. The watch app and the
//  widget extension are separate processes that don't share memory, so they
//  share settings through an App Group UserDefaults suite.
//

import Foundation
import Hebcal

public struct HebcalSettings: Equatable {
    /// Israel (true) or Diaspora (false) holiday and Torah reading schedule.
    public var il: Bool
    /// Sephardic transliterations (`.en`), Ashkenazi, or Hebrew.
    public var lang: TranslationLang
    /// Show the Daf Yomi in the app's date list.
    public var dafyomi: Bool

    public init(il: Bool = false, lang: TranslationLang = .en, dafyomi: Bool = false) {
        self.il = il
        self.lang = lang
        self.dafyomi = dafyomi
    }
}

// MARK: - Persistence

extension HebcalSettings {
    private enum Key {
        static let il = "israel"
        static let lang = "lang"
        static let dafyomi = "dafyomi"
    }

    public static let appGroupSuiteName = "group.com.hebcal.HebcalHDate"

    /// The App Group suite shared by the watch app and the widget extension.
    public static let appGroupDefaults: UserDefaults = {
        let shared = UserDefaults(suiteName: appGroupSuiteName) ?? .standard
        migrateLegacySettings(from: .standard, to: shared)
        return shared
    }()

    /// Before the ClockKit → WidgetKit migration, settings lived in
    /// `UserDefaults.standard`. Copy them into the shared suite once so the
    /// widget process sees them.
    static func migrateLegacySettings(from standard: UserDefaults, to shared: UserDefaults) {
        if shared.object(forKey: Key.lang) == nil && standard.object(forKey: Key.lang) != nil {
            shared.set(standard.bool(forKey: Key.il), forKey: Key.il)
            shared.set(standard.integer(forKey: Key.lang), forKey: Key.lang)
            shared.set(standard.bool(forKey: Key.dafyomi), forKey: Key.dafyomi)
        }
    }

    /// Reads settings, falling back to the defaults for anything unset.
    public init(defaults: UserDefaults) {
        self.init(
            il: defaults.bool(forKey: Key.il),
            lang: TranslationLang(rawValue: defaults.integer(forKey: Key.lang)) ?? .en,
            dafyomi: defaults.bool(forKey: Key.dafyomi))
    }

    public func save(to defaults: UserDefaults) {
        defaults.set(il, forKey: Key.il)
        defaults.set(lang.rawValue, forKey: Key.lang)
        defaults.set(dafyomi, forKey: Key.dafyomi)
    }
}
