//
//  ModelData.swift
//  HebcalHDate WatchKit App
//
//  Created by Michael Radwin on 8/23/21.
//
//  The watch app's observable state: the user settings and the rows of the
//  calendar list. The calendar logic itself lives in HebcalWatchCore.
//

import Foundation
import HebcalWatchCore
import WidgetKit
import os

final class ModelData: ObservableObject {
    static let shared = ModelData()

    /// Changing a setting persists it to the App Group suite (where the
    /// widget extension reads it), rebuilds the list and reloads the
    /// complications.
    @Published var settings: HebcalSettings {
        didSet {
            guard settings != oldValue else { return }
            Logger.model.debug("settings il=\(self.settings.il) lang=\(self.settings.lang.rawValue) dafyomi=\(self.settings.dafyomi)")
            settings.save(to: HebcalSettings.appGroupDefaults)
            formatter = HebcalFormatter(settings: settings)
            listDay = nil
            updateDateItems()
            reloadComplications()
        }
    }

    @Published private(set) var todayDateItem: DateItem
    @Published private(set) var dateItems: [DateItem] = []

    private var formatter: HebcalFormatter
    /// Start of the day the list was built for; nil forces a rebuild.
    private var listDay: Date?
    private var currentTimeZone = TimeZone.current

    private init() {
        let fakeDateChanged = DebugClock.setFakeDate(UserDefaults.standard.string(forKey: "FakeDate"))
        let settings = HebcalSettings(defaults: HebcalSettings.appGroupDefaults)
        self.settings = settings
        formatter = HebcalFormatter(settings: settings)
        let now = Self.now
        todayDateItem = formatter.dateItem(for: now, calendar: .current, now: now,
                                           showYear: true, forceParsha: true)
        updateDateItems()
        if fakeDateChanged {
            Logger.model.debug("clock offset is now \(DebugClock.offset())s; reloading complications")
            reloadComplications()
        }
    }

    /// Rebuilds the list if the day has changed since it was last built.
    func updateDateItems() {
        let now = Self.now
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        guard today != listDay else {
            Logger.model.debug("dateItems are already up to date; refresh skipped")
            return
        }
        Logger.model.debug("updating dateItems for \(today)")
        listDay = today
        todayDateItem = formatter.dateItem(for: now, calendar: calendar, now: now,
                                           showYear: true, forceParsha: true)
        dateItems = formatter.dateItems(from: now, calendar: calendar)
        Logger.model.debug("Made \(self.dateItems.count) dateItems")
    }

    /// The current time: the real time, or in Debug builds the fake clock
    /// set by the `-FakeDate` launch argument (see `DebugClock`).
    private static var now: Date {
        DebugClock.now()
    }

    /// Reloads the complications if the watch has moved to another time
    /// zone, since their timelines are pegged to local times.
    func checkTimeZone() {
        guard currentTimeZone != TimeZone.current else { return }
        Logger.model.debug("timezone changed from \(self.currentTimeZone.identifier) to \(TimeZone.current.identifier)")
        currentTimeZone = TimeZone.current
        listDay = nil
        reloadComplications()
    }

    private func reloadComplications() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}

extension Logger {
    private static let subsystem = "com.hebcal.HebcalHDate.watchkitapp"
    static let model = Logger(subsystem: subsystem, category: "Model")
    static let app = Logger(subsystem: subsystem, category: "App")
}
