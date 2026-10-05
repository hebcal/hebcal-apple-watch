//
//  HDateWidgetViews.swift
//  HebcalHDate Widgets
//
//  Views for HDateWidget (circular / corner / inline). Design goals
//  carried forward from the ClockKit version:
//    * Circular face shows day-on-top, month-below.
//    * Corner face has the month near the inside and the day curving
//      along the outer edge.
//

import SwiftUI
import WidgetKit
import HebcalWatchCore

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

// MARK: - Container view

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

// MARK: - Previews

#if DEBUG
// Oct 7, 2026 = 26 Tishrei 5787, an ordinary day just after Sukkot/Simchat
// Torah.
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
#endif
