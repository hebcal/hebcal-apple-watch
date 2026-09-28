//
//  HebcalSettings.swift
//  HebcalWatchCore
//
//  The user settings, and how they persist. The watch app and the
//  widget extension are separate processes that don't share memory, so they
//  share settings through an App Group UserDefaults suite.
//

import Foundation
import Hebcal

// UserDefaults predates Sendable but is documented as thread-safe
// (https://developer.apple.com/documentation/foundation/userdefaults); this
// lets `appGroupDefaults` be a `static let` under Swift 6's strict
// concurrency checking, since WidgetKit can request timelines for the three
// widgets concurrently, each reading it.
extension UserDefaults: @retroactive @unchecked Sendable {}

public struct HebcalSettings: Equatable {
    /// Israel (true) or Diaspora (false) holiday and Torah reading schedule.
    public var il: Bool
    /// Sephardic transliterations (`.en`), Ashkenazi, or Hebrew.
    public var lang: TranslationLang
    /// Show the Daf Yomi in the app's date list.
    public var dafyomi: Bool
    /// The user turned on location, for sunset and candle times. Off by
    /// default; when off (or before the first fix) nothing depends on
    /// location and the Hebrew date rolls over at 8 PM.
    public var useLocation: Bool
    /// The last location fix, written by the app.
    public var location: GeoPoint?
    /// Minutes before sunset to light candles, or nil for the custom where
    /// the user is (see `GeoPoint.defaultCandleLightingMinutes`).
    public var candleLightingMinutes: Int?
    public var havdalah: HavdalahSetting

    public init(il: Bool = false, lang: TranslationLang = .en, dafyomi: Bool = false,
                useLocation: Bool = false, location: GeoPoint? = nil,
                candleLightingMinutes: Int? = nil, havdalah: HavdalahSetting = .default) {
        self.il = il
        self.lang = lang
        self.dafyomi = dafyomi
        self.useLocation = useLocation
        self.location = location
        self.candleLightingMinutes = candleLightingMinutes
        self.havdalah = havdalah
    }
}

// MARK: - Persistence

extension HebcalSettings {
    private enum Key {
        static let il = "israel"
        static let lang = "lang"
        static let dafyomi = "dafyomi"
        static let useLocation = "useLocation"
        static let latitude = "latitude"
        static let longitude = "longitude"
        static let tzid = "tzid"
        // Same meanings as hebcal.com's `b`, `m` and `M` options: 0 or unset
        // means the default.
        static let candleLightingMins = "candleLightingMins"
        static let havdalahMins = "havdalahMins"
        static let havdalahDeg = "havdalahDeg"
        /// Whether the user has set the Israel toggle themselves. Until they
        /// have, the app may turn it on for them (see `launchSettings` and
        /// `applyingFirstLocation`).
        static let israelChosen = "israelChosen"
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

    /// Reads settings at app launch. On a brand-new install (nothing saved
    /// yet) in Israel's time zone, the Israel schedule is on (see
    /// `init(defaults:timeZone:)`); this saves it, so it sticks.
    /// Also records, once, whether an existing install already has an Israel
    /// setting, which then counts as the user's choice.
    public static func launchSettings(defaults: UserDefaults, timeZone: TimeZone) -> HebcalSettings {
        let isNewInstall = defaults.object(forKey: Key.lang) == nil
        if defaults.object(forKey: Key.israelChosen) == nil {
            defaults.set(defaults.object(forKey: Key.il) != nil, forKey: Key.israelChosen)
        }
        let settings = HebcalSettings(defaults: defaults, timeZone: timeZone)
        if isNewInstall && settings.il {
            settings.save(to: defaults)
        }
        return settings
    }

    /// Whether the user has set the Israel toggle themselves.
    public static func israelChosen(defaults: UserDefaults) -> Bool {
        defaults.bool(forKey: Key.israelChosen)
    }

    /// Called when the user flips the Israel toggle.
    public static func markIsraelChosen(defaults: UserDefaults) {
        defaults.set(true, forKey: Key.israelChosen)
    }

    /// These settings with the first location fix after turning on "Use
    /// Location": also switches to the Israel schedule if the fix is in
    /// Israel and the user hasn't chosen a schedule themselves.
    public func applyingFirstLocation(_ location: GeoPoint, israelChosen: Bool) -> HebcalSettings {
        var settings = self
        settings.location = location
        if !israelChosen && location.isInIsrael {
            settings.il = true
        }
        return settings
    }

    /// Reads settings, falling back to the defaults for anything unset. The
    /// Israel schedule defaults to on in Israel's time zone, so the widget
    /// agrees with the app even before the app first launches and saves.
    public init(defaults: UserDefaults, timeZone: TimeZone = .current) {
        var location: GeoPoint?
        if let tzid = defaults.string(forKey: Key.tzid) {
            location = GeoPoint(latitude: defaults.double(forKey: Key.latitude),
                                longitude: defaults.double(forKey: Key.longitude),
                                timeZoneIdentifier: tzid)
        }
        let candleLightingMins = defaults.integer(forKey: Key.candleLightingMins)
        let havdalahMins = defaults.integer(forKey: Key.havdalahMins)
        let havdalahDeg = defaults.double(forKey: Key.havdalahDeg)
        self.init(
            il: defaults.object(forKey: Key.il) != nil ? defaults.bool(forKey: Key.il)
                : GeoPoint.isIsrael(timeZoneIdentifier: timeZone.identifier),
            lang: TranslationLang(rawValue: defaults.integer(forKey: Key.lang)) ?? .en,
            dafyomi: defaults.bool(forKey: Key.dafyomi),
            useLocation: defaults.bool(forKey: Key.useLocation),
            location: location,
            candleLightingMinutes: candleLightingMins > 0 ? candleLightingMins : nil,
            havdalah: havdalahMins > 0 ? .minutes(havdalahMins)
                : havdalahDeg > 0 ? .degrees(havdalahDeg) : .default)
    }

    public func save(to defaults: UserDefaults) {
        defaults.set(il, forKey: Key.il)
        defaults.set(lang.rawValue, forKey: Key.lang)
        defaults.set(dafyomi, forKey: Key.dafyomi)
        defaults.set(useLocation, forKey: Key.useLocation)
        if let location {
            defaults.set(location.latitude, forKey: Key.latitude)
            defaults.set(location.longitude, forKey: Key.longitude)
            defaults.set(location.timeZoneIdentifier, forKey: Key.tzid)
        } else {
            for key in [Key.latitude, Key.longitude, Key.tzid] {
                defaults.removeObject(forKey: key)
            }
        }
        defaults.set(candleLightingMinutes ?? 0, forKey: Key.candleLightingMins)
        switch havdalah {
        case .minutes(let minutes):
            defaults.set(minutes, forKey: Key.havdalahMins)
            defaults.removeObject(forKey: Key.havdalahDeg)
        case .degrees(let degrees):
            defaults.removeObject(forKey: Key.havdalahMins)
            defaults.set(degrees, forKey: Key.havdalahDeg)
        }
    }
}
