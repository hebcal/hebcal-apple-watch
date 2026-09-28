//
//  ParshaCircularLayout.swift
//  HebcalWatchCore
//
//  Which of its three layouts the Parsha widget's circular complication
//  uses for an entry. Kept out of the SwiftUI view so tests can check it.
//

import Foundation

public enum ParshaCircularLayout: Equatable {
    /// Two stacked lines, e.g. "Bere-" / "sheet", "Ki" / "Tavo", "Sh." / "Shuva".
    case twoLines(String, String)
    /// Today is a one-word holiday (e.g. "Y.K."): large text, no Torah icon.
    case holiday(String)
    /// A one-word parsha (e.g. "Noach") with a Torah icon below it.
    case parsha(String)

    public init(entry: HebcalEntry) {
        let parts = entry.parshaParts
        if parts.count >= 2 {
            self = .twoLines(parts[0], parts[1])
        } else if entry.parshaShowsHoliday {
            self = .holiday(parts.first ?? "")
        } else {
            self = .parsha(parts.first ?? "")
        }
    }
}
