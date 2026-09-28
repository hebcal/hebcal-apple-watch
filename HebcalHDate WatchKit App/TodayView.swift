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
    var gregDate: String {
        var s = item.dow + ", " + String(item.gregDay) + " " + item.gregMonth
        if item.gregYear != 0 {
            s += " " + String(item.gregYear)
        }
        if let emoji = item.emoji {
            s += "  " + emoji
        }
        return s
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
                Text(gregDate)
                    .foregroundColor(.secondary)
                    .font(.system(size: smallFontSize, weight: .regular, design: .default))
                    .lineLimit(1)
                Text(item.hdate)
                    .foregroundColor(.white)
                    .font(.system(size: largeFontSize, weight: .regular, design: .default))
                    .lineLimit(1)
                ForEach(item.holidays, id: \.self) { holiday in
                    Text(holiday)
                        .foregroundColor(.yellow)
                        .font(.system(size: largeFontSize, weight: .regular, design: .default))
                        .lineLimit(holiday.count > 19 ? 2 : 1)
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

#Preview("Omer row", traits: .fixedLayout(width: 300, height: 150)) {
    let date = Calendar.current.date(from: DateComponents(year: 2027, month: 5, day: 10, hour: 12))!
    TodayView(item: HebcalFormatter(settings: HebcalSettings(lang: .en))
        .dateItem(for: date, calendar: .current, now: date, showYear: false, forceParsha: false),
              showsChevron: true)
}
