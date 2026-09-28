//
//  HebcalProvider.swift
//  HebcalHDate Widgets
//
//  TimelineProvider that produces sparse entries pegged to the
//  moments when the rendered text might change (mainly 8pm local,
//  when the Hebrew day rolls over). The entries themselves are built
//  by HebcalWatchCore.
//

import Foundation
import WidgetKit
import HebcalWatchCore

// HebcalWatchCore deliberately doesn't import WidgetKit (so its tests run on
// the Mac), so the conformance is added here.
extension HebcalEntry: @retroactive TimelineEntry {}

struct HebcalProvider: TimelineProvider {
    typealias Entry = HebcalEntry

    func placeholder(in context: Context) -> HebcalEntry {
        return HebcalProvider.entry(for: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (HebcalEntry) -> Void) {
        completion(HebcalProvider.entry(for: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HebcalEntry>) -> Void) {
        let dates = HebcalEntry.timelineDates(from: Date(), calendar: HebcalProvider.calendar)
        let entries = HebcalEntry.entries(at: dates, settings: HebcalProvider.currentSettings())
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    /// Read on every request rather than cached: the app writes the App
    /// Group suite and then reloads all timelines, and this process may
    /// have been alive since before the change.
    static func currentSettings() -> HebcalSettings {
        return HebcalSettings(defaults: HebcalSettings.appGroupDefaults)
    }

    static func entry(for date: Date) -> HebcalEntry {
        return HebcalEntry.entries(at: [date], settings: currentSettings())[0]
    }

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }()
}
