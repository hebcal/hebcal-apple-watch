//
//  HebcalFormatter.swift
//  HebcalWatchCore
//
//  Answers calendar questions (holidays, Torah portion, Omer, Daf Yomi) for
//  one set of user settings and turns the answers into display strings.
//  All Jewish calendar math comes from the Hebcal package; this layer picks
//  what to show and how to abbreviate it.
//
//  Settings are fixed for the formatter's lifetime: when they change, make
//  a new formatter (that also drops caches that depend on them, e.g. the
//  Israel and Diaspora Torah reading schedules differ).
//

import Foundation
import Hebcal

public final class HebcalFormatter {
    public let settings: HebcalSettings

    private var holidayCache: [Int: [HEvent]] = [:]   // keyed by Hebrew year
    private var sedraCache: [Int: Sedra] = [:]        // keyed by Hebrew year

    public init(settings: HebcalSettings) {
        self.settings = settings
    }

    var lang: TranslationLang { settings.lang }
    var isHebrew: Bool { settings.lang == .he }

    // MARK: - Hebrew date

    /// The Hebrew date to display at `date`. Hebrew days start at sundown, so
    /// from 8 PM local time on this returns the next day's date.
    public static func hebrewDate(for date: Date, calendar: Calendar) -> HDate {
        let hdate = HDate(date: date, calendar: calendar)
        let hour = calendar.component(.hour, from: date)
        return hour >= 20 ? hdate.next() : hdate
    }

    /// Day number as Hebrew numerals ("כ״ו") in Hebrew, else digits ("26").
    public func number(_ n: Int) -> String {
        return isHebrew ? hebnumToString(number: n) : String(n)
    }

    /// `["26", "Tishrei"]`, or `["26", "Tishrei", "5787"]` with the year.
    public func dateParts(_ hdate: HDate, showYear: Bool) -> [String] {
        var parts = [number(hdate.dd), lookupTranslation(str: hdate.monthName(), lang: lang)]
        if showYear {
            parts.append(number(hdate.yy))
        }
        return parts
    }

    /// "26 Tishrei" or "26 Tishrei 5787".
    public func dateString(_ hdate: HDate, showYear: Bool) -> String {
        return dateParts(hdate, showYear: showYear).joined(separator: " ")
    }

    // MARK: - Torah portion

    private func sedra(forYear year: Int) -> Sedra {
        if let sedra = sedraCache[year] {
            return sedra
        }
        let sedra = Sedra(year: year, il: settings.il)
        sedraCache[year] = sedra
        return sedra
    }

    /// The weekly Torah portion read on the Shabbat on or after `hdate`, or
    /// nil when a holiday reading replaces it that Shabbat.
    public func parsha(on hdate: HDate) -> String? {
        return sedra(forYear: hdate.yy).lookup(hdate: hdate, lang: lang)
    }

    /// Like `parsha(on:)`, but when a holiday replaces the weekly reading,
    /// the name of that holiday (e.g. "Sukkot").
    public func parshaOrHoliday(on hdate: HDate) -> String {
        return parsha(on: hdate)
            ?? lookupTranslation(str: holidayReplacingParsha(on: hdate), lang: lang)
    }

    private static func shabbat(onOrAfter hdate: HDate) -> HDate {
        return HDate(absdate: dayOnOrBefore(dayOfWeek: .SAT, absdate: hdate.abs() + 6))
    }

    /// The (untranslated) holiday whose reading replaces the weekly parsha
    /// on the Shabbat on or after `hdate`.
    private func holidayReplacingParsha(on hdate: HDate) -> String {
        let saturday = Self.shabbat(onOrAfter: hdate)
        switch saturday.mm {
        case .TISHREI:
            switch saturday.dd {
            case 1: return "Rosh Hashana"
            case 10: return "Yom Kippur"
            case 15...21: return "Sukkot"
            case 22: return "Shmini Atzeret"
            default: return "??"
            }
        case .NISAN: return "Pesach"
        case .SIVAN: return "Shavuot"
        default: return "??"
        }
    }

    // MARK: - Holidays

    /// Every holiday on `hdate` for this schedule (Israel or Diaspora).
    public func holidays(on hdate: HDate) -> [HEvent] {
        let year = hdate.yy
        let events: [HEvent]
        if let cached = holidayCache[year] {
            events = cached
        } else {
            events = getAllHolidaysForYear(year: year)
            holidayCache[year] = events
        }
        return getHolidaysOnDate(events: events, hdate: hdate, il: settings.il)
    }

    private static let priorityFlags = HolidayFlags([.EREV, .CHAG, .MINOR_HOLIDAY])

    /// The single holiday to feature for `hdate`. When several fall on the
    /// same day (e.g. "Erev Pesach" and "Ta'anit Bechorot") prefer an erev,
    /// chag or minor holiday. With `specialShabbat`, a day with no holiday
    /// of its own falls back to the upcoming Shabbat's special-Shabbat name
    /// (e.g. "Shabbat Shuva" all week long).
    public func holidayToDisplay(on hdate: HDate, specialShabbat: Bool) -> HEvent? {
        let holidays = holidays(on: hdate)
        if !holidays.isEmpty {
            return holidays.first(where: { !Self.priorityFlags.intersection($0.flags).isEmpty })
                ?? holidays[0]
        }
        guard specialShabbat else {
            return nil
        }
        let saturday = Self.shabbat(onOrAfter: hdate)
        return self.holidays(on: saturday).first(where: { $0.flags.contains(.SPECIAL_SHABBAT) })
    }

    /// The translated name of `ev`. With `abbreviated`, shortened for narrow
    /// complications ("Y.K.", "Sh. Shuva", "R.Ch. Kislev", "Pesach IV").
    public func holidayName(_ ev: HEvent, abbreviated: Bool) -> String {
        if ev.flags.contains(.ROSH_CHODESH) {
            var roshChodesh = lookupTranslation(str: "Rosh Chodesh", lang: lang)
            if abbreviated, let abbrev = Abbreviations.holiday[roshChodesh] {
                roshChodesh = abbrev
            }
            // ev.desc is "Rosh Chodesh <Month>"
            let month = String(ev.desc.dropFirst("Rosh Chodesh ".count))
            return roshChodesh + " " + lookupTranslation(str: month, lang: lang)
        }
        if ev.desc == "Rosh Hashana" {
            var name = lookupTranslation(str: ev.desc, lang: lang)
            if abbreviated, let abbrev = Abbreviations.holiday[name] {
                name = abbrev
            }
            return name + " " + number(ev.hdate.yy)
        }
        let name = lookupTranslation(str: ev.desc, lang: lang)
        guard abbreviated else {
            return name
        }
        // "Shabbat Shuva" → "Sh. Shuva"
        if ev.flags.contains(.SPECIAL_SHABBAT) && (lang == .en || lang == .ashkenazi),
           let space = name.firstIndex(of: " ") {
            return "Sh." + name[space...]
        }
        let key = Abbreviations.tableKey(name)
        if let abbrev = Abbreviations.holiday[key] {
            return abbrev
        }
        // "Pesach IV (CH''M)" → "Pesach IV"
        for suffix in [" (CH''M)", " (חוה״מ)"] where key.hasSuffix(suffix) {
            return String(name.dropLast(suffix.count))
        }
        return name
    }

    /// An emoji for a day with these holidays: the first holiday's own
    /// emoji, else ✡️ for a chag, else nil.
    public static func emoji(for events: [HEvent]) -> String? {
        var isChag = false
        for ev in events {
            if let emoji = ev.emoji {
                return emoji
            }
            if ev.flags.contains(.CHAG) {
                isChag = true
            }
        }
        return isChag ? "✡️" : nil
    }

    // MARK: - Omer and Daf Yomi

    /// Day 1–49 of the Omer count on `hdate`, or nil outside the Omer.
    static func omerDay(_ hdate: HDate) -> Int? {
        switch hdate.mm {
        case .NISAN where hdate.dd >= 16: return hdate.dd - 15
        case .IYYAR: return hdate.dd + 15
        case .SIVAN where hdate.dd <= 5: return hdate.dd + 44
        default: return nil
        }
    }

    /// English ordinal suffix: 1st, 2nd, 3rd, 4th, 11th, 12th, 13th, 21st…
    static func ordinalSuffix(_ n: Int) -> String {
        if (n % 100) / 10 == 1 {
            return "th"
        }
        switch n % 10 {
        case 1: return "st"
        case 2: return "nd"
        case 3: return "rd"
        default: return "th"
        }
    }

    /// "Omer: 31st day" / "עומר יום 31", or nil outside the Omer.
    public func omer(on hdate: HDate) -> String? {
        guard let day = Self.omerDay(hdate) else {
            return nil
        }
        return isHebrew ? "עומר יום \(day)" : "Omer: \(day)\(Self.ordinalSuffix(day)) day"
    }

    /// "Pesachim 108" / "פסחים דף ק״ח".
    public func dafYomi(on date: Date) -> String? {
        guard let daf = try? Hebcal.dafYomi(date: date) else {
            return nil
        }
        let name = lookupTranslation(str: daf.name, lang: lang)
        return isHebrew
            ? name + " דף " + hebnumToString(number: daf.blatt)
            : name + " " + String(daf.blatt)
    }
}
