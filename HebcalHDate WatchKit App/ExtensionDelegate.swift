//
//  ExtensionDelegate.swift
//  HebcalHDate WatchKit App
//
//  Created by Michael Radwin on 9/12/21.
//

import Foundation
import WatchKit
import ClockKit
import os

// Bundle identifier of the widget extension that hosts the migrated widgets.
private let widgetExtensionBundleIdentifier = "com.hebcal.HebcalHDate.watchkitapp.widgets"

// The app's extension delegate.
class ExtensionDelegate: NSObject, WKApplicationDelegate {
    // MARK: - Delegate Methods

    // Called when a background task occurs.
    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        Logger.app.debug("Handling a background task...")
        Logger.app.debug("App State: \(WKApplication.shared().applicationState.rawValue)")
        for task in backgroundTasks {
            Logger.app.debug("Task: \(task)")
            switch task {
            // Handle background refresh tasks.
            case let backgroundTask as WKApplicationRefreshBackgroundTask:
                let model = ModelData.shared
                model.checkTimeZone()
                model.updateDateItems()
                // Schedule the next background update.
                scheduleBackgroundRefreshTasks()
                // Mark the task as ended, and request an updated snapshot, if necessary.
                backgroundTask.setTaskCompletedWithSnapshot(true)
            case let snapshotTask as WKSnapshotRefreshBackgroundTask:
                snapshotTask.setTaskCompleted(restoredDefaultState: true, estimatedSnapshotExpiration: Date.distantFuture, userInfo: nil)
            default:
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }
}

// MARK: - ClockKit -> WidgetKit complication migration
//
// watchOS calls this migrator once, when a user updates in place from a build
// that still had ClockKit complications on a watch face to a build that provides
// this conformance. The legacy CLKComplicationDescriptor identifiers were reused
// verbatim as the WidgetKit `kind` strings (see HebcalWidgetBundle), so each old
// complication maps 1:1 to its equivalent static widget.
//
// Note: this is a one-shot, in-place-upgrade event. Users who already updated to
// a WidgetKit build that lacked this migrator have missed the window and must
// re-add complications by hand; only users still on the old ClockKit version
// benefit from this on their next update.
extension ExtensionDelegate: CLKComplicationWidgetMigrator {
    func widgetConfiguration(
        from complicationDescriptor: CLKComplicationDescriptor
    ) async -> CLKComplicationWidgetMigrationConfiguration? {
        CLKComplicationStaticWidgetMigrationConfiguration(
            kind: complicationDescriptor.identifier,
            extensionBundleIdentifier: widgetExtensionBundleIdentifier
        )
    }
}

// Schedule the next background refresh task.

private let backgroundRefreshInterval = 2.0 * 60.0 * 60.0
func scheduleBackgroundRefreshTasks() {
    let refreshTime = Date().advanced(by: backgroundRefreshInterval)
    WKApplication.shared().scheduleBackgroundRefresh(
        withPreferredDate: refreshTime,
        userInfo: nil
    ) { error in
        if let error {
            Logger.app.error("Couldn't schedule a background refresh: \(error.localizedDescription)")
        } else {
            Logger.app.debug("Scheduled the next background refresh task.")
        }
    }
}
