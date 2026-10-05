//
//  ParshaWidgetViews.swift
//  HebcalHDate Widgets
//
//  Views for ParshaWidget (circular / inline). More circular previews,
//  one per layout and language, are in ParshaCircularPreviews.swift.
//

import SwiftUI
import WidgetKit
import HebcalWatchCore

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

// MARK: - Container view

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
// Oct 7, 2026 = 26 Tishrei 5787, an ordinary day: the upcoming parsha.
#Preview("Oct 7, 2026 — Parsha Circular", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    HebcalProvider.entry(for: previewNoon(year: 2026, month: 10, day: 7))
}

// Sep 21, 2026 is Yom Kippur (a holiday, not Shabbat): shows the holiday,
// not the upcoming "Parashat Sukkot".
#Preview("Yom Kippur — Sep 21, 2026", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    HebcalProvider.entry(for: previewNoon(year: 2026, month: 9, day: 21))
}
#endif
