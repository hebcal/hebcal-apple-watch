//
//  ContentView.swift
//  HebcalHDate WatchKit App
//
//  Created by Michael Radwin on 8/17/21.
//

import SwiftUI
import HebcalWatchCore
import os

/// Screens pushed from the main screen. Every link in the stack is
/// value-based: a `NavigationLink(value:)` inside a screen pushed with
/// `NavigationLink(destination:)` pops right back off.
enum Screen: Hashable {
    case calendar, settings, zmanim
    /// One month of the calendar, by `DateMonth.id`.
    case month(Int)
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var modelData: ModelData

    /// During the Omer, today's count gets a row of its own under Today,
    /// linking to its card.
    private var omerLink: (detail: DateItemDetail, label: String)? {
        let today = modelData.todayDateItem
        guard let omer = today.detail?.omer, let label = today.omer else {
            return nil
        }
        return (.omer(omer), label)
    }

    var body: some View {
        NavigationStack {
            List {
                NavigationLink(value: Screen.calendar) {
                    // The Omer row below already shows the count.
                    TodayView(item: modelData.todayDateItem, showsOmer: omerLink == nil)
                }
                if let omerLink {
                    NavigationLink(value: omerLink.detail) {
                        Label {
                            Text(omerLink.label)
                        } icon: {
                            Text("🌾")
                        }
                    }
                }
                NavigationLink(value: Screen.settings) {
                    Label("Settings", systemImage: "gear")
                }
            }
            .navigationTitle("Hebcal")
            .navigationDestination(for: Screen.self) { screen in
                switch screen {
                case .calendar:
                    HDateList(items: modelData.dateItems, months: modelData.dateMonths,
                              title: Text("Calendar"))
                case .month(let id):
                    // Empty if the list was rebuilt and the month has passed.
                    let month = modelData.dateMonths.first { $0.id == id }
                    HDateList(items: month?.items ?? [], title: Text(verbatim: month?.title ?? ""))
                case .settings: SettingsView()
                case .zmanim: ZmanimSettingsView()
                }
            }
            .navigationDestination(for: DateItemDetail.self) { detail in
                DateItemDetailView(detail: detail)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .inactive:
                Logger.app.debug("Scene became inactive.")
            case .active:
                Logger.app.debug("Scene became active.")
                modelData.updateDateItems()
                modelData.refreshLocation()
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
