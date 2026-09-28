//
//  HebcalWatchCoreTests.swift
//  HebcalWatchCoreTests
//
//  Focused checks of the helpers. The year-long view of the Parsha
//  complication is in ParshaCircularYearTests.
//
//  Every suite is nested in `HebcalWatchCoreTests`, which is `.serialized`:
//  hebcal-swift has an unsynchronized global cache, so tests calling into it
//  in parallel crash.
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

@Suite(.serialized) struct HebcalWatchCoreTests {}

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
            ("Sh’lach", ["Sh’", "lach"]),
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
            // Day after YK: the upcoming Shabbat's holiday reading.
            (2026, 9, 22, .en, .parsha("Sukkot")),
            // Shabbat Shuva on Shabbat itself: the weekly parsha.
            (2026, 9, 19, .en, .twoLines("Ha’", "azinu")),
            // Rosh Chodesh Kislev on a weekday: the holiday.
            (2026, 11, 11, .en, .twoLines("R.Ch.", "Kislev")),
            (2026, 10, 15, .en, .parsha("Noach")),
            (2026, 12, 25, .en, .parsha("Vayechi")),
            (2027, 3, 22, .en, .twoLines("Erev", "Purim")),
            (2027, 3, 23, .en, .holiday("Purim")),
            (2027, 3, 24, .en, .twoLines("Shushan", "Purim")),
        ])
        func parshaCircularLayout(y: Int, m: Int, d: Int, lang: TranslationLang, expected: ParshaCircularLayout) {
            #expect(ParshaCircularLayout(entry: entry(y, m, d, lang)) == expected)
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
    }
}

// MARK: - Settings

extension HebcalWatchCoreTests {
    @Suite struct SettingsTests {
        private func scratchDefaults() -> UserDefaults {
            let name = "HebcalWatchCoreTests.\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: name)!
            defaults.removePersistentDomain(forName: name)
            return defaults
        }

        @Test func unsetDefaultsGiveDiasporaSephardic() {
            #expect(HebcalSettings(defaults: scratchDefaults()) == HebcalSettings(il: false, lang: .en, dafyomi: false))
        }

        @Test func roundTrip() {
            let defaults = scratchDefaults()
            let settings = HebcalSettings(il: true, lang: .he, dafyomi: true)
            settings.save(to: defaults)
            #expect(HebcalSettings(defaults: defaults) == settings)
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
