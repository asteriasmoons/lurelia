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
        case .apple: return "starcal"
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
}
