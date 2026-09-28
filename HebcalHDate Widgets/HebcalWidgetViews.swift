//
//  HebcalWidgetViews.swift
//  HebcalHDate Widgets
//
//  SwiftUI views for each accessory family. The big design goals carried
//  forward from the ClockKit version:
//    * Circular face shows day-on-top, month-below.
//    * Corner face has the month near the inside and the day curving
//      along the outer edge.
//    * Inline mirrors the old utilitarianSmallFlat / utilitarianLargeFlat
//      strings.
//    * Rectangular mirrors the old graphic-rectangular three-line body.
//

import SwiftUI
import WidgetKit
import Hebcal
import HebcalWatchCore

private let goldTint = Color(red: 1.0, green: 0.75, blue: 0.0)

// MARK: - Hebrew date

/// Accessory circular: big day number, gold month below. Adapted from
/// the legacy HDateTextView so the typography matches what users see
/// today.
struct HDateCircularView: View {
    @Environment(\.widgetRenderingMode) private var renderingMode

    let entry: HebcalEntry

    @ScaledMetric private var monthNameFontSize: CGFloat = 12
    private var dayFontSize: CGFloat {
        if entry.hebDayNumber.hasSuffix("׳") { return 30 }
        return entry.hebDayNumber.count == 1 ? 27.5 : 23
    }

    var body: some View {
        ZStack {
            if renderingMode == .fullColor {
                Circle().fill(Color(red: 0.11, green: 0.10, blue: 0.08))
            }
            VStack(spacing: 0) {
                Text(entry.hebDayNumber)
                    .offset(x: 0, y: -2)
                    .foregroundColor(.white)
                    .font(.system(size: dayFontSize, weight: .semibold))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(entry.hebMonthAbbrev)
                    .offset(x: 0, y: -5)
                    .foregroundColor(goldTint)
                    .font(.system(size: monthNameFontSize, weight: .semibold))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
            .widgetAccentable()
        }
    }
}

/// Accessory corner: large day number near the centre with the month
/// curving along the bezel via `.widgetLabel`.
struct HDateCornerView: View {
    let entry: HebcalEntry

    var body: some View {
        Text(entry.hebDayNumber)
            .widgetCurvesContent()
            .foregroundColor(.white)
            .lineLimit(1)
            .widgetLabel {
                Text(entry.hebMonthName)
                    .foregroundColor(goldTint)
            }
    }
}

/// Accessory rectangular: up to four lines, each shown only when relevant:
///   * header — Hebrew date (+ holiday emoji), shortened via ViewThatFits
///   * holiday — today's holiday, long or abbreviated name
///   * parsha — Torah icon + this week's parsha; when there's neither a
///     parsha nor a holiday today, the upcoming Shabbat holiday instead
///   * omer — the Omer count during the Omer period
struct HebcalRectangularView: View {
    let entry: HebcalEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Drop the year, then abbreviate the month, before
            // minimumScaleFactor shrinks the text.
            ViewThatFits(in: .horizontal) {
                Text(entry.richHeaderLong)
                Text(entry.richHeaderShort)
                Text(entry.richHeaderAbbrev)
            }
            .font(.headline)
            .foregroundColor(.primary)
            .widgetAccentable()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            if let holiday = entry.richHoliday {
                ViewThatFits(in: .horizontal) {
                    Text(holiday)
                    Text(entry.richHolidayShort ?? holiday)
                }
                .foregroundColor(.yellow)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            }
            // This week's parsha; when there's neither a parsha nor a holiday,
            // the holiday that replaces the upcoming Shabbat's reading.
            if let parsha = entry.parshaName ?? (entry.richHoliday == nil ? entry.parshaForFallback : nil) {
                HStack {
                    Image("torah-235339")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                    Text(parsha)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .foregroundColor(goldTint)
                }
            }
            if let omer = entry.omerToday {
                Text(omer)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Parsha

/// Accessory circular for Torah portion: 1 or 2 stacked lines. Which
/// layout is used is decided (and unit-tested) in ParshaCircularLayout.
struct ParshaCircularView: View {
    let entry: HebcalEntry
    // Starting sizes; minimumScaleFactor shrinks long names to fit the circle.
    @ScaledMetric private var holidayFontSize: CGFloat = 24
    @ScaledMetric private var singleLineFontSize: CGFloat = 17
    // Two-line sizes as fractions of the circle's diameter, so they suit
    // every watch size: the largest font (short lines like "Ki" or "ד׳"),
    // and the inset that keeps long lines clear of the circle's edges.
    private let twoLineFontFraction: CGFloat = 0.34
    private let twoLineInsetFraction: CGFloat = 0.17
    private let emojiAboveFontFraction: CGFloat = 0.34
    @ScaledMetric private var emojiFontSize: CGFloat = 13

    var body: some View {
        switch ParshaCircularLayout(entry: entry) {
        case let .twoLines(first, second):
            // Each line is sized on its own, so a short one such as "ד׳"
            // under "חנוכה" stays large while only a long one shrinks.
            GeometryReader { geometry in
                let diameter = min(geometry.size.width, geometry.size.height)
                VStack(spacing: 0) {
                    fittedLine(first, diameter: diameter, alignment: .bottom)
                    fittedLine(second, diameter: diameter, alignment: .top)
                }
            }
            .widgetAccentable()
        case let .emojiAbove(emoji, text):
            GeometryReader { geometry in
                let diameter = min(geometry.size.width, geometry.size.height)
                VStack(spacing: 0) {
                    Text(emoji)
                        .font(.system(size: diameter * emojiAboveFontFraction))
                        .lineLimit(1)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                    fittedLine(text, diameter: diameter, alignment: .top)
                        .widgetAccentable()
                }
            }
        case let .holiday(name):
            // Today is itself a one-word holiday (e.g. "Y.K."): show just its
            // name, with no Torah icon (it isn't a Shabbat Torah reading).
            Text(name)
                .font(.system(size: holidayFontSize, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.3)
                .padding(.horizontal, 2)
                .widgetAccentable()
        case let .holidayWithEmoji(name, emoji):
            // Like a one-line parsha, with the holiday's emoji for the icon.
            VStack(spacing: 1) {
                Text(name)
                    .font(.system(size: singleLineFontSize, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
                    .padding(.horizontal, 5)
                    .widgetAccentable()
                Text(emoji)
                    .font(.system(size: emojiFontSize))
                    .lineLimit(1)
            }
        case let .parsha(name):
            // Single-line parsha: fill the second line with a Torah icon
            VStack(spacing: 1) {
                // The text sits above the circle's center, where the circular
                // mask is narrower, so inset it to keep long names like
                // "Vayechi" from being clipped at the edges.
                Text(name)
                    .font(.system(size: singleLineFontSize, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
                    .padding(.horizontal, 5)
                Image("torah-235339")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
            }
            .widgetAccentable()
        }
    }

    /// One of two stacked lines, sized on its own: as large as fits the
    /// width, up to twoLineFontFraction of the circle. Aligned toward the
    /// center, where the circle is widest, and inset so its edges don't
    /// clip long lines such as "Vayeilech" or a large "Purim".
    private func fittedLine(_ text: String, diameter: CGFloat, alignment: Alignment) -> some View {
        Text(text)
            .font(.system(size: diameter * twoLineFontFraction, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.3)
            .padding(.horizontal, diameter * twoLineInsetFraction)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    }
}

// MARK: - Container views

struct HebcalWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: HebcalEntry

    @ViewBuilder
    var body: some View {
        switch family {
        case .accessoryRectangular:
            HebcalRectangularView(entry: entry)
        case .accessoryInline:
            // Progressively shorten the date; the parsha/holiday is kept
            // whole. If even the tiniest month doesn't fit, ViewThatFits
            // falls back to its last child, so repeat the un-abbreviated
            // month there and let the system truncate the parsha instead.
            ViewThatFits(in: .horizontal) {
                Text(entry.inlineText)
                Text(entry.inlineAbbrevText)
                Text(entry.inlineTinyText)
                Text(entry.inlineText)
            }
        default:
            // The Hebcal widget only declares rectangular+inline, but
            // be defensive for forward-compat.
            Text(entry.hebDateShort)
        }
    }
}

struct HDateWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: HebcalEntry

    @ViewBuilder
    var body: some View {
        switch family {
        case .accessoryCircular:
            HDateCircularView(entry: entry)
        case .accessoryCorner:
            HDateCornerView(entry: entry)
        case .accessoryInline:
            ViewThatFits(in: .horizontal) {
                Text(entry.hebDateLong)
                Text(entry.hebDateShort)
            }
        default:
            Text(entry.hebDateShort)
        }
    }
}

struct ParshaWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: HebcalEntry

    @ViewBuilder
    var body: some View {
        switch family {
        case .accessoryCircular:
            ParshaCircularView(entry: entry)
        case .accessoryInline:
            ViewThatFits(in: .horizontal) {
                Text(entry.parshaPrefixed) // "Parashat Ha’azinu", or "Yom Kippur" on a holiday
                Text(entry.parshaShort)    // "Ha’azinu", or "Y.K."
            }
        default:
            Text(entry.parshaParts.first ?? "")
        }
    }
}

// MARK: - Previews

#if DEBUG
/// Noon local time on the given Gregorian date, so `makeHDate`'s 8pm
/// day-rollover never pushes the preview onto the next Hebrew day.
private func previewNoon(year: Int, month: Int, day: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.hour = 12
    return Calendar(identifier: .gregorian).date(from: components)!
}

// Compares the ParshaCircularView fix directly: Sep 21, 2026 is Yom Kippur
// (a holiday, not Shabbat) and used to wrongly show the upcoming
// "Parashat Sukkot"; Sep 22 is an ordinary day between Yom Kippur and
// Sukkot and still correctly shows the upcoming weekly parsha.
#Preview("Yom Kippur — Sep 21, 2026", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    HebcalProvider.entry(for: previewNoon(year: 2026, month: 9, day: 21))
}

#Preview("YK — Rectangular", as: .accessoryRectangular) {
    HebcalWidget()
} timeline: {
    HebcalProvider.entry(for: previewNoon(year: 2026, month: 9, day: 21))
}

#Preview("RCh Chanukah weekday — Rectangular", as: .accessoryRectangular) {
    HebcalWidget()
} timeline: {
    HebcalProvider.entry(for: previewNoon(year: 2026, month: 12, day: 10))
}

#Preview("Pesach VI (CH’’M) — Rectangular", as: .accessoryRectangular) {
    HebcalWidget()
} timeline: {
    HebcalProvider.entry(for: previewNoon(year: 2027, month: 4, day: 27))
}

#Preview("Day after — Sep 22, 2026", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    HebcalProvider.entry(for: previewNoon(year: 2026, month: 9, day: 22))
}

// Oct 7, 2026 = 26 Tishrei 5787, an ordinary day just after Sukkot/Simchat
// Torah — exercises the other two widgets' non-holiday rendering.
#Preview("Oct 7, 2026 — Rectangular", as: .accessoryRectangular) {
    HebcalWidget()
} timeline: {
    HebcalProvider.entry(for: previewNoon(year: 2026, month: 10, day: 7))
}

#Preview("Oct 7, 2026 — Inline", as: .accessoryInline) {
    HebcalWidget()
} timeline: {
    HebcalProvider.entry(for: previewNoon(year: 2026, month: 10, day: 7))
}

#Preview("Oct 7, 2026 — HDate Circular", as: .accessoryCircular) {
    HDateWidget()
} timeline: {
    HebcalProvider.entry(for: previewNoon(year: 2026, month: 10, day: 7))
}

#Preview("Oct 7, 2026 — HDate Corner", as: .accessoryCorner) {
    HDateWidget()
} timeline: {
    HebcalProvider.entry(for: previewNoon(year: 2026, month: 10, day: 7))
}

#Preview("Oct 7, 2026 — HDate Inline", as: .accessoryInline) {
    HDateWidget()
} timeline: {
    HebcalProvider.entry(for: previewNoon(year: 2026, month: 10, day: 7))
}

#Preview("Oct 7, 2026 — Parsha Circular", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    HebcalProvider.entry(for: previewNoon(year: 2026, month: 10, day: 7))
}

#Preview("Parsha circular Noach", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    HebcalProvider.entry(for: previewNoon(year: 2026, month: 10, day: 15))
}

#Preview("Parsha circular Vayechi", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    HebcalProvider.entry(for: previewNoon(year: 2026, month: 12, day: 25))
}

// Parsha names with an apostrophe, which Sedra returns as ’ and which
// must still match parshaHyphenate. The June dates assume the Diaspora
// schedule; in Israel those weeks are Sh'lach and Korach instead.
#Preview("Parsha circular Beha'alotcha (Diaspora)", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    HebcalProvider.entry(for: previewNoon(year: 2026, month: 6, day: 3))
}

#Preview("Parsha circular Sh'lach (Diaspora)", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    HebcalProvider.entry(for: previewNoon(year: 2026, month: 6, day: 10))
}

#Preview("Parsha circular Ha'azinu", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    HebcalProvider.entry(for: previewNoon(year: 2026, month: 9, day: 16))
}

// Shabbat Shuva on Shabbat itself: shows the weekly parsha (Ha'azinu),
// not the special Shabbat name.
#Preview("Parsha circular Shabbat Shuva", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    HebcalProvider.entry(for: previewNoon(year: 2026, month: 9, day: 19))
}

#Preview("Shabbat Shuva — Inline", as: .accessoryInline) {
    HebcalWidget()
} timeline: {
    HebcalProvider.entry(for: previewNoon(year: 2026, month: 9, day: 19))
}

// Rosh Chodesh Kislev on a weekday (Wed Nov 11, 2026): shows the holiday.
#Preview("Parsha circular Rosh Chodesh weekday", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    HebcalProvider.entry(for: previewNoon(year: 2026, month: 11, day: 11))
}

#Preview("Parsha circular Erev Purim", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    HebcalProvider.entry(for: previewNoon(year: 2027, month: 3, day: 22))
}


#Preview("Parsha circular Purim", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    HebcalProvider.entry(for: previewNoon(year: 2027, month: 3, day: 23))
}

#Preview("Parsha circular Shushan Purim", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    HebcalProvider.entry(for: previewNoon(year: 2027, month: 3, day: 24))
}

// MARK: Parsha circular, one per layout and language
//
// These pass explicit settings rather than the saved ones, so Hebrew and
// Israel cases can be previewed side by side. Every date is also a row in
// the golden files (Snapshots/parsha-circular-*.md).

private func parshaPreview(_ year: Int, _ month: Int, _ day: Int,
                           lang: TranslationLang = .en, il: Bool = false) -> HebcalEntry {
    HebcalProvider.entry(for: previewNoon(year: year, month: month, day: day),
                         settings: HebcalSettings(il: il, lang: lang))
}

// The week before Rosh Hashana: abbreviated, with the Torah icon below.
#Preview("Parsha circular R.H. week", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    parshaPreview(2026, 9, 7)
}

#Preview("Parsha circular R.H. week (he)", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    parshaPreview(2026, 9, 7, lang: .he)
}

#Preview("Parsha circular Pesach week", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    parshaPreview(2027, 4, 18)
}

// A one-word holiday with an emoji; Y.K. has none, so it stays large text.
#Preview("Parsha circular Purim", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    parshaPreview(2027, 3, 23)
}

#Preview("Parsha circular Purim (he)", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    parshaPreview(2027, 3, 23, lang: .he)
}

#Preview("Parsha circular Y.K. (he)", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    parshaPreview(2026, 9, 21, lang: .he)
}

// Chanukah day 4: "🕎" / "Day 4️⃣" and "חנוכה" / "ד׳".
#Preview("Parsha circular Chanukah day 4", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    parshaPreview(2026, 12, 8)
}

#Preview("Parsha circular Chanukah day 4 (he)", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    parshaPreview(2026, 12, 8, lang: .he)
}

// The same abbreviation on one line: "28 Kislev · 🕎 Day 4️⃣".
#Preview("Hebcal inline Chanukah day 4", as: .accessoryInline) {
    HebcalWidget()
} timeline: {
    parshaPreview(2026, 12, 8)
}

#Preview("Hebcal inline Chanukah day 4 (he)", as: .accessoryInline) {
    HebcalWidget()
} timeline: {
    parshaPreview(2026, 12, 8, lang: .he)
}

// Two-word Hebrew parshiyot short enough for one line (parshaOneLine).
#Preview("Parsha circular Lech-Lecha (he)", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    parshaPreview(2026, 10, 19, lang: .he)
}

#Preview("Parsha circular Ki Tisa (he)", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    parshaPreview(2027, 2, 23, lang: .he)
}

#Preview("Parsha circular Sh'lach 2027", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    parshaPreview(2027, 6, 28)
}

#Preview("Parsha circular Bereshit (he)", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    parshaPreview(2026, 10, 5, lang: .he)
}

// Two short lines, each as large as fits half the circle.
#Preview("Parsha circular Tu B'Av (he)", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    parshaPreview(2027, 8, 18, lang: .he)
}

#Preview("Parsha circular Tish'a B'Av", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    parshaPreview(2027, 8, 12)
}

#Preview("Parsha circular Lag BaOmer (he)", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    parshaPreview(2027, 5, 25, lang: .he)
}

// Long lines, which shrink to fit the width without clipping.
#Preview("Parsha circular Nitzavim-Vayeilech", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    parshaPreview(2026, 9, 2)
}

#Preview("Parsha circular Shushan Purim", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    parshaPreview(2027, 3, 24)
}

#Preview("Parsha circular R.Ch. Kislev (he)", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    parshaPreview(2026, 11, 11, lang: .he)
}

// Israeli modern holidays (Israel schedule only). Long names like the Yom
// HaAliyah School Observance and Rabin Memorial Day shrink to fit; the
// civic days have no nikud in Hebrew once hebcal-swift 425ef8f is in.
#Preview("Parsha circular Yom HaAliyah School Observance (Israel)", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    parshaPreview(2026, 10, 18, lang: .en, il: true)
}

#Preview("Parsha circular Yom HaAliyah School Observance (he, Israel)", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    parshaPreview(2026, 10, 18, lang: .he, il: true)
}

#Preview("Parsha circular Rabin Memorial Day (Israel)", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    parshaPreview(2026, 10, 22, lang: .en, il: true)
}

#Preview("Parsha circular Rabin Memorial Day (he, Israel)", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    parshaPreview(2026, 10, 22, lang: .he, il: true)
}

#Preview("Parsha circular Sigd (Israel)", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    parshaPreview(2026, 11, 9, lang: .en, il: true)
}

#Preview("Parsha circular Sigd (he, Israel)", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    parshaPreview(2026, 11, 9, lang: .he, il: true)
}

#Preview("Parsha circular Family Day (Israel)", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    parshaPreview(2027, 2, 7, lang: .en, il: true)
}

#Preview("Parsha circular Family Day (he, Israel)", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    parshaPreview(2027, 2, 7, lang: .he, il: true)
}

#Preview("Parsha circular Yom HaShoah (Israel)", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    parshaPreview(2027, 5, 4, lang: .en, il: true)
}

#Preview("Parsha circular Yom HaShoah (he, Israel)", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    parshaPreview(2027, 5, 4, lang: .he, il: true)
}

#Preview("Parsha circular Yom HaZikaron (Israel)", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    parshaPreview(2027, 5, 11, lang: .en, il: true)
}

#Preview("Parsha circular Yom HaZikaron (he, Israel)", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    parshaPreview(2027, 5, 11, lang: .he, il: true)
}

#Preview("Parsha circular Yom HaAtzma'ut (Israel)", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    parshaPreview(2027, 5, 12, lang: .en, il: true)
}

#Preview("Parsha circular Yom HaAtzma'ut (he, Israel)", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    parshaPreview(2027, 5, 12, lang: .he, il: true)
}

#Preview("Parsha circular Herzl Day (Israel)", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    parshaPreview(2027, 5, 17, lang: .en, il: true)
}

#Preview("Parsha circular Herzl Day (he, Israel)", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    parshaPreview(2027, 5, 17, lang: .he, il: true)
}

#Preview("Parsha circular Yom Yerushalayim (Israel)", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    parshaPreview(2027, 6, 4, lang: .en, il: true)
}

#Preview("Parsha circular Yom Yerushalayim (he, Israel)", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    parshaPreview(2027, 6, 4, lang: .he, il: true)
}

#Preview("Parsha circular Jabotinsky Day (Israel)", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    parshaPreview(2027, 8, 3, lang: .en, il: true)
}

#Preview("Parsha circular Jabotinsky Day (he, Israel)", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    parshaPreview(2027, 8, 3, lang: .he, il: true)
}
#endif
