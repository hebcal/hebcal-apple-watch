//
//  Abbreviations.swift
//  HebcalWatchCore
//
//  Pixel-budgeted abbreviations for month, holiday and parsha names, and
//  the helper that splits a parsha name across two lines. The widths were
//  tuned for each watch face family on the legacy ClockKit complications.
//  When a name doesn't fit on a particular face, the fix usually belongs in
//  these tables rather than in layout code.
//
//  All tables are keyed with plain ASCII ' (e.g. "Sh'vat"), but Hebcal's
//  lookupTranslation() returns ’ for Sephardic and Ashkenazi, so always look
//  names up via tableKey(). Ashkenazi spellings that differ (e.g. "Teves")
//  need their own entries.
//

import Foundation

enum Abbreviations {
    /// Normalizes a translated name (’ → ') for lookup in these tables.
    static func tableKey(_ name: String) -> String {
        return name.replacingOccurrences(of: "’", with: "'")
    }

    /// Holiday names short enough for the narrow complication families.
    static let holiday: [String: String] = [
        "Rosh Chodesh": "R.Ch.",
        "Erev Rosh Hashana": "Erev R.H.",
        "Rosh Hashana": "R.H.",
        "Rosh Hashana II": "R.H. II",
        "Rosh Hashana LaBehemot": "R.H. LaBehemot",
        "Erev Yom Kippur": "Erev Y.K.",
        "Simchat Torah": "Sim. Torah",
        "Simchas Torah": "Sim. Torah",
        "Sukkot VII (Hoshana Raba)": "Hoshana Raba",
        "Sukkos VII (Hoshana Raba)": "Hoshana Raba",
        "Shmini Atzeres": "Shmini Atz.",
        "Shmini Atzeret": "Shmini Atz.",
        "Tish'a B'Av (observed)": "Tish’a B’Av (obs.)",
        "Yom Kippur": "Y.K.",
        "Chanukah: 1 Candle": "🕎 1️⃣ 🕯️",
        "Chanukah: 2 Candles": "🕎 Day 1",
        "Chanukah: 3 Candles": "🕎 Day 2",
        "Chanukah: 4 Candles": "🕎 Day 3",
        "Chanukah: 5 Candles": "🕎 Day 4",
        "Chanukah: 6 Candles": "🕎 Day 5",
        "Chanukah: 7 Candles": "🕎 Day 6",
        "Chanukah: 8 Candles": "🕎 Day 7",
        "Chanukah: 8th Day": "🕎 Day 8",
        "Yom HaZikaron": "Yom HaZik.",
        "Yom HaAtzma'ut": "Yom HaAtz.",
        "Yom Yerushalayim": "Yom Yerush.",
        "Jabotinsky Day": "Jabot. Day",
        "Yitzhak Rabin Memorial Day": "Rabin Day",
        "Yom HaAliyah School Observance": "Yom HaAliyah",
        "ראש חודש": "ר״ח",
        "ערב ראש השנה": "ערב ראה״ש",
        "ראש השנה": "ראה״ש",
        "ערב יום כפור": "ערב יוה״כ",
        "יום כפור": "יוה״כ",
        "ראש השנה למעשר בהמה": "ראה״ש לבהמות",
        "סוכות ז׳ (הושענא רבה)": "הושענא רבה",
        "יום העצמאות": "יוה״ע",
        "יום ירושלים": "יום ירוש׳",
        // with and without nikud (hebcal-swift 425ef8f drops it)
        "יוֹם ז׳בוטינסקי": "יום ז׳בוט׳",
        "יום ז׳בוטינסקי": "יום ז׳בוט׳",
        "יוֹם המשפחה": "יום המשפ׳",
        "יום המשפחה": "יום המשפ׳",
        "יוֹם הַזִּכָּרוֹן ליצחק רבין": "יום רבין",
        "יום הזכרון ליצחק רבין": "יום רבין",
        "שמירת בית הספר ליום העלייה": "יום העלייה",
        // Hebrew Chanukah counts days like the English, not candles,
        // with the same keycap emoji
        "חנוכה: א׳ נר": "חנוכה א׳ נר",
        "חנוכה: ב׳ נרות": "חנוכה 1️⃣",
        "חנוכה: ג׳ נרות": "חנוכה 2️⃣",
        "חנוכה: ד׳ נרות": "חנוכה 3️⃣",
        "חנוכה: ה׳ נרות": "חנוכה 4️⃣",
        "חנוכה: ו׳ נרות": "חנוכה 5️⃣",
        "חנוכה: ז׳ נרות": "חנוכה 6️⃣",
        "חנוכה: ח׳ נרות": "חנוכה 7️⃣",
        "חנוכה: יום ח׳": "חנוכה 8️⃣",
    ]

    // Two-line stack abbreviations (graphic circular, modular small, etc.).
    // nil means "the full name fits, no abbreviation needed".
    static let month: [String: String?] = [
        "Adar": nil,
        "Adar I": "Adar1",
        "Adar II": "Adar2",
        "Av": nil,
        "Cheshvan": "Chesh",
        "Elul": nil,
        "Iyyar": "Iyar",
        "Kislev": nil,
        "Nisan": nil,
        "Sh'vat": "Shvat",
        "Sivan": nil,
        "Tamuz": nil,
        "Tevet": nil,
        "Tishrei": "Tishr",
        // ashk
        "Teves": nil,
    ]

    // Tighter abbreviations used by the extra-large equivalent
    // (now: same fallback when even the short form is too wide).
    static let monthTiny: [String: String] = [
        "Adar": "Adar",
        "Adar I": "Ad 1",
        "Adar II": "Ad 2",
        "Av": "Av",
        "Cheshvan": "Chsh",
        "Elul": "Elul",
        "Iyyar": "Iyar",
        "Kislev": "Kis",
        "Nisan": "Nis",
        "Sh'vat": "Shvt",
        "Sivan": "Siv",
        "Tamuz": "Tam",
        "Tevet": "Tev",
        "Tishrei": "Tish",
        // ashk
        "Teves": "Tev",
    ]

    static let parshaHyphenation: [String: [String]?] = [
        "Achrei Mot": nil,
        "Balak": nil,
        "Bamidbar": ["Bamid", "bar"],
        "Bechukotai": ["Bechu", "kotai"],
        "Beha'alotcha": ["Behaa", "lotcha"],
        "Behar": nil,
        "Bereshit": ["Bere-", "sheet"],
        "Beshalach": ["Besha", "lach"],
        "Bo": nil,
        "Chayei Sara": nil,
        "Chukat": nil,
        "Devarim": ["Deva-", "rim"],
        "Eikev": nil,
        "Emor": nil,
        "Ha'azinu": ["Ha’", "azinu"],
        "Kedoshim": ["Kedo-", "shim"],
        "Ki Tavo": nil,
        "Ki Teitzei": nil,
        "Ki Tisa": nil,
        "Korach": nil,
        "Lech-Lecha": nil,
        "Masei": nil,
        "Matot": nil,
        "Metzora": ["Metz-", "ora"],
        "Miketz": ["Mi-", "ketz"],
        "Mishpatim": ["Mish-", "patim"],
        "Nasso": nil,
        "Nitzavim": ["Nitz-", "avim"],
        "Noach": nil,
        "Pekudei": ["Peku-", "dei"],
        "Pinchas": ["Pin-", "chas"],
        "Re'eh": nil,
        "Sh'lach": nil,
        "Shemot": nil,
        "Shmini": nil,
        "Shoftim": ["Shof-", "tim"],
        "Tazria": nil,
        "Terumah": ["Teru-", "mah"],
        "Tetzaveh": ["Tet-", "zaveh"],
        "Toldot": ["Tol-", "dot"],
        "Tzav": nil,
        "Vaera": nil,
        "Vaetchanan": ["Vaet-", "chanan"],
        "Vayakhel": ["Vaya-", "khel"],
        "Vayechi": nil,
        "Vayeilech": ["Vayei", "lech"],
        "Vayera": nil,
        "Vayeshev": ["Vaye-", "shev"],
        "Vayetzei": ["Vaye-", "tzei"],
        "Vayigash": ["Vayi-", "gash"],
        "Vayikra": ["Vayi-", "kra"],
        "Vayishlach": ["Vayish", "lach"],
        "Yitro": nil,
        // ashk
        "Bechukosai": ["Bechu", "kosai"],
        "Beha'aloscha": ["Behaa", "loscha"],
        "Bereshis": ["Bere-", "shis"],
        "Chukas": nil,
        "Shemos": nil,
        "Toldos": ["Tol-", "dos"],
        "Vaeschanan": ["Vaes-", "chanan"],
        "Yisro": nil,
    ]

    /// Two-word Hebrew parsha names narrow enough to stay on one line,
    /// no wider than the widest one-word names such as "בהעלתך".
    static let parshaOneLine: Set<String> = [
        "כי תשא",
        "כי־תצא",
        "לך־לך",
        "שלח־לך",
    ]

    private static let splitDelimiters: [Character] = ["-", "־", " "] // dash, maqaf, space

    /// Splits a parsha (or holiday) name into one or two lines for stacked
    /// layouts: at the first dash, maqaf or space if there is one, otherwise
    /// at the hyphenation point in `parshaHyphenation`. Names in
    /// `parshaOneLine` aren't split.
    static func splitParsha(_ parsha: String) -> [String] {
        if parshaOneLine.contains(parsha) {
            return [parsha]
        }
        for delim in splitDelimiters {
            if let idx = parsha.firstIndex(of: delim) {
                return [String(parsha[..<idx]), String(parsha[parsha.index(after: idx)...])]
            }
        }
        if let pair = parshaHyphenation[tableKey(parsha)] ?? nil {
            return pair
        }
        return [parsha]
    }
}
