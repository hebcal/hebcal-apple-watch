//
//  OmerDetail.swift
//  HebcalWatchCore
//
//  The card shown when tapping a day of the Omer, like the day's page on
//  hebcal.com/omer: the count, the Sefirah, the word and letter from
//  Psalm 67 and the word from Ana BeKoach, as display strings.
//

import Foundation
import Hebcal

public struct OmerDetail: Hashable, Codable, Sendable {
    public struct Line: Hashable, Codable, Sendable {
        public var text: String
        /// Hebrew text, to be right-aligned even when the card is in English.
        public var isHebrew: Bool
        /// Transliterated Hebrew, shown in italics.
        public var isTransliteration = false
    }

    public struct Section: Hashable, Codable, Sendable {
        public var heading: String
        public var lines: [Line]
    }

    /// Day 1–49.
    public var day: Int
    /// "13th day of the Omer" / "י״ג בעומר".
    public var title: String
    /// The card's heading, the evening the count is said: "Wednesday night,
    /// 19 May 2027", then shorter forms for when it doesn't fit.
    public var nightTitles: [String]
    /// The Hebrew date the count belongs to, shown under the heading:
    /// "13 Iyyar 5787" / "י״ג אִיָיר תשפ״ז".
    public var hebrewDate: String
    /// The card is in Hebrew (title and headings right-aligned).
    public var isHebrew: Bool
    public var sections: [Section]
    /// Today's word from Ana BeKoach, and its letter and word from Psalm 67,
    /// shown in one untitled row at the bottom of the card.
    public var anaBekoachWord: String
    public var lamnatzeachLetter: String
    public var lamnatzeachWord: String

    /// "Omer: 13th day", short enough for one line on a button; the Hebrew
    /// title is already short.
    public var shortTitle: String {
        isHebrew ? title : "Omer: \(day)\(HebcalFormatter.ordinalSuffix(day)) day"
    }
}

extension HebcalFormatter {
    /// The Omer card for `hdate`, or nil outside the Omer. In English it
    /// pairs the Hebrew count and Sefirah with a translation; in Hebrew it
    /// shows only the Hebrew.
    public func omerDetail(on hdate: HDate, calendar: Calendar) -> OmerDetail? {
        guard let ev = OmerEvent(hdate: hdate) else {
            return nil
        }
        func he(_ text: String) -> OmerDetail.Line { .init(text: text, isHebrew: true) }
        func en(_ text: String) -> OmerDetail.Line { .init(text: text, isHebrew: false) }
        func translit(_ text: String) -> OmerDetail.Line {
            .init(text: text, isHebrew: false, isTransliteration: true)
        }
        let sections: [OmerDetail.Section]
        if isHebrew {
            sections = [
                .init(heading: "ספירת העומר", lines: [he(ev.getTodayIs(lang: .heNikud))]),
                .init(heading: "ספירה", lines: [he(ev.sefira(lang: .he))]),
            ]
        } else {
            sections = [
                .init(heading: "Count", lines: [he(ev.getTodayIs(lang: .heNikud)),
                                                en(ev.getTodayIs(lang: .en))]),
                .init(heading: "Sefirah", lines: [he(ev.sefira(lang: .he)),
                                                  translit(ev.sefira(lang: .translit)),
                                                  en(ev.sefira(lang: .en))]),
            ]
        }
        return OmerDetail(day: ev.omer, title: ev.render(lang: lang),
                          nightTitles: nightTitles(for: hdate, calendar: calendar),
                          hebrewDate: dateString(hdate, showYear: true),
                          isHebrew: isHebrew, sections: sections,
                          anaBekoachWord: ev.getAnaBekoachWord(),
                          lamnatzeachLetter: ev.getLamnatzeachLetter(),
                          lamnatzeachWord: ev.getLamnatzeachWord())
    }
}
