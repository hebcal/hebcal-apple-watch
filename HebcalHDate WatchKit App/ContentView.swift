//
//  ContentView.swift
//  HebcalHDate WatchKit App
//
//  Created by Michael Radwin on 8/17/21.
//

import SwiftUI
import os

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var modelData: ModelData

    var body: some View {
        NavigationStack {
            List {
                NavigationLink(destination: HDateList()) {
                    TodayView(item: modelData.todayDateItem)
                }
                NavigationLink(destination: SettingsView()) {
                    Label("Settings", systemImage: "gear")
                }
            }
            .navigationTitle("Hebcal")
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .inactive:
                Logger.app.debug("Scene became inactive.")
            case .active:
                Logger.app.debug("Scene became active.")
                modelData.updateDateItems()
            case .background:
                Logger.app.debug("Scene moved to the background.")
                // Schedule a background refresh task
                // to update the complications.
                scheduleBackgroundRefreshTasks()
            @unknown default:
                Logger.app.debug("Scene entered unknown state.")
                assertionFailure()
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ModelData.shared)
        .environment(\.locale, .init(identifier: "he"))
}
