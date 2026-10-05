//
//  HebcalWidgetViews.swift
//  HebcalHDate Widgets
//
//  Views for HebcalWidget (rectangular / inline). Design goals carried
//  forward from the ClockKit version:
//    * Inline mirrors the old utilitarianSmallFlat / utilitarianLargeFlat
//      strings.
//    * Rectangular mirrors the old graphic-rectangular three-line body.
//
//  The other widgets' views are in HDateWidgetViews.swift and
//  ParshaWidgetViews.swift.
//

import SwiftUI
import WidgetKit
import Hebcal
import HebcalWatchCore

/// Accessory rectangular: up to four lines, each shown only when relevant:
///   * header — Hebrew date (+ holiday emoji), shortened via ViewThatFits
///   * holiday — today's holiday, long or abbreviated name
///   * parsha — Torah icon + this week's parsha; when there's neither a
///     parsha nor a holiday today, the upcoming Shabbat holiday instead
///   * omer — the Omer count during the Omer period
struct HebcalRectangularView: View {
    let entry: HebcalEntry

    var body: some View {
        VStack(alignment: entry.isHebrew ? .trailing : .leading, spacing: 0) {
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
                // Hebrew: Torah icon on the right, at the leading edge.
                .environment(\.layoutDirection, entry.isHebrew ? .rightToLeft : .leftToRight)
            }
            // A candle time takes the Omer's line: there's no room for both.
            if let zman = entry.zmanim.first {
                Text("\(entry.zmanim.map(\.emoji).joined()) \(zman.time, format: .dateTime.hour().minute())")
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundColor(.orange)
            } else if let omer = entry.omerToday {
                Text(omer)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: entry.isHebrew ? .trailing : .leading)
    }
}

// MARK: - Container view

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

// MARK: - Previews

#if DEBUG
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

// Hebrew: right-aligned.
#Preview("RCh Chanukah weekday — Rectangular, Hebrew", as: .accessoryRectangular) {
    HebcalWidget()
} timeline: {
    HebcalProvider.entry(for: previewNoon(year: 2026, month: 12, day: 10), settings: HebcalSettings(lang: .he))
}

// Friday of Chanukah: Chanukah and Shabbat candles at the same time.
#Preview("Chanukah Friday candles — Rectangular", as: .accessoryRectangular) {
    HebcalWidget()
} timeline: {
    HebcalProvider.entry(for: previewNoon(year: 2026, month: 12, day: 4), settings: previewZmanimSettings)
}

// A Friday of the Omer: candle lighting takes the Omer's line.
#Preview("Omer Friday candles — Rectangular", as: .accessoryRectangular) {
    HebcalWidget()
} timeline: {
    HebcalProvider.entry(for: previewNoon(year: 2027, month: 4, day: 23), settings: previewZmanimSettings)
}

#Preview("Pesach VI (CH’’M) — Rectangular", as: .accessoryRectangular) {
    HebcalWidget()
} timeline: {
    HebcalProvider.entry(for: previewNoon(year: 2027, month: 4, day: 27))
}

// Oct 7, 2026 = 26 Tishrei 5787, an ordinary day just after Sukkot/Simchat
// Torah.
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

// Shabbat Shuva on Shabbat itself: shows the weekly parsha (Ha'azinu),
// not the special Shabbat name.
#Preview("Shabbat Shuva — Inline", as: .accessoryInline) {
    HebcalWidget()
} timeline: {
    HebcalProvider.entry(for: previewNoon(year: 2026, month: 9, day: 19))
}

// Chanukah abbreviated on one line: "28 Kislev · 🕎 Day 4️⃣".
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
#endif
