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
    /// The card is in Hebrew (title and headings right-aligned).
    public var isHebrew: Bool
    public var sections: [Section]
}

extension HebcalFormatter {
    /// The Omer card for `hdate`, or nil outside the Omer. In English it
    /// pairs the Hebrew count and Sefirah with a translation; in Hebrew it
    /// shows only the Hebrew.
    public func omerDetail(on hdate: HDate) -> OmerDetail? {
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
                .init(heading: "למנצח", lines: [he(ev.getLamnatzeachWord())]),
                .init(heading: "ישמחו (תהלים ס״ז:ה׳)", lines: [he(ev.getLamnatzeachLetter())]),
                .init(heading: "אנא בכח", lines: [he(ev.getAnaBekoachWord())]),
            ]
        } else {
            sections = [
                .init(heading: "Count", lines: [he(ev.getTodayIs(lang: .heNikud)),
                                                en(ev.getTodayIs(lang: .en))]),
                .init(heading: "Sefirah", lines: [he(ev.sefira(lang: .he)),
                                                  translit(ev.sefira(lang: .translit)),
                                                  en(ev.sefira(lang: .en))]),
                .init(heading: "Psalm 67 word", lines: [he(ev.getLamnatzeachWord())]),
                .init(heading: "Psalm 67:5 letter", lines: [he(ev.getLamnatzeachLetter())]),
                .init(heading: "Ana BeKoach", lines: [he(ev.getAnaBekoachWord())]),
            ]
        }
        return OmerDetail(day: ev.omer, title: ev.render(lang: lang),
                          isHebrew: isHebrew, sections: sections)
    }
}
