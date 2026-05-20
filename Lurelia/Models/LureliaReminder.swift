//
//  LureliaReminder.swift
//  Lurelia
//

import Foundation
import SwiftData

enum LureliaReminderKind: String, Codable, CaseIterable {
    case standalone = "Standalone"
    case task = "Task"
    case routine = "Routine"
}

enum LureliaReminderRepeatUnit: String, Codable, CaseIterable {
    case none = "None"
    case minutes = "Minutes"
    case hours = "Hours"
    case days = "Days"
    case weeks = "Weeks"
    case months = "Months"
    case years = "Years"
}

@Model
final class LureliaReminder {
    
    var id: UUID = UUID()
    
    var title: String = ""
    var icon: String = "bellfill"
    var notes: String?
    var category: String = ""
    
    var kind: LureliaReminderKind = LureliaReminderKind.standalone
    
    var taskID: UUID?
    var taskStableID: String?
    var routinePersistentID: String?
    
    var isEnabled: Bool = true
    
    var scheduledDate: Date = Date()
    var additionalFireTimesStorage: String = "[]"
    
    var repeatUnit: LureliaReminderRepeatUnit = LureliaReminderRepeatUnit.none
    var repeatInterval: Int = 1
    
    var repeatWeekdays: [Int] = []
    var repeatMonthDay: Int?
    var repeatEndsAt: Date?
    
    var notificationID: String = UUID().uuidString
    
    var isCompleted: Bool = false
    var completedAt: Date?
    
    var lastFiredAt: Date?
    var nextFireAt: Date?
    var completionTimestampsStorage: String = "[]"
    var skippedTimestampsStorage: String = "[]"
    var primaryHour: Int = -1
    var primaryMinute: Int = -1
    // All configured fire times as "HH:mm" 24-hour strings — single source of truth
    var timesOfDayStorage: String = "[]"

    var timesOfDay: [String] {
        get {
            guard let data = timesOfDayStorage.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue),
                  let json = String(data: data, encoding: .utf8) else {
                timesOfDayStorage = "[]"
                return
            }
            timesOfDayStorage = json
        }
    }

    var completionTimestamps: [Date] {
        get {
            guard let data = completionTimestampsStorage.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([Date].self, from: data) else { return [] }
            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue),
                  let json = String(data: data, encoding: .utf8) else {
                completionTimestampsStorage = "[]"
                return
            }
            completionTimestampsStorage = json
        }
    }

    var skippedTimestamps: [Date] {
        get {
            guard let data = skippedTimestampsStorage.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([Date].self, from: data) else { return [] }
            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue),
                  let json = String(data: data, encoding: .utf8) else {
                skippedTimestampsStorage = "[]"
                return
            }
            skippedTimestampsStorage = json
        }
    }

    // MARK: - Daily Completion Helpers

    func isDue(on day: Date, calendar: Calendar = .current) -> Bool {
        let targetDay = calendar.startOfDay(for: day)
        let scheduledDay = calendar.startOfDay(for: scheduledDate)

        if repeatUnit == .none {
            return calendar.isDate(scheduledDate, inSameDayAs: targetDay)
        }

        guard targetDay >= scheduledDay else { return false }

        if let repeatEndsAt,
           targetDay > calendar.startOfDay(for: repeatEndsAt) {
            return false
        }

        switch repeatUnit {
        case .none:
            return calendar.isDate(scheduledDate, inSameDayAs: targetDay)

        case .minutes, .hours, .days:
            let components = calendar.dateComponents([.day], from: scheduledDay, to: targetDay)
            guard let daysBetween = components.day else { return false }

            if repeatUnit == .days {
                return daysBetween % max(1, repeatInterval) == 0
            }

            return true

        case .weeks:
            let weekday = calendar.component(.weekday, from: targetDay)

            if !repeatWeekdays.isEmpty,
               !repeatWeekdays.contains(weekday) {
                return false
            }

            let components = calendar.dateComponents([.weekOfYear], from: scheduledDay, to: targetDay)
            guard let weeksBetween = components.weekOfYear else { return false }
            return weeksBetween % max(1, repeatInterval) == 0

        case .months:
            let dayComponent = calendar.component(.day, from: targetDay)
            let targetMonthDay = repeatMonthDay ?? calendar.component(.day, from: scheduledDate)
            guard dayComponent == targetMonthDay else { return false }

            let components = calendar.dateComponents([.month], from: scheduledDay, to: targetDay)
            guard let monthsBetween = components.month else { return false }
            return monthsBetween % max(1, repeatInterval) == 0

        case .years:
            let targetComponents = calendar.dateComponents([.month, .day], from: targetDay)
            let scheduledComponents = calendar.dateComponents([.month, .day], from: scheduledDate)
            guard targetComponents.month == scheduledComponents.month,
                  targetComponents.day == scheduledComponents.day else { return false }

            let components = calendar.dateComponents([.year], from: scheduledDay, to: targetDay)
            guard let yearsBetween = components.year else { return false }
            return yearsBetween % max(1, repeatInterval) == 0
        }
    }

    func wasCompleted(on day: Date, calendar: Calendar = .current) -> Bool {
        if let completedAt,
           calendar.isDate(completedAt, inSameDayAs: day) {
            return true
        }

        return completionTimestamps.contains { timestamp in
            calendar.isDate(timestamp, inSameDayAs: day)
        }
    }

    func countsTowardFullCompletion(on day: Date, calendar: Calendar = .current) -> Bool {
        isDue(on: day, calendar: calendar) && wasCompleted(on: day, calendar: calendar)
    }
    
    var additionalFireTimes: [LureliaAdditionalFireTime] {
        get {
            guard let data = additionalFireTimesStorage.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([LureliaAdditionalFireTime].self, from: data) else {
                return []
            }

            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue),
                  let json = String(data: data, encoding: .utf8) else {
                additionalFireTimesStorage = "[]"
                return
            }

            additionalFireTimesStorage = json
        }
    }
    
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    init(
        title: String,
        icon: String = "bellfill",
        notes: String? = nil,
        category: String = "",
        kind: LureliaReminderKind = .standalone,
        scheduledDate: Date = Date(),
        repeatUnit: LureliaReminderRepeatUnit = .none,
        repeatInterval: Int = 1
    ) {
        self.id = UUID()
        self.title = title
        self.icon = icon
        self.notes = notes
        self.category = category
        self.kind = kind
        self.taskStableID = nil
        self.scheduledDate = scheduledDate
        self.repeatUnit = repeatUnit
        self.repeatInterval = max(1, repeatInterval)
        self.notificationID = UUID().uuidString
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

struct LureliaAdditionalFireTime: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var hour: Int
    var minute: Int

    init(
        id: UUID = UUID(),
        hour: Int,
        minute: Int
    ) {
        self.id = id
        self.hour = hour
        self.minute = minute
    }
}
