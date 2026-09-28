//
//  HDateList.swift
//  HebcalHDate WatchKit App
//
//  Created by Michael Radwin on 9/5/21.
//

import SwiftUI

struct HDateList: View {
    @EnvironmentObject var modelData: ModelData

    var body: some View {
        List(modelData.dateItems) { item in
            TodayView(item: item)
        }
        .navigationTitle("Calendar")
    }
}

#Preview {
    HDateList()
        .environmentObject(ModelData.shared)
}
