//
//  LureliaEventUnifiedOccurrence.swift
//  Lurelia
//

import SwiftUI

enum LureliaEventUnifiedOccurrence: Identifiable {
    case local(LureliaEventOccurrence)
    case apple(LureliaExternalCalendarOccurrence)

    var id: String {
        switch self {
        case .local(let occurrence): return "local-\(occurrence.id)"
        case .apple(let occurrence): return "apple-\(occurrence.id)"
        }
    }

    var title: String {
        switch self {
        case .local(let occurrence): return occurrence.title
        case .apple(let occurrence): return occurrence.title
        }
    }

    var icon: String {
        switch self {
        case .local(let occurrence): return occurrence.icon
        case .apple(let occurrence):
            let icon = occurrence.icon?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return icon.isEmpty ? "starcal" : icon
        }
    }

    var start: Date {
        switch self {
        case .local(let occurrence): return occurrence.start
        case .apple(let occurrence): return occurrence.start
        }
    }

    var end: Date {
        switch self {
        case .local(let occurrence): return occurrence.end
        case .apple(let occurrence): return occurrence.end
        }
    }

    var color: Color {
        switch self {
        case .local(let occurrence): return Color(lureliaHex: occurrence.colorHex)
        case .apple(let occurrence): return Color(lureliaHex: occurrence.colorHex)
        }
    }

    var subtitle: String {
        switch self {
        case .local(let occurrence):
            let time = occurrence.isAllDay
                ? "All day"
                : "\(occurrence.start.formatted(date: .omitted, time: .shortened)) - \(occurrence.end.formatted(date: .omitted, time: .shortened))"
            if let calendarName = occurrence.calendarName, !calendarName.isEmpty {
                return "\(calendarName) • \(time)"
            }
            return time
        case .apple(let occurrence):
            if occurrence.isAllDay { return "\(occurrence.calendarTitle) • All day" }
            return "\(occurrence.calendarTitle) • \(occurrence.start.formatted(date: .omitted, time: .shortened))"
        }
    }

    var isApple: Bool {
        switch self {
        case .local: return false
        case .apple: return true
        }
    }

    var isAppleOwned: Bool {
        switch self {
        case .local(let occurrence): return occurrence.isAppleCalendarEvent
        case .apple: return true
        }
    }

    var isAllDay: Bool {
        switch self {
        case .local(let occurrence): return occurrence.isAllDay
        case .apple(let occurrence): return occurrence.isAllDay
        }
    }

    /// Name of the calendar this row belongs to — the Lurelia calendar's
    /// name for local events, or the Apple Calendar's title for Apple
    /// events. `nil` for local events without a calendar assignment.
    var calendarName: String? {
        switch self {
        case .local(let occurrence): return occurrence.calendarName
        case .apple(let occurrence): return occurrence.calendarTitle
        }
    }

    var localOccurrence: LureliaEventOccurrence? {
        switch self {
        case .local(let occurrence): return occurrence
        case .apple: return nil
        }
    }

    var appleOccurrence: LureliaExternalCalendarOccurrence? {
        switch self {
        case .local: return nil
        case .apple(let occurrence): return occurrence
        }
    }

    func occurs(on day: Date, calendar: Calendar = .current) -> Bool {
        let dayStart = calendar.startOfDay(for: day)

        if isAllDay {
            let startDay = calendar.startOfDay(for: start)
            let endDay = calendar.startOfDay(for: end)

            if endDay <= startDay {
                return calendar.isDate(startDay, inSameDayAs: dayStart)
            }

            // Apple all-day event ends are exclusive. An event ending exactly
            // at today's midnight belongs to yesterday, not today.
            return dayStart >= startDay && dayStart < endDay
        }

        guard let dayInterval = calendar.dateInterval(of: .day, for: day) else {
            return calendar.isDate(start, inSameDayAs: day)
        }

        let eventEnd = max(end, start.addingTimeInterval(60))
        return start < dayInterval.end && eventEnd > dayInterval.start
    }

    static func deduplicated(_ rows: [LureliaEventUnifiedOccurrence]) -> [LureliaEventUnifiedOccurrence] {
        var seen = Set<AppleDedupKey>()
        var result: [LureliaEventUnifiedOccurrence] = []

        for row in rows {
            let keys = row.appleDedupKeys
            if keys.isEmpty || keys.isDisjoint(with: seen) {
                result.append(row)
                seen.formUnion(keys)
            }
        }

        return result
    }

    private struct AppleDedupKey: Hashable {
        let source: String
        let title: String?
        let start: Int
        let end: Int
        let isAllDay: Bool
    }

    private var appleDedupKeys: Set<AppleDedupKey> {
        guard isAppleOwned else { return [] }

        let titleKey = normalizedAppleTitle(title)
        let startKey = normalizedAppleTime(start)
        let endKey = normalizedAppleTime(end)
        var keys = Set<AppleDedupKey>()

        switch self {
        case .local(let occurrence):
            if let occurrenceKey = occurrence.appleOccurrenceKey?.trimmedNonEmptyForEventDedup {
                keys.insert(
                    AppleDedupKey(
                        source: "occurrence:\(occurrenceKey)",
                        title: nil,
                        start: startKey,
                        end: endKey,
                        isAllDay: occurrence.isAllDay
                    )
                )
            }

            if let seriesIdentifier = occurrence.appleSeriesIdentifier?.trimmedNonEmptyForEventDedup {
                keys.insert(
                    AppleDedupKey(
                        source: "series:\(seriesIdentifier)",
                        title: nil,
                        start: startKey,
                        end: endKey,
                        isAllDay: occurrence.isAllDay
                    )
                )
            }

            if let calendarIdentifier = occurrence.appleCalendarIdentifier?.trimmedNonEmptyForEventDedup {
                keys.insert(
                    AppleDedupKey(
                        source: "calendar:\(calendarIdentifier)",
                        title: titleKey,
                        start: startKey,
                        end: endKey,
                        isAllDay: occurrence.isAllDay
                    )
                )
            }

        case .apple(let occurrence):
            let occurrenceKey = occurrence.appleOccurrenceKey
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !occurrenceKey.isEmpty {
                keys.insert(
                    AppleDedupKey(
                        source: "occurrence:\(occurrenceKey)",
                        title: nil,
                        start: startKey,
                        end: endKey,
                        isAllDay: occurrence.isAllDay
                    )
                )
            }

            let seriesIdentifier = occurrence.appleSeriesIdentifier
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !seriesIdentifier.isEmpty {
                keys.insert(
                    AppleDedupKey(
                        source: "series:\(seriesIdentifier)",
                        title: nil,
                        start: startKey,
                        end: endKey,
                        isAllDay: occurrence.isAllDay
                    )
                )
            }

            let calendarIdentifier = occurrence.calendarIdentifier
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !calendarIdentifier.isEmpty {
                keys.insert(
                    AppleDedupKey(
                        source: "calendar:\(calendarIdentifier)",
                        title: titleKey,
                        start: startKey,
                        end: endKey,
                        isAllDay: occurrence.isAllDay
                    )
                )
            }
        }

        return keys
    }

    private func normalizedAppleTitle(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private func normalizedAppleTime(_ date: Date) -> Int {
        Int(date.timeIntervalSince1970.rounded())
    }
}

private extension String {
    var trimmedNonEmptyForEventDedup: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
