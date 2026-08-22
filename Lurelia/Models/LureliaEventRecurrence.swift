//
//  LureliaEventRecurrence.swift
//  Lurelia
//

import Foundation
import SwiftData

enum LureliaEventFrequency: String, Codable, CaseIterable, Identifiable {
    case daily
    case weekly
    case monthly
    case yearly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }
}

enum LureliaEventWeekday: Int, Codable, CaseIterable, Identifiable {
    case sunday = 1
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday

    var id: Int { rawValue }

    var shortLabel: String {
        switch self {
        case .sunday: return "S"
        case .monday: return "M"
        case .tuesday: return "T"
        case .wednesday: return "W"
        case .thursday: return "T"
        case .friday: return "F"
        case .saturday: return "S"
        }
    }

    var label: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }
}

enum LureliaEventRecurrenceEndType: String, Codable, CaseIterable, Identifiable {
    case never
    case onDate
    case afterOccurrences

    var id: String { rawValue }

    var label: String {
        switch self {
        case .never: return "Never"
        case .onDate: return "On Date"
        case .afterOccurrences: return "After Count"
        }
    }
}

@Model
final class LureliaEventRecurrence {
    var id: UUID = UUID()
    var frequencyRaw: String = LureliaEventFrequency.daily.rawValue
    var interval: Int = 1
    var weekdaysStorage: String = "[]"
    var dayOfMonth: Int?
    var weekOfMonth: Int?
    var weekdayOfMonthRaw: Int?
    var month: Int?
    var day: Int?
    var endTypeRaw: String = LureliaEventRecurrenceEndType.never.rawValue
    var endDate: Date?
    var occurrenceCount: Int?
    var excludedDatesStorage: String = "[]"
    var event: LureliaEvent?

    init(
        frequency: LureliaEventFrequency = .daily,
        interval: Int = 1,
        weekdays: [LureliaEventWeekday] = [],
        endType: LureliaEventRecurrenceEndType = .never
    ) {
        self.id = UUID()
        self.frequency = frequency
        self.interval = max(1, interval)
        self.weekdays = weekdays
        self.endType = endType
    }
}

extension LureliaEventRecurrence {
    var frequency: LureliaEventFrequency {
        get { LureliaEventFrequency(rawValue: frequencyRaw) ?? .daily }
        set { frequencyRaw = newValue.rawValue }
    }

    var weekdays: [LureliaEventWeekday] {
        get {
            guard let data = weekdaysStorage.data(using: .utf8),
                  let values = try? JSONDecoder().decode([Int].self, from: data) else { return [] }
            return values.compactMap { LureliaEventWeekday(rawValue: $0) }
        }
        set {
            let values = newValue.map(\.rawValue).sorted()
            if let data = try? JSONEncoder().encode(values),
               let json = String(data: data, encoding: .utf8) {
                weekdaysStorage = json
            }
        }
    }

    var weekdayOfMonth: LureliaEventWeekday? {
        get {
            guard let weekdayOfMonthRaw else { return nil }
            return LureliaEventWeekday(rawValue: weekdayOfMonthRaw)
        }
        set { weekdayOfMonthRaw = newValue?.rawValue }
    }

    var endType: LureliaEventRecurrenceEndType {
        get { LureliaEventRecurrenceEndType(rawValue: endTypeRaw) ?? .never }
        set { endTypeRaw = newValue.rawValue }
    }

    var excludedDates: [Date] {
        get {
            guard let data = excludedDatesStorage.data(using: .utf8),
                  let values = try? JSONDecoder().decode([Date].self, from: data) else { return [] }
            return values
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let json = String(data: data, encoding: .utf8) {
                excludedDatesStorage = json
            }
        }
    }
}
