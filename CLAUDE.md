# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Apple Watch (watchOS) app for the Hebrew calendar: shows today's Hebrew date, upcoming holidays, and the weekly Torah portion, plus watch face complications. Distributed via the App Store and TestFlight. There is no companion iPhone app — the iPhone target is the required stub that ships the watch app.

- Deployment targets: watchOS 10.6 (watch app and widget extension) / iOS 15.6 (iPhone stub). The app was migrated to watchOS 10 (single-target watch app) and its complications from ClockKit to WidgetKit.
- Swift Package dependency: [`hebcal-swift`](https://github.com/hebcal/hebcal-swift) (`Hebcal` module, tracks the `main` branch). All Jewish calendar math — HDate, Sedra, holidays, daf yomi, translations, Hebrew numerals — comes from this package.

## Build / test

Open `HebcalHDate.xcodeproj` in Xcode and build/run the `HebcalHDate WatchKit App` scheme on the watchOS simulator or a paired device. To run the unit tests, select the `HebcalWatchCore` scheme (destination "My Mac") and press ⌘U, or from the command line:

```sh
cd HebcalWatchCore && swift test          # ~1s, no simulator needed

xcodebuild -project HebcalHDate.xcodeproj \
  -scheme "HebcalHDate WatchKit App" \
  -destination 'generic/platform=watchOS Simulator' \
  build
```

Swift package resolution: `xcodebuild -resolvePackageDependencies` if package state gets wedged.

### Testing on another date (FakeDate)

Michael isn't a regular Xcode user — **whenever he's testing date-dependent behavior (Omer, holidays, parsha, 8 PM rollover, complications), remind him of these steps:**

1. In Xcode: **Product → Scheme → Edit Scheme… → Run → Arguments**.
2. Under *Arguments Passed On Launch*, tick `-FakeDate 2027-05-10T12:00` (already there, unchecked) and edit the date/time as needed. The format is `yyyy-MM-ddTHH:mm`, local time.
3. Run the app. The complications also use the fake time after the app has launched once.
4. To return to the real date, untick it and run the app again.

This only works in Debug builds; see `DebugClock.swift`. The fake clock keeps running from the time you set, so e.g. `T19:58` lets you watch the 8 PM Hebrew-date rollover.

With **Use Location** on, the rollover is at sunset instead, and candle times appear. In the watch simulator, set a location with **Features → Location → Custom Location…** (in the Simulator app) before turning it on. The location's time zone must match the simulator's, or the app ignores it and falls back to 8 PM.

### Golden-file tests

`HebcalWatchCore/Tests/HebcalWatchCoreTests/Snapshots/parsha-circular-{diaspora,israel}.md` record what the Parsha circular complication shows at noon every day for a full year (Sep 2026–Aug 2027) in all three languages — a Markdown table that renders on GitHub roughly like the watch face. When a change alters the output, the test fails and writes `<name>.actual.md` beside the golden file (git-ignored); diff the two, and if the new output is right accept it with `SNAPSHOT_RECORD=1 swift test` and commit the updated golden file. Output depends on `hebcal-swift`'s translations too, so a package update can legitimately change it.

All test suites are nested in one `.serialized` suite because older `hebcal-swift` revisions had an unsynchronized global cache (`edCache`) that crashed when called from several threads.

## Architecture

Three Xcode targets plus one local Swift package:

- `HebcalWatchCore/` — local Swift package with **all the calendar and formatting logic**, no SwiftUI or WidgetKit, so it's unit-testable on the Mac. Both app targets link it.
- `HebcalHDate WatchKit App` — the watchOS 10 watch app (SwiftUI views, `ModelData`, background refresh). Sources in `HebcalHDate WatchKit App/`.
- `HebcalHDate Widgets` — the WidgetKit extension that provides the watch face complications. Sources in `HebcalHDate Widgets/`.
- `HebcalHDate` — iPhone stub (required by App Store, no code).

### HebcalWatchCore

- `HebcalSettings.swift` — the user settings (`il` Israel vs Diaspora schedule, `lang: TranslationLang` Sephardic / Ashkenazi / Hebrew, `dafyomi`, and for zmanim `useLocation`, `location: GeoPoint?`, `candleLightingMinutes: Int?` (nil = automatic), `havdalah: HavdalahSetting`) and their persistence. The watch app and widget are separate processes, so settings live in an **App Group `UserDefaults` suite** (`HebcalSettings.appGroupDefaults`), not `UserDefaults.standard`; a one-time migration copies pre-WidgetKit settings out of `.standard`. **Israel is inferred, never silently flipped back:** with no saved Israel value, `init(defaults:timeZone:)` defaults `il` to on in `Asia/Jerusalem` (so the widget agrees with the app even before its first launch); the app loads settings with `launchSettings(defaults:timeZone:)`, which on a brand-new install (no saved `lang`) in `Asia/Jerusalem` turns on `il` and saves; and the first location fix after the user turns on Use Location goes through `applyingFirstLocation(_:israelChosen:)`, which turns on `il` if the fix is in Israel. Both only apply until the user flips the Israel toggle themselves (`israelChosen` key, set by `ModelData.setIsrael`); an install that already had a saved Israel value when this shipped counts as chosen. The schedule follows the person (a tourist keeps the Diaspora schedule), so never switch `il` off automatically, or on during later travel.
- `HebcalFormatter.swift` — answers calendar questions for one `HebcalSettings` and formats them: Hebrew date strings, parsha (`parsha(on:)`, `parshaOrHoliday(on:)`), holidays (`holidays(on:)`, `holidayToDisplay(on:specialShabbat:)`, `holidayName(_:abbreviated:)`), emoji, Omer, Daf Yomi. Caches holidays and Sedra per Hebrew year; settings are immutable, so make a new formatter when they change. The static `HebcalFormatter.hebrewDate(for:calendar:)` rolls over to the next Hebrew date from 8 PM local time, since Hebrew days start at sundown; the instance method of the same name rolls over at sunset when there's a location, else falls back to the static one — keep this in mind when changing date logic.
- `CandleTimes.swift` — optional location-based zmanim: `GeoPoint` (rounded to 0.01°; `defaultCandleLightingMinutes` detects Jerusalem 40 / Haifa & Zikhron Ya'akov 30 / elsewhere in Israel 20 / else 18 — by where the watch is, not by the `il` schedule), `HavdalahSetting`, `ZmanEvent` (🕯️ candle lighting / ✨ Havdalah / 🕎 Chanukah), `ZmanimDetail`, and formatter methods `zmanimLocation(calendar:)`, `sunset(on:)`, `candleTimes(on:)`, `zmanimDetail(on:)`. Which day gets which time is a port of hebcal-es6's `makeCandleEvent()` / `makeWeekdayChanukahCandleLighting()`; times come from hebcal-swift's `Zmanim` (tests use hebcal-es6 output as expected values). **With `useLocation` off, no fix yet, or a fix from another time zone than the watch's (the user travelled and hasn't opened the app), `zmanimLocation` is nil and everything behaves as before: 8 PM rollover, no times.**
- `Abbreviations.swift` — every pixel-budgeted table in one place: `holiday`, `month`/`monthTiny`, `parshaHyphenation`, plus `splitParsha`. When a new parsha string or month name doesn't fit on a particular face, the fix usually goes in these tables, not in layout code. The tables are keyed with plain ASCII `'`, but `lookupTranslation` returns `’` for Sephardic/Ashkenazi, so look names up via `Abbreviations.tableKey(_:)`. Ashkenazi spellings that differ (e.g. `Teves`) need their own entries; a test checks that every single-word parsha has one.
- `DateItem.swift` — one row of the app's calendar list, and `HebcalFormatter.dateItems(from:calendar:)` which builds the list: every day for 2 weeks, then only Shabbatot, holidays and (with a location) Fridays through one Hebrew year from today. A row's `zmanim` lists its candle times. A row's optional `detail: DateItemDetail` (an enum: `.omer`, `.zmanim`) is what makes it tappable in the app; add a case for each new kind of detail card. A day with both candle times and the Omer gets `.zmanim`, whose card links on to the Omer card (`DateItemDetail.omer` finds the Omer either way).
- `DebugClock.swift` — Debug builds only: the `-FakeDate yyyy-MM-ddTHH:mm` launch argument (in the shared scheme, unchecked) makes the app *and* the complications pretend it's that time, to test seasonal features in the simulator. The app stores the offset from real time in the App Group suite; the provider builds entries for fake times and stamps them with real times (`entries(…clockOffset:)`), since WidgetKit displays by the real clock. Use `DebugClock.now()` rather than `Date()` for "what day is it" logic.
- `OmerDetail.swift` — the Omer card's content (count, Sefirah, Psalm 67 word and letter, Ana BeKoach) from hebcal-swift's `OmerEvent`, as headed sections of display strings.
- `HebcalEntry.swift` — everything the complications show at one moment, as precomputed strings, plus `timelineDates(from:calendar:)` (sparse pivots, notably 8 PM) and `timelineDates(from:calendar:settings:)` (with a location: sunset, candle times and midnight through tomorrow). `zmanim` is the current Hebrew day's next candle time — Friday's candles until sunset, then Saturday's Havdalah — which the rectangular widget shows in place of the Omer line. and `entries(at:settings:calendar:)`, which builds a timeline under a lock (WidgetKit may request the three widgets' timelines concurrently).
- `ParshaCircularLayout.swift` — the Parsha circular complication's five layouts (two lines / large emoji above one line / one-word holiday / one-word holiday of today with its emoji below / one-word parsha, or upcoming holiday reading, with Torah icon), decided from an entry. The view switches on it; the golden-file test renders it.

### Watch app

`ModelData.swift` is an `ObservableObject` singleton (`ModelData.shared`) holding `@Published var settings: HebcalSettings`, `todayDateItem` and `dateItems`. Setting `settings` saves to the App Group suite, rebuilds the list and calls `WidgetCenter.shared.reloadAllTimelines()`, so changing a setting in the app refreshes the watch face. `updateDateItems()` rebuilds the list only when the calendar day has changed. `ModelData.locationManager` (`LocationManager.swift`, a `CLLocationManager` wrapper, When-In-Use) is only used while `settings.useLocation`: turning it on prompts, declining turns it back off, and each fix is written to `settings.location` (so it reaches the widget via the App Group suite). A new fix is requested whenever the app becomes active; the background refresh can't get one.

`ContentView` is the root and reacts to `scenePhase`: on `.active` it refreshes date items; on `.background` it schedules a `WKApplicationRefreshBackgroundTask`. `TodayView` renders one `DateItem` and is reused both for the top of the main screen and inside the scrolling `HDateList`. `SettingsView` binds directly to `modelData.settings` via `@EnvironmentObject`; its "Use Location" toggle reveals a link to `ZmanimSettingsView` (`Screen.zmanim`: candle-lighting minutes, Havdalah degrees/minutes, today's sunset). Rows with a `DateItemDetail` are value-based `NavigationLink`s (with a chevron in `HDateList`); the single `.navigationDestination(for: DateItemDetail.self)` in `ContentView` pushes `DateItemDetailView`, which switches on the case. All navigation in the stack is value-based (`Screen.calendar` / `.settings` for the main screen's links) — don't reintroduce `NavigationLink(destination:)`: a value link inside a screen pushed that way pops straight back off. During the Omer, `ContentView` adds a row under Today that opens today's Omer card.

`ExtensionDelegate` schedules a background refresh (roughly every 2 hours); on wake it calls `checkTimeZone()` (forces a complication reload via `WidgetCenter` if the device travelled across time zones) and `updateDateItems()`.

### Complications (WidgetKit)

- `HebcalWidgetBundle.swift` — the `@main WidgetBundle` and its three `StaticConfiguration` widgets: `HebcalWidget` (rectangular/inline), `HDateWidget` (circular/corner/inline) and `ParshaWidget` (circular/inline). Each widget's `kind` string (`complicationHebcal`, `complicationHdate`, `complicationParsha`) is **preserved verbatim from the legacy ClockKit `CLKComplicationDescriptor` identifiers** so existing faces migrate 1:1 — don't rename them. Each declares its `supportedFamilies` here.
- `HebcalProvider.swift` — the `TimelineProvider`. It reads `HebcalSettings` from the App Group suite on every request (the process may outlive a settings change) — including the location the app saved, since the widget can't ask for one — and builds entries with `HebcalEntry.entries(at:…)`; reload policy `.atEnd`. Also adds `HebcalEntry`'s `TimelineEntry` conformance (core doesn't import WidgetKit).
- `HebcalWidgetViews.swift` — one SwiftUI view per family (e.g. `HDateCircularView`, `HDateCornerView`, `ParshaCircularView`, `HebcalRectangularView`), plus the `*WidgetEntryView` containers that `switch` on `@Environment(\.widgetFamily)`, and the `#Preview`s. Note the family constraints: `.accessoryCorner` content and its `.widgetLabel` are **system-sized** — `.font(size:)` there is ignored; use `.accessoryCircular` when you need a large custom glyph.

ClockKit is otherwise gone; it survives only as the `CLKComplicationWidgetMigrator` conformance in `ExtensionDelegate.swift`, which maps each old ClockKit complication to its WidgetKit `kind` for users upgrading from the pre-migration build.

### Localization

`en.lproj`, `en-AU.lproj`, `en-GB.lproj`, `en-IN.lproj`, `he.lproj` (in `HebcalHDate WatchKit App/`) contain `Localizable.strings`. User-visible holiday/parsha translations come from the `Hebcal` package's `lookupTranslation(str:lang:)`, not the `.lproj` files — those are only for app chrome (button labels, section headers).

## Conventions worth knowing

- `TranslationLang` enum from the Hebcal package has cases `.en` (Sephardic), `.ashkenazi`, `.he`, `.heNikud`. UI exposes the first three; `.heNikud` (vowel points) is currently unused by the app. It's persisted as its `Int` raw value under the key `lang`.
- Hebrew (`lang == .he`) renders right-aligned — many views branch on `isHebrew` to flip alignment / insert `Spacer`s.
- Holiday abbreviations (`Abbreviations.holiday`) and Chanukah emoji renderings are tuned for narrow complication families; changing them affects what shows on the watch face (and the golden files).
- Dynamic Type scaling for fixed point sizes uses SwiftUI's built-in `@ScaledMetric` property wrapper (e.g. `TodayView`'s `smallFontSize`/`largeFontSize`), not a custom `UIFontMetrics` wrapper.
- New logic goes in `HebcalWatchCore` with a test, not in the app or widget targets; those should only hold UI and platform glue.
- **Parsha-vs-holiday priority rule** (`HebcalEntry.init`, `holidayToday`; used by the Parsha widget's `parshaShowsHoliday` / `parshaParts` / `parshaPrefixed` / `parshaShort` and by the Hebcal inline widget's `inline*Text`): on a Shabbat with a regular reading, show the parsha even if it's also a special Shabbat or Rosh Chodesh; otherwise, if today itself is a holiday, show the holiday; otherwise show the upcoming Shabbat's parsha (or the holiday that displaces it). This uses the `specialShabbat: false` holiday pick. Don't use `richHoliday` for it — that field also carries the *upcoming* special Shabbat (for the rectangular widget).
