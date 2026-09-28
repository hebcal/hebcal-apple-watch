//
//  DateItem.swift
//  HebcalWatchCore
//
//  One row of the watch app's calendar: a Gregorian day with its Hebrew
//  date, holidays, parsha, Omer, Daf Yomi and candle times.
//

import Foundation
import Hebcal

/// More about a day than fits in its row, shown on a card of its own when
/// the row is tapped. Rows without one aren't tappable.
public enum DateItemDetail: Hashable, Codable, Sendable {
    case omer(OmerDetail)
    /// Candle times; links on to the Omer card on a day of the Omer.
    case zmanim(ZmanimDetail)

    /// The Omer card, directly or linked from the day's candle times.
    public var omer: OmerDetail? {
        switch self {
        case .omer(let omer): return omer
        case .zmanim(let zmanim): return zmanim.omer
        }
    }
}

public struct DateItem: Hashable, Codable, Identifiable {
    public var id: Int
    public var lang: TranslationLang
    public var dow: String
    public var gregDay: Int
    public var gregMonth: String
    /// 0 when the year should be omitted (it's the current year).
    public var gregYear: Int
    public var hdate: String
    public var parsha: String?
    public var holidays: [String]
    /// `holidays` abbreviated ("R.Ch. Cheshvan"), for when a name won't fit
    /// on one line.
    public var holidaysShort: [String]
    public var emoji: String?
    public var omer: String?
    public var dafyomi: String?
    /// Candle lighting, Havdalah, Chanukah candles; empty without a location.
    /// On Shabbat of Chanukah the Chanukah time is left out, since it's the
    /// same as the candle lighting or Havdalah time (the detail card has both).
    public var zmanim: [ZmanEvent]
    public var detail: DateItemDetail?

    public init(id: Int, lang: TranslationLang, dow: String, gregDay: Int, gregMonth: String,
                gregYear: Int, hdate: String, parsha: String?, holidays: [String],
                emoji: String?, omer: String?, dafyomi: String?,
                zmanim: [ZmanEvent] = [], detail: DateItemDetail? = nil,
                holidaysShort: [String]? = nil) {
        self.id = id
        self.lang = lang
        self.dow = dow
        self.gregDay = gregDay
        self.gregMonth = gregMonth
        self.gregYear = gregYear
        self.hdate = hdate
        self.parsha = parsha
        self.holidays = holidays
        self.holidaysShort = holidaysShort ?? holidays
        self.emoji = emoji
        self.omer = omer
        self.dafyomi = dafyomi
        self.zmanim = zmanim
        self.detail = detail
    }
}

// MARK: - Building date items

private let dayOfWeek = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
private let dayOfWeekHe = ["", "ראשון", "שני", "שלישי", "רביעי", "חמישי", "שישי", "שבת"]
private let shortMonth = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun",
                          "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
private let shortMonthHe = ["", "ינו", "פבר", "מרץ", "אפר", "מאי", "יונ",
                            "יול", "אוג", "ספט", "אוק", "נוב", "דצמ"]

private let longMonth = ["", "January", "February", "March", "April", "May", "June",
                         "July", "August", "September", "October", "November", "December"]
private let longMonthHe = ["", "ינואר", "פברואר", "מרץ", "אפריל", "מאי", "יוני",
                           "יולי", "אוגוסט", "ספטמבר", "אוקטובר", "נובמבר", "דצמבר"]

extension HebcalFormatter {
    /// A Gregorian date like "Fri, 2 October" or "שישי, 2 אוקטובר": the
    /// weekday as in `DateItem.dow`, then the day and month, abbreviated
    /// as in `DateItem.gregMonth` when `shortMonth` is set.
    func gregorianTitle(for date: Date, calendar: Calendar, shortMonth abbreviated: Bool) -> String {
        let c = calendar.dateComponents([.weekday, .month, .day], from: date)
        let dow = isHebrew ? dayOfWeekHe[c.weekday!] : dayOfWeek[c.weekday!]
        let month = isHebrew
            ? (abbreviated ? shortMonthHe : longMonthHe)[c.month!]
            : (abbreviated ? shortMonth : longMonth)[c.month!]
        return "\(dow), \(c.day!) \(month)"
    }

    /// The row for Gregorian day `date`. The Gregorian year is shown when
    /// `showYear` is set or when it differs from the year of `now`; the
    /// Hebrew year when `showYear` is set or on Rosh Hashana. The parsha is
    /// shown on Shabbat, or on any day with `forceParsha`.
    public func dateItem(for date: Date, calendar: Calendar, now: Date,
                         showYear: Bool, forceParsha: Bool) -> DateItem {
        let components = calendar.dateComponents([.weekday, .month, .day, .year], from: date)
        let weekday = components.weekday!
        let month = components.month!
        let year = components.year!
        let hdate = HDate(date: date, calendar: calendar)
        let isRoshHashana = hdate.mm == .TISHREI && hdate.dd == 1
        let events = holidays(on: hdate)
        let currentYear = calendar.component(.year, from: now)
        let zmanimDetail = zmanimDetail(on: hdate, calendar: calendar)
        let zmanim = zmanimDetail?.events ?? []
        return DateItem(
            id: (hdate.yy * 10000) + (hdate.mm.rawValue * 100) + hdate.dd,
            lang: lang,
            dow: isHebrew ? dayOfWeekHe[weekday] : dayOfWeek[weekday],
            gregDay: components.day!,
            gregMonth: isHebrew ? shortMonthHe[month] : shortMonth[month],
            gregYear: showYear || year != currentYear ? year : 0,
            hdate: dateString(hdate, showYear: showYear || isRoshHashana),
            parsha: forceParsha || weekday == 7 ? parsha(on: hdate) : nil,
            holidays: events.map { holidayName($0, abbreviated: false) },
            emoji: Self.emoji(for: events),
            omer: omer(on: hdate),
            dafyomi: settings.dafyomi ? dafYomi(on: date) : nil,
            zmanim: zmanim.filter { zman in
                zman.kind != .chanukah || !zmanim.contains { $0.kind != .chanukah && $0.time == zman.time }
            },
            detail: zmanimDetail.map(DateItemDetail.zmanim) ?? omerDetail(on: hdate).map(DateItemDetail.omer),
            holidaysShort: events.map { holidayName($0, abbreviated: true) }
        )
    }

    /// The app's scrolling calendar starting at `date`: every day for two
    /// weeks, then only Shabbatot, holidays and (with a location) other days
    /// with candle times, i.e. Fridays, through one Hebrew year from today.
    public func dateItems(from date: Date, calendar: Calendar) -> [DateItem] {
        let oneDay = 24.0 * 60.0 * 60.0
        var items = [dateItem(for: date, calendar: calendar, now: date,
                              showYear: true, forceParsha: false)]
        var current = date.addingTimeInterval(oneDay)
        let twoWeeks = date.addingTimeInterval(14 * oneDay)
        while current < twoWeeks {
            items.append(dateItem(for: current, calendar: calendar, now: date,
                                  showYear: false, forceParsha: false))
            current = current.addingTimeInterval(oneDay)
        }
        let today = HDate(date: date, calendar: calendar)
        let endAbs = today.abs() + Int64(daysInYear(year: today.yy))
        for abs in greg2abs(date: current)...endAbs {
            let hdate = HDate(absdate: abs)
            let isShabbat = hdate.dow() == .SAT
            if isShabbat || !holidays(on: hdate).isEmpty
                || (hdate.dow() == .FRI && zmanimLocation(calendar: calendar) != nil) {
                items.append(dateItem(for: hdate.greg(), calendar: calendar, now: date,
                                      showYear: false, forceParsha: isShabbat))
            }
        }
        return items
    }
}
