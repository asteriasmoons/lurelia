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

    // Journey reverse links
    var journeyID: UUID?
    var journeyMilestoneID: UUID?
    var journeyStepID: UUID?
    var journeyTimelineItemID: UUID?
    
    var isEnabled: Bool = true
    
    var scheduledDate: Date = Date()
    var additionalFireTimesStorage: String = "[]"
    
    var repeatUnit: LureliaReminderRepeatUnit = LureliaReminderRepeatUnit.none
    var repeatInterval: Int = 1
    
    var repeatWeekdays: [Int] = []
    var repeatMonthDay: Int?
    var repeatEndsAt: Date?
    
    var notificationID: String = UUID().uuidString

    var duplicatePreventionKey: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let scheduledMinute = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: scheduledDate)
        let datePart = [
            scheduledMinute.year,
            scheduledMinute.month,
            scheduledMinute.day,
            scheduledMinute.hour,
            scheduledMinute.minute
        ]
            .map { String($0 ?? -1) }
            .joined(separator: "-")
        let timesPart = timesOfDay.sorted().joined(separator: ",")
        let additionalTimesPart = additionalFireTimes
            .map { String(format: "%02d:%02d", $0.hour, $0.minute) }
            .sorted()
            .joined(separator: ",")
        let weekdaysPart = repeatWeekdays.sorted().map(String.init).joined(separator: ",")
        let taskPart = taskStableID ?? taskID?.uuidString ?? "no-task"
        let routinePart = routinePersistentID ?? "no-routine"

        return [
            trimmedTitle,
            trimmedCategory,
            kind.rawValue,
            taskPart,
            routinePart,
            datePart,
            repeatUnit.rawValue,
            String(repeatInterval),
            weekdaysPart,
            String(repeatMonthDay ?? -1),
            timesPart,
            additionalTimesPart
        ]
            .joined(separator: "|")
    }

    func isDuplicateConfiguration(of other: LureliaReminder) -> Bool {
        duplicatePreventionKey == other.duplicatePreventionKey
    }
    
    var isCompleted: Bool = false
    var completedAt: Date?
    
    var lastFiredAt: Date?
    var nextFireAt: Date?

    var historyEntries: [LureliaReminderHistory]?

    var completionTimestampsStorage: String = "[]"
    var skippedTimestampsStorage: String = "[]"
    var checklistItemsStorage: String = "[]"
    var levelsStorage: String = "[]"
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

    var checklistItems: [LureliaReminderChecklistItem] {
        get {
            guard let data = checklistItemsStorage.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([LureliaReminderChecklistItem].self, from: data)
            else {
                return []
            }

            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue),
                  let json = String(data: data, encoding: .utf8)
            else {
                checklistItemsStorage = "[]"
                return
            }

            checklistItemsStorage = json
            updatedAt = Date()
        }
    }

    var checklistCompletedCount: Int {
        checklistItems.filter { $0.isCompleted }.count
    }

    var checklistTotalCount: Int {
        checklistItems.count
    }

    var checklistProgress: Double {
        guard checklistTotalCount > 0 else { return 0 }
        return Double(checklistCompletedCount) / Double(checklistTotalCount)
    }

    var hasChecklist: Bool {
        !checklistItems.isEmpty
    }
    
    var levelCount: Int {
        levels.count
    }

    var hasLevels: Bool {
        !levels.isEmpty
    }
    
    var levels: [LureliaReminderLevel] {
        get {
            guard let data = levelsStorage.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([LureliaReminderLevel].self, from: data)
            else {
                return []
            }

            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue),
                  let json = String(data: data, encoding: .utf8)
            else {
                levelsStorage = "[]"
                return
            }

            levelsStorage = json
            updatedAt = Date()
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

    // MARK: - Detail fields

    var purpose: String?
    var importance: String?
    var reminderOutcome: String?
    var motivation: String?
    var consequences: String?
    var recoveryPlan: String?
    var friction: String?

    // MARK: - Temptation Bundling

    var temptationNeed: String?
    var temptationWant: String?

    // MARK: - Location

    var locationLabel: String?
    var locationAddress: String?
    var locationLatitude: Double?
    var locationLongitude: Double?
    
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
        let scheduledComponents = Calendar.current.dateComponents([.hour, .minute], from: scheduledDate)
        self.primaryHour = scheduledComponents.hour ?? -1
        self.primaryMinute = scheduledComponents.minute ?? -1
        self.timesOfDay = [String(format: "%02d:%02d", self.primaryHour, self.primaryMinute)]
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Streak Calculations

extension LureliaReminder {

    var hasLocation: Bool {
        locationLatitude != nil && locationLongitude != nil
    }

    var currentStreak: Int {
        guard repeatUnit != .none else {
            return isCompleted ? 1 : 0
        }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let sorted = completionTimestamps.map { cal.startOfDay(for: $0) }.sorted(by: >)
        let unique = Array(Set(sorted)).sorted(by: >)
        guard !unique.isEmpty else { return 0 }

        var streak = 0
        var cursor = today

        for day in unique {
            if day == cursor || day == cal.date(byAdding: .day, value: -1, to: cursor) {
                streak += 1
                cursor = day
            } else if day < cursor {
                break
            }
        }
        return streak
    }

    var longestStreak: Int {
        guard repeatUnit != .none else {
            return isCompleted ? 1 : 0
        }
        let cal = Calendar.current
        let sorted = Array(Set(completionTimestamps.map { cal.startOfDay(for: $0) })).sorted()
        guard !sorted.isEmpty else { return 0 }

        var longest = 1
        var current = 1
        for i in 1..<sorted.count {
            let diff = cal.dateComponents([.day], from: sorted[i - 1], to: sorted[i]).day ?? 0
            if diff == 1 {
                current += 1
                longest = max(longest, current)
            } else if diff > 1 {
                current = 1
            }
        }
        return longest
    }

    var lastCompletedDate: Date? {
        completionTimestamps.max()
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

struct LureliaReminderChecklistItem: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var isCompleted: Bool
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct LureliaReminderLevel: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
