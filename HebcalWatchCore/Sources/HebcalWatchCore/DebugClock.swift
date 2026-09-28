//
//  DebugClock.swift
//  HebcalWatchCore
//
//  Debug builds only: pretend it's another time, to try out seasonal
//  features such as the Omer in the simulator, whose clock can't be set.
//  Launch the app with e.g. `-FakeDate 2027-05-10T12:00` (the shared scheme
//  has it, unchecked). The app stores the offset from the real time in the
//  App Group suite, so the widget extension (a separate process that never
//  sees the app's launch arguments) runs on the same fake clock. The fake
//  clock keeps ticking, so the 8 PM rollover can be watched too.
//

import Foundation

public enum DebugClock {
    static let offsetKey = "debugClockOffset"

    /// Parses `yyyy-MM-ddTHH:mm` in local time.
    static func parse(_ string: String) -> Date? {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return parser.date(from: string)
    }

    /// Seconds to add to the real time; always 0 in Release builds.
    public static func offset(defaults: UserDefaults = HebcalSettings.appGroupDefaults) -> TimeInterval {
        #if DEBUG
        return defaults.double(forKey: offsetKey)
        #else
        return 0
        #endif
    }

    /// The current time on the (possibly fake) clock.
    public static func now(defaults: UserDefaults = HebcalSettings.appGroupDefaults) -> Date {
        return Date().addingTimeInterval(offset(defaults: defaults))
    }

    /// Called by the app at launch with its `FakeDate` launch argument, or
    /// nil to go back to the real time. Returns whether the offset changed,
    /// i.e. whether the complications need reloading. Does nothing in
    /// Release builds.
    @discardableResult
    public static func setFakeDate(_ string: String?,
                                   defaults: UserDefaults = HebcalSettings.appGroupDefaults) -> Bool {
        #if DEBUG
        let old = offset(defaults: defaults)
        if let string, let date = parse(string) {
            defaults.set(date.timeIntervalSinceNow, forKey: offsetKey)
        } else {
            defaults.removeObject(forKey: offsetKey)
        }
        // A relaunch with the same FakeDate gives a slightly different
        // offset; only a jump of more than a minute counts as a change.
        return abs(offset(defaults: defaults) - old) > 60
        #else
        return false
        #endif
    }
}
