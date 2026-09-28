//
//  HebcalHDateApp.swift
//  HebcalHDate WatchKit App
//
//  Created by Michael Radwin on 8/17/21.
//

import SwiftUI

@main
struct HebcalHDateApp: App {
    @WKApplicationDelegateAdaptor private var appDelegate: ExtensionDelegate

    @StateObject private var modelData = ModelData.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(modelData)
        }
    }
}
