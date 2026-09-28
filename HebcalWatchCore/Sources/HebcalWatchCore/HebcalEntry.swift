//
//  HebcalEntry.swift
//  HebcalWatchCore
//
//  Everything the complications display at one moment, precomputed as
//  strings. The widget extension adds the WidgetKit `TimelineEntry`
//  conformance; keeping it out of here lets tests build entries on the Mac.
//

import Foundation
import Hebcal

public struct HebcalEntry {
    public let date: Date

    // Hebrew date pieces (already localized / transliterated for the
    // current user setting).
    public let hebDayNumber: String        // "26" or "כ״ו"
    public let hebMonthName: String        // "Iyyar" or "אייר"
    public let hebDateShort: String        // "26 Iyyar"
    public let hebDateLong: String         // "26 Iyyar 5785"
    public let hebMonthAbbrev: String      // best-fit short month for circular faces

    // Parsha
    public let parshaName: String?         // "Behar-Bechukotai"
    public let parshaForFallback: String   // parshaName, or the holiday that displaces it

    // What the Parsha widget should actually show for today:
    // - on a Shabbat with a regular weekly reading, that parsha, even if
    //   the day is also a special Shabbat or Rosh Chodesh;
    // - otherwise, if today itself is a holiday (e.g. Yom Kippur, or Rosh
    //   Chodesh on a weekday), the holiday name;
    // - otherwise the upcoming Shabbat's parsha, or the holiday that
    //   displaces it (e.g. "Sukkot").
    public let parshaShowsHoliday: Bool    // true when a holiday of today replaces the parsha
    public let parshaParts: [String]       // 1 or 2 elements for stacked layouts
    // Shown below a one-line holiday of today in place of the Torah icon:
    // "Purim" with 🎭️📜. Never set for an upcoming holiday's reading (e.g.
    // "Sukkot" the week before), which keeps the Torah icon so it doesn't
    // read as if today were the holiday.
    public let parshaEmoji: String?
    public let parshaPrefixed: String      // "Parashat Behar-Bechukotai", or the holiday name on a holiday
    public let parshaShort: String         // "Behar-Bechukotai", or the abbreviated holiday name

    // Holiday for the rectangular (rich) widget: today's holiday if any,
    // else the upcoming Shabbat's special-Shabbat name (e.g. "Shabbat
    // Shuva" all week long). Not strictly today's — see parshaShowsHoliday.
    public let richHoliday: String?
    public let richHolidayShort: String?
    // Header tiers for the rectangular widget, widest to narrowest (each
    // with the holiday emoji, if any).
    public let richHeaderLong: String      // "26 Tishrei 5787"
    public let richHeaderShort: String     // "26 Tishrei" (no year)
    public let richHeaderAbbrev: String    // "26 Tishr" (Abbreviations.month)
    public let omerToday: String?

    // Inline (one-line) form, replaces utilitarian-large. Tiers from
    // widest to narrowest; the view picks the first one that fits.
    public let inlineText: String          // "26 Tishrei · Bereshit"
    public let inlineAbbrevText: String    // "26 Tishr · Bereshit" (Abbreviations.month)
    public let inlineTinyText: String      // "26 Tish · Bereshit" (Abbreviations.monthTiny)
}

extension HebcalEntry {
    private static let inlineFormatRTL = "\u{202E}%@ · %@"
    private static let inlineFormatLTR = "%@ · %@"

    /// Computes every complication string for `date`.
    public init(date: Date, formatter: HebcalFormatter, calendar: Calendar = .current) {
        let hdate = HebcalFormatter.hebrewDate(for: date, calendar: calendar)
        let lang = formatter.lang

        let parts = formatter.dateParts(hdate, showYear: false)
        let dayNum = parts[0]
        let monthName = parts[1]
        let hebDateShort = parts.joined(separator: " ")
        let hebDateLong = formatter.dateString(hdate, showYear: true)
        let monthKey = Abbreviations.tableKey(monthName)
        let monthShort = (Abbreviations.month[monthKey] ?? nil) ?? monthName
        let hebDateAbbrev = "\(dayNum) \(monthShort)"

        // Parsha (independent of holiday)
        let parshaName = formatter.parsha(on: hdate)
        let parshaForFallback = formatter.parshaOrHoliday(on: hdate)
        let parshaPrefix = lookupTranslation(str: "Parashat", lang: lang)

        // Today's own holiday (specialShabbat: false, so a weekday before a
        // special Shabbat doesn't pick up "Sh. Shuva"), shown instead of the
        // parsha by the inline and Parsha widgets — except on a Shabbat with
        // a regular reading (Shabbat Shuva, Shabbat Rosh Chodesh), which
        // keeps its parsha. Showing "Parashat Sukkot" (the upcoming Shabbat)
        // on a non-Shabbat holiday such as Yom Kippur reads as a mistake.
        let isShabbatWithParsha = hdate.dow() == .SAT && parshaName != nil
        let holidayToday = isShabbatWithParsha ? nil
            : formatter.holidayToDisplay(on: hdate, specialShabbat: false)
        let holidayTodayName = holidayToday.map { formatter.holidayName($0, abbreviated: false) }
        let holidayTodayShort = holidayToday.map { formatter.holidayName($0, abbreviated: true) }
        // The holiday that replaces the upcoming Shabbat's parsha, shortened
        // ("R.H.") for the Parsha circular face.
        let fallbackShort = Abbreviations.holiday[Abbreviations.tableKey(parshaForFallback)]
            ?? parshaForFallback

        // Inline: date tiers, each followed by today's holiday or the parsha.
        let inlineExtra = holidayTodayShort ?? parshaName
        let inlineFormat = lang == .he ? Self.inlineFormatRTL : Self.inlineFormatLTR
        func inline(_ hebDate: String) -> String {
            guard let extra = inlineExtra else { return hebDate }
            return String(format: inlineFormat, hebDate, extra)
        }

        // Rich (rectangular): specialShabbat: true, with emoji on the header.
        var richHeaderSuffix = ""
        var richHoliday: String? = nil
        var richHolidayShort: String? = nil
        if let ev = formatter.holidayToDisplay(on: hdate, specialShabbat: true) {
            richHoliday = formatter.holidayName(ev, abbreviated: false)
            richHolidayShort = formatter.holidayName(ev, abbreviated: true)
            if let emoji = HebcalFormatter.emoji(for: [ev]) {
                richHeaderSuffix = " " + emoji
            }
        }

        self.date = date
        self.hebDayNumber = dayNum
        self.hebMonthName = monthName
        self.hebDateShort = hebDateShort
        self.hebDateLong = hebDateLong
        self.hebMonthAbbrev = monthShort
        self.parshaName = parshaName
        self.parshaForFallback = parshaForFallback
        self.parshaShowsHoliday = holidayToday != nil
        self.parshaParts = holidayTodayShort.map { Abbreviations.splitParsha($0) }
            ?? parshaName.map { Abbreviations.splitParsha($0) }
            ?? [fallbackShort]
        self.parshaEmoji = holidayToday?.emoji
        self.parshaPrefixed = holidayTodayName ?? "\(parshaPrefix) \(parshaForFallback)"
        self.parshaShort = holidayTodayShort ?? parshaForFallback
        self.richHoliday = richHoliday
        self.richHolidayShort = richHolidayShort
        self.richHeaderLong = hebDateLong + richHeaderSuffix
        self.richHeaderShort = hebDateShort + richHeaderSuffix
        self.richHeaderAbbrev = hebDateAbbrev + richHeaderSuffix
        self.omerToday = formatter.omer(on: hdate)
        self.inlineText = inline(hebDateShort)
        self.inlineAbbrevText = inline(hebDateAbbrev)
        self.inlineTinyText = inline("\(dayNum) \(Abbreviations.monthTiny[monthKey] ?? monthShort)")
    }

    /// Entries for `dates`; safe to call from several threads at once.
    public static func entries(at dates: [Date], settings: HebcalSettings,
                               calendar: Calendar = .current) -> [HebcalEntry] {
        let formatter = HebcalFormatter(settings: settings)
        return dates.map { HebcalEntry(date: $0, formatter: formatter, calendar: calendar) }
    }

    /// Sparse timeline pivots starting at `date`: only the moments when the
    /// displayed text can change, notably 8 PM (when `hebrewDate(for:)`
    /// advances to the next Hebrew day) and around midnight.
    public static func timelineDates(from date: Date, calendar: Calendar) -> [Date] {
        let fourHours = 4.0 * 60.0 * 60.0
        let hour = calendar.component(.hour, from: date)
        if hour < 2 {
            let oneFiftyNine = calendar.date(bySettingHour: 1, minute: 59, second: 59, of: date)!
            return [date, oneFiftyNine]
        } else if hour < 10 {
            let tenAm = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: date)!
            return [date, tenAm]
        } else if hour < 20 {
            let sevenFiftyNine = calendar.date(bySettingHour: 19, minute: 59, second: 0, of: date)!
            let eightPm = sevenFiftyNine.addingTimeInterval(60.0)
            let elevenFiftyNine = sevenFiftyNine.addingTimeInterval(fourHours)
            return [date, sevenFiftyNine, eightPm, elevenFiftyNine]
        } else {
            let elevenFiftyNine = calendar.date(bySettingHour: 23, minute: 59, second: 0, of: date)!
            let oneFiftyNineAm = elevenFiftyNine.addingTimeInterval(fourHours)
            return [date, elevenFiftyNine, oneFiftyNineAm]
        }
    }
}
