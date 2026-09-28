//
//  SettingsView.swift
//  HebcalHDate WatchKit App
//
//  Created by Michael Radwin on 9/6/21.
//

import SwiftUI
import Hebcal

struct SettingsView: View {
    @EnvironmentObject var modelData: ModelData

    var langDescription: String {
        switch modelData.settings.lang {
        case .en: return "e.g. “Sukkot”"
        case .ashkenazi: return "e.g. “Sukkos”"
        case .he: return "e.g. \"סוכות\""
        default: return ""
        }
    }

    var ilDescription: LocalizedStringKey {
        modelData.settings.il ? "Israel schedule" : "Diaspora schedule"
    }

    var body: some View {
        Form {
            Section {
                Picker("Language", selection: $modelData.settings.lang) {
                    Text("Sephardic").tag(TranslationLang.en)
                    Text("Ashkenazi").tag(TranslationLang.ashkenazi)
                    Text("Hebrew").tag(TranslationLang.he)
                }
            } header: {
                Text(langDescription).textCase(.none)
            }
            Section {
                Toggle("Israel", isOn: $modelData.settings.il)
            } header: {
                Text(ilDescription).textCase(.none)
            }
            Section {
                Toggle("Daf Yomi", isOn: $modelData.settings.dafyomi)
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    SettingsView()
        .environmentObject(ModelData.shared)
        .environment(\.locale, .init(identifier: "he"))
}
