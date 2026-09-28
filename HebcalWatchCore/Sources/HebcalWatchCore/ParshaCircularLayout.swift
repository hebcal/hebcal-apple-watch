//
//  ParshaCircularLayout.swift
//  HebcalWatchCore
//
//  Which of its five layouts the Parsha widget's circular complication
//  uses for an entry. Kept out of the SwiftUI view so tests can check it.
//

import Foundation

public enum ParshaCircularLayout: Equatable, Sendable {
    /// Two stacked lines, e.g. "Bere-" / "sheet", "Ki" / "Tavo", "Sh." / "Shuva".
    case twoLines(String, String)
    /// Two lines whose first is only an emoji, e.g. "🕎" / "Day 4️⃣": the
    /// emoji is drawn large, since at the two-line size it's tiny.
    case emojiAbove(String, String)
    /// Today is a one-word holiday (e.g. "Y.K."): large text, no Torah icon.
    case holiday(String)
    /// Today is a one-word holiday (e.g. "Purim") with its emoji below in
    /// place of the Torah icon.
    case holidayWithEmoji(String, String)
    /// A one-word parsha (e.g. "Noach") with a Torah icon below it. Also
    /// the upcoming Shabbat's holiday reading (e.g. "Sukkot" or "R.H." the
    /// week before), so it reads as a Torah portion, not today's holiday.
    case parsha(String)

    public init(entry: HebcalEntry) {
        let parts = entry.parshaParts
        if parts.count >= 2 {
            self = Self.isEmojiOnly(parts[0]) ? .emojiAbove(parts[0], parts[1])
                : .twoLines(parts[0], parts[1])
        } else if let emoji = entry.parshaEmoji {
            self = .holidayWithEmoji(parts.first ?? "", emoji)
        } else if entry.parshaShowsHoliday {
            self = .holiday(parts.first ?? "")
        } else {
            self = .parsha(parts.first ?? "")
        }
    }

    /// True for "🕎" but not "Day 4️⃣" or "4" (digits have the Emoji
    /// property too, but not Emoji_Presentation).
    static func isEmojiOnly(_ text: String) -> Bool {
        !text.isEmpty && text.allSatisfy { $0.unicodeScalars.first!.properties.isEmojiPresentation }
    }
}
