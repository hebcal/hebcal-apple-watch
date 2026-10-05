//
//  ParshaCircularPreviews.swift
//  HebcalHDate Widgets
//
//  A few Parsha circular previews, about one per layout. Kept out of
//  ParshaWidgetViews.swift so editing the view doesn't re-render them all.
//  The golden files (Snapshots/parsha-circular-*.md) cover every day of
//  the year; these are only for eyeballing the rendering.
//

import SwiftUI
import WidgetKit

#if DEBUG
// Two lines: long ones shrink to fit the width without clipping.
#Preview("Parsha circular Nitzavim-Vayeilech", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    parshaPreview(2026, 9, 2)
}

// One-word parsha with the Torah icon below.
#Preview("Parsha circular Noach", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    parshaPreview(2026, 10, 15)
}

// A one-word holiday with its emoji below.
#Preview("Parsha circular Purim", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    parshaPreview(2027, 3, 23)
}

// Large emoji above one line: "🕎" / "ד׳".
#Preview("Parsha circular Chanukah day 4 (he)", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    parshaPreview(2026, 12, 8, lang: .he)
}

// Shabbat Shuva on Shabbat itself: shows the weekly parsha (Ha'azinu),
// not the special Shabbat name.
#Preview("Parsha circular Shabbat Shuva", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    parshaPreview(2026, 9, 19)
}

// An Israeli modern holiday (Israel schedule only).
#Preview("Parsha circular Yom HaAtzma'ut (he, Israel)", as: .accessoryCircular) {
    ParshaWidget()
} timeline: {
    parshaPreview(2027, 5, 12, lang: .he, il: true)
}
#endif
