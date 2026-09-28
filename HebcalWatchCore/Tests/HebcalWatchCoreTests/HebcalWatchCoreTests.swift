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
