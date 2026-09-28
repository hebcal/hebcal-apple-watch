//
//  DateItemDetailView.swift
//  HebcalHDate WatchKit App
//
//  The card pushed when tapping a day that has more to show than fits in
//  its row (currently only the days of the Omer).
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
        }
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

#Preview("English") {
    OmerDetailView(omer: HebcalFormatter(settings: HebcalSettings(lang: .en))
        .omerDetail(on: HDate(yy: 5787, mm: .IYYAR, dd: 13))!)
}

#Preview("Hebrew") {
    OmerDetailView(omer: HebcalFormatter(settings: HebcalSettings(lang: .he))
        .omerDetail(on: HDate(yy: 5787, mm: .IYYAR, dd: 13))!)
}
