//
//  WidgetSupport.swift
//  HebcalHDate Widgets
//
//  Shared by the widget view files: the gold tint, and the helpers the
//  #Previews use to build entries for a given date.
//

import SwiftUI
import Hebcal
import HebcalWatchCore

let goldTint = Color(red: 1.0, green: 0.75, blue: 0.0)

#if DEBUG
/// Noon local time on the given Gregorian date, so `makeHDate`'s 8pm
/// day-rollover never pushes the preview onto the next Hebrew day.
func previewNoon(year: Int, month: Int, day: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.hour = 12
    return Calendar(identifier: .gregorian).date(from: components)!
}

/// Settings with a location in the preview's time zone (New York
/// coordinates), so candle times show.
let previewZmanimSettings = HebcalSettings(useLocation: true, location: GeoPoint(
    latitude: 40.71, longitude: -74.01, timeZoneIdentifier: TimeZone.current.identifier))

/// An entry at noon on the given date with explicit settings rather than
/// the saved ones, so Hebrew and Israel cases can be previewed side by side.
func parshaPreview(_ year: Int, _ month: Int, _ day: Int,
                   lang: TranslationLang = .en, il: Bool = false) -> HebcalEntry {
    HebcalProvider.entry(for: previewNoon(year: year, month: month, day: day),
                         settings: HebcalSettings(il: il, lang: lang))
}
#endif
