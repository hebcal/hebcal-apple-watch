//
//  HDateList.swift
//  HebcalHDate WatchKit App
//
//  Created by Michael Radwin on 9/5/21.
//

import SwiftUI
import HebcalWatchCore

struct HDateList: View {
    @EnvironmentObject var modelData: ModelData

    var body: some View {
        List(modelData.dateItems) { item in
            // Only rows with more to show are tappable.
            if let detail = item.detail {
                NavigationLink(value: detail) {
                    TodayView(item: item, showsChevron: true)
                }
            } else {
                TodayView(item: item)
            }
        }
        .navigationTitle("Calendar")
    }
}

#Preview {
    NavigationStack {
        HDateList()
            .navigationDestination(for: DateItemDetail.self) { detail in
                DateItemDetailView(detail: detail)
            }
    }
    .environmentObject(ModelData.shared)
}
