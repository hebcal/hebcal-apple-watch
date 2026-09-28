//
//  DateItemDetailView.swift
//  HebcalHDate WatchKit App
//
//  The card pushed when tapping a day that has more to show than fits in
//  its row: candle times (with a location), or the Omer count.
//

import SwiftUI
import Hebcal
import HebcalWatchCore

struct DateItemDetailView: View {
    var detail: DateItemDetail

    var body: some View {
        switch detail {
        case .omer(let omer):
            OmerDetailView(omer: omer)
        case .zmanim(let zmanim):
            ZmanimDetailView(zmanim: zmanim)
        }
    }
}

struct ZmanimDetailView: View {
    var zmanim: ZmanimDetail

    private var alignment: Alignment {
        zmanim.isHebrew ? .trailing : .leading
    }

    /// Sunset among the candle times, in time order: after candle lighting,
    /// before Havdalah.
    private var rows: [(emoji: String, title: String, time: Date)] {
        var rows = zmanim.events.map { (emoji: $0.emoji, title: $0.title, time: $0.time) }
        if let sunset = zmanim.sunset {
            rows.append((emoji: "🌅", title: zmanim.isHebrew ? "שקיעה" : "Sunset", time: sunset))
        }
        // Stable, so Chanukah and Shabbat candles at the same time keep their order.
        return rows.enumerated()
            .sorted { ($0.element.time, $0.offset) < ($1.element.time, $1.offset) }
            .map(\.element)
    }

    private func row(_ emoji: String, _ title: String, _ time: Date) -> some View {
        VStack(alignment: zmanim.isHebrew ? .trailing : .leading, spacing: 0) {
            Text("\(emoji) \(title)")
                .font(.footnote)
                .foregroundColor(.secondary)
            Text(time, format: .dateTime.hour().minute())
                .font(.title3)
                .foregroundColor(.orange)
        }
        .frame(maxWidth: .infinity, alignment: alignment)
    }

    private func header(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.yellow)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: alignment)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ViewThatFits(in: .horizontal) {
                    header(zmanim.title)
                    header(zmanim.shortTitle)
                }
                let rows = rows
                ForEach(rows.indices, id: \.self) { i in
                    row(rows[i].emoji, rows[i].title, rows[i].time)
                }
                if let omer = zmanim.omer {
                    NavigationLink(value: DateItemDetail.omer(omer)) {
                        Label {
                            Text(omer.title)
                        } icon: {
                            Text("🌾")
                        }
                    }
                }
            }
        }
        .navigationTitle("Zmanim")
    }
}

struct OmerDetailView: View {
    var omer: OmerDetail

    private func alignment(hebrew: Bool) -> Alignment {
        hebrew ? .trailing : .leading
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(omer.title)
                    .font(.headline)
                    .foregroundColor(.yellow)
                    .frame(maxWidth: .infinity, alignment: alignment(hebrew: omer.isHebrew))
                ForEach(omer.sections, id: \.self) { section in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(section.heading)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: alignment(hebrew: omer.isHebrew))
                        ForEach(section.lines, id: \.self) { line in
                            Text(line.text)
                                .italic(line.isTransliteration)
                                .multilineTextAlignment(line.isHebrew ? .trailing : .leading)
                                .frame(maxWidth: .infinity, alignment: alignment(hebrew: line.isHebrew))
                        }
                    }
                }
            }
        }
        .navigationTitle("Omer")
    }
}

#Preview("Zmanim") {
    let settings = HebcalSettings(useLocation: true, location: GeoPoint(
        latitude: 40.71, longitude: -74.01, timeZoneIdentifier: TimeZone.current.identifier))
    NavigationStack {
        ZmanimDetailView(zmanim: HebcalFormatter(settings: settings)
            .zmanimDetail(on: HDate(yy: 5787, mm: .KISLEV, dd: 24), calendar: .current)!)
    }
}

#Preview("English") {
    OmerDetailView(omer: HebcalFormatter(settings: HebcalSettings(lang: .en))
        .omerDetail(on: HDate(yy: 5787, mm: .IYYAR, dd: 13))!)
}

#Preview("Hebrew") {
    OmerDetailView(omer: HebcalFormatter(settings: HebcalSettings(lang: .he))
        .omerDetail(on: HDate(yy: 5787, mm: .IYYAR, dd: 13))!)
}
