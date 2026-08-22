//
//  LureliaHabit.swift
//  Lurelia
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Habit Frequency

enum LureliaHabitFrequency: String, Codable, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly"

    var label: String { rawValue }
}

// MARK: - Cue Type

enum LureliaCueType: String, Codable, CaseIterable, Identifiable {
    case visual = "Visual"
    case object = "Object"
    case location = "Location"
    case time = "Time"
    case person = "Person"
    case sound = "Sound"
    case existingHabit = "Existing Habit"

    var id: String { rawValue }

    var label: String { rawValue }

    var iconName: String {
        switch self {
        case .visual: return "eye"
        case .object: return "objects"
        case .location: return "lovelocation"
        case .time: return "clockwavy"
        case .person: return "profilewavy"
        case .sound: return "bells"
        case .existingHabit: return "repeatarrows"
        }
    }
}

// MARK: - Habit

@Model
final class LureliaHabit {

    // MARK: - Identity

    var id: UUID = UUID()

    // MARK: - Core

    var title: String = ""
    var details: String?
    var iconName: String?
    /// User-selected color for this habit's visual identity across the Habits system.
    /// Uses a safe fallback so pre-existing habits continue rendering correctly.
    var colorHex: String = "#7d19f7"
    var daysPerWeek: Int = 7
    var activeWeekdaysStorage: String = "[1,2,3,4,5,6,7]"
    var timesPerDay: Int = 1

    // MARK: - State

    var isArchived: Bool = false

    // MARK: - Notifications

    var _reminderEnabled: Bool = false
    var timesOfDayStorage: String = "[]"
    var reminderDaysOfWeekStorage: String = "[]"
    var alarmID: String?
    var alarmEnabled: Bool = false
    var alarmDate: Date?
    var alarmSoundName: String?
    var alarmFireTimesStorage: String = "[]"
    var alarmIDsStorage: String = "[]"

    // MARK: - Stats

    var statsResetAt: Date?

    // MARK: - Blueprint: Identity & Purpose

    var identityStatement: String?
    var habitPurpose: String?

    // MARK: - Blueprint: Implementation

    var implementationIntention: String?

    // MARK: - Blueprint: Cue

    var cueTypeRaw: String?
    var cueDescription: String?
    var cueReason: String?

    // MARK: - Blueprint: Environment

    var currentEnvironment: String?
    var idealEnvironment: String?
    var environmentChanges: String?

    // MARK: - Blueprint: Temptation Bundling

    var temptationNeed: String?
    var temptationWant: String?
    
    // MARK: - Blueprint: Friction

    var friction: String?
    
    // MARK: - Blueprint: Levels

    var levelsStorage: String = "[]"

    // MARK: - Blueprint: Rules (JSON array)

    var habitRulesStorage: String?

    // MARK: - Blueprint: Obstacles & Solutions (JSON arrays)

    var habitObstaclesStorage: String?
    var habitSolutionsStorage: String?

    // MARK: - Blueprint: Rewards

    var immediateReward: String?
    var longTermReward: String?

    // MARK: - Metadata

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // MARK: - Relationships

    @Relationship(deleteRule: .cascade, inverse: \LureliaHabitLog.habit)
    var logs: [LureliaHabitLog]?

    @Relationship(deleteRule: .cascade, inverse: \LureliaHabitSkip.habit)
    var skips: [LureliaHabitSkip]?

    // MARK: - Init

    init(
        title: String,
        details: String? = nil,
        iconName: String? = nil,
        daysPerWeek: Int = 7,
        timesPerDay: Int = 1
    ) {
        self.id = UUID()
        self.title = title
        self.details = details
        self.iconName = iconName
        self.daysPerWeek = max(1, min(7, daysPerWeek))
        self.timesPerDay = max(1, timesPerDay)
        self.isArchived = false
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Helpers

extension LureliaHabit {

    var target: Int {
        max(1, timesPerDay)
    }

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Resolved SwiftUI color for this habit, with a safe fallback so existing
    /// habits without a user-selected color continue rendering correctly.
    var color: Color {
        let trimmed = colorHex.trimmingCharacters(in: .whitespacesAndNewlines)
        return Color(lureliaHex: trimmed.isEmpty ? "#7d19f7" : trimmed)
    }

    // MARK: - Blueprint computed helpers

    var cueType: LureliaCueType? {
        get {
            guard let raw = cueTypeRaw else { return nil }
            return LureliaCueType(rawValue: raw)
        }
        set {
            cueTypeRaw = newValue?.rawValue
            updatedAt = Date()
        }
    }

    var habitRules: [String] {
        get {
            guard let s = habitRulesStorage,
                  let data = s.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue),
                  let json = String(data: data, encoding: .utf8) else {
                habitRulesStorage = nil
                return
            }
            habitRulesStorage = newValue.isEmpty ? nil : json
            updatedAt = Date()
        }
    }

    var habitObstacles: [String] {
        get {
            guard let s = habitObstaclesStorage,
                  let data = s.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue),
                  let json = String(data: data, encoding: .utf8) else {
                habitObstaclesStorage = nil
                return
            }
            habitObstaclesStorage = newValue.isEmpty ? nil : json
            updatedAt = Date()
        }
    }

    var habitSolutions: [String] {
        get {
            guard let s = habitSolutionsStorage,
                  let data = s.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue),
                  let json = String(data: data, encoding: .utf8) else {
                habitSolutionsStorage = nil
                return
            }
            habitSolutionsStorage = newValue.isEmpty ? nil : json
            updatedAt = Date()
        }
    }
    
    var levels: [LureliaHabitLevel] {
        get {
            guard let data = levelsStorage.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([LureliaHabitLevel].self, from: data)
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

    var levelCount: Int {
        levels.count
    }

    var hasLevels: Bool {
        !levels.isEmpty
    }

    var hasBlueprint: Bool {
        identityStatement?.isEmpty == false ||
        habitPurpose?.isEmpty == false ||
        implementationIntention?.isEmpty == false ||
        cueType != nil ||
        cueDescription?.isEmpty == false ||
        !habitRules.isEmpty ||
        !habitObstacles.isEmpty ||
        immediateReward?.isEmpty == false ||
        longTermReward?.isEmpty == false ||
        currentEnvironment?.isEmpty == false ||
        idealEnvironment?.isEmpty == false ||
        environmentChanges?.isEmpty == false
        || friction?.isEmpty == false
        || hasLevels
    }

    // MARK: - Active weekdays

    var activeWeekdays: [Int] {
        get {
            guard let data = activeWeekdaysStorage.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([Int].self, from: data)
            else {
                return [1, 2, 3, 4, 5, 6, 7]
            }

            let sanitized = decoded
                .filter { (1...7).contains($0) }
                .sorted()

            return sanitized.isEmpty
                ? [1, 2, 3, 4, 5, 6, 7]
                : sanitized
        }
        set {
            let sanitized = Array(Set(newValue))
                .filter { (1...7).contains($0) }
                .sorted()

            let final = sanitized.isEmpty
                ? [1, 2, 3, 4, 5, 6, 7]
                : sanitized

            if let data = try? JSONEncoder().encode(final),
               let json = String(data: data, encoding: .utf8) {
                activeWeekdaysStorage = json
            }

            daysPerWeek = final.count
            updatedAt = Date()
        }
    }

    func isActiveOn(_ date: Date, calendar: Calendar = .current) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return activeWeekdays.contains(weekday)
    }

    // MARK: - Stats reset filtering

    func includeLog(_ log: LureliaHabitLog) -> Bool {
        guard let reset = statsResetAt else { return true }
        let cal = Calendar.current
        let resetDay = cal.startOfDay(for: reset)
        let logDay = cal.startOfDay(for: log.dayStart)
        if logDay > resetDay { return true }
        if logDay < resetDay { return false }
        return log.createdAt >= reset
    }

    func includeSkip(_ skip: LureliaHabitSkip) -> Bool {
        guard let reset = statsResetAt else { return true }
        let cal = Calendar.current
        let resetDay = cal.startOfDay(for: reset)
        let skipDay = cal.startOfDay(for: skip.dayStart)
        if skipDay > resetDay { return true }
        if skipDay < resetDay { return false }
        return skip.createdAt >= reset
    }

    // MARK: - Today

    func todaysLog(calendar: Calendar = .current) -> LureliaHabitLog? {
        let today = calendar.startOfDay(for: Date())
        return (logs ?? []).first { calendar.isDate($0.dayStart, inSameDayAs: today) }
    }

    func todaysSkip(calendar: Calendar = .current) -> LureliaHabitSkip? {
        let today = calendar.startOfDay(for: Date())
        return (skips ?? []).first { calendar.isDate($0.dayStart, inSameDayAs: today) }
    }

    var todaysCount: Int {
        todaysLog()?.count ?? 0
    }

    var progress: Double {
        guard target > 0 else { return 0 }
        return min(Double(todaysCount) / Double(target), 1.0)
    }

    var isCompletedToday: Bool {
        todaysCount >= target
    }

    func log(on day: Date, calendar: Calendar = .current) -> LureliaHabitLog? {
        let dayStart = calendar.startOfDay(for: day)
        return (logs ?? []).first { calendar.isDate($0.dayStart, inSameDayAs: dayStart) }
    }

    func skip(on day: Date, calendar: Calendar = .current) -> LureliaHabitSkip? {
        let dayStart = calendar.startOfDay(for: day)
        return (skips ?? []).first { calendar.isDate($0.dayStart, inSameDayAs: dayStart) }
    }

    func count(on day: Date, calendar: Calendar = .current) -> Int {
        log(on: day, calendar: calendar)?.count ?? 0
    }

    func progress(on day: Date, calendar: Calendar = .current) -> Double {
        guard target > 0 else { return 0 }
        return min(Double(count(on: day, calendar: calendar)) / Double(target), 1.0)
    }

    func isCompleted(on day: Date, calendar: Calendar = .current) -> Bool {
        count(on: day, calendar: calendar) >= target
    }

    func isSkipped(on day: Date, calendar: Calendar = .current) -> Bool {
        skip(on: day, calendar: calendar) != nil
    }

    func fireDates(on day: Date, calendar: Calendar = .current) -> [Date] {
        guard !isArchived, isActiveOn(day, calendar: calendar) else { return [] }

        let selectedTimes = decodedTimesOfDay
            .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let timeStrings = selectedTimes.isEmpty ? ["09:00"] : selectedTimes
        let dayStart = calendar.startOfDay(for: day)

        return timeStrings.compactMap { timeString -> Date? in
            let parts = timeString.split(separator: ":")
            guard parts.count == 2,
                  let hour = Int(parts[0]),
                  let minute = Int(parts[1]),
                  (0...23).contains(hour),
                  (0...59).contains(minute)
            else {
                return nil
            }

            var components = calendar.dateComponents([.year, .month, .day], from: dayStart)
            components.hour = hour
            components.minute = minute
            components.second = 0
            return calendar.date(from: components)
        }
        .sorted()
    }

    private var decodedTimesOfDay: [String] {
        guard let data = timesOfDayStorage.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }

        return decoded
    }

    // MARK: - Streak helpers

    private var completedDayStarts: Set<Date> {
        Set((logs ?? [])
            .filter { includeLog($0) && $0.count >= target }
            .map { Calendar.current.startOfDay(for: $0.dayStart) })
    }

    private var skippedDayStarts: Set<Date> {
        Set((skips ?? [])
            .filter { includeSkip($0) }
            .map { Calendar.current.startOfDay(for: $0.dayStart) })
    }

    func isCompletedDay(_ day: Date) -> Bool {
        completedDayStarts.contains(Calendar.current.startOfDay(for: day))
    }

    func isSkippedDay(_ day: Date) -> Bool {
        skippedDayStarts.contains(Calendar.current.startOfDay(for: day))
    }

    var dailyStreak: Int {
        let cal = Calendar.current
        var cursor = cal.startOfDay(for: Date())

        if !isCompletedDay(cursor) && !isSkippedDay(cursor) {
            cursor = cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }

        var streak = 0
        while true {
            if !isActiveOn(cursor, calendar: cal) {
                guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
                cursor = prev
                continue
            }
            if isCompletedDay(cursor) {
                streak += 1
            } else if isSkippedDay(cursor) {
                // skipped days protect the streak without incrementing
            } else {
                break
            }
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    var weeklyStreak: Int {
        let cal = Calendar.current
        var cursor = weekStart(for: Date())

        if !weekMet(weekStarting: cursor) {
            cursor = cal.date(byAdding: .weekOfYear, value: -1, to: cursor) ?? cursor
        }

        var streak = 0
        while weekMet(weekStarting: cursor) {
            streak += 1
            guard let prev = cal.date(byAdding: .weekOfYear, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    private func weekStart(for date: Date) -> Date {
        Calendar.current.dateInterval(of: .weekOfYear, for: date)?.start
            ?? Calendar.current.startOfDay(for: date)
    }

    private func weekMet(weekStarting start: Date) -> Bool {
        guard let interval = Calendar.current.dateInterval(of: .weekOfYear, for: start) else { return false }

        let activeDaysInWeek = activeWeekdays.filter { weekday in
            guard let sample = Calendar.current.date(byAdding: .day, value: weekday - 1, to: interval.start) else {
                return false
            }
            return interval.contains(sample)
        }

        var completedDays = Set<Date>()
        for log in logs ?? [] {
            guard includeLog(log) else { continue }
            let d = Calendar.current.startOfDay(for: log.dayStart)
            if interval.contains(d), log.count >= target { completedDays.insert(d) }
        }

        var skippedDays = Set<Date>()
        for skip in skips ?? [] {
            guard includeSkip(skip) else { continue }
            let d = Calendar.current.startOfDay(for: skip.dayStart)
            if interval.contains(d) { skippedDays.insert(d) }
        }

        return completedDays.union(skippedDays).count >= max(1, activeDaysInWeek.count)
    }
}

struct LureliaHabitLevel: Codable, Identifiable, Hashable {
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
