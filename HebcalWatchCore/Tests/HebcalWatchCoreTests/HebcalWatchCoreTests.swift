//
//  HebcalWatchCoreTests.swift
//  HebcalWatchCoreTests
//
//  Focused checks of the helpers. The year-long view of the Parsha
//  complication is in ParshaCircularYearTests.
//

import Foundation
import Hebcal
import Testing
@testable import HebcalWatchCore

private let calendar = HebcalWatchCoreTests.ParshaCircularYear.calendar

private func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12, minute: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: y, month: m, day: d, hour: hour, minute: minute))!
}

private func formatter(_ lang: TranslationLang = .en, il: Bool = false) -> HebcalFormatter {
    HebcalFormatter(settings: HebcalSettings(il: il, lang: lang))
}

private func entry(_ y: Int, _ m: Int, _ d: Int, _ lang: TranslationLang = .en, il: Bool = false) -> HebcalEntry {
    HebcalEntry(date: date(y, m, d), formatter: formatter(lang, il: il), calendar: calendar)
}

/// An empty UserDefaults suite of its own.
private func scratchDefaults() -> UserDefaults {
    let name = "HebcalWatchCoreTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
}

@Suite struct HebcalWatchCoreTests {}

// MARK: - Abbreviations

extension HebcalWatchCoreTests {
    @Suite struct AbbreviationTests {
        @Test func tableKeyNormalizesCurlyApostrophe() {
            #expect(Abbreviations.tableKey("Sh’vat") == "Sh'vat")
            #expect(Abbreviations.tableKey("Noach") == "Noach")
        }

        @Test(arguments: [
            ("Nitzavim-Vayeilech", ["Nitzavim", "Vayeilech"]),  // dash
            ("נצבים־וילך", ["נצבים", "וילך"]),                   // Hebrew maqaf
            ("Ki Tavo", ["Ki", "Tavo"]),                         // space
            ("Bereshit", ["Bere-", "sheet"]),                    // hyphenation table
            ("Bereshis", ["Bere-", "shis"]),                     // Ashkenazi entry
            ("Beha’alotcha", ["Behaa", "lotcha"]),               // ’ from lookupTranslation
            ("Sh’lach", ["Sh’lach"]),                            // nil in table: fits
            ("כי תשא", ["כי תשא"]),                              // parshaOneLine
            ("שלח־לך", ["שלח־לך"]),
            ("חיי שרה", ["חיי", "שרה"]),
            ("Noach", ["Noach"]),                                // nil in table: fits
            ("Vayechi", ["Vayechi"]),
            ("נח", ["נח"]),                                      // not in table
        ])
        func splitParsha(name: String, expected: [String]) {
            #expect(Abbreviations.splitParsha(name) == expected)
        }

        /// Every parsha as Sedra spells it (after tableKey) should have a
        /// hyphenation entry, so that a missing one is a deliberate choice.
        @Test(arguments: [TranslationLang.en, .ashkenazi])
        func everySingleWordParshaIsInHyphenationTable(lang: TranslationLang) {
            let formatter = formatter(lang)
            var missing = Set<String>()
            for offset in 0..<(3 * 7 * 55) where offset % 7 == 0 {
                let hdate = HDate(absdate: HDate(yy: 5787, mm: .TISHREI, dd: 1).abs() + Int64(offset))
                guard let parsha = formatter.parsha(on: hdate) else { continue }
                let key = Abbreviations.tableKey(parsha)
                if !key.contains(where: { $0 == " " || $0 == "-" }) && Abbreviations.parshaHyphenation[key] == nil {
                    missing.insert(key)
                }
            }
            #expect(missing.isEmpty, "not in parshaHyphenation: \(missing.sorted())")
        }
    }
}

// MARK: - HebcalFormatter

extension HebcalWatchCoreTests {
    @Suite struct FormatterTests {
        @Test func hebrewDateRollsOverAt8PM() {
            let before = HebcalFormatter.hebrewDate(for: date(2026, 10, 7, hour: 19, minute: 59), calendar: calendar)
            let after = HebcalFormatter.hebrewDate(for: date(2026, 10, 7, hour: 20), calendar: calendar)
            #expect(before.dd == 26 && before.mm == .TISHREI)
            #expect(after.dd == 27 && after.mm == .TISHREI)
        }

        @Test func dateStrings() {
            let hdate = HDate(yy: 5787, mm: .TISHREI, dd: 26)
            #expect(formatter(.en).dateString(hdate, showYear: true) == "26 Tishrei 5787")
            #expect(formatter(.he).dateString(hdate, showYear: false) == "כ״ו תשרי")
        }

        @Test(arguments: [
            (TranslationLang.en, false, "Yom Kippur"), (.en, true, "Y.K."),
            (.he, false, "יום כפור"), (.he, true, "יוה״כ"),
        ])
        func yomKippurName(lang: TranslationLang, abbreviated: Bool, expected: String) throws {
            let f = formatter(lang)
            let ev = try #require(f.holidayToDisplay(on: HDate(yy: 5787, mm: .TISHREI, dd: 10), specialShabbat: false))
            #expect(f.holidayName(ev, abbreviated: abbreviated) == expected)
        }

        @Test func abbreviatedHolidayNames() throws {
            let f = formatter(.en)
            func short(_ mm: HebrewMonth, _ dd: Int, specialShabbat: Bool = false) throws -> String {
                let ev = try #require(f.holidayToDisplay(on: HDate(yy: 5787, mm: mm, dd: dd), specialShabbat: specialShabbat))
                return f.holidayName(ev, abbreviated: true)
            }
            #expect(try short(.TISHREI, 1) == "R.H. 5787")
            #expect(try short(.KISLEV, 1) == "R.Ch. Kislev")
            #expect(try short(.TISHREI, 17) == "Sukkot III")           // (CH''M) dropped
            #expect(try short(.TISHREI, 5, specialShabbat: true) == "Sh. Shuva")
        }

        @Test func specialShabbatOnlyWhenRequested() {
            let weekdayBeforeShuva = HDate(yy: 5787, mm: .TISHREI, dd: 5)
            #expect(formatter().holidayToDisplay(on: weekdayBeforeShuva, specialShabbat: false) == nil)
            #expect(formatter().holidayToDisplay(on: weekdayBeforeShuva, specialShabbat: true) != nil)
        }

        @Test(arguments: [(1, "st"), (2, "nd"), (3, "rd"), (4, "th"), (11, "th"), (12, "th"),
                          (13, "th"), (21, "st"), (22, "nd"), (23, "rd"), (33, "rd"), (49, "th")])
        func ordinalSuffix(n: Int, expected: String) {
            #expect(HebcalFormatter.ordinalSuffix(n) == expected)
        }

        @Test func omer() {
            #expect(formatter().omer(on: HDate(yy: 5787, mm: .NISAN, dd: 15)) == nil)
            #expect(formatter().omer(on: HDate(yy: 5787, mm: .NISAN, dd: 16)) == "Omer: 1st day")
            #expect(formatter().omer(on: HDate(yy: 5787, mm: .IYYAR, dd: 18)) == "Omer: 33rd day")
            #expect(formatter(.he).omer(on: HDate(yy: 5787, mm: .SIVAN, dd: 5)) == "עומר יום 49")
            #expect(formatter().omer(on: HDate(yy: 5787, mm: .SIVAN, dd: 6)) == nil)
        }

        @Test func omerDetail() throws {
            #expect(formatter().omerDetail(on: HDate(yy: 5787, mm: .NISAN, dd: 15)) == nil)
            #expect(formatter().omerDetail(on: HDate(yy: 5787, mm: .SIVAN, dd: 6)) == nil)
            let detail = try #require(formatter().omerDetail(on: HDate(yy: 5787, mm: .IYYAR, dd: 13)))
            #expect(detail.day == 28)
            #expect(detail.title == "28th day of the Omer")
            #expect(detail.shortTitle == "Omer: 28th day")
            #expect(!detail.isHebrew)
            #expect(detail.sections.map(\.heading) ==
                    ["Count", "Sefirah", "Psalm 67 word", "Psalm 67:5 letter", "Ana BeKoach"])
            let count = detail.sections[0].lines
            #expect(count.map(\.isHebrew) == [true, false])
            #expect(count[1].text == "Today is 28 days, which are 4 weeks of the Omer")
            let sefirah = detail.sections[1].lines.map(\.text)
            #expect(sefirah[1] == "Malkhut sheb'Netzach")
            #expect(sefirah[2] == "Majesty within Eternity")
            #expect(detail.sections[1].lines.map(\.isTransliteration) == [false, true, false])
        }

        @Test func omerDetailInHebrew() throws {
            let detail = try #require(formatter(.he).omerDetail(on: HDate(yy: 5787, mm: .NISAN, dd: 16)))
            #expect(detail.title == "א׳ בעומר")
            #expect(detail.isHebrew)
            #expect(detail.sections.allSatisfy { $0.lines.allSatisfy(\.isHebrew) })
        }

        @Test func onlyOmerDaysHaveDetail() {
            let f = formatter()
            let omerDay = f.dateItem(for: date(2027, 4, 23), calendar: calendar, now: date(2027, 4, 23),
                                     showYear: false, forceParsha: false)
            let plainDay = f.dateItem(for: date(2026, 10, 7), calendar: calendar, now: date(2026, 10, 7),
                                      showYear: false, forceParsha: false)
            guard case .omer(let omer) = omerDay.detail else {
                Issue.record("expected an Omer detail on \(omerDay.hdate)")
                return
            }
            #expect(omerDay.omer == "Omer: \(omer.day)\(HebcalFormatter.ordinalSuffix(omer.day)) day")
            #expect(plainDay.detail == nil)
        }

        @Test func parshaReplacedByHoliday() {
            let beforeSukkot = HDate(yy: 5787, mm: .TISHREI, dd: 11)
            #expect(formatter().parsha(on: beforeSukkot) == nil)
            #expect(formatter().parshaOrHoliday(on: beforeSukkot) == "Sukkot")
            #expect(formatter(.he).parshaOrHoliday(on: beforeSukkot) == "סוכות")
        }

        @Test func dateItemsCoverTwoWeeksThenShabbatotAndHolidays() {
            let items = formatter().dateItems(from: date(2026, 10, 7), calendar: calendar)
            #expect(items.count > 14)
            #expect(items.first?.gregYear == 2026)          // first row shows the year
            #expect(items[1].gregYear == 0)                 // later rows in the same year don't
            #expect(Set(items.map(\.id)).count == items.count)
        }
    }
}

// MARK: - HebcalEntry

extension HebcalWatchCoreTests {
    @Suite struct EntryTests {
        /// Scenarios from the widget's #Previews, pinned down as assertions.
        @Test(arguments: [
            // Yom Kippur (weekday holiday): the holiday, not "Parashat Sukkot".
            (2026, 9, 21, TranslationLang.en, ParshaCircularLayout.holiday("Y.K.")),
            (2026, 9, 21, .he, .holiday("יוה״כ")),
            // Day after YK: the upcoming Shabbat's holiday reading, with the
            // Torah icon rather than the holiday's emoji.
            (2026, 9, 22, .en, .parsha("Sukkot")),
            // The week before Rosh Hashana: abbreviated, with the Torah icon.
            (2026, 9, 7, .en, .parsha("R.H.")),
            (2026, 9, 7, .he, .parsha("ראה״ש")),
            // Shabbat Shuva on Shabbat itself: the weekly parsha.
            (2026, 9, 19, .en, .twoLines("Ha’", "azinu")),
            // Rosh Chodesh Kislev on a weekday: the holiday.
            (2026, 11, 11, .en, .twoLines("R.Ch.", "Kislev")),
            (2026, 10, 15, .en, .parsha("Noach")),
            (2026, 12, 25, .en, .parsha("Vayechi")),
            (2027, 3, 22, .en, .twoLines("Erev", "Purim")),
            (2027, 3, 23, .en, .holidayWithEmoji("Purim", "🎭️📜")),
            (2026, 12, 7, .en, .emojiAbove("🕎", "Day 3️⃣")),
            (2026, 12, 7, .he, .twoLines("חנוכה", "3️⃣")),
            (2027, 2, 22, .he, .parsha("כי תשא")),
            (2027, 3, 24, .en, .twoLines("Shushan", "Purim")),
        ])
        func parshaCircularLayout(y: Int, m: Int, d: Int, lang: TranslationLang, expected: ParshaCircularLayout) {
            #expect(ParshaCircularLayout(entry: entry(y, m, d, lang)) == expected)
        }

        @Test(arguments: [
            ("🕎", true), ("🍏🍯", true),
            ("Day 4️⃣", false), ("4", false), ("חנוכה", false), ("", false),
        ])
        func isEmojiOnly(text: String, expected: Bool) {
            #expect(ParshaCircularLayout.isEmojiOnly(text) == expected)
        }

        @Test func inlineText() {
            let e = entry(2026, 10, 7)
            #expect(e.inlineText == "26 Tishrei · Bereshit")
            #expect(e.inlineAbbrevText == "26 Tishr · Bereshit")
            #expect(e.inlineTinyText == "26 Tish · Bereshit")
            #expect(entry(2026, 10, 7, .he).inlineText.hasPrefix("\u{202E}"))
        }

        @Test func richHolidayIncludesUpcomingSpecialShabbat() {
            let e = entry(2026, 9, 16)   // Wednesday before Shabbat Shuva
            #expect(e.richHoliday == "Shabbat Shuva")
            #expect(e.parshaShowsHoliday == false)
        }

        @Test func timelinePivotsAroundEightPM() {
            let dates = HebcalEntry.timelineDates(from: date(2026, 11, 3, hour: 15, minute: 30), calendar: calendar)
            let hm = dates.map { calendar.dateComponents([.hour, .minute], from: $0) }.map { "\($0.hour!):\($0.minute!)" }
            #expect(hm == ["15:30", "19:59", "20:0", "23:59"])
        }

        @Test func clockOffsetStampsEntriesOnTheRealClock() {
            let fake = date(2027, 5, 10)
            let offset = 180.0 * 24 * 60 * 60
            let entry = HebcalEntry.entries(at: [fake], settings: HebcalSettings(), calendar: calendar,
                                            clockOffset: offset)[0]
            #expect(entry.date == fake.addingTimeInterval(-offset))
            #expect(entry.omerToday == "Omer: 18th day")        // contents are for the fake date
        }
    }
}

// MARK: - Settings

extension HebcalWatchCoreTests {
    @Suite struct SettingsTests {
        @Test func unsetDefaultsGiveDiasporaSephardic() {
            #expect(HebcalSettings(defaults: scratchDefaults(), timeZone: TimeZone(identifier: "America/New_York")!)
                    == HebcalSettings(il: false, lang: .en, dafyomi: false))
        }

        @Test func unsetIsraelDefaultsToOnInIsrael() {
            let jerusalem = TimeZone(identifier: "Asia/Jerusalem")!
            // What the widget reads before the app has ever launched.
            #expect(HebcalSettings(defaults: scratchDefaults(), timeZone: jerusalem).il)
            // A saved choice wins.
            let defaults = scratchDefaults()
            HebcalSettings(il: false).save(to: defaults)
            #expect(!HebcalSettings(defaults: defaults, timeZone: jerusalem).il)
        }

        @Test func roundTrip() {
            let defaults = scratchDefaults()
            let settings = HebcalSettings(il: true, lang: .he, dafyomi: true)
            settings.save(to: defaults)
            #expect(HebcalSettings(defaults: defaults) == settings)
        }

        @Test func newInstallInIsraelDefaultsToIsraelSchedule() {
            let defaults = scratchDefaults()
            let settings = HebcalSettings.launchSettings(defaults: defaults,
                                                         timeZone: TimeZone(identifier: "Asia/Jerusalem")!)
            #expect(settings.il)
            #expect(HebcalSettings(defaults: defaults).il)      // saved
            #expect(!HebcalSettings.israelChosen(defaults: defaults))
        }

        @Test func newInstallElsewhereSavesNothing() {
            let defaults = scratchDefaults()
            let settings = HebcalSettings.launchSettings(defaults: defaults,
                                                         timeZone: TimeZone(identifier: "America/New_York")!)
            #expect(!settings.il)
            #expect(defaults.object(forKey: "lang") == nil)
        }

        @Test func existingInstallInIsraelIsLeftAlone() {
            let defaults = scratchDefaults()
            HebcalSettings(il: false, lang: .he).save(to: defaults)
            let settings = HebcalSettings.launchSettings(defaults: defaults,
                                                         timeZone: TimeZone(identifier: "Asia/Jerusalem")!)
            #expect(!settings.il)
            // An Israel setting saved before this version counts as chosen.
            #expect(HebcalSettings.israelChosen(defaults: defaults))
        }

        @Test func firstLocationInIsraelTurnsOnIsraelUnlessChosen() {
            let tlv = GeoPoint(latitude: 32.08, longitude: 34.78, timeZoneIdentifier: "Asia/Jerusalem")
            let nyc = GeoPoint(latitude: 40.71, longitude: -74.01, timeZoneIdentifier: "America/New_York")
            let diaspora = HebcalSettings(il: false, useLocation: true)
            #expect(diaspora.applyingFirstLocation(tlv, israelChosen: false).il)
            #expect(diaspora.applyingFirstLocation(tlv, israelChosen: false).location == tlv)
            #expect(!diaspora.applyingFirstLocation(tlv, israelChosen: true).il)
            #expect(!diaspora.applyingFirstLocation(nyc, israelChosen: false).il)
            // Never switches Israel off.
            #expect(HebcalSettings(il: true).applyingFirstLocation(nyc, israelChosen: false).il)
        }

        @Test func zmanimRoundTrip() {
            let defaults = scratchDefaults()
            let point = GeoPoint(latitude: 31.7683, longitude: 35.2137, timeZoneIdentifier: "Asia/Jerusalem")
            #expect(point.latitude == 31.77)            // rounded to ~1 km
            for havdalah in [HavdalahSetting.minutes(72), .degrees(7.083), .default] {
                let settings = HebcalSettings(useLocation: true, location: point,
                                              candleLightingMinutes: 30, havdalah: havdalah)
                settings.save(to: defaults)
                #expect(HebcalSettings(defaults: defaults) == settings)
            }
            // Back to automatic, and forgetting the location.
            HebcalSettings().save(to: defaults)
            #expect(HebcalSettings(defaults: defaults) == HebcalSettings())
        }

        @Test func legacyMigrationCopiesOnlyOnce() {
            let standard = scratchDefaults()
            let shared = scratchDefaults()
            HebcalSettings(il: true, lang: .ashkenazi, dafyomi: true).save(to: standard)
            HebcalSettings.migrateLegacySettings(from: standard, to: shared)
            #expect(HebcalSettings(defaults: shared) == HebcalSettings(il: true, lang: .ashkenazi, dafyomi: true))

            // A later change in the shared suite isn't clobbered by the old values.
            HebcalSettings(lang: .he).save(to: shared)
            HebcalSettings.migrateLegacySettings(from: standard, to: shared)
            #expect(HebcalSettings(defaults: shared).lang == .he)
        }
    }
}

// MARK: - Candle times

private let newYork = GeoPoint(latitude: 40.7128, longitude: -74.0060, timeZoneIdentifier: "America/New_York")

private func zmanimFormatter(_ lang: TranslationLang = .en, havdalah: HavdalahSetting = .default,
                             candleLightingMinutes: Int? = nil) -> HebcalFormatter {
    HebcalFormatter(settings: HebcalSettings(lang: lang, useLocation: true, location: newYork,
                                             candleLightingMinutes: candleLightingMinutes, havdalah: havdalah))
}

/// "kind HH:mm" in UTC, to compare with @hebcal/core output.
private func describe(_ events: [ZmanEvent]) -> [String] {
    let utc = ISO8601DateFormatter()
    return events.map { "\($0.kind.rawValue) \(utc.string(from: $0.time))" }
}

private func candleTimes(_ f: HebcalFormatter, _ y: Int, _ m: Int, _ d: Int) -> [String] {
    describe(f.candleTimes(on: HDate(date: date(y, m, d), calendar: calendar), calendar: calendar))
}

extension HebcalWatchCoreTests {
    /// Expected times from @hebcal/core's HebrewCalendar.calendar() with
    /// candlelighting, havdalahDeg 8.5 (or havdalahMins 42), for New York.
    @Suite struct CandleTimeTests {
        @Test(arguments: [
            // Erev Rosh Hashana on Friday: Shabbat candles before sunset.
            (2026, 9, 11, ["candleLighting 2026-09-11T22:53:00Z"]),
            // RH I on Shabbat: candles for RH II at nightfall, no Havdalah.
            (2026, 9, 12, ["candleLighting 2026-09-12T23:51:00Z"]),
            (2026, 9, 13, ["havdalah 2026-09-13T23:49:00Z"]),
            (2026, 9, 14, []),                                  // Tzom Gedaliah: no fast times here
            (2026, 9, 20, ["candleLighting 2026-09-20T22:38:00Z"]),   // Erev Yom Kippur
            (2026, 9, 21, ["havdalah 2026-09-21T23:35:00Z"]),         // Yom Kippur ends
            (2026, 9, 26, ["candleLighting 2026-09-26T23:27:00Z"]),   // Sukkot I → II
            (2026, 9, 27, ["havdalah 2026-09-27T23:25:00Z"]),
            (2026, 10, 3, ["candleLighting 2026-10-03T23:15:00Z"]),   // Shabbat → Shmini Atzeret
            // Chanukah on Friday: with Shabbat candles; Saturday: after Havdalah;
            // weekdays: bein hashmashot.
            (2026, 12, 4, ["candleLighting 2026-12-04T21:10:00Z", "chanukah 2026-12-04T21:10:00Z"]),
            (2026, 12, 5, ["havdalah 2026-12-05T22:14:00Z", "chanukah 2026-12-05T22:14:00Z"]),
            (2026, 12, 7, ["chanukah 2026-12-07T21:52:00Z"]),
            (2026, 12, 12, ["havdalah 2026-12-12T22:14:00Z"]),
            (2026, 12, 13, []),
        ])
        func matchesHebcalCore(y: Int, m: Int, d: Int, expected: [String]) {
            #expect(candleTimes(zmanimFormatter(), y, m, d) == expected)
        }

        @Test func havdalahMinutes() {
            let f = zmanimFormatter(havdalah: .minutes(42))
            #expect(candleTimes(f, 2026, 9, 12) == ["candleLighting 2026-09-12T23:52:00Z"])
            #expect(candleTimes(f, 2026, 9, 13) == ["havdalah 2026-09-13T23:50:00Z"])
        }

        @Test func candleLightingMinutesOverride() {
            // 18 → 40 minutes before sunset is 22 minutes earlier.
            #expect(candleTimes(zmanimFormatter(candleLightingMinutes: 40), 2026, 9, 11)
                    == ["candleLighting 2026-09-11T22:31:00Z"])
        }

        @Test func titles() throws {
            let friday = HDate(date: date(2026, 12, 4), calendar: calendar)
            #expect(zmanimFormatter().candleTimes(on: friday, calendar: calendar).map(\.title)
                    == ["Candle lighting", "Chanukah: 1 Candle"])
            #expect(zmanimFormatter(.he).candleTimes(on: friday.next(), calendar: calendar).first?.title == "הבדלה")
        }

        @Test func nothingWithoutLocation() {
            #expect(candleTimes(formatter(), 2026, 9, 11) == [])
            // Location off, even with a fix saved.
            let off = HebcalFormatter(settings: HebcalSettings(useLocation: false, location: newYork))
            #expect(candleTimes(off, 2026, 9, 11) == [])
        }

        @Test func nothingInAnotherTimeZone() {
            let la = GeoPoint(latitude: 34.05, longitude: -118.24, timeZoneIdentifier: "America/Los_Angeles")
            let f = HebcalFormatter(settings: HebcalSettings(useLocation: true, location: la))
            #expect(f.zmanimLocation(calendar: calendar) == nil)
            #expect(candleTimes(f, 2026, 9, 11) == [])
        }

        @Test(arguments: [
            (31.7683, 35.2137, "Asia/Jerusalem", 40),      // Jerusalem
            (31.80, 35.10, "Asia/Jerusalem", 40),          // Jerusalem outskirts
            (32.8191, 34.9983, "Asia/Jerusalem", 30),      // Haifa
            (32.5706, 34.9544, "Asia/Jerusalem", 30),      // Zikhron Ya'akov
            (32.0853, 34.7818, "Asia/Jerusalem", 20),      // Tel Aviv
            (40.7128, -74.0060, "America/New_York", 18),   // New York
        ])
        func defaultCandleLightingMinutes(lat: Double, lon: Double, tzid: String, expected: Int) {
            let point = GeoPoint(latitude: lat, longitude: lon, timeZoneIdentifier: tzid)
            #expect(point.defaultCandleLightingMinutes == expected)
        }

        @Test func automaticCandleLightingIgnoresSchedule() {
            let tlv = GeoPoint(latitude: 32.08, longitude: 34.78, timeZoneIdentifier: "Asia/Jerusalem")
            let visitor = HebcalFormatter(settings: HebcalSettings(il: false, useLocation: true, location: tlv))
            #expect(visitor.candleLightingMinutes(at: tlv) == 20)
            let israeliAbroad = HebcalFormatter(settings: HebcalSettings(il: true, useLocation: true, location: newYork))
            #expect(israeliAbroad.candleLightingMinutes(at: newYork) == 18)
        }

        @Test func hebrewDateRollsOverAtSunset() {
            // Sunset in New York on Oct 7, 2026 is 6:28:09 PM.
            let f = zmanimFormatter()
            #expect(f.hebrewDate(for: date(2026, 10, 7, hour: 18, minute: 25), calendar: calendar).dd == 26)
            #expect(f.hebrewDate(for: date(2026, 10, 7, hour: 18, minute: 35), calendar: calendar).dd == 27)
            // Without a location, still 8 PM.
            #expect(formatter().hebrewDate(for: date(2026, 10, 7, hour: 18, minute: 35), calendar: calendar).dd == 26)
        }

        @Test func dateItemsIncludeFridaysAndDetail() throws {
            let f = zmanimFormatter()
            let items = f.dateItems(from: date(2026, 10, 7), calendar: calendar)
            // Fridays beyond the first two weeks, e.g. Nov 6, 2026.
            let nov6 = try #require(items.first { $0.gregMonth == "Nov" && $0.gregDay == 6 })
            #expect(nov6.zmanim.map(\.kind) == [.candleLighting])
            guard case .zmanim(let detail) = nov6.detail else {
                Issue.record("expected a zmanim detail")
                return
            }
            #expect(detail.sunset != nil)
            #expect(detail.omer == nil)
            // Without a location, no Fridays that aren't holidays.
            #expect(!formatter().dateItems(from: date(2026, 10, 7), calendar: calendar)
                .contains { $0.gregMonth == "Nov" && $0.gregDay == 6 })
        }

        @Test func dateItemHasAbbreviatedHolidays() {
            let item = formatter().dateItem(for: date(2026, 10, 12), calendar: calendar,
                                            now: date(2026, 10, 12), showYear: false, forceParsha: false)
            #expect(item.holidays == ["Rosh Chodesh Cheshvan"])
            #expect(item.holidaysShort == ["R.Ch. Cheshvan"])
        }

        @Test func dateItemDoesNotAbbreviateChanukah() {
            let item = formatter().dateItem(for: date(2026, 12, 7), calendar: calendar,
                                            now: date(2026, 12, 7), showYear: false, forceParsha: false)
            #expect(item.holidays == ["Chanukah: 4 Candles"])
            #expect(item.holidaysShort == item.holidays)
        }

        @Test func omerFridayLinksToOmer() throws {
            let item = zmanimFormatter().dateItem(for: date(2027, 4, 23), calendar: calendar,
                                                  now: date(2027, 4, 23), showYear: false, forceParsha: false)
            #expect(item.zmanim.map(\.kind) == [.candleLighting])
            #expect(item.detail?.omer != nil)
        }

        @Test func chanukahShabbatRowShowsOnlyShabbatTime() throws {
            let f = zmanimFormatter()
            func item(_ d: Int) -> DateItem {
                f.dateItem(for: date(2026, 12, d), calendar: calendar,
                           now: date(2026, 12, d), showYear: false, forceParsha: false)
            }
            #expect(item(4).zmanim.map(\.kind) == [.candleLighting])
            #expect(item(5).zmanim.map(\.kind) == [.havdalah])
            #expect(item(7).zmanim.map(\.kind) == [.chanukah])
            // The detail card still has both.
            guard case .zmanim(let detail) = item(4).detail else {
                Issue.record("expected a zmanim detail")
                return
            }
            #expect(detail.events.map(\.kind) == [.candleLighting, .chanukah])
        }

        @Test func entryShowsOnlyTodaysCandleTimes() {
            let f = zmanimFormatter()
            func kinds(_ d: Int, _ h: Int, _ min: Int = 0) -> [ZmanEvent.Kind] {
                HebcalEntry(date: date(2026, 11, d, hour: h, minute: min), formatter: f, calendar: calendar)
                    .zmanim.map(\.kind)
            }
            // Fri Nov 6: candles 4:28 PM, sunset 4:46 PM; Sat Nov 7: sunset 4:45 PM, Havdalah 5:28 PM.
            #expect(kinds(5, 12) == [])                      // Thursday
            #expect(kinds(5, 20) == [])                      // Thursday night: Friday's candles wait for midnight
            #expect(kinds(6, 0, 1) == [.candleLighting])
            #expect(kinds(6, 9) == [.candleLighting])
            #expect(kinds(6, 16, 40) == [.candleLighting])   // lit, not yet sunset
            #expect(kinds(6, 17, 0) == [])                   // Friday night: Havdalah waits for midnight
            #expect(kinds(7, 0, 1) == [.havdalah])
            #expect(kinds(7, 17, 0) == [.havdalah])          // after sunset, before Havdalah
            #expect(kinds(7, 18, 0) == [])
        }

        @Test func timelinePivotsAtSunsetAndCandleTimes() {
            let settings = HebcalSettings(useLocation: true, location: newYork)
            let start = date(2026, 11, 6, hour: 9)
            let dates = HebcalEntry.timelineDates(from: start, calendar: calendar, settings: settings)
            let hm = dates.map { calendar.dateComponents([.day, .hour, .minute], from: $0) }
                .map { "\($0.day!) \($0.hour!):\($0.minute!)" }
            #expect(hm.first == "6 9:0")
            #expect(hm.contains("6 16:28"))     // candle lighting
            #expect(hm.contains("6 16:46"))     // sunset
            #expect(hm.contains("7 17:28"))     // Havdalah
            #expect(hm.contains("7 0:0"))       // midnight
            #expect(hm.last == "8 0:0")
            #expect(dates == dates.sorted())
            // Without a location, the 8 PM pivots.
            #expect(HebcalEntry.timelineDates(from: start, calendar: calendar, settings: HebcalSettings())
                    == HebcalEntry.timelineDates(from: start, calendar: calendar))
        }
    }
}

// MARK: - DebugClock

extension HebcalWatchCoreTests {
    @Suite struct DebugClockTests {
        @Test func parsesLocalTime() throws {
            let parsed = try #require(DebugClock.parse("2027-05-10T20:15"))
            let c = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: parsed)
            #expect([c.year, c.month, c.day, c.hour, c.minute] == [2027, 5, 10, 20, 15])
            #expect(DebugClock.parse("May 10") == nil)
        }

        @Test func fakeDateSetsAndClearsTheOffset() throws {
            let defaults = scratchDefaults()
            #expect(DebugClock.offset(defaults: defaults) == 0)
            #expect(DebugClock.setFakeDate("2027-05-10T12:00", defaults: defaults))
            let fake = try #require(DebugClock.parse("2027-05-10T12:00"))
            #expect(abs(DebugClock.now(defaults: defaults).timeIntervalSince(fake)) < 5)
            #expect(!DebugClock.setFakeDate("2027-05-10T12:00", defaults: defaults))  // relaunch
            #expect(DebugClock.setFakeDate(nil, defaults: defaults))
            #expect(DebugClock.offset(defaults: defaults) == 0)
            #expect(!DebugClock.setFakeDate("garbage", defaults: defaults))
        }
    }
}
