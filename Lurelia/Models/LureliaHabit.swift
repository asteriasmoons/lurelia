//
//  LureliaHabit.swift
//  Lurelia
//

import Foundation
import SwiftData

// MARK: - Habit Frequency

enum LureliaHabitFrequency: String, Codable, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly"

    var label: String { rawValue }
}

// MARK: - Habit

@Model
final class LureliaHabit {

    // MARK: - Identity

    var id: UUID = UUID()

    // MARK: - Core

    var title: String = ""
    var details: String?
    var daysPerWeek: Int = 7
    var timesPerDay: Int = 1

    // MARK: - State

    var isArchived: Bool = false

    // MARK: - Notifications

    var _reminderEnabled: Bool = false
    var timesOfDayStorage: String = "[]"
    var reminderDaysOfWeekStorage: String = "[]"

    // MARK: - Stats

    var statsResetAt: Date?

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
        daysPerWeek: Int = 7,
        timesPerDay: Int = 1
    ) {
        self.id = UUID()
        self.title = title
        self.details = details
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

        return completedDays.union(skippedDays).count >= max(1, daysPerWeek)
    }
}
