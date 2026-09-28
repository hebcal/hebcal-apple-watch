//
//  ZmanimSettingsView.swift
//  HebcalHDate WatchKit App
//
//  Candle-lighting and Havdalah options, one level below Settings (only
//  reachable while "Use Location" is on).
//

import SwiftUI
import HebcalWatchCore

struct ZmanimSettingsView: View {
    @EnvironmentObject var modelData: ModelData

    private static let candleLightingChoices = [15, 18, 20, 22, 24, 30, 40]
    private static let havdalahChoices: [HavdalahSetting] = [
        .degrees(8.5), .degrees(7.083), .minutes(42), .minutes(50), .minutes(72),
    ]

    private var settings: HebcalSettings { modelData.settings }

    /// The custom where the user is, shown as the "Automatic" choice.
    private var automaticMinutes: Int? {
        settings.location?.defaultCandleLightingMinutes
    }

    /// The standard choices, plus the current one if it's something else
    /// (e.g. set in an earlier version).
    private var candleLightingChoices: [Int] {
        var choices = Self.candleLightingChoices
        if let current = settings.candleLightingMinutes, !choices.contains(current) {
            choices.append(current)
            choices.sort()
        }
        return choices
    }

    private var havdalahChoices: [HavdalahSetting] {
        Self.havdalahChoices.contains(settings.havdalah)
            ? Self.havdalahChoices : Self.havdalahChoices + [settings.havdalah]
    }

    private func havdalahLabel(_ setting: HavdalahSetting) -> Text {
        switch setting {
        case .degrees(let degrees):
            return Text("\(degrees.formatted(.number.precision(.fractionLength(0...3))))° below horizon")
        case .minutes(let minutes):
            return Text("\(minutes) min after sunset")
        }
    }

    private var sunsetToday: Date? {
        HebcalFormatter(settings: settings).sunset(on: DebugClock.now(), calendar: .current)
    }

    var body: some View {
        Form {
            Section {
                Picker("Minutes before sunset", selection: $modelData.settings.candleLightingMinutes) {
                    if let automaticMinutes {
                        Text("Automatic (\(automaticMinutes))").tag(Int?.none)
                    } else {
                        Text("Automatic").tag(Int?.none)
                    }
                    ForEach(candleLightingChoices, id: \.self) { minutes in
                        Text("\(minutes) min").tag(Int?.some(minutes))
                    }
                }
            } header: {
                Text("Candle lighting")
            } footer: {
                Text("Automatic is 18 minutes, or 20 in Israel: 30 in Haifa and Zikhron Ya’akov, 40 in Jerusalem.")
            }
            Section {
                Picker("Havdalah", selection: $modelData.settings.havdalah) {
                    ForEach(havdalahChoices, id: \.self) { setting in
                        havdalahLabel(setting).tag(setting)
                    }
                }
            } header: {
                Text("Havdalah")
            } footer: {
                Text("8.5° is the default. 42 and 50 minutes are 3 medium and 3 small stars; 72 minutes is Rabbeinu Tam.")
            }
            Section {
                if let sunsetToday {
                    LabeledContent("Sunset today") {
                        Text(sunsetToday, format: .dateTime.hour().minute())
                    }
                } else if settings.location?.timeZoneIdentifier == TimeZone.current.identifier {
                    Text("No sunset today.")
                        .foregroundColor(.secondary)
                } else if settings.location != nil {
                    Text("Location is from another time zone; waiting for a new one.")
                        .foregroundColor(.secondary)
                } else {
                    Text("Waiting for location…")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Zmanim")
    }
}

#Preview {
    ZmanimSettingsView()
        .environmentObject(ModelData.shared)
}
