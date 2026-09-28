//
//  CandleTimes.swift
//  HebcalWatchCore
//
//  Sunset, candle-lighting, Havdalah and Chanukah candle times, when the
//  user has shared their location. Without a location none of this runs:
//  the Hebrew date rolls over at 8 PM and no times are shown.
//
//  Which days get which time is ported from @hebcal/core's
//  `makeCandleEvent()` and `makeWeekdayChanukahCandleLighting()`
//  (hebcal-es6 src/candles.ts, src/calendar.ts); the times themselves come
//  from hebcal-swift's `Zmanim`.
//

import Foundation
import Hebcal

/// Where the watch was when the app last got a location fix. Rounded to
/// about a kilometer: plenty for sunset, and no more precise than needed.
public struct GeoPoint: Hashable, Codable, Sendable {
    public var latitude: Double
    public var longitude: Double
    /// The time zone the watch was in; times are only computed while the
    /// watch is still in it (see `HebcalFormatter.zmanimLocation`).
    public var timeZoneIdentifier: String

    public init(latitude: Double, longitude: Double, timeZoneIdentifier: String) {
        self.latitude = (latitude * 100).rounded() / 100
        self.longitude = (longitude * 100).rounded() / 100
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    var timeZone: TimeZone { TimeZone(identifier: timeZoneIdentifier) ?? .current }

    /// Israel's time zone covers Israel only (the Palestinian territories
    /// are Asia/Gaza and Asia/Hebron); Asia/Tel_Aviv is an old alias.
    static func isIsrael(timeZoneIdentifier: String) -> Bool {
        timeZoneIdentifier == "Asia/Jerusalem" || timeZoneIdentifier == "Asia/Tel_Aviv"
    }

    var isInIsrael: Bool { Self.isIsrael(timeZoneIdentifier: timeZoneIdentifier) }

    /// Great-circle distance in kilometers.
    func distance(to other: GeoPoint) -> Double {
        let radians = Double.pi / 180
        let dLat = (other.latitude - latitude) * radians
        let dLon = (other.longitude - longitude) * radians
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(latitude * radians) * cos(other.latitude * radians) * sin(dLon / 2) * sin(dLon / 2)
        return 6371 * 2 * atan2(sqrt(a), sqrt(1 - a))
    }

    /// Cities with their own candle-lighting custom, and how close counts
    /// as being there.
    private static let candleLightingCities: [(center: GeoPoint, radiusKm: Double, minutes: Int)] = [
        (GeoPoint(latitude: 31.778, longitude: 35.235, timeZoneIdentifier: "Asia/Jerusalem"), 15, 40),  // Jerusalem
        (GeoPoint(latitude: 32.794, longitude: 34.990, timeZoneIdentifier: "Asia/Jerusalem"), 10, 30),  // Haifa
        (GeoPoint(latitude: 32.571, longitude: 34.954, timeZoneIdentifier: "Asia/Jerusalem"), 5, 30),   // Zikhron Ya'akov
    ]

    /// Minutes before sunset to light candles here: 40 in Jerusalem, 30 in
    /// Haifa and Zikhron Ya'akov, 20 elsewhere in Israel, 18 outside it.
    /// It's the local custom, so it goes by where the watch is, not by the
    /// user's Israel/Diaspora schedule.
    public var defaultCandleLightingMinutes: Int {
        for city in Self.candleLightingCities where distance(to: city.center) <= city.radiusKm {
            return city.minutes
        }
        return isInIsrael ? 20 : 18
    }
}

/// When Havdalah (and candle lighting on the second night of Yom Tov) is.
public enum HavdalahSetting: Hashable, Codable, Sendable {
    /// When the sun is this many degrees below the horizon, e.g. 8.5.
    case degrees(Double)
    /// This many minutes after sunset, e.g. 42, 50 or 72.
    case minutes(Int)

    public static let `default` = HavdalahSetting.degrees(8.5)

    var opinion: HavdalahOpinion {
        switch self {
        case .degrees(let angle): return .degreesBelowHorizon(angle: angle)
        case .minutes(let minutes): return .minutesAfterSunset(minutes: minutes)
        }
    }
}

/// A candle-lighting, Havdalah or Chanukah candle time.
public struct ZmanEvent: Hashable, Codable, Sendable {
    public enum Kind: String, Hashable, Codable, Sendable {
        case candleLighting, havdalah, chanukah
    }

    public var kind: Kind
    public var time: Date
    /// "Candle lighting", "Havdalah" or "Chanukah: 3 Candles", translated.
    public var title: String

    public init(kind: Kind, time: Date, title: String) {
        self.kind = kind
        self.time = time
        self.title = title
    }

    public var emoji: String {
        switch kind {
        case .candleLighting: return "🕯️"
        case .havdalah: return "✨"
        case .chanukah: return "🕎"
        }
    }
}

/// The card for a day with candle times: the times, sunset, and a link to
/// the Omer card on a day of the Omer.
public struct ZmanimDetail: Hashable, Codable, Sendable {
    /// The Gregorian date, e.g. "Fri, 2 October" (or "ו׳, 2 באוקטובר" in Hebrew).
    public var title: String
    public var events: [ZmanEvent]
    public var sunset: Date?
    public var omer: OmerDetail?
    public var isHebrew: Bool
}

extension HebcalFormatter {
    private static let candleFlags = HolidayFlags([.LIGHT_CANDLES, .LIGHT_CANDLES_TZEIS,
                                                   .CHANUKAH_CANDLES, .YOM_TOV_ENDS])

    /// The location to compute times for, or nil when the user hasn't turned
    /// it on, there's no fix yet, or the watch has since moved to another
    /// time zone (the app wasn't opened to get a new fix, and times for the
    /// old place would be confidently wrong).
    public func zmanimLocation(calendar: Calendar) -> GeoPoint? {
        guard settings.useLocation, let location = settings.location,
              location.timeZoneIdentifier == calendar.timeZone.identifier else {
            return nil
        }
        return location
    }

    /// Minutes before sunset to light candles: the user's choice, else the
    /// custom where they are.
    public func candleLightingMinutes(at location: GeoPoint) -> Int {
        settings.candleLightingMinutes ?? location.defaultCandleLightingMinutes
    }

    /// The Hebrew date to display at `date`. Hebrew days start at sundown:
    /// from sunset on, this returns the next day's date. Without a location
    /// (or where the sun doesn't set that day), 8 PM stands in for sunset.
    public func hebrewDate(for date: Date, calendar: Calendar) -> HDate {
        guard let sunset = sunset(on: date, calendar: calendar) else {
            return Self.hebrewDate(for: date, calendar: calendar)
        }
        let hdate = HDate(date: date, calendar: calendar)
        return date >= sunset ? hdate.next() : hdate
    }

    /// Sunset on the civil day of `date`, or nil without a location.
    public func sunset(on date: Date, calendar: Calendar) -> Date? {
        guard let location = zmanimLocation(calendar: calendar) else {
            return nil
        }
        return Zmanim.getSunset(for: date, latitude: location.latitude, longitude: location.longitude,
                                timeZone: location.timeZone)
    }

    /// Candle-lighting, Havdalah and Chanukah candle times on the civil day
    /// of `hdate`, in time order, Shabbat's before Chanukah's when they
    /// coincide. Empty without a location.
    ///
    /// - Friday, or erev Shabbat/Yom Tov: candle lighting before sunset.
    /// - The second night of Yom Tov, or Yom Tov starting Saturday night
    ///   (`LIGHT_CANDLES_TZEIS`): candle lighting at the Havdalah time.
    /// - Saturday, or the end of Yom Tov (`YOM_TOV_ENDS`): Havdalah.
    /// - Chanukah: at bein hashmashot on weekdays; with Shabbat candles on
    ///   Friday; after Havdalah on Saturday night.
    public func candleTimes(on hdate: HDate, calendar: Calendar) -> [ZmanEvent] {
        guard let location = zmanimLocation(calendar: calendar) else {
            return []
        }
        var localCalendar = Calendar(identifier: .gregorian)
        localCalendar.timeZone = location.timeZone
        let noon = abs2greg(absdate: hdate.abs(), calendar: localCalendar).addingTimeInterval(12 * 60 * 60)
        let dow = hdate.dow()
        let isFriday = dow == .FRI
        let isSaturday = dow == .SAT

        var events: [ZmanEvent] = []
        var candles: ZmanEvent?
        for ev in holidays(on: hdate) where !ev.flags.isDisjoint(with: Self.candleFlags) {
            candles = candleEvent(for: ev, on: noon, at: location, isFriday: isFriday, isSaturday: isSaturday)
            if ev.flags.contains(.CHANUKAH_CANDLES), let shabbatTime = candles?.time {
                let time = isFriday || isSaturday ? shabbatTime
                    : Zmanim.getBeinHaShmashosTime(for: noon, latitude: location.latitude,
                                                   longitude: location.longitude, timeZone: location.timeZone)
                if let time {
                    events.append(ZmanEvent(kind: .chanukah, time: time,
                                            title: holidayName(ev, abbreviated: false)))
                }
                // Shabbat's own candle lighting or Havdalah is added below.
                candles = nil
            }
        }
        if candles == nil && (isFriday || isSaturday) {
            candles = candleEvent(for: nil, on: noon, at: location, isFriday: isFriday, isSaturday: isSaturday)
        }
        if let candles {
            events.append(candles)
        }
        // At the same time, Shabbat's candles or Havdalah before Chanukah's.
        return events.sorted { ($0.time, $0.kind == .chanukah ? 1 : 0) < ($1.time, $1.kind == .chanukah ? 1 : 0) }
    }

    /// Port of `makeCandleEvent()`: candle lighting or Havdalah for holiday
    /// `ev` (nil for a plain Shabbat).
    private func candleEvent(for ev: HEvent?, on noon: Date, at location: GeoPoint,
                             isFriday: Bool, isSaturday: Bool) -> ZmanEvent? {
        var isHavdalah = false
        var afterNightfall = isSaturday
        if let ev {
            if !isFriday {
                if !ev.flags.isDisjoint(with: [.LIGHT_CANDLES_TZEIS, .CHANUKAH_CANDLES]) {
                    afterNightfall = true
                } else if ev.flags.contains(.YOM_TOV_ENDS) {
                    isHavdalah = true
                    afterNightfall = true
                }
            }
        } else if isSaturday {
            isHavdalah = true
        }
        let time = afterNightfall
            ? Zmanim.getHavdalahTime(for: noon, latitude: location.latitude, longitude: location.longitude,
                                     timeZone: location.timeZone, opinion: settings.havdalah.opinion)
            : Zmanim.getCandleLightingTime(for: noon, latitude: location.latitude, longitude: location.longitude,
                                           timeZone: location.timeZone,
                                           minutesBeforeSunset: candleLightingMinutes(at: location))
        guard let time else {
            return nil
        }
        return isHavdalah
            ? ZmanEvent(kind: .havdalah, time: time, title: isHebrew ? "הבדלה" : "Havdalah")
            : ZmanEvent(kind: .candleLighting, time: time, title: isHebrew ? "הדלקת נרות" : "Candle lighting")
    }

    /// The card for `hdate` if it has candle times, else nil.
    public func zmanimDetail(on hdate: HDate, calendar: Calendar) -> ZmanimDetail? {
        let events = candleTimes(on: hdate, calendar: calendar)
        guard !events.isEmpty else {
            return nil
        }
        let noon = abs2greg(absdate: hdate.abs(), calendar: calendar).addingTimeInterval(12 * 60 * 60)
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        if isHebrew {
            formatter.locale = Locale(identifier: "he")
            formatter.setLocalizedDateFormatFromTemplate("EEEd MMMM")
        } else {
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "EEE, d MMMM"
        }
        return ZmanimDetail(title: formatter.string(from: noon), events: events,
                            sunset: sunset(on: noon, calendar: calendar),
                            omer: omerDetail(on: hdate), isHebrew: isHebrew)
    }
}
