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

    var langFooter: String {
        switch modelData.settings.lang {
        case .en: return "e.g. “Sukkot”"
        case .ashkenazi: return "e.g. “Sukkos”"
        case .he: return "e.g. \"סוכות\""
        default: return ""
        }
    }

    var ilFooter: LocalizedStringKey {
        modelData.settings.il
            ? "Holidays and Torah readings follow the Israel schedule."
            : "Holidays and Torah readings follow the Diaspora schedule."
    }

    var locationFooter: LocalizedStringKey {
        if modelData.locationManager.isDenied {
            return "Location access is off for Hebcal. Turn it on in the Settings app under Privacy & Security › Location Services."
        }
        return modelData.settings.useLocation
            ? "Hebrew date changes at sunset; candle-lighting and Havdalah times are shown."
            : "For sunset, candle-lighting and Havdalah times. Otherwise the Hebrew date changes at 8 PM."
    }

    var body: some View {
        Form {
            Section {
                Picker("Language", selection: $modelData.settings.lang) {
                    Text("Sephardic").tag(TranslationLang.en)
                    Text("Ashkenazi").tag(TranslationLang.ashkenazi)
                    Text("Hebrew").tag(TranslationLang.he)
                }
            } footer: {
                Text(langFooter)
            }
            Section {
                Toggle("Use Location", isOn: $modelData.settings.useLocation)
                if modelData.settings.useLocation {
                    NavigationLink(value: Screen.zmanim) {
                        Label("Zmanim", systemImage: "sunset")
                    }
                }
            } footer: {
                Text(locationFooter)
            }
            Section {
                Toggle("Israel", isOn: Binding(get: { modelData.settings.il },
                                               set: { modelData.setIsrael($0) }))
            } footer: {
                Text(ilFooter)
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
