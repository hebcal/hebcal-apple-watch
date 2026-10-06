//
//  HDateList.swift
//  HebcalHDate WatchKit App
//
//  Created by Michael Radwin on 9/5/21.
//

import SwiftUI
import HebcalWatchCore

/// A list of days, then a link to each of `months` (each another
/// `HDateList`, via `Screen.month`).
struct HDateList: View {
    var items: [DateItem]
    var months: [DateMonth] = []
    var title: Text

    var body: some View {
        List {
            ForEach(items) { item in
                // Only rows with more to show are tappable.
                if let detail = item.detail {
                    NavigationLink(value: detail) {
                        TodayView(item: item, showsChevron: true)
                    }
                } else {
                    TodayView(item: item)
                }
            }
            ForEach(months) { month in
                NavigationLink(value: Screen.month(month.id)) {
                    MonthSummaryView(month: month)
                }
            }
        }
        .navigationTitle(title)
    }
}

/// A month's row in the calendar: its name and year, the Hebrew months it
/// spans and its events' emoji, opening its days.
struct MonthSummaryView: View {
    @ScaledMetric private var smallFontSize: CGFloat = 16
    @ScaledMetric private var largeFontSize: CGFloat = 18
    var month: DateMonth

    private var isHebrew: Bool {
        month.items.first?.lang == .he
    }
    private var chevron: some View {
        Image(systemName: isHebrew ? "chevron.left" : "chevron.right")
            .font(.footnote)
            .foregroundColor(.secondary)
    }

    var body: some View {
        HStack {
            if isHebrew {
                chevron
                Spacer()
            }
            VStack(alignment: isHebrew ? .trailing : .leading, spacing: 0) {
                Text(verbatim: month.title)
                    .font(.system(size: largeFontSize, weight: .regular, design: .default))
                Text(verbatim: month.hebrewMonths)
                    .foregroundColor(.secondary)
                    .font(.system(size: smallFontSize, weight: .regular, design: .default))
                if !month.emoji.isEmpty {
                    Text(verbatim: month.emoji.joined())
                        .font(.system(size: smallFontSize, weight: .regular, design: .default))
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            if !isHebrew {
                Spacer()
                chevron
            }
        }
    }
}

#Preview {
    let modelData = ModelData.shared
    NavigationStack {
        HDateList(items: modelData.dateItems, months: modelData.dateMonths,
                  title: Text("Calendar"))
            .navigationDestination(for: DateItemDetail.self) { detail in
                DateItemDetailView(detail: detail)
            }
            .navigationDestination(for: Screen.self) { screen in
                if case .month(let id) = screen,
                   let month = modelData.dateMonths.first(where: { $0.id == id }) {
                    HDateList(items: month.items, title: Text(verbatim: month.title))
                }
            }
    }
    .environmentObject(modelData)
}
