//
//  TodayView.swift
//  HebcalHDate WatchKit App
//
//  Created by Michael Radwin on 9/30/21.
//

import SwiftUI
import HebcalWatchCore

struct TodayView: View {
    @ScaledMetric private var smallFontSize: CGFloat = 16
    @ScaledMetric private var largeFontSize: CGFloat = 18
    var item: DateItem
    /// Hints that tapping the row opens a detail card.
    var showsChevron = false
    /// False when the Omer count is shown elsewhere on screen.
    var showsOmer = true
    /// `item.gregDates`, longest first, each followed by the emoji.
    var gregDates: [String] {
        item.gregDates.map { s in
            item.emoji.map { s + "  " + $0 } ?? s
        }
    }
    var isHebrew: Bool {
        item.lang == .he
    }
    private var chevron: some View {
        Image(systemName: isHebrew ? "chevron.left" : "chevron.right")
            .font(.footnote)
            .foregroundColor(.secondary)
    }
    var body: some View {
        HStack {
            if showsChevron && isHebrew {
                chevron
            }
            if isHebrew {
                Spacer()
            }
            VStack(alignment: isHebrew ? .trailing : .leading, spacing:0) {
                // The longest form that fits; the last one may still be
                // shrunk by minimumScaleFactor.
                ViewThatFits(in: .horizontal) {
                    ForEach(gregDates, id: \.self) { s in
                        Text(s)
                            .lineLimit(1)
                    }
                }
                .foregroundColor(.secondary)
                .font(.system(size: smallFontSize, weight: .regular, design: .default))
                Text(item.hdate)
                    .foregroundColor(.white)
                    .font(.system(size: largeFontSize, weight: .regular, design: .default))
                    .lineLimit(1)
                // A name of up to 19 characters ("Chanukah: 8 Candles") stays
                // on one line, shrunk by minimumScaleFactor if need be.
                // Longer ones: the full name if it fits on one line, else the
                // abbreviated one ("R.Ch. Cheshvan"), else the abbreviated one
                // wrapped. (ViewThatFits measures at full size, ignoring
                // minimumScaleFactor, so it can't make the first choice.)
                ForEach(item.holidays.indices, id: \.self) { i in
                    let holiday = item.holidays[i]
                    let short = item.holidaysShort[i]
                    Group {
                        if holiday.count <= 19 {
                            Text(holiday)
                                .lineLimit(1)
                        } else {
                            ViewThatFits(in: .horizontal) {
                                Text(holiday)
                                    .lineLimit(1)
                                if short != holiday {
                                    Text(short)
                                        .lineLimit(1)
                                }
                                Text(short)
                                    .lineLimit(2)
                            }
                        }
                    }
                    .foregroundColor(.yellow)
                    .font(.system(size: largeFontSize, weight: .regular, design: .default))
                }
                if showsOmer, let omer = item.omer {
                    Text(omer)
                        .foregroundColor(.secondary)
                        .font(.system(size: smallFontSize, weight: .regular, design: .default))
                        .lineLimit(1)
                }
                if let parsha = item.parsha {
                    HStack {
                        Image("torah-235339")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                        Text(parsha)
                            .foregroundColor(Color(red: 1.0, green: 0.75, blue: 0.0))
                            .font(.system(size: largeFontSize, weight: .regular, design: .default))
                            .lineLimit(1)
                    }
                }
                if let dafyomi = item.dafyomi {
                    Text(dafyomi)
                        .foregroundColor(.secondary)
                        .font(.system(size: smallFontSize, weight: .regular, design: .default))
                        .lineLimit(1)
                }
                // Last, since they're in the evening (Havdalah comes after
                // Shabbat morning's reading). Compact: the holiday is
                // already named above, and the detail card has the titles.
                ForEach(item.zmanim, id: \.self) { zman in
                    Text("\(zman.emoji) \(zman.time, format: .dateTime.hour().minute())")
                        .foregroundColor(.orange)
                        .font(.system(size: largeFontSize, weight: .regular, design: .default))
                        .lineLimit(1)
                }
            }
            .minimumScaleFactor(0.6)
            .multilineTextAlignment(isHebrew ? .trailing : .leading)
            if showsChevron && !isHebrew {
                Spacer()
                chevron
            }
        }
    }
}


#Preview(traits: .fixedLayout(width: 300, height: 150)) {
    TodayView(item: DateItem(
        id: 1,
        lang: .en,
        dow: "Wed", gregDay: 28, gregMonth: "Apr",
        gregYear: 2021,
        hdate: "16 Iyyar 5782", parsha: "Emor",
        holidays: ["Lag BaOmer"],
        emoji: "😀",
        omer: "Omer: 31st day",
        dafyomi: "Pesachim 108"
    ))
}

#Preview("Candle lighting row", traits: .fixedLayout(width: 300, height: 150)) {
    let date = Calendar.current.date(from: DateComponents(year: 2026, month: 12, day: 4, hour: 12))!
    let settings = HebcalSettings(useLocation: true, location: GeoPoint(
        latitude: 40.71, longitude: -74.01, timeZoneIdentifier: TimeZone.current.identifier))
    TodayView(item: HebcalFormatter(settings: settings)
        .dateItem(for: date, calendar: .current, now: date, showYear: false, forceParsha: false),
              showsChevron: true)
}

#Preview("Omer row", traits: .fixedLayout(width: 300, height: 150)) {
    let date = Calendar.current.date(from: DateComponents(year: 2027, month: 5, day: 10, hour: 12))!
    TodayView(item: HebcalFormatter(settings: HebcalSettings(lang: .en))
        .dateItem(for: date, calendar: .current, now: date, showYear: false, forceParsha: false),
              showsChevron: true)
}

#Preview("Hebrew", traits: .fixedLayout(width: 300, height: 150)) {
    let date = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 12, hour: 12))!
    TodayView(item: HebcalFormatter(settings: HebcalSettings(lang: .he))
        .dateItem(for: date, calendar: .current, now: date, showYear: true, forceParsha: true),
              showsChevron: true)
}
