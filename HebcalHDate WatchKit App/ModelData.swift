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
            if settings.useLocation && !oldValue.useLocation {
                awaitingFirstLocation = true
                locationManager.requestLocation()
            }
        }
    }

    /// Gets fixes for sunset and candle times while `settings.useLocation`.
    let locationManager = LocationManager()
    /// Set when the user turns on location: the first fix may also switch
    /// on the Israel schedule.
    private var awaitingFirstLocation = false

    @Published private(set) var todayDateItem: DateItem
    /// The calendar list: two weeks of days, then a link per month.
    @Published private(set) var dateItems: [DateItem] = []
    @Published private(set) var dateMonths: [DateMonth] = []

    private var formatter: HebcalFormatter
    /// Start of the day the list was built for; nil forces a rebuild.
    private var listDay: Date?
    private var currentTimeZone = TimeZone.current

    private init() {
        let fakeDateChanged = DebugClock.setFakeDate(UserDefaults.standard.string(forKey: "FakeDate"))
        let settings = HebcalSettings.launchSettings(defaults: HebcalSettings.appGroupDefaults,
                                                     timeZone: .current)
        self.settings = settings
        formatter = HebcalFormatter(settings: settings)
        let now = Self.now
        todayDateItem = formatter.dateItem(for: now, calendar: .current, now: now,
                                           showYear: true, forceParsha: true)
        updateDateItems()
        locationManager.onLocation = { [weak self] point in
            guard let self else { return }
            if self.awaitingFirstLocation {
                self.awaitingFirstLocation = false
                let chosen = HebcalSettings.israelChosen(defaults: HebcalSettings.appGroupDefaults)
                self.settings = self.settings.applyingFirstLocation(point, israelChosen: chosen)
            } else {
                self.settings.location = point
            }
        }
        locationManager.onDenied = { [weak self] in
            self?.settings.useLocation = false
        }
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
        let list = formatter.dateItemList(from: now, calendar: calendar)
        dateItems = list.days
        dateMonths = list.months
        Logger.model.debug("Made \(self.dateItems.count) dateItems and \(self.dateMonths.count) months")
    }

    /// The Israel toggle, as set by the user (after which the app no longer
    /// sets it for them).
    func setIsrael(_ il: Bool) {
        HebcalSettings.markIsraelChosen(defaults: HebcalSettings.appGroupDefaults)
        settings.il = il
    }

    /// Gets a new fix if location is on, in case the watch has moved. The
    /// settings (and so the complications) only change if it has moved
    /// more than about a kilometer or into another time zone.
    func refreshLocation() {
        if settings.useLocation {
            locationManager.requestLocation()
        }
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
